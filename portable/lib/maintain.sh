#!/bin/bash
# ============================================================
# U-Claw Maintenance Functions (shared by Mac menus)
# Requires caller to set: $UCLAW_DIR, $DATA_DIR, $STATE_DIR,
#   $CONFIG_PATH, $NODE_BIN, $NPM_BIN, $CORE_DIR,
#   color vars ($RED $GREEN $YELLOW $CYAN $WHITE $NC $BOLD $DIM),
#   and run_oc() function.
# ============================================================

LOG_DIR="$DATA_DIR/logs"
BACKUP_DIR="$DATA_DIR/backups"
DEFAULT_CONFIG="$UCLAW_DIR/default-config.json"

# Detect install mode: installed (~/.uclaw), usb (/Volumes or /media), portable (other)
detect_install_mode() {
    if echo "$UCLAW_DIR" | grep -q "/.uclaw"; then
        echo "installed"
    elif echo "$UCLAW_DIR" | grep -qE "/Volumes/|/media/|/mnt/"; then
        echo "usb"
    else
        echo "portable"
    fi
}

# ── [9] Kill residual gateway processes ──────────────────────

do_kill_gateway() {
    echo ""
    echo -e "  ${CYAN}${BOLD}━━━ Kill leftover processes ━━━${NC}"
    echo ""

    local FOUND=0

    # Method 1: Check ports 18789-18799
    for PORT in $(seq 18789 18799); do
        local PIDS=""
        if command -v lsof >/dev/null 2>&1; then
            PIDS=$(lsof -ti :$PORT 2>/dev/null)
        elif command -v ss >/dev/null 2>&1; then
            PIDS=$(ss -tlnp 2>/dev/null | grep ":$PORT " | sed -n 's/.*pid=\([0-9]*\).*/\1/p')
        fi
        if [ -n "$PIDS" ]; then
            for PID in $PIDS; do
                local CMD=$(ps -p "$PID" -o comm= 2>/dev/null || echo "unknown")
                echo -e "  ${YELLOW}Port $PORT: PID $PID ($CMD)${NC}"
                FOUND=1
            done
        fi
    done

    # Method 2: Check for openclaw.mjs processes
    local OC_PIDS=$(pgrep -f "openclaw.mjs gateway" 2>/dev/null)
    if [ -n "$OC_PIDS" ]; then
        for PID in $OC_PIDS; do
            echo -e "  ${YELLOW}OpenClaw gateway process: PID $PID${NC}"
            FOUND=1
        done
    fi

    if [ "$FOUND" = "0" ]; then
        echo -e "  ${GREEN}No leftover processes${NC}"
        return
    fi

    echo ""
    read -p "  Kill these processes? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo -e "  ${YELLOW}Cancelled${NC}"
        return
    fi

    # Kill port processes
    for PORT in $(seq 18789 18799); do
        if command -v lsof >/dev/null 2>&1; then
            lsof -ti :$PORT 2>/dev/null | xargs kill 2>/dev/null
        elif command -v ss >/dev/null 2>&1; then
            ss -tlnp 2>/dev/null | grep ":$PORT " | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | xargs kill 2>/dev/null
        fi
    done

    # Kill openclaw.mjs processes
    pgrep -f "openclaw.mjs gateway" 2>/dev/null | xargs kill 2>/dev/null

    sleep 1
    echo -e "  ${GREEN}Processes cleared${NC}"
}

# ── [10] View/export/clean logs ──────────────────────────────

