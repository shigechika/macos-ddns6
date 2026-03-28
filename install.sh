#!/bin/bash
# install.sh — Install macos-ddns6
#
# Usage:
#   ./install.sh            # LaunchAgent (runs when user is logged in)
#   ./install.sh --daemon   # LaunchDaemon (runs at boot, no login required)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/usr/local/lib/macos-ddns6"
BIN_LINK="/usr/local/bin/ddns6-update.sh"
LABEL="com.github.macos-ddns6"

# Parse options
DAEMON_MODE=false
if [[ "${1:-}" == "--daemon" ]]; then
    DAEMON_MODE=true
fi

if [[ "$DAEMON_MODE" == true ]]; then
    PLIST_SRC="$SCRIPT_DIR/launchd/com.github.macos-ddns6.daemon.plist"
    PLIST_DST="/Library/LaunchDaemons/com.github.macos-ddns6.plist"
    CONFIG_DIR="/etc/macos-ddns6"
    echo "==> Installing macos-ddns6 (LaunchDaemon — runs at boot)"
else
    PLIST_SRC="$SCRIPT_DIR/launchd/com.github.macos-ddns6.plist"
    PLIST_DST="$HOME/Library/LaunchAgents/com.github.macos-ddns6.plist"
    CONFIG_DIR="$HOME/.config/macos-ddns6"
    echo "==> Installing macos-ddns6 (LaunchAgent — runs when logged in)"
fi

# Copy files to /usr/local/lib/macos-ddns6
sudo mkdir -p "$INSTALL_DIR"
sudo cp -R "$SCRIPT_DIR/ddns6-update.sh" "$SCRIPT_DIR/lib" "$SCRIPT_DIR/providers" "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/ddns6-update.sh"

# Symlink to /usr/local/bin
sudo ln -sf "$INSTALL_DIR/ddns6-update.sh" "$BIN_LINK"
echo "    $BIN_LINK -> $INSTALL_DIR/ddns6-update.sh"

# Config file
if [[ ! -f "$CONFIG_DIR/ddns6.conf" ]]; then
    sudo mkdir -p "$CONFIG_DIR"
    sudo cp "$SCRIPT_DIR/ddns6.conf.example" "$CONFIG_DIR/ddns6.conf"
    if [[ "$DAEMON_MODE" == true ]]; then
        sudo chmod 600 "$CONFIG_DIR/ddns6.conf"
    fi
    echo "    Created $CONFIG_DIR/ddns6.conf — please edit before starting"
else
    echo "    Config already exists: $CONFIG_DIR/ddns6.conf"
fi

# Detect Python 3.10+ for CLOUDSDK_PYTHON
CLOUDSDK_PYTHON=""
for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
    if [[ -x "$candidate" ]]; then
        ver=$("$candidate" -c "import sys; print(sys.version_info.minor)" 2>/dev/null || echo "0")
        if [[ "$ver" -ge 10 ]]; then
            CLOUDSDK_PYTHON="$candidate"
            break
        fi
    fi
done
if [[ -z "$CLOUDSDK_PYTHON" ]]; then
    echo "    WARNING: Python 3.10+ not found. gcloud may not work."
    CLOUDSDK_PYTHON="/usr/bin/python3"
fi
echo "    CLOUDSDK_PYTHON: $CLOUDSDK_PYTHON"

# Unload existing service
if [[ "$DAEMON_MODE" == true ]]; then
    sudo launchctl unload "$PLIST_DST" 2>/dev/null || true
else
    launchctl unload "$PLIST_DST" 2>/dev/null || true
fi

# Install plist (replace placeholders)
sed -e "s|CLOUDSDK_PYTHON_PLACEHOLDER|$CLOUDSDK_PYTHON|" \
    -e "s|DDNS6_CONFIG_PLACEHOLDER|$CONFIG_DIR/ddns6.conf|" \
    "$PLIST_SRC" | sudo tee "$PLIST_DST" > /dev/null

if [[ "$DAEMON_MODE" == true ]]; then
    sudo chown root:wheel "$PLIST_DST"
    sudo chmod 644 "$PLIST_DST"
fi
echo "    Installed plist: $PLIST_DST"

echo ""
echo "==> Next steps:"
echo "    1. Edit $CONFIG_DIR/ddns6.conf"
if [[ "$DAEMON_MODE" == true ]]; then
    echo "    2. sudo launchctl load $PLIST_DST"
    echo "    3. Check /var/log/ddns6-update.log"
else
    echo "    2. launchctl load $PLIST_DST"
    echo "    3. Check /tmp/ddns6-update.log"
fi
