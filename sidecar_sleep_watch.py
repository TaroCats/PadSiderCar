#!/usr/bin/env python3
"""
Sidecar Sleep Watch
====================
监听 macOS 睡眠/唤醒事件，自动断开/重连 iPad Sidecar（随航）扩展屏。

核心依赖：SidecarBridge（基于 SidecarCore.framework 的 ObjC 工具）
工作原理：
  睡眠事件 → SidecarBridge disconnect → 断开 iPad 扩展屏
  唤醒事件 → 等待系统就绪 → SidecarBridge connect → 重连 iPad 扩展屏
"""

import subprocess
import os
import sys
import time
import signal
import logging
import argparse
from pathlib import Path

# ──────────────────────────────────────────────
# 配置
# ──────────────────────────────────────────────
LOG_DIR = Path(os.path.expanduser("~/Library/Logs"))
LOG_FILE = LOG_DIR / "sidecar_sleep_watch.log"
WAKE_RECONNECT_DELAY = 5          # 唤醒后等待秒数再重连

# SidecarBridge 路径（安装时会放到脚本同目录或 /usr/local/bin）
SCRIPT_DIR = Path(__file__).resolve().parent
SIDECAR_BRIDGE = SCRIPT_DIR / "SidecarBridge"
if not SIDECAR_BRIDGE.exists():
    # 尝试系统路径
    import shutil
    found = shutil.which("SidecarBridge")
    if found:
        SIDECAR_BRIDGE = Path(found)

# ──────────────────────────────────────────────
# 日志初始化
# ──────────────────────────────────────────────
def setup_logging():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=[
            logging.FileHandler(LOG_FILE),
            logging.StreamHandler(sys.stdout),
        ],
    )
    return logging.getLogger("SidecarWatch")

logger = setup_logging()

# ──────────────────────────────────────────────
# Sidecar 控制（通过 SidecarBridge）
# ──────────────────────────────────────────────
def _run_bridge(*args: str, timeout: int = 20) -> subprocess.CompletedProcess:
    """调用 SidecarBridge 并返回结果。"""
    cmd = [str(SIDECAR_BRIDGE), *args]
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def is_sidecar_active() -> bool:
    """检查 Sidecar 是否作为扩展显示器连接。"""
    try:
        result = _run_bridge("status", timeout=5)
        return result.stdout.strip() == "CONNECTED"
    except Exception as e:
        logger.debug(f"状态检测异常: {e}")
        return False


def disconnect_sidecar() -> bool:
    """断开 iPad Sidecar 扩展屏。"""
    logger.info("正在断开 Sidecar...")

    if not is_sidecar_active():
        logger.info("Sidecar 当前未连接，跳过断开。")
        return True

    try:
        result = _run_bridge("disconnect", timeout=20)
        if result.returncode == 0:
            logger.info("✓ Sidecar 已断开。")
            return True
        logger.error(f"断开失败: {result.stderr.strip()}")
        return False
    except subprocess.TimeoutExpired:
        logger.error("断开操作超时")
        return False
    except Exception as e:
        logger.error(f"断开异常: {e}")
        return False


def reconnect_sidecar() -> bool:
    """重连 iPad 扩展屏。"""
    logger.info("正在重连 Sidecar（iPad 扩展屏）...")

    if is_sidecar_active():
        logger.info("Sidecar 已连接，无需重连。")
        return True

    try:
        result = _run_bridge("connect", timeout=25)
        if result.returncode == 0:
            logger.info("✓ Sidecar 重连成功。")
            return True
        logger.warning(f"重连失败: {result.stderr.strip()}")
        return False
    except subprocess.TimeoutExpired:
        logger.warning("重连操作超时，请确认 iPad 在附近、已解锁且同一 Apple ID。")
        return False
    except Exception as e:
        logger.error(f"重连异常: {e}")
        return False


