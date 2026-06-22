# PadSidecar

> macOS 菜单栏助手：连接、断开并自动管理 iPad Sidecar（随航）扩展屏。

## 项目简介

PadSidecar 是一个面向 macOS 的轻量级菜单栏工具，用来简化 iPad Sidecar（随航）扩展屏的连接与管理。

它适合这样的使用场景：

- 经常把 iPad 作为 Mac 扩展屏使用
- 希望快速连接或断开 Sidecar，而不是每次都进入系统界面操作
- 希望在 Mac 睡眠 / 唤醒后自动处理 Sidecar 连接状态
- 希望在设备重新接入后自动尝试恢复上次连接

## 项目特色

- 菜单栏常驻：启动后驻留在 macOS 菜单栏，操作路径短
- 一键连接管理：支持手动连接和断开 iPad 扩展屏
- 睡眠自动处理：睡眠时自动断开，唤醒后自动重连
- 设备接入自动连接：重新检测到设备时自动恢复连接
- 轻量无主窗口：默认不弹主窗口，尽量减少对桌面的打扰
- 可自动发布：支持通过 GitHub Actions 构建 `.dmg` 并发布到 GitHub Releases

## 主要功能

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

## 系统要求

- macOS 12 或更高版本
- 已配对且支持 Sidecar 的 iPad
- Mac 与 iPad 建议登录同一 Apple ID
- iPad 建议保持已解锁、靠近 Mac，且网络或 USB 连接状态正常

## 安装与运行

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

## 使用说明

- 启动应用后，图标会出现在屏幕右上角菜单栏
- 点击菜单栏图标，可以执行连接、断开、自动断开、自动重连等操作
- 应用是菜单栏形态，不会像普通 App 一样弹出主窗口
- 首次启动时会弹出提示框，帮助你快速找到菜单入口

## 工作原理

- 菜单栏应用通过 `SidecarBridge` 查询当前 Sidecar 状态
- 开启“睡眠时自动断开”后，应用监听系统睡眠/唤醒事件
- 开启“设备接入时自动连接”后，应用监听设备变化并尝试重连上次连接的 iPad

## 打开应用时可能遇到的问题

### 1. 双击后没有弹出窗口

这通常不是异常。

PadSidecar 是菜单栏应用，启动后不会弹出主窗口，而是显示在屏幕右上角菜单栏。

处理方法：

- 查看屏幕右上角是否出现 iPad 图标
- 点击菜单栏图标打开操作菜单
- 如果首次启动，应用通常会弹出一次性提示框

### 2. macOS 提示“无法验证开发者”或“无法打开”

如果当前产物尚未经过正式开发者签名 / 公证，macOS 可能拦截首次打开。

处理方法：

- 在 Finder 中找到应用
- 按住 `Control` 键点击应用，选择“打开”
- 在弹窗中再次点击“打开”

如果仍被拦截，可进入：

- 系统设置 → 隐私与安全性
- 在安全提示区域选择“仍要打开”

### 3. 提示“已损坏”或打开失败

这通常与系统安全校验、下载来源或隔离属性有关，不一定代表文件真的损坏。

可尝试：

- 重新从 GitHub Releases 下载最新版本
- 确认下载过程未被中断
- 按照上面的“仍要打开”流程重新尝试

### 4. 打开后能看到菜单栏图标，但无法连接 iPad

这通常不是应用启动问题，而是 Sidecar 可用性或系统环境问题。

可先检查：

- iPad 是否已解锁
- Mac 与 iPad 是否为同一 Apple ID
- 两台设备是否靠近
- Sidecar 在系统原生界面中是否可正常使用
- USB 或无线连接是否稳定

## 注意事项

- `SidecarBridge` 依赖 macOS 私有框架，系统升级后可能需要重新验证兼容性
- 本项目更适合作为个人效率工具或技术探索项目使用
- 如果自动连接失败，优先排查 iPad 解锁状态、Apple ID、距离和网络 / USB 状态
- 当前发布物以 `.dmg` 为主，适合作为 GitHub Releases 下载产物
- 若未启用正式签名和公证，首次打开时可能触发 macOS 安全提示

## 开源许可

本项目使用 MIT License。

你可以在遵守 MIT License 的前提下自由使用、修改、分发和二次开发。

如果你准备基于本项目做二次发布，建议保留原始许可声明并自行评估私有框架相关风险。
