---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 0b45cb7c70da02cc2552e8764ddb8c35_3f6a1d256d9011f18805525400d9a7a1
    ReservedCode1: 3yzHcUlq1p3smv3pggKCtziJBEuq5JrIqxKSuaxEbUn9oXWJumBj8EW7Ax7VKxfBxAUwSTRpLQYYRLE7H2UGG/qi97bIvcwMzUAN5kGgdyC9XUKsSYYqe+FD3WPQRa/fZoV6tH3tRT47PYX6IdTzzYwB/fyXGrSjYQbK1HpaDlGmRw3qqKU2FHGpZ2Y=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 0b45cb7c70da02cc2552e8764ddb8c35_3f6a1d256d9011f18805525400d9a7a1
    ReservedCode2: 3yzHcUlq1p3smv3pggKCtziJBEuq5JrIqxKSuaxEbUn9oXWJumBj8EW7Ax7VKxfBxAUwSTRpLQYYRLE7H2UGG/qi97bIvcwMzUAN5kGgdyC9XUKsSYYqe+FD3WPQRa/fZoV6tH3tRT47PYX6IdTzzYwB/fyXGrSjYQbK1HpaDlGmRw3qqKU2FHGpZ2Y=
---



# Sidecar Sleep Watch

> macOS 守护脚本：睡眠时自动断开 iPad 扩展屏，唤醒时自动重连。

## 功能概述

- 🔵 **睡眠断开**：macOS 进入睡眠 / 关闭显示器时，自动断开 Sidecar（随航）iPad 连接
- 🟢 **唤醒重连**：macOS 唤醒后延迟 5 秒（可配置），自动重连 iPad 作为扩展屏
- 📝 **完整日志**：所有操作记录到 `~/Library/Logs/sidecar_sleep_watch.log`
- 🔄 **多重策略**：断开与重连均内置多种 fallback 策略，确保可靠性

## 系统要求

- macOS 12 (Monterey) 或更高版本
- 已配对的 iPad（支持 Sidecar 随航）
- Python 3（macOS 自带）
- **权限**：辅助功能权限（系统设置 → 隐私与安全性 → 辅助功能 → 允许终端/launchd）

## 文件说明

| 文件 | 用途 |
|------|------|
| `sidecar_sleep_watch.py` | 主守护脚本 |
| `com.sidecar.sleepwatch.plist` | LaunchAgent 配置文件 |
| `setup.sh` | 一键安装 / 卸载 / 状态查看脚本 |
| `README.md` | 本文档 |

## 快速安装

```bash
# 1. 确保脚本有执行权限
chmod +x setup.sh

# 2. 一键安装
./setup.sh install
```

安装完成后，守护进程即刻开始运行，无需重启。

## 工作原理

```
┌─────────────────────────────────────────────────────────┐
│                  sidecar_sleep_watch.py                  │
│                                                         │
│  log stream ──→ 监听 powerd 事件                         │
│       │                                                 │
│       ├── "sleep" ──→ disconnect_sidecar()              │
│       │                 ├─ osascript GUI 点击            │
│       │                 ├─ pkill SidecarRelay            │
│       │                 └─ defaults delete + killall     │
│       │                                                 │
│       └── "wake"  ──→ 等待 5 秒 ──→ reconnect_sidecar() │
│                         ├─ osascript GUI 点击            │
│                         ├─ defaults write 触发           │
│                         └─ killall -HUP SidecarRelay     │
└─────────────────────────────────────────────────────────┘
```

## 使用命令

```bash
# 守护进程模式（LaunchAgent 自动管理）
# 安装后自动运行，无需手动启动

# 查看 Sidecar 连接状态
/usr/local/bin/sidecar_sleep_watch.py --status

# 手动断开
/usr/local/bin/sidecar_sleep_watch.py --disconnect

# 手动重连
/usr/local/bin/sidecar_sleep_watch.py --reconnect

# 自定义唤醒延迟（10 秒）
/usr/local/bin/sidecar_sleep_watch.py --delay 10

# 查看实时日志
tail -f ~/Library/Logs/sidecar_sleep_watch.log
```

## 管理命令

```bash
./setup.sh status      # 查看运行状态
./setup.sh uninstall   # 卸载
```

## 故障排查

### 辅助功能权限
系统设置 → 隐私与安全性 → 辅助功能 → 确保终端（Terminal）或 `/usr/bin/python3` 已勾选。

### 查看日志
```bash
# 主日志
tail -f ~/Library/Logs/sidecar_sleep_watch.log

# 错误日志
tail -f ~/Library/Logs/sidecar_sleep_watch.stderr.log
```

### 手动测试守护进程
```bash
# 前台运行（Ctrl+C 退出）
/usr/local/bin/sidecar_sleep_watch.py
```

### LaunchAgent 不运行
```bash
# 检查服务状态
launchctl list | grep sidecar

# 手动加载
launchctl load ~/Library/LaunchAgents/com.sidecar.sleepwatch.plist

# 手动卸载后重新加载
launchctl bootout gui/$(id -u)/com.sidecar.sleepwatch
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.sidecar.sleepwatch.plist
```

## 高级配置

修改 `/usr/local/bin/sidecar_sleep_watch.py` 中的常量：

```python
WAKE_RECONNECT_DELAY = 5       # 唤醒后延迟秒数
SIDECAR_PREFS_DOMAIN = "com.apple.sidecar.display"
```

修改 plist 中的 `ThrottleInterval` 可控制守护进程崩溃后的重启间隔（默认 5 秒）。

## 许可

MIT License — 仅供个人使用，风险自负。
*（内容由AI生成，仅供参考）*
*（内容由AI生成，仅供参考）*
