#!/bin/bash
# install.sh — Install macos-ddns6
#
# Usage:
#   ./install.sh            # LaunchAgent (runs when user is logged in)
#   ./install.sh --daemon   # LaunchDaemon (runs at boot, no login required)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/usr/local/lib/macos-ddns6"

# Parse options
DAEMON_MODE=false
if [[ "${1:-}" == "--daemon" ]]; then
    DAEMON_MODE=true
fi

if [[ "$DAEMON_MODE" == true ]]; then
    PLIST6_SRC="$SCRIPT_DIR/launchd/com.github.macos-ddns6.daemon.plist"
    PLIST6_DST="/Library/LaunchDaemons/com.github.macos-ddns6.plist"
    PLIST4_SRC="$SCRIPT_DIR/launchd/com.github.macos-ddns6.ddns4.plist"
    PLIST4_DST="/Library/LaunchDaemons/com.github.macos-ddns6.ddns4.plist"
    CONFIG_DIR="/etc/macos-ddns6"
    echo "==> Installing macos-ddns6 (LaunchDaemon — runs at boot)"
else
    PLIST6_SRC="$SCRIPT_DIR/launchd/com.github.macos-ddns6.plist"
    PLIST6_DST="$HOME/Library/LaunchAgents/com.github.macos-ddns6.plist"
    PLIST4_SRC="$SCRIPT_DIR/launchd/com.github.macos-ddns6.ddns4.plist"
    PLIST4_DST="$HOME/Library/LaunchAgents/com.github.macos-ddns6.ddns4.plist"
    CONFIG_DIR="$HOME/.config/macos-ddns6"
    echo "==> Installing macos-ddns6 (LaunchAgent — runs when logged in)"
fi

# Copy files to /usr/local/lib/macos-ddns6
sudo mkdir -p "$INSTALL_DIR"
sudo cp -R "$SCRIPT_DIR/ddns6-update.sh" "$SCRIPT_DIR/ddns4-update.sh" \
    "$SCRIPT_DIR/lib" "$SCRIPT_DIR/providers" "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/ddns6-update.sh" "$INSTALL_DIR/ddns4-update.sh"

# Symlinks to /usr/local/bin
sudo ln -sf "$INSTALL_DIR/ddns6-update.sh" /usr/local/bin/ddns6-update.sh
echo "    /usr/local/bin/ddns6-update.sh -> $INSTALL_DIR/ddns6-update.sh"
sudo ln -sf "$INSTALL_DIR/ddns4-update.sh" /usr/local/bin/ddns4-update.sh
echo "    /usr/local/bin/ddns4-update.sh -> $INSTALL_DIR/ddns4-update.sh"

# Config files
sudo mkdir -p "$CONFIG_DIR"
for conf in ddns6 ddns4; do
    if [[ ! -f "$CONFIG_DIR/${conf}.conf" ]]; then
        sudo cp "$SCRIPT_DIR/${conf}.conf.example" "$CONFIG_DIR/${conf}.conf"
        if [[ "$DAEMON_MODE" == true ]]; then
            sudo chmod 600 "$CONFIG_DIR/${conf}.conf"
        fi
        echo "    Created $CONFIG_DIR/${conf}.conf — please edit before starting"
    else
        echo "    Config already exists: $CONFIG_DIR/${conf}.conf"
    fi
done

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

