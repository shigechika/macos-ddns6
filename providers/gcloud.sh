# shellcheck shell=bash
# providers/gcloud.sh — Google Cloud DNS provider
#
# Required config:
#   DNS_ZONE    — Cloud DNS managed zone name
#   DNS_FQDN   — Fully qualified domain name (with trailing dot)
#   DNS_TTL     — Record TTL in seconds
#
# Required environment:
#   GOOGLE_APPLICATION_CREDENTIALS — path to service account key JSON
#   GCLOUD — path to gcloud binary (default: gcloud)

GCLOUD="${GCLOUD:-gcloud}"

# Activate service account if key file is provided.
# gcloud CLI ignores GOOGLE_APPLICATION_CREDENTIALS; it requires explicit activation.
if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" && -f "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
    "$GCLOUD" auth activate-service-account \
        --key-file="$GOOGLE_APPLICATION_CREDENTIALS" --quiet
fi

# dns_get_current — returns the current AAAA record value
dns_get_current() {
    "$GCLOUD" dns record-sets list \
        --zone="$DNS_ZONE" --name="$DNS_FQDN" --type=AAAA \
        --format='value(rrdatas[0])' 2>/dev/null || echo ""
}

# dns_update — updates the AAAA record from $1 (old) to $2 (new)
dns_update() {
    local old="$1" new="$2"
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    "$GCLOUD" dns record-sets transaction start --zone="$DNS_ZONE" \
        --transaction-file="$tmpdir/tr.yaml"

    if [[ -n "$old" ]]; then
        "$GCLOUD" dns record-sets transaction remove "$old" \
            --zone="$DNS_ZONE" --name="$DNS_FQDN" --type=AAAA --ttl="$DNS_TTL" \
            --transaction-file="$tmpdir/tr.yaml"
    fi

    "$GCLOUD" dns record-sets transaction add "$new" \
        --zone="$DNS_ZONE" --name="$DNS_FQDN" --type=AAAA --ttl="$DNS_TTL" \
        --transaction-file="$tmpdir/tr.yaml"

    "$GCLOUD" dns record-sets transaction execute --zone="$DNS_ZONE" \
        --transaction-file="$tmpdir/tr.yaml"
}
