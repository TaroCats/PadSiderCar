import SwiftUI

struct MenuView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(nsImage: SidecarIcon.icon(isConnected: appState.isConnected))
                    .resizable().frame(width: 16, height: 16)
                Text(appState.statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(appState.isConnected ? .green : .secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            
            Divider()
            
            Button(action: { appState.toggleConnection() }) {
                HStack {
                    Image(systemName: appState.isConnected
                        ? "rectangle.connected.to.line.below"
                        : "rectangle.connected.to.line.below.fill")
                        .frame(width: 18)
                    Text(appState.isConnected ? "断开 iPad 扩展屏" : "连接 iPad 扩展屏")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .disabled(appState.isExecuting)
            
            Divider()
            
            Toggle(isOn: $appState.autoModeEnabled) {
                HStack {
                    Image(systemName: "moon.zzz.fill").frame(width: 18)
                    Text("睡眠时自动断开")
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .onChange(of: appState.autoModeEnabled) { newValue in
                appState.toggleAutoMode()
            }
            
            Divider()
            
            Button(action: {
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = "PadSidecar"
                alert.informativeText = "iPad 扩展屏菜单栏助手\n\n自动连接/断开 iPad Sidecar（随航）扩展屏。\n睡眠时自动断开，唤醒后自动重连。\n\n基于 SidecarCore.framework"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "好的")
                alert.runModal()
            }) {
                HStack {
                    Image(systemName: "info.circle").frame(width: 18)
                    Text("关于 PadSidecar")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12).padding(.vertical, 6)
            
            Divider()
            
            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack {
                    Image(systemName: "power").frame(width: 18)
                    Text("退出")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 260)
    }
}