do_logs() {
    echo ""
    echo -e "  ${CYAN}${BOLD}━━━ Logs ━━━${NC}"
    echo ""

    mkdir -p "$LOG_DIR"
    local LOG_FILE="$LOG_DIR/gateway.log"

    echo -e "  ${GREEN}[a]${NC}  View recent logs (last 50 lines)"
    echo -e "  ${GREEN}[b]${NC}  Export logs to Desktop"
    echo -e "  ${GREEN}[c]${NC}  Delete logs older than 7 days"
    echo ""
    read -p "  Choose (a-c): " -n 1 LOG_CHOICE
    echo ""
    echo ""

    case $LOG_CHOICE in
        a)
            if [ -f "$LOG_FILE" ]; then
                echo -e "  ${DIM}── $LOG_FILE ──${NC}"
                echo ""
                tail -50 "$LOG_FILE"
            else
                echo -e "  ${YELLOW}Log file not found: $LOG_FILE${NC}"
                echo "  Logs are created after the gateway starts."
            fi
            ;;
        b)
            if [ ! -f "$LOG_FILE" ]; then
                echo -e "  ${YELLOW}No logs to export${NC}"
                return
            fi
            local TS=$(date +%Y%m%d_%H%M%S)
            local EXPORT_DIR="$HOME/Desktop"
            [ ! -d "$EXPORT_DIR" ] && EXPORT_DIR="$HOME"
            local EXPORT_FILE="$EXPORT_DIR/uclaw-logs-$TS.txt"
            cp "$LOG_FILE" "$EXPORT_FILE"
            echo -e "  ${GREEN}Logs exported: $EXPORT_FILE${NC}"
            echo "  Size: $(du -sh "$EXPORT_FILE" | cut -f1)"
            ;;
        c)
            local COUNT=$(find "$LOG_DIR" -name "*.log" -mtime +7 2>/dev/null | wc -l | tr -d ' ')
            if [ "$COUNT" = "0" ]; then
                echo -e "  ${GREEN}No old logs to clean${NC}"
                return
            fi
            echo -e "  Found ${YELLOW}$COUNT${NC} log files older than 7 days"
            read -p "  Clean them? (y/N): " CONFIRM
            if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
                find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null
                echo -e "  ${GREEN}Old logs removed${NC}"
            else
                echo -e "  ${YELLOW}Cancelled${NC}"
            fi
            ;;
        *)
            echo -e "  ${RED}Invalid choice${NC}"
            ;;
    esac
}

# ── [11] Factory reset ───────────────────────────────────────

do_factory_reset() {
    echo ""
    echo -e "  ${RED}${BOLD}━━━ Factory reset ━━━${NC}"
    echo ""
    echo -e "  ${RED}Warning: this deletes all config and memory!${NC}"
    echo ""
    echo "  This will:"
    echo "    1. Auto-backup current config and memory"
    echo "    2. Delete config (openclaw.json)"
    echo "    3. Delete memory (memory/)"
    echo "    4. Restore default config"
    echo ""
    echo -e "  ${YELLOW}请输入 RESET 确认（区分Size写）:${NC}"
    read -p "  > " CONFIRM

    if [ "$CONFIRM" != "RESET" ]; then
        echo -e "  ${YELLOW}Cancelled${NC}"
        return
    fi

    # Step 1: Auto backup
    echo ""
    echo -e "  ${CYAN}[1/4] Auto backup...${NC}"
    local TS=$(date +%Y%m%d_%H%M%S)
    local BK="$BACKUP_DIR/pre-reset_$TS"
    mkdir -p "$BK"
    [ -f "$CONFIG_PATH" ] && cp "$CONFIG_PATH" "$BK/" 2>/dev/null
    [ -d "$DATA_DIR/memory" ] && cp -R "$DATA_DIR/memory" "$BK/" 2>/dev/null
    echo -e "  ${GREEN}Backup saved: $BK${NC}"

    # Step 2: Delete config
    echo -e "  ${CYAN}[2/4] Deleting config...${NC}"
    rm -f "$CONFIG_PATH" 2>/dev/null
    rm -f "$DATA_DIR/config.json" 2>/dev/null

    # Step 3: Delete memory
    echo -e "  ${CYAN}[3/4] Clearing memory...${NC}"
    rm -rf "$DATA_DIR/memory" 2>/dev/null
    mkdir -p "$DATA_DIR/memory"

    # Step 4: Restore default config
    echo -e "  ${CYAN}[4/4] Restore default config...${NC}"
    mkdir -p "$STATE_DIR"
    if [ -f "$DEFAULT_CONFIG" ]; then
        cp "$DEFAULT_CONFIG" "$CONFIG_PATH"
    else
        cat > "$CONFIG_PATH" << 'CFGEOF'
{
  "gateway": {
    "mode": "local",
    "auth": { "token": "uclaw" }
  }
}
CFGEOF
    fi

    echo ""
    echo -e "  ${GREEN}Factory reset complete.${NC}"
    echo -e "  Backup location: $BK"
    echo -e "  Run setup wizard [1] to configure a model."
}

