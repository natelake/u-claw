#!/bin/bash
# U-Claw Menu - Portable AI Agent
# macOS version

UCLAW_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$UCLAW_DIR/app"

# Migration shim: rename old core-mac to core for existing USB users
if [ -d "$APP_DIR/core-mac" ] && [ ! -d "$APP_DIR/core" ]; then
    mv "$APP_DIR/core-mac" "$APP_DIR/core"
fi

CORE_DIR="$APP_DIR/core"
DATA_DIR="$UCLAW_DIR/data"
STATE_DIR="$DATA_DIR/.openclaw"
CONFIG_PATH="$STATE_DIR/openclaw.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Node.js — detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    NODE_DIR="$APP_DIR/runtime/node-mac-arm64"
else
    NODE_DIR="$APP_DIR/runtime/node-mac-x64"
fi
NODE_BIN="$NODE_DIR/bin/node"
NPM_BIN="$NODE_DIR/bin/npm"
export PATH="$NODE_DIR/bin:$PATH"
export OPENCLAW_HOME="$DATA_DIR"
export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_CONFIG_PATH="$CONFIG_PATH"

mkdir -p "$STATE_DIR" "$DATA_DIR/memory" "$DATA_DIR/backups" "$DATA_DIR/logs"

# Load maintenance functions
source "$UCLAW_DIR/lib/maintain.sh"

# Remove macOS quarantine
if xattr -l "$NODE_BIN" 2>/dev/null | grep -q "com.apple.quarantine"; then
    xattr -rd com.apple.quarantine "$UCLAW_DIR" 2>/dev/null || true
fi

# Run openclaw command
OPENCLAW_MJS="$CORE_DIR/node_modules/openclaw/openclaw.mjs"

run_oc() {
    cd "$CORE_DIR"
    "$NODE_BIN" "$OPENCLAW_MJS" "$@"
}

# Show menu
show_menu() {
    clear
    local NODE_VER=$("$NODE_BIN" --version 2>/dev/null || echo "N/A")
    local CFG_STATUS="${RED}Not configured${NC}"
    [ -f "$CONFIG_PATH" ] && CFG_STATUS="${GREEN}Configured${NC}"

    echo ""
    echo -e "  ${CYAN}${BOLD}╔══════════════════════════════════════╗"
    echo -e "  ║   U-Claw v1.1                             ║"
    echo -e "  ║   Portable AI Agent                   ║"
    echo -e "  ╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Node: ${GREEN}${NODE_VER}${NC}  Config: ${CFG_STATUS}"
    echo ""
    echo -e "  ${WHITE}${BOLD}-- Setup --------------------------------${NC}"
    echo -e "  ${GREEN}[1]${NC}  Setup wizard (pick a model, enter API Key)"
    echo -e "  ${GREEN}[2]${NC}  Open web dashboard"
    echo ""
    echo -e "  ${WHITE}${BOLD}-- Chat apps (optional) -----------------${NC}"
    echo -e "  ${GREEN}[3]${NC}  Optional: QQ bot (if you use QQ)"
    echo -e "  ${GREEN}[4]${NC}  Other platforms (Telegram / Discord / Feishu)"
    echo ""
    echo -e "  ${WHITE}${BOLD}-- Maintenance --------------------------${NC}"
    echo -e "  ${GREEN}[5]${NC}  Diagnose and repair"
    echo -e "  ${GREEN}[6]${NC}  Backup config"
    echo -e "  ${GREEN}[7]${NC}  Restore backup"
    echo -e "  ${GREEN}[8]${NC}  System info"
    echo ""
    echo -e "  ${WHITE}${BOLD}-- Advanced -----------------------------${NC}"
    echo -e "  ${GREEN}[9]${NC}  Kill leftover processes"
    echo -e "  ${GREEN}[10]${NC} View logs"
    echo -e "  ${GREEN}[11]${NC} Factory reset"
    echo -e "  ${GREEN}[12]${NC} Uninstall"
    echo -e "  ${GREEN}[13]${NC} Check for updates"
    echo -e "  ${GREEN}[14]${NC} Free disk space"
    echo -e "  ${GREEN}[15]${NC} Plugins"
    echo -e "  ${GREEN}[16]${NC} Open CLI terminal (openclaw chat/configure/doctor)"
    echo ""
    echo -e "  ${DIM}[0]  Exit${NC}"
    echo ""
}

