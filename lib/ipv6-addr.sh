# shellcheck shell=bash
# lib/ipv6-addr.sh — IPv6 address detection library (source only)
#
# Usage:
#   source "$SCRIPT_DIR/lib/ipv6-addr.sh"
#   addr=$(get_ipv6_addr)

# get_ipv6_addr — returns the autoconf secured IPv6 global address
# Prefers higher interface numbers (e.g. en7 wired > en0 wireless)
get_ipv6_addr() {
    ifconfig -a \
        | awk '/^[a-z]/ { iface=$1 } /inet6.*autoconf secured/ { if (index($0, "temporary") == 0) { sub(/:$/, "", iface); n=iface; gsub(/[^0-9]/, "", n); print n, $2 } }' \
        | sort -rn \
        | head -1 \
        | awk '{print $2}'
}
