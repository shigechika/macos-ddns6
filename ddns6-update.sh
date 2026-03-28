#!/bin/bash
# ddns6-update.sh — Dynamic DNS updater for macOS
#
# Detects the IPv6 SLAAC autoconf secured address and updates
# the AAAA record via the configured DNS provider.
#
# Usage:
#   ddns6-update.sh                          # use default config
#   ddns6-update.sh --config /path/to/conf   # custom config

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"

# --- Config loading ---

CONFIG_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config) CONFIG_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$CONFIG_FILE" ]]; then
    for candidate in \
        "$HOME/.config/macos-ddns6/ddns6.conf" \
        "/etc/macos-ddns6/ddns6.conf"; do
        if [[ -f "$candidate" ]]; then
            CONFIG_FILE="$candidate"
            break
        fi
    done
fi

if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: No config file found. Copy ddns6.conf.example to ~/.config/macos-ddns6/ddns6.conf" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

# --- Defaults ---

DNS_PROVIDER="${DNS_PROVIDER:-gcloud}"
DNS_TTL="${DNS_TTL:-300}"
LOG_TAG="ddns6"
CACHE_FILE="/tmp/ddns6-update.cache"

export GOOGLE_APPLICATION_CREDENTIALS="${GOOGLE_APPLICATION_CREDENTIALS:-}"

log() { logger -t "$LOG_TAG" "$*"; echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

# --- IPv6 address detection ---

source "$SCRIPT_DIR/lib/ipv6-addr.sh"

ADDR=$(get_ipv6_addr)

if [[ -z "$ADDR" ]]; then
    log "ERROR: no autoconf secured IPv6 address found"
    exit 1
fi

# --- Local cache check ---

CACHED=$(cat "$CACHE_FILE" 2>/dev/null || echo "")
if [[ "$CACHED" == "$ADDR" ]]; then
    exit 0
fi

log "Detected IPv6 address: ${ADDR} (previous: ${CACHED:-(none)})"

# --- Load DNS provider ---

PROVIDER_FILE="$SCRIPT_DIR/providers/${DNS_PROVIDER}.sh"
if [[ ! -f "$PROVIDER_FILE" ]]; then
    log "ERROR: unknown DNS provider: $DNS_PROVIDER"
    exit 1
fi

# shellcheck source=/dev/null
source "$PROVIDER_FILE"

# --- DNS update ---

CURRENT=$(dns_get_current)

if [[ "$CURRENT" == "$ADDR" ]]; then
    log "DNS record is up to date ($ADDR)"
    echo "$ADDR" > "$CACHE_FILE"
    exit 0
fi

log "DNS update: ${CURRENT:-(none)} -> $ADDR"

dns_update "$CURRENT" "$ADDR"

echo "$ADDR" > "$CACHE_FILE"
log "DNS update complete: $DNS_FQDN -> $ADDR"