# [1] Config wizard
do_config() {
    echo ""
    echo -e "  ${CYAN}${BOLD}--- Setup wizard ---${NC}"
    echo ""
    echo -e "  ${WHITE}Provider hints:${NC}"
    echo ""
    echo -e "  DeepSeek  -> Custom Provider"
    echo -e "              URL: https://api.deepseek.com/v1"
    echo -e "              Model: deepseek-v4-flash"
    echo -e "  Kimi      -> Moonshot AI"
    echo -e "  Qwen      → choose Qwen"
    echo -e "  Doubao    → choose Volcano Engine"
    echo ""
    read -p "  Press Enter to start the wizard..."
    run_oc onboard
}

# [2] Web dashboard
do_dashboard() {
    echo ""
    echo -e "  ${CYAN}Starting web dashboard...${NC}"
    echo ""
    cd "$CORE_DIR"

    # Find free port
    local PORT=18789
    while lsof -i :$PORT >/dev/null 2>&1; do
        PORT=$((PORT + 1))
        if [ $PORT -gt 18799 ]; then
            echo -e "  ${RED}Ports 18789-18799 are all in use${NC}"
            return
        fi
    done

    local TOKEN=$(python3 -c "import json,os; p='$CONFIG_PATH'; d=json.load(open(p)) if os.path.exists(p) else {}; print(d.get('gateway',{}).get('auth',{}).get('token','uclaw'))" 2>/dev/null || echo "uclaw")

    "$NODE_BIN" "$OPENCLAW_MJS" gateway run --allow-unconfigured --force --port $PORT &
    local PID=$!

    for i in $(seq 1 30); do
        sleep 0.5
        if curl --noproxy '*' -s -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; then
            local URL="http://127.0.0.1:$PORT/#token=$TOKEN"
            echo -e "  ${GREEN}Dashboard: $URL${NC}"
            open "$URL" 2>/dev/null
            break
        fi
    done

    echo "  Closing this window stops the service"
    wait $PID
}

# [3] QQ Bot (pre-installed)
do_qq() {
    echo ""
    echo -e "  ${CYAN}${BOLD}--- Optional QQ bot ---${NC}"
    echo ""
    echo -e "  ${GREEN}QQ plugin is bundled. Enter AppID and AppSecret if you use QQ.${NC}"
    echo ""
    echo "  Get credentials at q.qq.com -> create a bot"
    echo ""
    read -p "  AppID: " QQ_ID
    read -p "  AppSecret: " QQ_SECRET
    echo ""

    if [ -z "$QQ_ID" ] || [ -z "$QQ_SECRET" ]; then
        echo -e "  ${YELLOW}Cancelled${NC}"
        return
    fi

    run_oc channels add --channel qqbot --token "${QQ_ID}:${QQ_SECRET}" 2>&1 || true
    echo ""
    read -p "  Your QQ number (allowlist, empty to skip): " QQ_ALLOW
    if [ -n "$QQ_ALLOW" ]; then
        run_oc config set channels.qqbot.allowFrom "\"${QQ_ALLOW}\"" 2>&1 || true
        echo -e "  ${GREEN}Allowlist set${NC}"
    fi
    echo ""
    echo -e "  ${GREEN}QQ bot configured. Restart the gateway to apply.${NC}"
}

# [4] Other platforms
do_platforms() {
    echo ""
    echo -e "  ${CYAN}${BOLD}--- Other chat apps ---${NC}"
    echo ""
    echo -e "  ${GREEN}[a]${NC} Feishu / Lark     - optional work chat"
    echo -e "  ${GREEN}[b]${NC} Telegram          - recommended"
    echo -e "  ${GREEN}[c]${NC} WeChat (community) - currently unavailable"
    echo -e "  ${GREEN}[d]${NC} Discord"
    echo ""
    read -p "  Choose (a-d): " -n 1 CH
    echo ""
    echo ""

    case $CH in
        a) echo "  Feishu: create an app at open.feishu.cn/app" ;;
        b) echo "  Telegram: create a bot with @BotFather" ;;
        c)
            echo -e "  ${YELLOW}WeChat plugin is temporarily unavailable (upstream load issue; see WECHAT_ENABLED).${NC}"
            echo -e "  Wait for an upstream fix before installing."
            ;;
        d) echo "  Discord: discord.com/developers/applications" ;;
        *) echo "  Invalid choice" ;;
    esac
    echo ""
    echo "  After you have tokens, run setup wizard [1] to bind a platform"
}

