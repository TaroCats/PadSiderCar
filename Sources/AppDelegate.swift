import Cocoa
import SwiftUI

class AppState: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isExecuting: Bool = false
    @Published var autoModeEnabled: Bool = UserDefaults.standard.bool(forKey: "PadSidecar_autoModeEnabled")
    @Published var autoReconnectEnabled: Bool = UserDefaults.standard.bool(forKey: "PadSidecar_autoReconnectEnabled")

    private let autoModeKey = "PadSidecar_autoModeEnabled"
    private let autoReconnectKey = "PadSidecar_autoReconnectEnabled"

    var statusText: String {
        isConnected ? "iPad 扩展屏：已连接" : "iPad 扩展屏：未连接"
    }

    func refreshStatus() {
        let status = SidecarController.shared.currentStatus()
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = (status == .connected)
        }
    }

    func toggleConnection() {
        isExecuting = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer { DispatchQueue.main.async { self?.isExecuting = false } }
            guard let self = self else { return }
            if SidecarController.shared.currentStatus() == .connected {
                _ = SidecarController.shared.disconnect()
            } else {
                _ = SidecarController.shared.connect()
            }
            DispatchQueue.main.async { self.refreshStatus() }
        }
    }

    func toggleAutoMode() {
        UserDefaults.standard.set(autoModeEnabled, forKey: autoModeKey)
        if autoModeEnabled {
            SleepWakeMonitor.shared.onSleep = { [weak self] in
                _ = SidecarController.shared.disconnect()
                self?.refreshStatus()
            }
            SleepWakeMonitor.shared.onWake = { [weak self] in
                _ = SidecarController.shared.connect()
                self?.refreshStatus()
            }
            SleepWakeMonitor.shared.start()
        } else {
            SleepWakeMonitor.shared.stop()
        }
    }

    func toggleAutoReconnect() {
        UserDefaults.standard.set(autoReconnectEnabled, forKey: autoReconnectKey)
        if autoReconnectEnabled {
            DeviceMonitor.shared.start()
        } else {
            DeviceMonitor.shared.stop()
        }
    }
}

func makeMenuView<V: View>(_ view: V, width: CGFloat, height: CGFloat) -> NSView {
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
    hostingView.autoresizingMask = [.width]
    return hostingView
}

// 带图标+checkbox的菜单项视图
struct MenuCheckboxRow: View {
    @ObservedObject var appState: AppState
    let icon: String
    let title: String
    let checked: KeyPath<AppState, Bool>
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16, height: 16)
                Text(title)
                Spacer()
                Image(systemName: appState[keyPath: checked] ? "checkmark" : "xmark")
                    .frame(width: 14)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// 带图标的普通菜单项视图
struct MenuActionRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16, height: 16)
                Text(title)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let appState = AppState()
    private var menu: NSMenu!
    private let menuWidth: CGFloat = 210

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        appState.refreshStatus()
        updateIcon()

        menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        menu.minimumWidth = menuWidth
        statusItem.menu = menu

        rebuildMenu()

        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.appState.refreshStatus()
                self?.updateIcon()
            }
        }

        if appState.autoModeEnabled {
            appState.toggleAutoMode()
        }
        if appState.autoReconnectEnabled {
            appState.toggleAutoReconnect()
        }

        // 启动时如果已连接，记录设备 ID 以便自动重连
        if SidecarController.shared.currentStatus() == .connected {
            SidecarController.shared.captureConnectedDeviceId()
        }
    }

    private func updateIcon() {
        if let button = statusItem.button {
            button.image = SidecarIcon.icon(isConnected: appState.isConnected)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        appState.refreshStatus()
        updateIcon()
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let w = menuWidth

        // 状态头
        let headerItem = NSMenuItem()
        headerItem.view = makeMenuView(
            MenuHeaderView(appState: appState), width: w, height: 28)
        menu.addItem(headerItem)

        menu.addItem(.separator())

        // 连接/断开
        let toggleItem = NSMenuItem()
        toggleItem.view = makeMenuView(
            MenuToggleView(appState: appState, action: { [weak self] in
                self?.appState.toggleConnection()
                self?.menu.cancelTracking()
            }), width: w, height: 30)
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        // 自动模式
        let autoItem = NSMenuItem()
        autoItem.view = makeMenuView(
            MenuCheckboxRow(
                appState: appState,
                icon: "moon.zzz",
                title: "睡眠时自动断开",
                checked: \.autoModeEnabled,
                action: { [weak self] in
                    self?.appState.autoModeEnabled.toggle()
                    self?.appState.toggleAutoMode()
                }
            ), width: w, height: 30)
        menu.addItem(autoItem)

        // 自动重连
        let reconnectItem = NSMenuItem()
        reconnectItem.view = makeMenuView(
            MenuCheckboxRow(
                appState: appState,
                icon: "arrow.trianglehead.clockwise",
                title: "设备接入时自动连接",
                checked: \.autoReconnectEnabled,
                action: { [weak self] in
                    self?.appState.autoReconnectEnabled.toggle()
                    self?.appState.toggleAutoReconnect()
                }
            ), width: w, height: 30)
        menu.addItem(reconnectItem)

        menu.addItem(.separator())

        // 关于
        let aboutItem = NSMenuItem()
        aboutItem.view = makeMenuView(
            MenuActionRow(
                icon: "info.circle",
                title: "关于 PadSidecar",
                action: { [weak self] in
                    self?.menu.cancelTracking()
                    self?.showAbout()
                }
            ), width: w, height: 30)
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        // 退出
        let quitItem = NSMenuItem()
        quitItem.view = makeMenuView(
            MenuActionRow(
                icon: "xmark.square",
                title: "退出 PadSidecar",
                action: {
                    SleepWakeMonitor.shared.stop()
                    DeviceMonitor.shared.stop()
                    NSApplication.shared.terminate(nil)
                }
            ), width: w, height: 30)
        menu.addItem(quitItem)
    }

    private func showAbout() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "PadSidecar"
            alert.informativeText = "iPad 扩展屏菜单栏助手\n\n自动连接/断开 iPad Sidecar（随航）扩展屏。\n睡眠时自动断开，唤醒后自动重连。\n\n基于 SidecarCore.framework"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "好的")
            alert.runModal()
        }
    }
}

// MARK: - 菜单项视图

struct MenuHeaderView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: SidecarIcon.icon(isConnected: appState.isConnected))
                .resizable().frame(width: 16, height: 16)
            Text(appState.statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

struct MenuToggleView: View {
    @ObservedObject var appState: AppState
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: appState.isConnected
                    ? "rectangle.connected.to.line.below"
                    : "rectangle.connected.to.line.below.fill")
                    .frame(width: 16, height: 16)
                    .foregroundColor(.primary)
                Text(appState.isConnected ? "断开 iPad 扩展屏" : "连接 iPad 扩展屏")
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(appState.isExecuting)
    }
}
