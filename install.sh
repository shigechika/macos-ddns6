#!/bin/bash
# install.sh — Install macos-ddns6
#
# Usage:
#   git clone https://github.com/shigechika/macos-ddns6.git
#   cd macos-ddns6
#   ./install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/usr/local/lib/macos-ddns6"
BIN_LINK="/usr/local/bin/ddns6-update.sh"
PLIST_SRC="$SCRIPT_DIR/launchd/com.github.macos-ddns6.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.github.macos-ddns6.plist"
CONFIG_DIR="$HOME/.config/macos-ddns6"

echo "==> Installing macos-ddns6"

# Copy files to /usr/local/lib/macos-ddns6
sudo mkdir -p "$INSTALL_DIR"
sudo cp -R "$SCRIPT_DIR/ddns6-update.sh" "$SCRIPT_DIR/lib" "$SCRIPT_DIR/providers" "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/ddns6-update.sh"

# Symlink to /usr/local/bin
sudo ln -sf "$INSTALL_DIR/ddns6-update.sh" "$BIN_LINK"
echo "    $BIN_LINK -> $INSTALL_DIR/ddns6-update.sh"

# Config file
if [[ ! -f "$CONFIG_DIR/ddns6.conf" ]]; then
    mkdir -p "$CONFIG_DIR"
    cp "$SCRIPT_DIR/ddns6.conf.example" "$CONFIG_DIR/ddns6.conf"
    echo "    Created $CONFIG_DIR/ddns6.conf — please edit before starting"
else
    echo "    Config already exists: $CONFIG_DIR/ddns6.conf"
fi

# launchd plist
if launchctl list 2>/dev/null | grep -q com.github.macos-ddns6; then
    launchctl unload "$PLIST_DST" 2>/dev/null || true
fi
cp "$PLIST_SRC" "$PLIST_DST"
echo "    Installed launchd plist: $PLIST_DST"

echo ""
echo "==> Next steps:"
echo "    1. Edit $CONFIG_DIR/ddns6.conf"
echo "    2. launchctl load $PLIST_DST"
echo "    3. Check /tmp/ddns6-update.log"