# [5] Doctor
do_doctor() {
    echo ""
    echo -e "  ${CYAN}--- Diagnose and repair ---${NC}"
    echo ""
    run_oc doctor --repair 2>&1 || echo -e "  ${YELLOW}Doctor command failed${NC}"
}

# [6] Backup
do_backup() {
    echo ""
    local TS=$(date +%Y%m%d_%H%M%S)
    local BK="$DATA_DIR/backups/backup_$TS"
    mkdir -p "$BK"

    [ -f "$CONFIG_PATH" ] && cp "$CONFIG_PATH" "$BK/" && echo -e "  ${GREEN}  + openclaw.json${NC}"
    [ -d "$DATA_DIR/memory" ] && cp -R "$DATA_DIR/memory" "$BK/" 2>/dev/null && echo -e "  ${GREEN}  + memory/${NC}"

    echo ""
    echo -e "  ${GREEN}Backup done: $BK${NC}"
    echo "  Size: $(du -sh "$BK" | cut -f1)"
}

# [7] Restore
do_restore() {
    echo ""
    local BK_DIR="$DATA_DIR/backups"
    if [ ! -d "$BK_DIR" ] || [ -z "$(ls -A "$BK_DIR" 2>/dev/null)" ]; then
        echo -e "  ${YELLOW}No backups${NC}"
        return
    fi

    echo "  Available backups:"
    local i=1
    for b in "$BK_DIR"/*/; do
        echo -e "  ${GREEN}[$i]${NC} $(basename "$b") ($(du -sh "$b" | cut -f1))"
        i=$((i+1))
    done
    echo ""
    read -p "  Choose a number: " NUM

    local j=1
    for b in "$BK_DIR"/*/; do
        if [ "$j" = "$NUM" ]; then
            [ -f "$b/openclaw.json" ] && cp "$b/openclaw.json" "$CONFIG_PATH" && echo -e "  ${GREEN}  + config restored${NC}"
            [ -d "$b/memory" ] && cp -R "$b/memory" "$DATA_DIR/" && echo -e "  ${GREEN}  + memory restored${NC}"
            echo -e "  ${GREEN}Restore complete${NC}"
            return
        fi
        j=$((j+1))
    done
    echo -e "  ${RED}Invalid choice${NC}"
}

# [8] System info
do_sysinfo() {
    echo ""
    echo "  OS:    $(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
    echo "  CPU:   $(uname -m)"
    echo "  RAM:    $(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f GB", $1/1024/1024/1024}')"
    echo "  Node:  $("$NODE_BIN" --version 2>/dev/null)"
    echo "  Path:  $UCLAW_DIR"
    echo "  Size:  $(du -sh "$UCLAW_DIR" 2>/dev/null | cut -f1)"
    echo "  Disk:  $(df -h "$UCLAW_DIR" | tail -1 | awk '{print $4 " free"}')"
}

# [16] CLI terminal (advanced: openclaw chat/configure/doctor)
do_cli() {
    echo ""
    echo -e "  ${CYAN}${BOLD}--- CLI terminal ---${NC}"
    echo ""
    echo "  Opening a new terminal with openclaw on PATH..."
    open "$UCLAW_DIR/Mac-OpenClaw-CLI.command" 2>/dev/null || \
        echo -e "  ${YELLOW}Could not open a new window. Double-click Mac-OpenClaw-CLI.command${NC}"
}

# Main loop
while true; do
    show_menu
    read -p "  Choose [0-16]: " CHOICE
    echo ""

    case $CHOICE in
        1) do_config ;;
        2) do_dashboard ;;
        3) do_qq ;;
        4) do_platforms ;;
        5) do_doctor ;;
        6) do_backup ;;
        7) do_restore ;;
        8) do_sysinfo ;;
        9) do_kill_gateway ;;
        10) do_logs ;;
        11) do_factory_reset ;;
        12) do_uninstall ;;
        13) do_update ;;
        14) do_cleanup ;;
        15) do_plugins ;;
        16) do_cli ;;
        0) echo -e "  ${CYAN}Bye!${NC}"; exit 0 ;;
        *) echo -e "  ${RED}Invalid choice${NC}" ;;
    esac

    echo ""
    read -p "  Press Enter to return..."
done
