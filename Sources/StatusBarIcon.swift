import AppKit

enum SidecarIcon {
    static func icon(isConnected: Bool) -> NSImage {
        let size = NSSize(width: 20, height: 18)
        let image = NSImage(size: size)
        image.isTemplate = true

        image.lockFocus()

        // iPad 轮廓（template 白色边框）
        if let ipad = NSImage(systemSymbolName: "ipad.landscape", accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            if let base = ipad.withSymbolConfiguration(cfg) {
                base.draw(in: NSRect(x: 0, y: 1, width: 20, height: 16))
            }
        }

        // 已连接：屏幕中间亮起（实心小矩形表示屏幕活动）
        if isConnected {
            let screenBar = NSBezierPath(
                roundedRect: NSRect(x: 7, y: 8, width: 8, height: 3),
                xRadius: 1.5, yRadius: 1.5)
            screenBar.fill()
        }

        image.unlockFocus()
        return image
    }
}
