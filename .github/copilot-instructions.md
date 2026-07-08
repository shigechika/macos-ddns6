# Repository overview

`macos-ddns6` is a Dynamic DNS updater for macOS. Two near-identical
entry-point scripts, `ddns6-update.sh` (IPv6 AAAA, via SLAAC "autoconf
secured" address detection) and `ddns4-update.sh` (IPv4 A record), each
loads a config file, detects the current address, compares against a local
cache to skip a no-op run, then delegates the actual record read/write to a
pluggable DNS provider script (`providers/<name>.sh`, currently only
`gcloud.sh` for Google Cloud DNS). `install.sh` sets up a launchd
LaunchAgent (per-login) or LaunchDaemon (at-boot) to run these on a
schedule. See `CLAUDE.md` for the architecture map (in Japanese — this
repo's existing convention; keep it consistent with itself rather than
translating on an unrelated PR).

# Build & validate

```bash
shellcheck *.sh lib/*.sh providers/*.sh
```

There is currently **no CI workflow enforcing this** — `.github/workflows/`
in this repo only has `release-please.yml`. Don't assume a lint job exists
in this repo's CI; if you want it enforced, that's a separate PR adding a
`lint.yml`, not an assumption to review against.

# What to focus review on in this repo

## 1. The provider plugin contract is implicit, not type-checked

`providers/<name>.sh` must define two shell functions, `dns_get_current()`
and `dns_update(old, new)`, matching what the two entry-point scripts call
after `source`-ing the provider file. There is no schema or test enforcing
this contract — a new or edited provider script that omits either function,
or changes its argument order/count, fails silently at runtime (a `source`
of a script missing a function just means the later call errors out with a
generic "command not found", not a clear contract-violation message). Flag
a new provider that doesn't implement both functions, or that reads
`DNS_TYPE`/`DNS_ZONE`/`DNS_FQDN`/`DNS_TTL` under different names than the
existing `gcloud.sh` does (that's the de facto shared config-variable
contract other providers would need to follow too).

## 2. Cache-file logic gates every DNS write — an off-by-one here means stale or spammed records

Both entry scripts compare the freshly detected address against
`$CACHE_FILE` and exit early on a match, and only write the cache file
*after* a successful `dns_get_current`/`dns_update` round-trip. A change
that writes the cache before confirming the DNS update actually succeeded
would make a subsequent real address change silently never propagate
(the script would believe it's already up to date). Conversely, removing
or weakening the cache check would turn every cron/launchd tick into a live
`dns_update()` call — most DNS provider APIs (`gcloud dns record-sets
transaction ...` here) are not free of rate limits or side effects on every
call. Flag any reordering of "detect → compare cache → provider round-trip
→ write cache" in either script.

## 3. `GOOGLE_APPLICATION_CREDENTIALS` and other secrets must never reach a log line

`ddns6-update.sh`/`ddns4-update.sh` log via `logger` (syslog) and stdout
(`log()`); `providers/gcloud.sh` calls `gcloud auth activate-service-account
--key-file=...`. Flag any diff that logs the contents of the credentials
file, a full `gcloud` command line that could embed a secret, or any config
variable that isn't already logged today (`DNS_FQDN`/addresses are fine —
they're not secret; a service-account key path is borderline info, its
*contents* are not).

## 4. launchd plist placeholders must stay in sync with `install.sh`'s `sed` calls

The `launchd/*.plist` templates use placeholder tokens
(`CLOUDSDK_PYTHON_PLACEHOLDER`, `DDNS6_CONFIG_PLACEHOLDER`,
`CLOUDSDK_PROJECT_PLACEHOLDER`) that `install.sh` replaces via `sed` before
installing. A new placeholder added to a plist template needs a matching
`sed -e "s|...|...|"` line added to **every** `install.sh` code path that
installs that plist (LaunchAgent vs LaunchDaemon are separate branches with
separate `sed` invocations — see the daemon-mode-only
`CLOUDSDK_PROJECT_PLACEHOLDER` substitution as the precedent for "not every
placeholder applies to every mode"). A plist left with an un-substituted
`_PLACEHOLDER` token fails silently at launchd load time, not at install
time — flag a new placeholder that isn't threaded through both `sed`
blocks it needs.

## 5. Shell script conventions

- `set -euo pipefail` in every executable script.
- Library scripts (`lib/`, `providers/`) start with `# shellcheck shell=bash`
  and are meant to be `source`d, never executed directly — they don't have
  (and shouldn't need) their own shebang/`set -e` line.
- `shellcheck`-clean is the bar (see Build & validate) even though it's not
  yet CI-enforced.

# Out of scope for review comments

- There is no test suite in this repo — don't ask for one unless the PR is
  adding meaningfully complex new logic (e.g. a new provider) that would
  clearly benefit from one.
- `CLAUDE.md` is written in Japanese while this file and `README.md` are in
  English — that's this repo's existing, intentional split (developer notes
  vs. public-facing docs), not an inconsistency to fix.
- `release-please.yml`'s use of `secrets.RELEASE_PLEASE_TOKEN` instead of
  `GITHUB_TOKEN` is intentional (a `GITHUB_TOKEN`-authored release doesn't
  trigger downstream workflow runs, and personal-repo default settings can
  block Actions from creating PRs at all). Falls back to `GITHUB_TOKEN` when
  the secret is unset so PR CI still passes on forks — don't suggest
  reverting it.
