#!/bin/bash
# ============================================================
# U-Claw - Intranet Check (macOS)
# Double-click: proxy env + direct reachability + one real chat
# ============================================================

UCLAW_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$UCLAW_DIR/app"
CONFIG_FILE="$UCLAW_DIR/data/.openclaw/openclaw.json"

ARCH=$(uname -m)
case "$ARCH" in
    arm64)  NODE_BIN="$APP_DIR/runtime/node-mac-arm64/bin/node" ;;
    x86_64) NODE_BIN="$APP_DIR/runtime/node-mac-x64/bin/node" ;;
    *)      NODE_BIN="" ;;
esac
# Fall back to system node
if [ ! -x "$NODE_BIN" ]; then NODE_BIN="$(command -v node)"; fi
if [ -z "$NODE_BIN" ] || [ ! -x "$NODE_BIN" ]; then
    echo "  [ERROR] Node runtime not found. Start U-Claw once first."
    read -p "  Press Enter to close..."
    exit 1
fi

# Remove macOS quarantine so Gatekeeper does not block
xattr -rd com.apple.quarantine "$UCLAW_DIR" 2>/dev/null || true

"$NODE_BIN" "$UCLAW_DIR/lib/intranet-check.mjs" "$CONFIG_FILE"

echo ""
echo "  Screenshot this window and send it to support."
echo ""
read -p "  Press Enter to close..."
