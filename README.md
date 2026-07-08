# macos-ddns6

English | [日本語](README.ja.md)

Dynamic DNS updater for macOS — automatically detects IPv6 SLAAC and/or global IPv4 addresses and updates DNS records.

## Features

- **IPv6 SLAAC detection** — finds `autoconf secured` (RFC 7217) addresses across all interfaces
- **IPv4 detection** — queries an external service to discover the global WAN address (useful behind NAT/router DNAT)
- **Event-driven updates** — uses macOS `launchd` WatchPaths to trigger on network changes
- **Polling fallback** — checks every 5 minutes in case events are missed
- **Local cache** — skips DNS API calls when the address hasn't changed
- **Provider plugins** — currently supports Google Cloud DNS; extensible to Cloudflare, Route53, etc.

## How it works

### IPv6 (AAAA record) — `ddns6-update.sh`

macOS assigns three types of IPv6 addresses via SLAAC:

| Type | Flag | Stability | Used by ddns6 |
|------|------|-----------|:---:|
| Link-local | `secured` | Stable | No (not routable) |
| Global stable | `autoconf secured` | Stable while network environment unchanged | **Yes** |
| Global temporary | `autoconf temporary` | Rotates periodically | No |

The `autoconf secured` address (RFC 7217) is deterministically generated from the network prefix and a per-host secret. It remains stable as long as you stay on the same network, making it ideal for DNS registration.

### IPv4 (A record) — `ddns4-update.sh`

macOS behind a home router or NAT device does not expose the global IPv4 address via `ifconfig`. `ddns4-update.sh` queries `https://checkip.amazonaws.com` to obtain the global address, then updates the A record. This is useful when port-forwarding (DNAT) is configured on the router and you need the A record to track the router's dynamic WAN IP.

## Quick Start

```bash
git clone https://github.com/shigechika/macos-ddns6.git
cd macos-ddns6
./install.sh
```

Edit the config file(s):

```bash
vi ~/.config/macos-ddns6/ddns6.conf   # AAAA record (IPv6)
vi ~/.config/macos-ddns6/ddns4.conf   # A record (IPv4) — skip if not needed
```

Start the service(s):

```bash
launchctl load ~/Library/LaunchAgents/com.github.macos-ddns6.plist        # IPv6
launchctl load ~/Library/LaunchAgents/com.github.macos-ddns6.ddns4.plist  # IPv4 (optional)
```

### LaunchAgent vs LaunchDaemon

| Mode | Runs when | Config location | Install command |
|------|-----------|-----------------|-----------------|
| **LaunchAgent** (default) | User is logged in | `~/.config/macos-ddns6/` | `./install.sh` |
| **LaunchDaemon** | System boot (no login required) | `/etc/macos-ddns6/` | `./install.sh --daemon` |

Use `--daemon` for headless servers or Mac minis that may reboot without user login:

```bash
sudo ./install.sh --daemon
sudo vi /etc/macos-ddns6/ddns6.conf
sudo vi /etc/macos-ddns6/ddns4.conf  # if using IPv4 DDNS
sudo launchctl load /Library/LaunchDaemons/com.github.macos-ddns6.plist
sudo launchctl load /Library/LaunchDaemons/com.github.macos-ddns6.ddns4.plist  # if using IPv4 DDNS
```

> **LaunchDaemon requirements** (important — skipping either causes silent failures):
>
> 1. **Service account key must be in a root-readable path.**
>    macOS TCC may block `root` from reading files under `/Users/<user>/`.
>    Copy the key to `/etc/macos-ddns6/` instead:
>    ```bash
>    sudo cp sa-dns-updater.json /etc/macos-ddns6/sa-dns-updater.json
>    sudo chmod 600 /etc/macos-ddns6/sa-dns-updater.json
>    ```
>    Then set `GOOGLE_APPLICATION_CREDENTIALS="/etc/macos-ddns6/sa-dns-updater.json"` in both conf files.
>
> 2. **Pin the GCP project with `CLOUDSDK_CORE_PROJECT`.**
>    `gcloud` uses whichever configuration is active in the calling shell. In a daemon context this may be the wrong project.
>    `install.sh --daemon` auto-detects the current project and injects it into the plist. Verify it is correct:
>    ```bash
>    sudo cat /Library/LaunchDaemons/com.github.macos-ddns6.plist | grep -A1 CLOUDSDK_CORE_PROJECT
>    ```

## Configuration

### IPv6 — `ddns6.conf`

Copy `ddns6.conf.example` to `~/.config/macos-ddns6/ddns6.conf`:

```bash
# DNS provider: gcloud (default)
DNS_PROVIDER="gcloud"

# Your FQDN (trailing dot required for Cloud DNS)
DNS_FQDN="myhost.example.com."

# Record TTL in seconds
DNS_TTL=300

# Google Cloud DNS zone name
DNS_ZONE="example-com"

# Service account key
GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/sa-dns-updater.json"
```

