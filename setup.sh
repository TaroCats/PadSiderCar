#!/bin/bash
set -e

INSTALL_DIR="/usr/local/bin"
PLIST_DIR="$HOME/Library/LaunchAgents"
SCRIPT_NAME="sidecar_sleep_watch.py"
BRIDGE_NAME="SidecarBridge"
PLIST_NAME="com.sidecar.sleepwatch.plist"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

CUR_DIR="$(cd "$(dirname "$0")" && pwd)"

install() {
    echo "安装 Sidecar Sleep Watch..."

    # 复制文件
    cp "$CUR_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
    cp "$CUR_DIR/$BRIDGE_NAME" "$INSTALL_DIR/$BRIDGE_NAME"
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$BRIDGE_NAME"

    # 生成并安装 plist
    mkdir -p "$PLIST_DIR"
    sed "s|__SCRIPT_PATH__|$INSTALL_DIR/$SCRIPT_NAME|g" "$CUR_DIR/$PLIST_NAME" > "$PLIST_DIR/$PLIST_NAME"

    # 加载 LaunchAgent
    launchctl unload "$PLIST_DIR/$PLIST_NAME" 2>/dev/null || true
    launchctl load "$PLIST_DIR/$PLIST_NAME"

    echo -e "${GREEN}安装完成${NC}"
    echo "  Python 脚本: $INSTALL_DIR/$SCRIPT_NAME"
    echo "  SidecarBridge: $INSTALL_DIR/$BRIDGE_NAME"
    echo "  LaunchAgent: $PLIST_DIR/$PLIST_NAME"
    echo ""
    echo "状态检查: $INSTALL_DIR/$SCRIPT_NAME --status"
    echo "手动断开: $INSTALL_DIR/$SCRIPT_NAME --disconnect"
    echo "手动重连: $INSTALL_DIR/$SCRIPT_NAME --reconnect"
    echo "查看日志: tail -f ~/Library/Logs/sidecar_sleep_watch.log"
}

uninstall() {
    echo "卸载 Sidecar Sleep Watch..."

    launchctl unload "$PLIST_DIR/$PLIST_NAME" 2>/dev/null || true
    rm -f "$PLIST_DIR/$PLIST_NAME"
    rm -f "$INSTALL_DIR/$SCRIPT_NAME"
    rm -f "$INSTALL_DIR/$BRIDGE_NAME"

    echo -e "${GREEN}卸载完成${NC}"
}

status() {
    echo "=== 文件状态 ==="
    for f in "$INSTALL_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$BRIDGE_NAME" "$PLIST_DIR/$PLIST_NAME"; do
        if [ -f "$f" ]; then
            echo -e "  ${GREEN}✓${NC} $f"
        else
            echo -e "  ${RED}✗${NC} $f"
        fi
    done

    echo ""
    echo "=== LaunchAgent 状态 ==="
    if launchctl list | grep -q com.sidecar.sleepwatch; then
        echo -e "  ${GREEN}运行中${NC}"
    else
        echo -e "  ${RED}未运行${NC}"
    fi

    echo ""
    echo "=== Sidecar 连接状态 ==="
    if [ -x "$INSTALL_DIR/$BRIDGE_NAME" ]; then
        "$INSTALL_DIR/$BRIDGE_NAME" status
    else
        echo "  SidecarBridge 未安装"
    fi
}

case "${1:-}" in
    install)   install ;;
    uninstall) uninstall ;;
    status)    status ;;
    *)
        echo "用法: $0 {install|uninstall|status}"
        exit 1
        ;;
esac
