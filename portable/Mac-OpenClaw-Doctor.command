#!/bin/bash
# ============================================================
# U-Claw - OpenClaw Doctor (official full check, advanced, English)
# NOTE: start U-Claw first, or doctor stalls probing a gateway that is not up.
# Read-only: do not pass --fix/--repair/--force. Ctrl+C is safe.
# ============================================================

UCLAW_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$UCLAW_DIR/app"
CORE_DIR="$APP_DIR/core"
DATA_DIR="$UCLAW_DIR/data"
STATE_DIR="$DATA_DIR/.openclaw"
OPENCLAW_MJS="$CORE_DIR/node_modules/openclaw/openclaw.mjs"

ARCH=$(uname -m)
case "$ARCH" in
    arm64)  NODE_BIN="$APP_DIR/runtime/node-mac-arm64/bin/node" ;;
    x86_64) NODE_BIN="$APP_DIR/runtime/node-mac-x64/bin/node" ;;
    *)      NODE_BIN="" ;;
esac
if [ ! -x "$NODE_BIN" ]; then NODE_BIN="$(command -v node)"; fi
if [ -z "$NODE_BIN" ] || [ ! -x "$NODE_BIN" ]; then
    echo "  [ERROR] Node runtime not found."
    read -p "  Press Enter to close..."
    exit 1
fi
if [ ! -f "$OPENCLAW_MJS" ]; then
    echo "  [ERROR] OpenClaw runtime not found (app/core/node_modules/openclaw)."
    read -p "  Press Enter to close..."
    exit 1
fi

export OPENCLAW_HOME="$DATA_DIR"
export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_CONFIG_PATH="$STATE_DIR/openclaw.json"
export OPENCLAW_DISABLE_BONJOUR=1

xattr -rd com.apple.quarantine "$UCLAW_DIR" 2>/dev/null || true

echo ""
echo "  ========================================"
echo "    OpenClaw Doctor (official, English, slower)"
echo "  ========================================"
echo "  Make sure U-Claw is already running. Ctrl+C is safe (read-only)."
echo "  For a quicker model-connection check, use Mac-IntranetFix.command."
echo ""
read -p "  Press Enter to start..."

"$NODE_BIN" "$OPENCLAW_MJS" doctor --non-interactive

echo ""
read -p "  Press Enter to close..."
