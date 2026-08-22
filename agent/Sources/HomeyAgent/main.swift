import Foundation
import AppKit
import Security

struct Config: Codable {
    let apiURL: URL
    let deviceID: String
    let enabled: Bool
    let minIntervalMinutes: Double
    let maxIntervalMinutes: Double
    let retentionDays: Int

    static func load() -> Config? {
        let env = ProcessInfo.processInfo.environment
        let path = env["HOMEY_CONFIG_PATH"] ?? "\(NSHomeDirectory())/Library/Application Support/Homey Work Insights/config.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let config = try? JSONDecoder().decode(Config.self, from: data) {
            return config
        }
        guard let rawURL = env["HOMEY_API_URL"], let url = URL(string: rawURL),
              let deviceID = env["HOMEY_DEVICE_ID"] else { return nil }
        let enabled = env["SCREENSHOT_MONITORING_ENABLED"]?.lowercased() == "true"
        return Config(apiURL: url, deviceID: deviceID, enabled: enabled,
                      minIntervalMinutes: Double(env["SCREENSHOT_MIN_INTERVAL_MINUTES"] ?? "20") ?? 20,
                      maxIntervalMinutes: Double(env["SCREENSHOT_MAX_INTERVAL_MINUTES"] ?? "40") ?? 40,
                      retentionDays: Int(env["SCREENSHOT_RETENTION_DAYS"] ?? "30") ?? 30)
    }
}

final class KeychainToken {
    static let service = "com.homey.work-insights.agent.token"

    static func read() -> String? {
        let account = NSUserName()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

final class HomeyAgent {
    private let config: Config
    private let token: String
    private let session: URLSession
    private var timer: Timer?

    init(config: Config, token: String) {
        self.config = config
        self.token = token
        self.session = URLSession(configuration: .ephemeral)
    }

    func start() {
        report(status: config.enabled ? "running" : "disabled")
        guard config.enabled else { return }
        scheduleNextCapture()
    }

    private func scheduleNextCapture() {
        let min = max(1, config.minIntervalMinutes)
        let max = max(min, config.maxIntervalMinutes)
        let seconds = Double.random(in: min * 60 ... max * 60)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.captureAndUpload()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func captureAndUpload() {
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
        request.setValue(token, forHTTPHeaderField: "X-Homey-Agent-Token")
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
        request.setValue(token, forHTTPHeaderField: "X-Homey-Agent-Token")
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

if let config = Config.load(), let token = KeychainToken.read() {
    HomeyAgent(config: config, token: token).start()
    RunLoop.main.run()
} else {
    fputs("HomeyAgent: configuration or Keychain token missing\n", stderr)
    exit(2)
}
