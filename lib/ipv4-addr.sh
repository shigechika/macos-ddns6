# shellcheck shell=bash
# lib/ipv4-addr.sh — IPv4 address detection library (source only)
#
# Usage:
#   source "$SCRIPT_DIR/lib/ipv4-addr.sh"
#   addr=$(get_ipv4_addr)

# get_ipv4_addr — returns the public IPv4 address by querying an external service
get_ipv4_addr() {
    local addr
    addr=$(curl -4 -s --connect-timeout 10 https://checkip.amazonaws.com 2>/dev/null | tr -d '[:space:]')
    if [[ "$addr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$addr"
        return 0
    fi
    return 1
}
