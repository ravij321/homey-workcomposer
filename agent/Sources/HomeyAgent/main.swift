import Foundation
import AppKit

struct Config {
    let apiURL: URL
    let deviceID: String
    let agentToken: String
    let enabled: Bool
    let minInterval: TimeInterval
    let maxInterval: TimeInterval
    let retentionDays: Int

    static func load() -> Config? {
        let env = ProcessInfo.processInfo.environment
        guard let rawURL = env["HOMEY_API_URL"], let url = URL(string: rawURL),
              let deviceID = env["HOMEY_DEVICE_ID"], let token = env["HOMEY_AGENT_TOKEN"] else { return nil }
        let enabled = env["SCREENSHOT_MONITORING_ENABLED"]?.lowercased() == "true"
        let min = Double(env["SCREENSHOT_MIN_INTERVAL_MINUTES"] ?? "20") ?? 20
        let max = Double(env["SCREENSHOT_MAX_INTERVAL_MINUTES"] ?? "40") ?? 40
        let retention = Int(env["SCREENSHOT_RETENTION_DAYS"] ?? "30") ?? 30
        return Config(apiURL: url, deviceID: deviceID, agentToken: token, enabled: enabled,
                      minInterval: max(1, min), maxInterval: max(min, max), retentionDays: max(1, retention))
    }
}

final class HomeyAgent {
    private let config: Config
    private let session: URLSession
    private var timer: Timer?

    init(config: Config) {
        self.config = config
        self.session = URLSession(configuration: .ephemeral)
    }

    func start() {
        report(status: config.enabled ? "running" : "disabled")
        guard config.enabled else { return }
        scheduleNextCapture()
    }

    private func scheduleNextCapture() {
        let seconds = Double.random(in: config.minInterval * 60 ... config.maxInterval * 60)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.captureAndUpload()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func captureAndUpload() {
        // macOS itself decides whether Screen Recording permission is available.
        let task = Process()
        let errorPipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("homey-\(UUID().uuidString).png")
        task.arguments = ["-x", temp.path]
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else {
                report(status: "permission_required")
                scheduleNextCapture()
                return
            }
            upload(file: temp)
        } catch {
            report(status: "capture_failed")
            scheduleNextCapture()
        }
    }

    private func upload(file: URL) {
        guard let data = try? Data(contentsOf: file) else { scheduleNextCapture(); return }
        var request = URLRequest(url: config.apiURL.appendingPathComponent("api/screenshots/agent-upload"))
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(config.deviceID, forHTTPHeaderField: "X-Homey-Device-ID")
        request.setValue(config.agentToken, forHTTPHeaderField: "X-Homey-Agent-Token")
        request.setValue("1.0.0", forHTTPHeaderField: "X-Homey-Agent-Version")
        request.httpBody = data

        session.dataTask(with: request) { [weak self] _, response, _ in
            try? FileManager.default.removeItem(at: file)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                self?.report(status: "upload_failed")
            }
            self?.scheduleNextCapture()
        }.resume()
    }

    private func report(status: String) {
        var request = URLRequest(url: config.apiURL.appendingPathComponent("api/agent/status"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.deviceID, forHTTPHeaderField: "X-Homey-Device-ID")
        request.setValue(config.agentToken, forHTTPHeaderField: "X-Homey-Agent-Token")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "status": status,
            "agentVersion": "1.0.0",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "screenshotMonitoring": config.enabled,
            "retentionDays": config.retentionDays
        ])
        session.dataTask(with: request).resume()
    }
}

if let config = Config.load() {
    HomeyAgent(config: config).start()
    RunLoop.main.run()
} else {
    fputs("HomeyAgent: HOMEY_API_URL, HOMEY_DEVICE_ID or HOMEY_AGENT_TOKEN missing\n", stderr)
    exit(2)
}
