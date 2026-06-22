# Debug Session: app-launch-failure [RESOLVED]

## 症状

- 打包出来的 `PadSidecar.app` 无法打开

## 期望

- 双击或 `open` 应用后可正常启动菜单栏应用

## 假设

- 假设 1：`.app` bundle 结构不完整，缺少启动所需资源或可执行文件
- 假设 2：应用已启动但立即崩溃，原因是运行时找不到 `SidecarBridge` 或私有框架调用失败
- 假设 3：应用被 macOS 安全机制拦截，例如签名、隔离属性或 LaunchServices 校验失败
- 假设 4：`Info.plist` 或可执行文件元数据不符合 AppKit 菜单栏应用要求，导致无法被系统正常拉起
- 假设 5：本地打包脚本生成的 bundle 能构建但不能运行，原因是 `swiftc` 直编缺少正确的运行时嵌入或链接配置

## 当前计划

- 复现启动失败
- 收集启动日志和系统报错
- 对照假设定位根因
- 再做最小修复

## 证据

- 本地执行 `open build/PadSidecar.app` 后，`PadSidecar` 进程保持运行
- 同时存在 `Contents/Resources/SidecarBridge watch` 子进程，说明应用已完成主流程启动
- 用户确认从 `.dmg` 中打开后“没有任何窗口”，但菜单栏右上角可以看到 iPad 图标

## 结论

- 这不是启动失败或崩溃
- `PadSidecar` 当前是 `LSUIElement` 菜单栏应用，设计上不会弹主窗口
- 用户感知为“打不开”，实际是“启动成功但没有窗口提示”
