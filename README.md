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
| `Resources/Info.plist` | 应用 bundle 元数据模板 |
| `SidecarBridge.m` | 桥接工具源码 |
| `icon.iconset/` | 应用图标资源 |
| `scripts/` | 本地构建和打包脚本 |
| `.github/workflows/release.yml` | GitHub Actions 发布流程 |

## 运行方式

本仓库不提交 `.app`，应用由脚本或 GitHub Actions 现打包。

本地构建 `.app`：

```bash
bash scripts/build_app.sh
open build/PadSidecar.app
```

本地打包 `.dmg`：

```bash
bash scripts/package_dmg.sh
open dist
```

也可以通过 GitHub Actions 发布：

- 推送 `v*` 标签时，自动构建并把 `.dmg` 发布到 GitHub Releases
- 手动触发 `Release` 工作流时，可填写 `release_tag`，直接把产物发布到 GitHub Releases
- 如果手动触发时不填写 `release_tag`，则只上传 workflow artifact，不创建 Release

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
- 发布流程当前输出 `.dmg`，适合作为 GitHub Releases 下载产物

## 许可

MIT License
