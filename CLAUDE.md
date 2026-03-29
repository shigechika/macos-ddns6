# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

macOS 向け Dynamic DNS アップデーター。IPv6 SLAAC `autoconf secured`（RFC 7217）アドレスを検出し、DNS AAAA レコードを自動更新する。全スクリプトは Bash で記述。

## Architecture

メインスクリプト `ddns6-update.sh` が以下を順に実行する:

1. 設定読み込み（`~/.config/macos-ddns6/ddns6.conf` or `/etc/macos-ddns6/ddns6.conf`）
2. `lib/ipv6-addr.sh` の `get_ipv6_addr()` で IPv6 アドレスを検出
3. `/tmp/ddns6-update.cache` とのキャッシュ比較（変更なければ即終了）
4. `providers/<DNS_PROVIDER>.sh` をロードし、`dns_get_current()` / `dns_update()` を呼び出し

**プロバイダプラグイン**: `providers/` 配下に `dns_get_current()` と `dns_update()` の 2 関数を実装するシェルスクリプトを置く。現在は `gcloud.sh`（Google Cloud DNS）のみ。

**launchd テンプレート**: `launchd/` 配下の plist テンプレートを `install.sh` が `CLOUDSDK_PYTHON_PLACEHOLDER` / `DDNS6_CONFIG_PLACEHOLDER` を sed で置換してインストールする。

## Commands

```bash
# 手動実行
./ddns6-update.sh
./ddns6-update.sh --config /path/to/ddns6.conf

# インストール（LaunchAgent / LaunchDaemon）
./install.sh
sudo ./install.sh --daemon

# ログ確認
tail -f /tmp/ddns6-update.log          # LaunchAgent
tail -f /var/log/ddns6-update.log      # LaunchDaemon
```

## Conventions

- Public リポジトリ: コミットメッセージ・コメント・ドキュメントは英語
- シェルスクリプトには `shellcheck` 準拠のアノテーション（`# shellcheck shell=bash` 等）を付ける
- ライブラリスクリプト（`lib/`, `providers/`）は `source` で読み込む前提で、直接実行不可
