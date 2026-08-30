#!/bin/bash
# ============================================================
# U-Claw - Local / intranet model setup (macOS)
# Double-click: configure Ollama / newapi from the CLI and test (does not touch the web UI)
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
if [ ! -x "$NODE_BIN" ]; then NODE_BIN="$(command -v node)"; fi
if [ -z "$NODE_BIN" ] || [ ! -x "$NODE_BIN" ]; then
    echo "  [ERROR] Node runtime not found. Start U-Claw once first."
    read -p "  Press Enter to close..."
    exit 1
fi

xattr -rd com.apple.quarantine "$UCLAW_DIR" 2>/dev/null || true

"$NODE_BIN" "$UCLAW_DIR/lib/setup-local-model.mjs" "$CONFIG_FILE"

echo ""
read -p "  Press Enter to close..."
