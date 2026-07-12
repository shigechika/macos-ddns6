# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

macOS 向け Dynamic DNS アップデーター。IPv6 SLAAC `autoconf secured`（RFC 7217）アドレスを検出して DNS AAAA レコードを、グローバル IPv4 アドレスを検出して A レコードを、それぞれ自動更新する。全スクリプトは Bash で記述。

## Architecture

エントリポイントは対等な 2 本ある。`ddns6-update.sh`（IPv6 / AAAA レコード）と `ddns4-update.sh`（IPv4 / A レコード）で、ほぼ同一の流れを実行する:

1. 設定読み込み（ddns6 は `~/.config/macos-ddns6/ddns6.conf` or `/etc/macos-ddns6/ddns6.conf`、ddns4 は同じ場所の `ddns4.conf`。例は `ddns6.conf.example` / `ddns4.conf.example`）
2. アドレス検出。ddns6 は `lib/ipv6-addr.sh` の `get_ipv6_addr()` が **ローカルの `ifconfig`** から検出。ddns4 は `lib/ipv4-addr.sh` の `get_ipv4_addr()` が **外部エンドポイント `https://checkip.amazonaws.com`** を curl で問い合わせる（その応答がそのまま A レコードに書かれるため、可用性・信頼の面で外部依存が 1 つ増える点に注意）
3. キャッシュ比較（ddns6 は `/tmp/ddns6-update.cache`、ddns4 は `/tmp/ddns4-update.cache`）。この固定 `/tmp` パスの内容を無条件に信頼し、一致すれば即終了する。daemon モードでは root がこの固定パスへ書き込む
4. `providers/<DNS_PROVIDER>.sh` をロードし、`dns_get_current()` / `dns_update()` を呼び出し

**プロバイダプラグイン**: `providers/` 配下に `dns_get_current()` と `dns_update()` の 2 関数を実装するシェルスクリプトを置く。現在は `gcloud.sh`（Google Cloud DNS）のみ。ddns6 / ddns4 は同じプロバイダ層を共有する。

**launchd テンプレート**: `launchd/` 配下の plist テンプレート（`.plist` = ddns6 LaunchAgent、`.daemon.plist` = ddns6 LaunchDaemon、`.ddns4.plist` = ddns4 用）を `install.sh` が sed でプレースホルダ置換してインストールする。プレースホルダは 3 種類 — `CLOUDSDK_PYTHON_PLACEHOLDER`・`DDNS6_CONFIG_PLACEHOLDER`・daemon モード専用の `CLOUDSDK_PROJECT_PLACEHOLDER`（`CLOUDSDK_CORE_PROJECT` 用）— で、sed ブロックは ddns6 の agent 分岐・daemon 分岐・ddns4 用の 3 つある。新しいプレースホルダを追加したら、それが必要な全 sed ブロックに通すこと。

## Commands

```bash
# 手動実行
./ddns6-update.sh
./ddns6-update.sh --config /path/to/ddns6.conf
./ddns4-update.sh                      # IPv4 / A レコード

# インストール（LaunchAgent / LaunchDaemon。ddns6 と ddns4 の両 plist を導入）
./install.sh
sudo ./install.sh --daemon

# ログ確認
tail -f /tmp/ddns6-update.log          # ddns6 LaunchAgent
tail -f /var/log/ddns6-update.log      # ddns6 LaunchDaemon
tail -f /tmp/ddns4-update.log          # ddns4（.ddns4.plist は Agent/Daemon とも /tmp に出力）
```

## Conventions

- Public リポジトリ: コミットメッセージ・コメント・ドキュメントは英語
- シェルスクリプトには `shellcheck` 準拠のアノテーション（`# shellcheck shell=bash` 等）を付ける
- ライブラリスクリプト（`lib/`, `providers/`）は `source` で読み込む前提で、直接実行不可