# ──────────────────────────────────────────────
# 事件监听（使用 log stream）
# ──────────────────────────────────────────────
def monitor_power_events():
    """使用 log stream 持续监听系统电源事件（睡眠/唤醒）。"""
    logger.info("=" * 50)
    logger.info("Sidecar Sleep Watch 守护进程已启动")
    logger.info(f"日志文件: {LOG_FILE}")
    logger.info(f"唤醒重连延迟: {WAKE_RECONNECT_DELAY} 秒")
    logger.info(f"SidecarBridge: {SIDECAR_BRIDGE}")
    logger.info(f"当前 Sidecar: {'已连接' if is_sidecar_active() else '未连接'}")
    logger.info("=" * 50)

    combined_predicate = (
        '(process == "powerd" AND (eventMessage CONTAINS "sleep" OR eventMessage CONTAINS "wake")) '
        'OR (eventMessage CONTAINS "Display is turned off") '
        'OR (eventMessage CONTAINS "Display is turned on")'
    )

    cmd = [
        "log", "stream",
        "--predicate", combined_predicate,
        "--style", "compact",
        "--source",
    ]

    was_asleep = False
    last_event_time = 0.0
    COOLDOWN = 10

    logger.info("开始监听系统电源事件...")

    try:
        process = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, bufsize=1,
        )

        for line in process.stdout:
            line = line.strip()
            if not line:
                continue

            now = time.time()
            sleep_hit = "sleep" in line.lower() or "display is turned off" in line.lower()
            wake_hit = "wake" in line.lower() or "display is turned on" in line.lower()

            if sleep_hit and not was_asleep:
                if now - last_event_time < COOLDOWN:
                    continue
                last_event_time = now
                was_asleep = True
                logger.info(f"Sleep → {line[:120]}")
                disconnect_sidecar()

            elif wake_hit and was_asleep:
                if now - last_event_time < COOLDOWN:
                    continue
                last_event_time = now
                was_asleep = False
                logger.info(f"Wake → {line[:120]}")
                logger.info(f"等待 {WAKE_RECONNECT_DELAY} 秒后重连...")
                time.sleep(WAKE_RECONNECT_DELAY)
                reconnect_sidecar()

    except KeyboardInterrupt:
        logger.info("收到中断信号，正在退出...")
    except Exception as e:
        logger.error(f"监听循环异常: {e}")
        raise
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
        logger.info("Sidecar Sleep Watch 已停止。")


# ──────────────────────────────────────────────
# 一次性操作
# ──────────────────────────────────────────────
def oneshot_disconnect():
    return disconnect_sidecar()


def oneshot_reconnect():
    """一次性重连，先等待延迟。"""
    time.sleep(WAKE_RECONNECT_DELAY)
    return reconnect_sidecar()


# ──────────────────────────────────────────────
# 命令行入口
# ──────────────────────────────────────────────
def main():
    global WAKE_RECONNECT_DELAY

    parser = argparse.ArgumentParser(
        description="Sidecar Sleep Watch - 睡眠时断开 iPad 扩展屏，唤醒时自动重连",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用示例:
  %(prog)s                    # 守护进程模式（持续监听）
  %(prog)s --disconnect       # 手动断开 Sidecar
  %(prog)s --reconnect        # 手动重连 Sidecar
  %(prog)s --status           # 查看 Sidecar 当前连接状态
        """,
    )
    parser.add_argument("--disconnect", action="store_true",
                        help="一次性断开 Sidecar（用于 sleepwatcher hook）")
    parser.add_argument("--reconnect", action="store_true",
                        help="一次性重连 Sidecar（用于 sleepwatcher hook）")
    parser.add_argument("--status", action="store_true",
                        help="查看 Sidecar 当前连接状态")
    parser.add_argument("--delay", type=int, default=WAKE_RECONNECT_DELAY,
                        help=f"唤醒后重连延迟秒数（默认: {WAKE_RECONNECT_DELAY}）")
    parser.add_argument("--oneshot", action="store_true",
                        help="兼容 sleepwatcher 的 oneshot 模式")

    args = parser.parse_args()
    WAKE_RECONNECT_DELAY = args.delay

    # 检查 SidecarBridge 是否可用
    if not SIDECAR_BRIDGE.exists():
        logger.error(f"SidecarBridge 未找到: {SIDECAR_BRIDGE}")
        logger.error("请先运行 setup.sh install")
        sys.exit(1)

    if args.status:
        active = is_sidecar_active()
        print(f"Sidecar 状态: {'已连接' if active else '未连接'}")
        sys.exit(0 if active else 1)

    elif args.disconnect or (args.oneshot and not args.reconnect):
        success = oneshot_disconnect()
        sys.exit(0 if success else 1)

    elif args.reconnect:
        success = oneshot_reconnect()
        sys.exit(0 if success else 1)

    else:
        logger.info(f"守护进程模式启动 (PID: {os.getpid()})")
        signal.signal(signal.SIGTERM, lambda s, f: sys.exit(0))
        signal.signal(signal.SIGINT, lambda s, f: sys.exit(0))
        monitor_power_events()


if __name__ == "__main__":
    main()
