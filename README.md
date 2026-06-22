# PadSidecar

> macOS 菜单栏助手：连接、断开并自动管理 iPad Sidecar（随航）扩展屏。

## 功能

- 手动连接或断开 iPad 扩展屏
- 睡眠时自动断开，唤醒后自动重连
- 设备重新接入时自动连接
- 菜单栏显示当前连接状态

## 项目结构

| 文件/目录 | 用途 |
|------|------|
| `Sources/` | Swift 源码 |
| `PadSidecar.app/` | 已打包的 macOS 应用 |
| `SidecarBridge` | 调用 SidecarCore.framework 的桥接工具 |
| `SidecarBridge.m` | 桥接工具源码 |
| `icon.iconset/` | 应用图标资源 |

## 运行方式

直接启动已打包应用：

```bash
open PadSidecar.app
```

或在 Xcode / Swift 构建环境中自行编译 `Sources/` 下的代码。

## 工作原理

- 菜单栏应用通过 `SidecarBridge` 查询当前 Sidecar 状态
- 开启“睡眠时自动断开”后，应用监听系统睡眠/唤醒事件
- 开启“设备接入时自动连接”后，应用监听设备变化并尝试重连上次连接的 iPad

## 系统要求

- macOS 12 或更高版本
- 已配对且支持 Sidecar 的 iPad
- 允许应用访问必要的系统能力

## 注意事项

- `SidecarBridge` 依赖系统私有框架，系统升级后可能需要重新验证兼容性
- 如果自动连接失败，先确认 iPad 已解锁、靠近 Mac 且使用同一 Apple ID

## 许可

MIT License
