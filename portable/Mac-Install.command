#!/bin/bash
# ============================================================
# U-Claw - Install to Mac (copy from USB to this computer)
# Prefer files already on the USB; download only if missing
# ============================================================

set -e

UCLAW_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$UCLAW_DIR/app"
INSTALL_TARGET="$HOME/.uclaw"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

NODE_VER="v22.22.3"
MIRROR="https://registry.npmjs.org"
# China fallback: MIRROR="https://registry.npmmirror.com"
NODE_MIRROR="https://nodejs.org/dist"
# China fallback: NODE_MIRROR="https://npmmirror.com/mirrors/node"

clear
echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║   Install U-Claw on Mac                  ║"
echo "  ║   Offline install from USB                     ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ---- Check CPU ----
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    echo -e "  ${GREEN}Apple Silicon (M series) OK${NC}"
    NODE_PLATFORM="node-mac-arm64"
else
    echo -e "  ${YELLOW}Intel Mac${NC}"
    NODE_PLATFORM="node-mac-x64"
fi
echo ""

# ---- Check existing installation ----
if [ -d "$INSTALL_TARGET" ]; then
    echo -e "  ${YELLOW}Existing install found: $INSTALL_TARGET${NC}"
    read -p "  Overwrite? (y/n): " -n 1 OVERWRITE
    echo ""
    if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
        echo -e "  ${DIM}Cancelled${NC}"
        exit 0
    fi
    echo ""
fi

# ---- Step 1: Check environment ----
echo -e "  ${BOLD}[1/4] Checking environment...${NC}"

NEED_DOWNLOAD_NODE=false
NEED_DOWNLOAD_OPENCLAW=false

# Check Node.js - prefer USB, then system, then download
USB_NODE="$APP_DIR/runtime/$NODE_PLATFORM/bin/node"
USB_NPM="$APP_DIR/runtime/$NODE_PLATFORM/bin/npm"

if [ -f "$USB_NODE" ]; then
    echo -e "  ${GREEN}Node.js: using USB copy ($("$USB_NODE" --version))${NC}"
    USE_NODE="usb"
elif command -v node >/dev/null 2>&1; then
    SYS_VER=$(node --version)
    MAJOR=$(echo "$SYS_VER" | sed 's/v//' | cut -d. -f1)
    if [ "$MAJOR" -ge 20 ] 2>/dev/null; then
        echo -e "  ${GREEN}Node.js: using system ($SYS_VER)${NC}"
        USE_NODE="system"
    else
        echo -e "  ${YELLOW}Node.js: system version too old ($SYS_VER), need v20+${NC}"
        NEED_DOWNLOAD_NODE=true
        USE_NODE="download"
    fi
else
    echo -e "  ${YELLOW}Node.js: not installed${NC}"
    NEED_DOWNLOAD_NODE=true
    USE_NODE="download"
fi

# Check OpenClaw
USB_OPENCLAW="$APP_DIR/core/node_modules/openclaw/openclaw.mjs"
if [ -f "$USB_OPENCLAW" ]; then
    echo -e "  ${GREEN}OpenClaw: using USB copy${NC}"
    USE_OPENCLAW="usb"
else
    echo -e "  ${YELLOW}OpenClaw: not on USB, will download${NC}"
    NEED_DOWNLOAD_OPENCLAW=true
    USE_OPENCLAW="download"
fi

echo ""

# ---- Step 2: Create install directory ----
echo -e "  ${BOLD}[2/4] Installing to $INSTALL_TARGET ...${NC}"

mkdir -p "$INSTALL_TARGET"
mkdir -p "$INSTALL_TARGET/data/.openclaw"
mkdir -p "$INSTALL_TARGET/data/memory"
mkdir -p "$INSTALL_TARGET/data/backups"

# ---- Step 3: Copy/Download Node.js ----
echo -e "  ${BOLD}[3/4] Installing Node.js...${NC}"

NODE_INSTALL_DIR="$INSTALL_TARGET/runtime/$NODE_PLATFORM"

case $USE_NODE in
    usb)
        echo -e "  ${CYAN}Copying Node.js from USB...${NC}"
        mkdir -p "$NODE_INSTALL_DIR"
        cp -R "$APP_DIR/runtime/$NODE_PLATFORM/"* "$NODE_INSTALL_DIR/"
        chmod +x "$NODE_INSTALL_DIR/bin/node"
        INSTALL_NODE="$NODE_INSTALL_DIR/bin/node"
        INSTALL_NPM="$NODE_INSTALL_DIR/bin/npm"
        echo -e "  ${GREEN}Node.js installed OK${NC}"
        ;;
    system)
        INSTALL_NODE="$(which node)"
        INSTALL_NPM="$(which npm)"
        echo -e "  ${GREEN}Using system Node.js OK${NC}"
        ;;
    download)
        echo -e "  ${CYAN}Downloading Node.js $NODE_VER...${NC}"
        PLATFORM_NAME="darwin-$ARCH"
        TARBALL="node-${NODE_VER}-${PLATFORM_NAME}.tar.gz"
        URL="${NODE_MIRROR}/${NODE_VER}/${TARBALL}"

        mkdir -p "$NODE_INSTALL_DIR"
        curl -# -L "$URL" -o "/tmp/$TARBALL"
        tar -xzf "/tmp/$TARBALL" -C "$NODE_INSTALL_DIR" --strip-components=1
        rm -f "/tmp/$TARBALL"
        chmod +x "$NODE_INSTALL_DIR/bin/node"
        INSTALL_NODE="$NODE_INSTALL_DIR/bin/node"
        INSTALL_NPM="$NODE_INSTALL_DIR/bin/npm"
        echo -e "  ${GREEN}Node.js downloaded OK${NC}"
        ;;
esac