# ── [12] Uninstall ───────────────────────────────────────────

do_uninstall() {
    echo ""
    echo -e "  ${RED}${BOLD}━━━ Uninstall U-Claw ━━━${NC}"
    echo ""

    local MODE=$(detect_install_mode)

    case $MODE in
        installed)
            echo "  Detected: installed copy (~/.uclaw/)"
            echo ""
            echo "  This will delete:"
            echo -e "    ${YELLOW}$HOME/.uclaw/${NC}"
            if [ -d "$HOME/.uclaw" ]; then
                echo "    Size: $(du -sh "$HOME/.uclaw" 2>/dev/null | cut -f1)"
            fi
            echo ""
            echo -e "  ${RED}Type UNINSTALL to confirm:${NC}"
            read -p "  > " CONFIRM
            if [ "$CONFIRM" != "UNINSTALL" ]; then
                echo -e "  ${YELLOW}Cancelled${NC}"
                return
            fi
            rm -rf "$HOME/.uclaw"
            echo -e "  ${GREEN}Uninstall complete.${NC}"
            ;;
        usb)
            echo "  Detected: USB mode"
            echo ""
            echo "  Portable copy does not need uninstall. Just:"
            echo "    1. Close all U-Claw windows"
            echo "    2. Eject the USB safely"
            echo "    3. To clear host data, delete ~/.uclaw/ if it exists"
            echo ""
            if [ -d "$HOME/.uclaw" ]; then
                echo -e "  ${YELLOW}Host data found: ~/.uclaw/${NC}"
                echo "  Size: $(du -sh "$HOME/.uclaw" 2>/dev/null | cut -f1)"
                read -p "  Delete host data? (y/N): " DEL
                if [ "$DEL" = "y" ] || [ "$DEL" = "Y" ]; then
                    rm -rf "$HOME/.uclaw"
                    echo -e "  ${GREEN}Host data removed${NC}"
                fi
            fi
            ;;
        portable)
            echo "  Detected: portable copy"
            echo ""
            echo "  Just delete the folder:"
            echo -e "    ${YELLOW}$UCLAW_DIR${NC}"
            echo ""
            if [ -d "$HOME/.uclaw" ]; then
                echo -e "  ${YELLOW}Host data found: ~/.uclaw/${NC}"
                echo "  Size: $(du -sh "$HOME/.uclaw" 2>/dev/null | cut -f1)"
                read -p "  Delete host data? (y/N): " DEL
                if [ "$DEL" = "y" ] || [ "$DEL" = "Y" ]; then
                    rm -rf "$HOME/.uclaw"
                    echo -e "  ${GREEN}Host data removed${NC}"
                fi
            fi
            echo ""
            echo "  Electron app uninstall:"
            echo "    macOS: drag U-Claw.app from Applications to Trash"
            ;;
    esac
}

# ── [13] Check for updates (P1) ─────────────────────────────

