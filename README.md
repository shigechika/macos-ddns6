# macos-ddns6

Dynamic DNS updater for macOS — automatically detects your IPv6 SLAAC address and updates DNS records.

## Features

- **IPv6 SLAAC detection** — finds `autoconf secured` (RFC 7217) addresses across all interfaces
- **Event-driven updates** — uses macOS `launchd` WatchPaths to trigger on network changes
- **Polling fallback** — checks every 5 minutes in case events are missed
- **Local cache** — skips DNS API calls when the address hasn't changed
- **Provider plugins** — currently supports Google Cloud DNS; extensible to Cloudflare, Route53, etc.

## How it works

macOS assigns three types of IPv6 addresses via SLAAC:

| Type | Flag | Stability | Used by macos-ddns6 |
|------|------|-----------|:---:|
| Link-local | `secured` | Stable | No (not routable) |
| Global stable | `autoconf secured` | Stable across reboots | **Yes** |
| Global temporary | `autoconf temporary` | Rotates periodically | No |

The `autoconf secured` address (RFC 7217) is deterministically generated from the network prefix and a per-host secret. It remains stable as long as you stay on the same network, making it ideal for DNS registration.

## Quick Start

```bash
git clone https://github.com/shigechika/macos-ddns6.git
cd macos-ddns6
./install.sh
```

Edit the config file:

```bash
vi ~/.config/macos-ddns6/ddns6.conf
```

Start the service:

```bash
launchctl load ~/Library/LaunchAgents/com.github.macos-ddns6.plist
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
sudo launchctl load /Library/LaunchDaemons/com.github.macos-ddns6.plist
```

## Configuration

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

## Manual Run

```bash
ddns6-update.sh
# or with a custom config:
ddns6-update.sh --config /path/to/ddns6.conf
```

Check the log:

```bash
tail -f /tmp/ddns6-update.log
```

## Project Structure

```
macos-ddns6/
├── ddns6-update.sh         # Main update script
├── ddns6.conf.example      # Configuration template
├── install.sh              # Installer (--daemon for LaunchDaemon)
├── lib/
│   └── ipv6-addr.sh        # IPv6 address detection library
├── providers/
│   └── gcloud.sh           # Google Cloud DNS provider
├── launchd/
│   ├── com.github.macos-ddns6.plist         # LaunchAgent template
│   └── com.github.macos-ddns6.daemon.plist  # LaunchDaemon template
└── README.md
```

## Adding a DNS Provider

Create a new file in `providers/` (e.g., `providers/cloudflare.sh`) implementing two functions:

```bash
# dns_get_current — returns the current AAAA record value
dns_get_current() { ... }

# dns_update — updates the AAAA record from $1 (old) to $2 (new)
dns_update() { ... }
```

Then set `DNS_PROVIDER="cloudflare"` in your config.

## Requirements

- macOS (uses `ifconfig` and `launchd`)
- Bash
- `gcloud` CLI (for Google Cloud DNS provider)

## License

MIT