echo ""

# ---- Step 4: Copy/Download OpenClaw ----
echo -e "  ${BOLD}[4/4] Installing OpenClaw...${NC}"

CORE_INSTALL_DIR="$INSTALL_TARGET/core"

case $USE_OPENCLAW in
    usb)
        echo -e "  ${CYAN}Copying OpenClaw + plugins from USB...${NC}"
        mkdir -p "$CORE_INSTALL_DIR"
        cp -R "$APP_DIR/core/"* "$CORE_INSTALL_DIR/"
        echo -e "  ${GREEN}OpenClaw installed OK${NC}"
        ;;
    download)
        echo -e "  ${CYAN}Downloading OpenClaw...${NC}"
        mkdir -p "$CORE_INSTALL_DIR"
        cat > "$CORE_INSTALL_DIR/package.json" << 'PKGEOF'
{
  "name": "u-claw-core",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "openclaw": "latest"
  }
}
PKGEOF
        cd "$CORE_INSTALL_DIR"
        "$INSTALL_NODE" "$INSTALL_NPM" install --registry="$MIRROR" 2>&1 | tail -3
        "$INSTALL_NODE" "$INSTALL_NPM" install @sliverp/qqbot@latest --registry="$MIRROR" 2>&1 | tail -2
        echo -e "  ${GREEN}OpenClaw downloaded OK${NC}"
        ;;
esac

# ---- Stage WeChat plugin into the dir OpenClaw actually reads ----
# OpenClaw loads extensions ONLY from OPENCLAW_STATE_DIR/extensions; start.command
# points STATE_DIR at $INSTALL_TARGET/data/.openclaw, so the plugin must live there.
WECHAT_DST="$INSTALL_TARGET/data/.openclaw/extensions/openclaw-weixin"
if [ -f "$APP_DIR/extensions/openclaw-weixin/openclaw.plugin.json" ]; then
    echo -e "  ${CYAN}Installing WeChat plugin...${NC}"
    mkdir -p "$INSTALL_TARGET/data/.openclaw/extensions"
    if cp -R "$APP_DIR/extensions/openclaw-weixin" "$WECHAT_DST" 2>/dev/null; then
        echo -e "  ${GREEN}WeChat plugin installed ✓${NC}"
    fi
    # Copy zod from the bundled OpenClaw core: the plugin's npm tarball ships without it
    # and the host node_modules is off the plugin's resolution path, so otherwise it
    # fails to load with "Cannot find module 'zod'".
    if [ ! -d "$WECHAT_DST/node_modules/zod" ] && [ -d "$APP_DIR/core/node_modules/zod" ]; then
        mkdir -p "$WECHAT_DST/node_modules"
        cp -R "$APP_DIR/core/node_modules/zod" "$WECHAT_DST/node_modules/zod" 2>/dev/null
    fi
fi

# ---- Default config ----
CONFIG_PATH="$INSTALL_TARGET/data/.openclaw/openclaw.json"
if [ ! -f "$CONFIG_PATH" ]; then
    cat > "$CONFIG_PATH" << 'CFGEOF'
{
  "gateway": {
    "mode": "local",
    "auth": { "token": "uclaw" }
  }
}
CFGEOF
fi

# ---- Copy launch scripts ----
for f in Config.html U-Claw.html; do
    [ -f "$UCLAW_DIR/$f" ] && cp "$UCLAW_DIR/$f" "$INSTALL_TARGET/"
done

# ---- Create launch script ----
cat > "$INSTALL_TARGET/start.command" << 'STARTEOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ARCH=$(uname -m)
NODE_PLATFORM="node-mac-$( [ "$ARCH" = "arm64" ] && echo "arm64" || echo "x64" )"

NODE_BIN="$DIR/runtime/$NODE_PLATFORM/bin/node"
[ ! -f "$NODE_BIN" ] && NODE_BIN="$(which node)"

CORE_DIR="$DIR/core"
OPENCLAW_MJS="$CORE_DIR/node_modules/openclaw/openclaw.mjs"

export OPENCLAW_HOME="$DIR/data"
export OPENCLAW_STATE_DIR="$DIR/data/.openclaw"
export OPENCLAW_CONFIG_PATH="$DIR/data/.openclaw/openclaw.json"

PORT=18789
while lsof -i :$PORT >/dev/null 2>&1; do
    PORT=$((PORT + 1))
    [ $PORT -gt 18799 ] && echo "No available port" && exit 1
done

cd "$CORE_DIR"
"$NODE_BIN" "$OPENCLAW_MJS" gateway run --allow-unconfigured --force --port $PORT &
PID=$!

for i in $(seq 1 30); do
    sleep 0.5
    if curl -s -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; then
        open "http://127.0.0.1:$PORT/#token=uclaw"
        break
    fi
done

wait $PID
STARTEOF
chmod +x "$INSTALL_TARGET/start.command"

echo ""

# ---- Summary ----
INSTALL_SIZE=$(du -sh "$INSTALL_TARGET" | cut -f1)

echo -e "  ${GREEN}${BOLD}╔══════════════════════════════════════╗"
echo -e "  ║   Install succeeded                          ║"
echo -e "  ╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Location:${NC} $INSTALL_TARGET"
echo -e "  ${BOLD}Size:${NC}     $INSTALL_SIZE"
echo ""
echo -e "  ${BOLD}Start:${NC}"
echo -e "    Double-click ${CYAN}$INSTALL_TARGET/start.command${NC}"
echo -e "    Or run: ${CYAN}bash ~/.uclaw/start.command${NC}"
echo ""
echo -e "  ${BOLD}First use:${NC}"
echo -e "    After start, the browser opens the config page"
echo -e "    Pick a model -> enter API Key -> start"
echo ""
read -p "  Press Enter to close..."