do_update() {
    echo ""
    echo -e "  ${CYAN}${BOLD}━━━ Check for updates ━━━${NC}"
    echo ""

    if [ ! -f "$NODE_BIN" ]; then
        echo -e "  ${RED}Node.js 未找到，无法Check for updates${NC}"
        return
    fi

    echo -e "  ${DIM}Checking latest version...${NC}"

    # Get current version
    local CUR_VER=""
    if [ -f "$CORE_DIR/node_modules/openclaw/package.json" ]; then
        CUR_VER=$("$NODE_BIN" -e "console.log(require('$CORE_DIR/node_modules/openclaw/package.json').version)" 2>/dev/null)
    fi

    if [ -z "$CUR_VER" ]; then
        echo -e "  ${RED}Cannot read current version (OpenClaw may be missing)${NC}"
        return
    fi

    # Get latest version from npmmirror
    local LATEST_VER=$(curl -s --connect-timeout 10 "https://registry.npmjs.org/openclaw/latest" 2>/dev/null | "$NODE_BIN" -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).version)}catch(e){console.log('error')}})" 2>/dev/null)

    if [ -z "$LATEST_VER" ] || [ "$LATEST_VER" = "error" ]; then
        echo -e "  ${YELLOW}Cannot fetch latest version (network?)${NC}"
        echo "  Current: $CUR_VER"
        return
    fi

    echo "  Current: $CUR_VER"
    echo "  Latest: $LATEST_VER"
    echo ""

    if [ "$CUR_VER" = "$LATEST_VER" ]; then
        echo -e "  ${GREEN}已是Latest！${NC}"
        return
    fi

    echo -e "  ${YELLOW}A newer version is available.${NC}"
    read -p "  Upgrade now? (y/N): " DO_UPDATE
    if [ "$DO_UPDATE" != "y" ] && [ "$DO_UPDATE" != "Y" ]; then
        echo -e "  ${YELLOW}Cancelled${NC}"
        return
    fi

    echo ""
    echo -e "  ${CYAN}Upgrading...${NC}"
    cd "$CORE_DIR"
    "$NPM_BIN" install openclaw@latest --registry=https://registry.npmjs.org 2>&1
    local NEW_VER=$("$NODE_BIN" -e "console.log(require('./node_modules/openclaw/package.json').version)" 2>/dev/null)
    echo ""
    echo -e "  ${GREEN}Upgrade complete.${NC} $CUR_VER → $NEW_VER"
}

# ── [14] Disk cleanup (P1) ───────────────────────────────────