# Detect GCP project for CLOUDSDK_CORE_PROJECT (daemon mode only)
# Prevents gcloud from inheriting the wrong active configuration when multiple
# gcloud configs exist on the system.
CLOUDSDK_PROJECT=""
if [[ "$DAEMON_MODE" == true ]]; then
    for gcloud_bin in /opt/homebrew/bin/gcloud /usr/local/bin/gcloud; do
        if [[ -x "$gcloud_bin" ]]; then
            CLOUDSDK_PROJECT=$("$gcloud_bin" config get-value core/project 2>/dev/null || true)
            # gcloud prints "(unset)" (not empty) when no project is configured
            [[ "$CLOUDSDK_PROJECT" == "(unset)" ]] && CLOUDSDK_PROJECT=""
            break
        fi
    done
    if [[ -n "$CLOUDSDK_PROJECT" ]]; then
        echo "    CLOUDSDK_CORE_PROJECT: $CLOUDSDK_PROJECT (detected from active gcloud config)"
    else
        echo "    WARNING: Could not detect GCP project. Edit CLOUDSDK_CORE_PROJECT in $PLIST6_DST"
        CLOUDSDK_PROJECT="YOUR_GCP_PROJECT_ID"
    fi
fi

# Install ddns6 plist
if [[ "$DAEMON_MODE" == true ]]; then
    sudo launchctl unload "$PLIST6_DST" 2>/dev/null || true
else
    launchctl unload "$PLIST6_DST" 2>/dev/null || true
fi
if [[ "$DAEMON_MODE" == true ]]; then
    sed -e "s|CLOUDSDK_PYTHON_PLACEHOLDER|$CLOUDSDK_PYTHON|" \
        -e "s|DDNS6_CONFIG_PLACEHOLDER|$CONFIG_DIR/ddns6.conf|" \
        -e "s|CLOUDSDK_PROJECT_PLACEHOLDER|$CLOUDSDK_PROJECT|" \
        "$PLIST6_SRC" | sudo tee "$PLIST6_DST" > /dev/null
    sudo chown root:wheel "$PLIST6_DST"
    sudo chmod 644 "$PLIST6_DST"
else
    sed -e "s|CLOUDSDK_PYTHON_PLACEHOLDER|$CLOUDSDK_PYTHON|" \
        -e "s|DDNS6_CONFIG_PLACEHOLDER|$CONFIG_DIR/ddns6.conf|" \
        "$PLIST6_SRC" | sudo tee "$PLIST6_DST" > /dev/null
fi
echo "    Installed plist: $PLIST6_DST"

# Install ddns4 plist
if [[ "$DAEMON_MODE" == true ]]; then
    sudo launchctl unload "$PLIST4_DST" 2>/dev/null || true
else
    launchctl unload "$PLIST4_DST" 2>/dev/null || true
fi
sed -e "s|CLOUDSDK_PYTHON_PLACEHOLDER|$CLOUDSDK_PYTHON|" \
    "$PLIST4_SRC" | sudo tee "$PLIST4_DST" > /dev/null
if [[ "$DAEMON_MODE" == true ]]; then
    sudo chown root:wheel "$PLIST4_DST"
    sudo chmod 644 "$PLIST4_DST"
fi
echo "    Installed plist: $PLIST4_DST"

echo ""
echo "==> Next steps:"
echo "    1. Edit $CONFIG_DIR/ddns6.conf (AAAA record)"
echo "       Edit $CONFIG_DIR/ddns4.conf (A record) — skip if you don't need IPv4 DDNS"
if [[ "$DAEMON_MODE" == true ]]; then
    echo "    2. Place your service account key in a root-accessible path:"
    echo "         sudo cp sa-key.json /etc/macos-ddns6/sa-dns-updater.json"
    echo "         sudo chmod 600 /etc/macos-ddns6/sa-dns-updater.json"
    echo "       Then update GOOGLE_APPLICATION_CREDENTIALS in both conf files"
    echo "       (macOS TCC blocks root from reading files under /Users/<user>/)"
    echo "    3. sudo launchctl load $PLIST6_DST"
    echo "       sudo launchctl load $PLIST4_DST  # if using IPv4 DDNS"
    echo "    4. Check /var/log/ddns6-update.log and /tmp/ddns4-update.log"
else
    echo "    2. launchctl load $PLIST6_DST"
    echo "       launchctl load $PLIST4_DST  # if using IPv4 DDNS"
    echo "    3. Check /tmp/ddns6-update.log and /tmp/ddns4-update.log"
fi
