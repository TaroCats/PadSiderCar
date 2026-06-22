import Foundation

class SleepWakeMonitor {
    static let shared = SleepWakeMonitor()
    private var process: Process?
    private var isRunning = false
    private var wasAsleep = false
    private var lastEventTime: TimeInterval = 0
    private var streamStartTime: TimeInterval = 0
    private let cooldown: TimeInterval = 10
    private let startupGracePeriod: TimeInterval = 3
    private let reconnectDelay: TimeInterval = 5

    var onSleep: (() -> Void)?
    var onWake: (() -> Void)?

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // 根据当前连接状态初始化，避免启动时误判
        wasAsleep = (SidecarController.shared.currentStatus() != .connected)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        p.arguments = [
            "stream",
            "--predicate",
            "(process == \"powerd\" AND (eventMessage CONTAINS \"sleep\" OR eventMessage CONTAINS \"wake\")) OR (eventMessage CONTAINS \"Display is turned off\") OR (eventMessage CONTAINS \"Display is turned on\")",
            "--style", "compact",
            "--source"
        ]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            self.process = p
            self.streamStartTime = Date().timeIntervalSince1970
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.readStream(pipe: pipe)
            }
        } catch {
            print("Failed to start log stream: \(error)")
            isRunning = false
        }
    }

    func stop() {
        isRunning = false
        process?.terminate()
        process = nil
    }

    private func readStream(pipe: Pipe) {
        let handle = pipe.fileHandleForReading
        var buffer = ""
        while isRunning {
            let data = handle.availableData
            if data.isEmpty { break }
            if let chunk = String(data: data, encoding: .utf8) {
                buffer += chunk
                let lines = buffer.components(separatedBy: "\n")
                buffer = lines.last ?? ""
                for line in lines.dropLast() {
                    handleLogLine(line.trimmingCharacters(in: .whitespaces))
                }
            }
        }
    }

    private func handleLogLine(_ line: String) {
        guard !line.isEmpty else { return }
        let now = Date().timeIntervalSince1970

        // 启动后 3 秒内忽略缓冲历史事件
        guard now - streamStartTime >= startupGracePeriod else { return }
        guard now - lastEventTime >= cooldown else { return }

        let lower = line.lowercased()
        let sleepHit = lower.contains("sleep") || lower.contains("display is turned off")
        let wakeHit = lower.contains("wake") || lower.contains("display is turned on")

        if sleepHit && !wasAsleep {
            lastEventTime = now
            wasAsleep = true
            DispatchQueue.main.async { [weak self] in self?.onSleep?() }
        } else if wakeHit && wasAsleep {
            lastEventTime = now
            wasAsleep = false
            DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
                self?.onWake?()
            }
        }
    }
}
