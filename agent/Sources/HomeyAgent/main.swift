import Foundation
import AppKit

struct Config: Codable {
    let apiURL: URL
    let deviceID: String
    let enabled: Bool
    let minInterval: TimeInterval
    let maxInterval: TimeInterval
    let retentionDays: Int

    static func load() -> Config? {
        let env = ProcessInfo.processInfo.environment
        guard let rawURL = env["HOMEY_API_URL"], let url = URL(string: rawURL),
              let deviceID = env["HOMEY_DEVICE_ID"] else { return nil }
        let enabled = env["SCREENSHOT_MONITORING_ENABLED"]?.lowercased() == "true"
        let min = Double(env["SCREENSHOT_MIN_INTERVAL_MINUTES"] ?? "20") ?? 20
        let max = Double(env["SCREENSHOT_MAX_INTERVAL_MINUTES"] ?? "40") ?? 40
        let retention = Int(env["SCREENSHOT_RETENTION_DAYS"] ?? "30") ?? 30
        return Config(apiURL: url, deviceID: deviceID, enabled: enabled,
                      minInterval: max(1, min), maxInterval: max(min, max),
                      retentionDays: max(1, retention))
    }
}

final class HomeyAgent {
    private let config: Config
    private let session: URLSession
    private var timer: Timer?

    init(config: Config) {
        self.config = config
        let delegate = SessionDelegate()
        self.session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
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
        guard NSApp.activationPolicy() != .prohibited else {
            report(status: "permission_required")
            scheduleNextCapture()
            return
        }

        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("homey-\(UUID().uuidString).png")
        task.arguments = ["-x", temp.path]
        task.standardError = pipe

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
        var request = URLRequest(url: config.apiURL.appendingPathComponent("api/agent/screenshots"))
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(config.deviceID, forHTTPHeaderField: "X-Homey-Device-ID")
        request.setValue("1", forHTTPHeaderField: "X-Homey-Agent-Version")
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
        let body: [String: Any] = [
            "status": status,
            "agentVersion": "1.0.0",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "screenshotMonitoring": config.enabled,
            "retentionDays": config.retentionDays
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        session.dataTask(with: request).resume()
    }
}

final class SessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }
}

if let config = Config.load() {
    let agent = HomeyAgent(config: config)
    agent.start()
    RunLoop.main.run()
} else {
    fputs("HomeyAgent: missing HOMEY_API_URL or HOMEY_DEVICE_ID\n", stderr)
    exit(2)
}
