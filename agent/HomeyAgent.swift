import Foundation
import IOKit

struct AgentConfig: Codable {
    let apiURL: URL
    let deviceID: String
    let heartbeatSeconds: Int
    let collectApplicationUsage: Bool
    let screenshotMonitoringEnabled: Bool
}

struct Event: Codable {
    let deviceID: String
    let type: String
    let timestamp: String
    let payload: [String: String]
}

final class HomeyAgent {
    private let config: AgentConfig
    private let session: URLSession

    init(config: AgentConfig) {
        self.config = config
        self.session = URLSession(configuration: .ephemeral)
    }

    func run() async {
        await send(type: "agent_started", payload: ["version": "1.0.0"])
        while true {
            await send(type: "heartbeat", payload: [
                "hostname": Host.current().localizedName ?? "unknown",
                "os": ProcessInfo.processInfo.operatingSystemVersionString
            ])
            try? await Task.sleep(for: .seconds(max(30, config.heartbeatSeconds)))
        }
    }

    private func send(type: String, payload: [String: String]) async {
        let event = Event(
            deviceID: config.deviceID,
            type: type,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            payload: payload
        )
        guard let url = URL(string: "/api/agent/events", relativeTo: config.apiURL),
              var request = URLRequest(url: url) as URLRequest? else { return }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(event)
        _ = try? await session.data(for: request)
    }
}

func loadConfig() throws -> AgentConfig {
    let path = "/Library/Application Support/HomeyWorkInsights/config.json"
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(AgentConfig.self, from: data)
}

@main
struct Main {
    static func main() async {
        do {
            let config = try loadConfig()
            await HomeyAgent(config: config).run()
        } catch {
            FileHandle.standardError.write(Data("HomeyAgent configuration error: \(error)\n".utf8))
            exit(1)
        }
    }
}