do_cleanup() {
    echo ""
    echo -e "  ${CYAN}${BOLD}━━━ Free disk space ━━━${NC}"
    echo ""

    # Show directory sizes
    echo -e "  ${WHITE}Disk use:${NC}"
    [ -d "$CORE_DIR/node_modules" ] && echo "    node_modules: $(du -sh "$CORE_DIR/node_modules" 2>/dev/null | cut -f1)"
    [ -d "$DATA_DIR/memory" ] && echo "    memory:       $(du -sh "$DATA_DIR/memory" 2>/dev/null | cut -f1)"
    [ -d "$BACKUP_DIR" ] && echo "    backups:      $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)"
    [ -d "$LOG_DIR" ] && echo "    logs:         $(du -sh "$LOG_DIR" 2>/dev/null | cut -f1)"
    echo "    Total:         $(du -sh "$UCLAW_DIR" 2>/dev/null | cut -f1)"
    echo ""

    local CLEANED=0

    # Clean old backups (keep latest 3)
    if [ -d "$BACKUP_DIR" ]; then
        local BK_COUNT=$(ls -d "$BACKUP_DIR"/*/ 2>/dev/null | wc -l | tr -d ' ')
        if [ "$BK_COUNT" -gt 3 ]; then
            local OLD_COUNT=$((BK_COUNT - 3))
            echo -e "  ${YELLOW}发现 $BK_COUNT 个备份，保留最新 3 个，删除 $OLD_COUNT 个旧备份${NC}"
            read -p "  确认? (y/N): " DEL_BK
            if [ "$DEL_BK" = "y" ] || [ "$DEL_BK" = "Y" ]; then
                ls -dt "$BACKUP_DIR"/*/ 2>/dev/null | tail -n "$OLD_COUNT" | while read -r DIR; do
                    rm -rf "$DIR"
                done
                echo -e "  ${GREEN}旧备份已清理${NC}"
                CLEANED=1
            fi
        else
            echo "  备份: ${BK_COUNT} 个（无需清理）"
        fi
    fi

    # Clean old logs (>7 days)
    if [ -d "$LOG_DIR" ]; then
        local OLD_LOGS=$(find "$LOG_DIR" -name "*.log" -mtime +7 2>/dev/null | wc -l | tr -d ' ')
        if [ "$OLD_LOGS" -gt 0 ]; then
            echo -e "  ${YELLOW}发现 $OLD_LOGS 个超过 7 天的日志${NC}"
            read -p "  Clean them? (y/N): " DEL_LOG
            if [ "$DEL_LOG" = "y" ] || [ "$DEL_LOG" = "Y" ]; then
                find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null
                echo -e "  ${GREEN}Old logs removed${NC}"
                CLEANED=1
            fi
        else
            echo "  日志: 无需清理"
        fi
    fi

    # Clean npm cache
    echo ""
    read -p "  是否清理 npm 缓存? (y/N): " DEL_CACHE
    if [ "$DEL_CACHE" = "y" ] || [ "$DEL_CACHE" = "Y" ]; then
        "$NPM_BIN" cache clean --force 2>/dev/null
        echo -e "  ${GREEN}npm 缓存已清理${NC}"
        CLEANED=1
    fi

    if [ "$CLEANED" = "0" ]; then
        echo ""
        echo -e "  ${GREEN}没有需要清理的内容${NC}"
    else
        echo ""
        echo "  清理后Total: $(du -sh "$UCLAW_DIR" 2>/dev/null | cut -f1)"
    fi
}

# ── [15] Plugin management (P1) ─────────────────────────────

do_plugins() {
    echo ""
    echo -e "  ${CYAN}${BOLD}━━━ Plugins ━━━${NC}"
    echo ""
    echo -e "  ${GREEN}[a]${NC}  List installed plugins"
    echo -e "  ${GREEN}[b]${NC}  Install plugin"
    echo -e "  ${GREEN}[c]${NC}  Remove plugin"
    echo ""
    read -p "  Choose (a-c): " -n 1 PLG_CHOICE
    echo ""
    echo ""

    case $PLG_CHOICE in
        a)
            echo -e "  ${WHITE}已Install plugin:${NC}"
            echo ""
            run_oc plugins list 2>&1 || echo -e "  ${YELLOW}无法获取插件列表${NC}"
            ;;
        b)
            echo "  Common plugins:"
            echo "    @icesword760/openclaw-wechat  — WeChat"
            echo "    @nicepkg/openclaw-plugin-qq    — QQ (community)"
            echo ""
            read -p "  Plugin name (empty to cancel): " PLG_NAME
            if [ -z "$PLG_NAME" ]; then
                echo -e "  ${YELLOW}Cancelled${NC}"
                return
            fi
            echo ""
            echo -e "  ${CYAN}Installing $PLG_NAME ...${NC}"
            run_oc plugins install "$PLG_NAME" 2>&1
            echo ""
            echo -e "  ${GREEN}Install complete${NC}"
            ;;
        c)
            echo -e "  ${WHITE}已Install plugin:${NC}"
            echo ""
            run_oc plugins list 2>&1 || true
            echo ""
            read -p "  Plugin to remove (empty to cancel): " PLG_NAME
            if [ -z "$PLG_NAME" ]; then
                echo -e "  ${YELLOW}Cancelled${NC}"
                return
            fi
            echo ""
            echo -e "  ${CYAN}Removing $PLG_NAME ...${NC}"
            run_oc plugins remove "$PLG_NAME" 2>&1
            echo ""
            echo -e "  ${GREEN}Removed${NC}"
            ;;
        *)
            echo -e "  ${RED}Invalid choice${NC}"
            ;;
    esac
}
