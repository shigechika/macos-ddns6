# shellcheck shell=bash
# lib/ipv4-addr.sh — IPv4 address detection library (source only)
#
# Usage:
#   source "$SCRIPT_DIR/lib/ipv4-addr.sh"
#   addr=$(get_ipv4_addr)

# get_ipv4_addr — returns the global IPv4 address by querying an external service
get_ipv4_addr() {
    local addr
    addr=$(curl -4 -s --connect-timeout 10 https://checkip.amazonaws.com 2>/dev/null | tr -d '[:space:]')
    if [[ "$addr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$addr"
    fi
    # always returns 0 (empty output on failure), mirroring get_ipv6_addr
}
