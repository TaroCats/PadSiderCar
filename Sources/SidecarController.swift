import Foundation

class SidecarController {
    static let shared = SidecarController()

    private var bridgePath: String {
        Bundle.main.path(forResource: "SidecarBridge", ofType: nil) ?? "/Users/taro/Git/padSidecar/SidecarBridge"
    }

    enum Status { case connected, disconnected, unknown }

    func currentStatus() -> Status {
        let result = runBridge(args: ["status"])
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if output == "CONNECTED" { return .connected }
        if output == "DISCONNECTED" { return .disconnected }
        return .unknown
    }

    func connect(toId: String? = nil) -> Bool {
        var args = ["connect"]
        if let id = toId { args.append(id) }
        let result = runBridge(args: args, timeout: 25)
        if result.exitCode == 0 {
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.hasPrefix("OK "), output.count > 3 {
                let deviceId = String(output.dropFirst(3))
                DeviceMonitor.shared.saveConnectedDeviceId(deviceId)
            }
        }
        return result.exitCode == 0
    }

    /// 启动时若已连接，从设备列表捕获已连接设备 ID 并保存
    func captureConnectedDeviceId() {
        guard let devs = listDevices() else { return }
        for d in devs {
            if let connected = d["connected"] as? Bool, connected,
               let deviceId = d["id"] as? String {
                DeviceMonitor.shared.saveConnectedDeviceId(deviceId)
                return
            }
        }
    }

    func disconnect() -> Bool {
        runBridge(args: ["disconnect"], timeout: 20).exitCode == 0
    }

    func listDevices() -> [[String: Any]]? {
        let result = runBridge(args: ["list"])
        guard let data = result.output.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    }

    private func runBridge(args: [String], timeout: Double = 10) -> (output: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: bridgePath)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        let output: String
        let exitCode: Int32
        do {
            try process.run()
            let deadline = DispatchTime.now() + timeout
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global().async { process.waitUntilExit(); group.leave() }
            if group.wait(timeout: deadline) == .timedOut { process.terminate() }
            exitCode = process.terminationStatus
            output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        } catch {
            exitCode = -1
            output = error.localizedDescription
        }
        return (output, exitCode)
    }
}
