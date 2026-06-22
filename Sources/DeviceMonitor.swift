import Foundation
import IOKit

class DeviceMonitor {
    static let shared = DeviceMonitor()
    private var process: Process?
    private var isRunning = false
    private var lastDeviceId: String?

    // IOKit USB 监听
    private var usbPollTimer: DispatchSourceTimer?
    private var lastUSBConnectedState = false

    var onDeviceFound: ((String) -> Void)?

    private let lastDeviceKey = "PadSidecar_lastDeviceId"
    private let usbReconnectDelay: UInt64 = 1_000_000_000  // USB 接入后等待 1 秒再重连

    func saveConnectedDeviceId(_ id: String) {
        lastDeviceId = id
        UserDefaults.standard.set(id, forKey: lastDeviceKey)
    }

    func lastKnownDeviceId() -> String? {
        if let cached = lastDeviceId { return cached }
        lastDeviceId = UserDefaults.standard.string(forKey: lastDeviceKey)
        return lastDeviceId
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // 1. 启动 SidecarCore 事件监听
        startSidecarWatch()
        // 2. 启动 IOKit USB 设备接入监听
        startUSBWatch()
    }

    func stop() {
        isRunning = false
        process?.terminate()
        process = nil
        stopUSBWatch()
    }

    // MARK: - SidecarCore 事件监听

    private func startSidecarWatch() {
        let p = Process()
        p.executableURL = Bundle.main.url(forResource: "SidecarBridge", withExtension: nil)
        p.arguments = ["watch"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice

        do {
            try p.run()
            self.process = p
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.readStream(pipe: pipe)
            }
        } catch {
            print("DeviceMonitor failed to start SidecarWatch: \(error)")
        }
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
                    handleLine(line.trimmingCharacters(in: .whitespaces))
                }
            }
        }
    }

    private func handleLine(_ line: String) {
        guard !line.isEmpty, line.hasPrefix("[") else { return }
        guard let data = line.data(using: .utf8) else { return }
        do {
            if let devices = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                checkAndAutoConnect(devices, source: "SidecarCore")
            }
        } catch {}
    }

    // MARK: - IOKit USB 设备轮询

    private let usbPollInterval: TimeInterval = 0.5  // 每 500ms 轮询

    private func startUSBWatch() {
        let queue = DispatchQueue(label: "com.padsidebar.usbwatch", qos: .utility)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: usbPollInterval)
        timer.setEventHandler { [weak self] in
            self?.pollUSBDevices()
        }
        timer.resume()
        usbPollTimer = timer
        print("[USBWatch] IOKit USB 轮询已启动 (间隔 \(usbPollInterval)s)")
    }

    private func stopUSBWatch() {
        usbPollTimer?.cancel()
        usbPollTimer = nil
    }

    private func pollUSBDevices() {
        let matchDict = NSMutableDictionary()
        matchDict.setObject("IOUSBHostDevice", forKey: "IOProviderClass" as NSString)
        matchDict.setObject(0x05AC, forKey: "idVendor" as NSString)

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchDict as CFDictionary, &iterator) == KERN_SUCCESS else {
            return
        }

        var foundIPad = false
        var device = IOIteratorNext(iterator)
        while device != 0 {
            let name = getUSBDeviceProperty(device, "USB Product Name") ?? ""
            if name.lowercased().contains("ipad") || name.lowercased().contains("iphone") {
                foundIPad = true
                IOObjectRelease(device)
                break
            }
            IOObjectRelease(device)
            device = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)

        // 状态变化：iPad USB 从无到有 → 触发重连
        if foundIPad && !lastUSBConnectedState {
            lastUSBConnectedState = true
            print("[USBWatch] 检测到 iOS 设备 USB 接入，\(usbReconnectDelay / 1_000_000_000) 秒后检查 Sidecar...")
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .nanoseconds(Int(usbReconnectDelay))) { [weak self] in
                self?.usbReconnectCheck()
            }
        } else if !foundIPad && lastUSBConnectedState {
            lastUSBConnectedState = false
            print("[USBWatch] iOS 设备 USB 已断开")
        }
    }

    private func getUSBDeviceProperty(_ device: io_service_t, _ key: String) -> String? {
        if let cfValue = IORegistryEntryCreateCFProperty(device, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
            return "\(cfValue)"
        }
        return nil
    }

    private func usbReconnectCheck() {
        guard lastKnownDeviceId() != nil,
              let devices = SidecarController.shared.listDevices() else { return }

        checkAndAutoConnect(devices, source: "USB-IOKit")
    }

    // MARK: - 自动连接逻辑

    private func checkAndAutoConnect(_ devices: [[String: Any]], source: String) {
        guard let targetId = lastKnownDeviceId() else { return }

        for d in devices {
            guard let ident = d["id"] as? String, ident == targetId,
                  let connected = d["connected"] as? Bool, !connected else { continue }
            print("[AutoReconnect] [\(source)] 检测到设备 \(targetId) 未连接，自动连接...")
            DispatchQueue.main.async {
                if SidecarController.shared.connect(toId: targetId) {
                    print("[AutoReconnect] 连接成功")
                }
            }
            return
        }
    }
}