### IPv4 — `ddns4.conf`

Copy `ddns4.conf.example` to `~/.config/macos-ddns6/ddns4.conf`:

```bash
DNS_PROVIDER="gcloud"
DNS_TYPE="A"
DNS_FQDN="myhost.example.com."
DNS_TTL=300
DNS_ZONE="example-com"
GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/sa-dns-updater.json"
```

The only difference from `ddns6.conf` is `DNS_TYPE="A"`. Both configs can share the same service account key.

### Google Cloud DNS Setup

1. Create a service account:

```bash
gcloud iam service-accounts create dns-updater \
  --project=YOUR_PROJECT \
  --display-name="DNS Updater"
```

2. Grant DNS admin role:

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT \
  --member="serviceAccount:dns-updater@YOUR_PROJECT.iam.gserviceaccount.com" \
  --role="roles/dns.admin"
```

3. Create a key file:

```bash
gcloud iam service-accounts keys create ~/.config/gcloud/sa-dns-updater.json \
  --iam-account=dns-updater@YOUR_PROJECT.iam.gserviceaccount.com
chmod 600 ~/.config/gcloud/sa-dns-updater.json
```

### Authentication Methods

The gcloud provider supports two authentication methods:

**Method A: Key file (default)** — Set `GOOGLE_APPLICATION_CREDENTIALS` in your config. The provider automatically runs `gcloud auth activate-service-account` on each invocation.

```bash
# In ddns6.conf / ddns4.conf
GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/sa-dns-updater.json"
```

**Method B: gcloud configuration** — Create a dedicated gcloud configuration with the service account pre-activated. This avoids re-activation on every run and isolates credentials from your other gcloud projects.

```bash
# Create a dedicated configuration
gcloud config configurations create example-dns
gcloud auth activate-service-account \
  --key-file=~/.config/gcloud/sa-dns-updater.json
gcloud config set project YOUR_PROJECT

# Set the configuration via environment variable
export CLOUDSDK_ACTIVE_CONFIG_NAME=example-dns
```

When using Method B, leave `GOOGLE_APPLICATION_CREDENTIALS` unset (or empty) in your config — the gcloud configuration handles authentication.

## Manual Run

```bash
# IPv6
ddns6-update.sh
ddns6-update.sh --config /path/to/ddns6.conf

# IPv4
ddns4-update.sh
ddns4-update.sh --config /path/to/ddns4.conf
```

Check the log:

```bash
tail -f /tmp/ddns6-update.log
tail -f /tmp/ddns4-update.log
```

## Project Structure

```
macos-ddns6/
├── ddns6-update.sh         # IPv6 (AAAA) update script
├── ddns4-update.sh         # IPv4 (A) update script
├── ddns6.conf.example      # Configuration template (AAAA)
├── ddns4.conf.example      # Configuration template (A)
├── install.sh              # Installer (--daemon for LaunchDaemon)
├── lib/
│   ├── ipv6-addr.sh        # IPv6 address detection library
│   └── ipv4-addr.sh        # IPv4 address detection library
├── providers/
│   └── gcloud.sh           # Google Cloud DNS provider (A and AAAA)
├── launchd/
│   ├── com.github.macos-ddns6.plist         # LaunchAgent template (IPv6)
│   ├── com.github.macos-ddns6.ddns4.plist   # LaunchAgent template (IPv4)
│   └── com.github.macos-ddns6.daemon.plist  # LaunchDaemon template (IPv6)
└── README.md
```

## Adding a DNS Provider

Create a new file in `providers/` (e.g., `providers/cloudflare.sh`) implementing two functions:

```bash
# dns_get_current — returns the current record value (A or AAAA, per DNS_TYPE)
dns_get_current() { ... }

# dns_update — updates the record from $1 (old) to $2 (new)
dns_update() { ... }
```

The record type is available as `$DNS_TYPE` (default: `AAAA`). Then set `DNS_PROVIDER="cloudflare"` in your config.

## Requirements

- macOS (uses `ifconfig` for IPv6 detection and `launchd`)
- Bash
- `curl` (for IPv4 detection via `checkip.amazonaws.com`)
- `gcloud` CLI (for Google Cloud DNS provider)

## Releasing

Releases are automated with [release-please](https://github.com/googleapis/release-please).
Merging [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, …)
to `main` keeps a release PR open with the next version and changelog. Merging
that PR tags `vX.Y.Z` and publishes a GitHub Release.

> [!IMPORTANT]
> The release-please workflow should be given a repository secret
> `RELEASE_PLEASE_TOKEN` (a PAT with `contents: write` + `pull-requests: write`).
> A personal repository's default settings can block GitHub Actions'
> built-in `GITHUB_TOKEN` from creating pull requests at all, which would
> silently stop release-please from ever opening its release PR — the PAT
> works around that. The workflow falls back to `GITHUB_TOKEN` when the
> secret is unset, so PR CI still passes on forks (release automation just
> won't run there).

## License

MIT
