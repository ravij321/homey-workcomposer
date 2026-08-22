import Foundation
import IOKit
import CoreGraphics

struct AgentConfig: Codable {
    let apiURL: URL
    let deviceID: String
    let agentToken: String
    let heartbeatSeconds: Int
    let collectApplicationUsage: Bool
    let screenshotMonitoringEnabled: Bool
    let activityIntervalSeconds: Int
    let idleThresholdSeconds: Int
}

struct Event: Codable {
    let deviceID: String
    let type: String
    let timestamp: String
    let durationMinutes: Int?
    let application: String?
    let metadata: [String: String]
}

final class HomeyAgent {
    private let config: AgentConfig
    private let session: URLSession
    private let formatter = ISO8601DateFormatter()

    init(config: AgentConfig) {
        self.config = config
        self.session = URLSession(configuration: .ephemeral)
    }

    func run() async {
        await send(type: "agent_started", durationMinutes: nil, application: nil, metadata: ["version": "1.0.1"])

        async let heartbeatLoop: Void = heartbeat()
        async let activityLoop: Void = activity()
        _ = await (heartbeatLoop, activityLoop)
    }

    private func heartbeat() async {
        while true {
            await send(type: "heartbeat", durationMinutes: nil, application: nil, metadata: [
                "hostname": Host.current().localizedName ?? "unknown",
                "os": ProcessInfo.processInfo.operatingSystemVersionString
            ])
            try? await Task.sleep(for: .seconds(max(30, config.heartbeatSeconds)))
        }
    }

    private func activity() async {
        let interval = max(30, config.activityIntervalSeconds)
        while true {
            let idleSeconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
            let isActive = idleSeconds < Double(max(60, config.idleThresholdSeconds))
            let minutes = max(1, Int(round(Double(interval) / 60.0)))

            if isActive || config.collectApplicationUsage {
                await send(
                    type: isActive ? "active_minute" : "idle_minute",
                    durationMinutes: minutes,
                    application: nil,
                    metadata: [
                        "idleSeconds": String(Int(idleSeconds)),
                        "state": isActive ? "active" : "idle"
                    ]
                )
            }

            try? await Task.sleep(for: .seconds(interval))
        }
    }

    private func send(type: String, durationMinutes: Int?, application: String?, metadata: [String: String]) async {
        guard !config.agentToken.isEmpty,
              let url = URL(string: "/api/agent/events", relativeTo: config.apiURL) else { return }

        let event = Event(
            deviceID: config.deviceID,
            type: type,
            timestamp: formatter.string(from: Date()),
            durationMinutes: durationMinutes,
            application: application,
            metadata: metadata
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.agentToken, forHTTPHeaderField: "X-Homey-Agent-Token")
        request.setValue(config.deviceID, forHTTPHeaderField: "X-Homey-Device-ID")
        request.httpBody = try? JSONEncoder().encode(event)
        _ = try? await session.data(for: request)
    }
}

func loadConfig() throws -> AgentConfig {
    let path = "/Library/Application Support/HomeyWorkInsights/config.json"
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(AgentConfig.self, from: data)
}

Task {
    do {
        let config = try loadConfig()
        await HomeyAgent(config: config).run()
    } catch {
        FileHandle.standardError.write(Data("HomeyAgent configuration error: \(error)\n".utf8))
        exit(1)
    }
}

RunLoop.main.run()
