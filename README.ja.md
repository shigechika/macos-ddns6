# macos-ddns6

[English](README.md) | 日本語

macOS 向けダイナミック DNS 更新ツール — IPv6 SLAAC・グローバル IPv4 アドレスを自動検出して DNS レコードを更新します。

## 特徴

- **IPv6 SLAAC 検出** — 全インターフェースから `autoconf secured`（RFC 7217）アドレスを検出
- **IPv4 検出** — 外部サービスに問い合わせてグローバル WAN アドレスを取得（NAT/ルーター DNAT 環境に対応）
- **イベント駆動更新** — macOS `launchd` の WatchPaths でネットワーク変化を検知
- **ポーリングフォールバック** — イベント漏れに備えて 5 分ごとにチェック
- **ローカルキャッシュ** — アドレス変化がなければ DNS API 呼び出しをスキップ
- **プロバイダプラグイン** — 現在 Google Cloud DNS に対応、Cloudflare・Route53 等に拡張可能

## 仕組み

### IPv6（AAAA レコード）— `ddns6-update.sh`

macOS は SLAAC で 3 種類の IPv6 アドレスを割り当てます：

| タイプ | フラグ | 安定性 | ddns6 で使用 |
|--------|--------|--------|:---:|
| リンクローカル | `secured` | 安定 | No（ルーティング不可） |
| グローバル安定 | `autoconf secured` | 同じ環境なら安定 | **Yes** |
| グローバル一時 | `autoconf temporary` | 定期的にローテーション | No |

`autoconf secured` アドレス（RFC 7217）はネットワークプレフィックスとホスト固有のシークレットから自動的に生成されます。同じ環境においては安定しているため、DNS 登録に向いています。

### IPv4（A レコード）— `ddns4-update.sh`

ホームルーターや NAT 環境下の macOS では、`ifconfig` でグローバル WAN IPv4 アドレスを取得できません。`ddns4-update.sh` は `https://checkip.amazonaws.com` に問い合わせてグローバルアドレスを取得し、A レコードを更新します。ルーターでポートフォワーディング（DNAT）を設定している場合に、ルーターの動的 WAN IP を A レコードで追跡するのに便利です。

## クイックスタート

```bash
git clone https://github.com/shigechika/macos-ddns6.git
cd macos-ddns6
./install.sh
```

設定ファイルを編集：

```bash
vi ~/.config/macos-ddns6/ddns6.conf   # AAAA レコード（IPv6）
vi ~/.config/macos-ddns6/ddns4.conf   # A レコード（IPv4）— 不要なら省略可
```

サービスを開始：

```bash
launchctl load ~/Library/LaunchAgents/com.github.macos-ddns6.plist        # IPv6
launchctl load ~/Library/LaunchAgents/com.github.macos-ddns6.ddns4.plist  # IPv4（任意）
```

### LaunchAgent と LaunchDaemon

| モード | 動作タイミング | 設定ファイルの場所 | インストールコマンド |
|--------|---------------|-------------------|---------------------|
| **LaunchAgent**（デフォルト） | ユーザーがログイン中 | `~/.config/macos-ddns6/` | `./install.sh` |
| **LaunchDaemon** | システム起動時（ログイン不要） | `/etc/macos-ddns6/` | `./install.sh --daemon` |

ヘッドレスサーバーやログインなしで再起動する Mac mini には `--daemon` を使用：

```bash
sudo ./install.sh --daemon
sudo vi /etc/macos-ddns6/ddns6.conf
sudo vi /etc/macos-ddns6/ddns4.conf  # IPv4 DDNS を使う場合
sudo launchctl load /Library/LaunchDaemons/com.github.macos-ddns6.plist
sudo launchctl load /Library/LaunchDaemons/com.github.macos-ddns6.ddns4.plist  # IPv4 DDNS を使う場合
```

> **LaunchDaemon 使用時の必須事項**（どちらか欠けると無言で失敗します）
>
> 1. **サービスアカウントキーを root が読めるパスに置く**
>    macOS TCC により、`root` は `/Users/<user>/` 配下のファイルを読めない場合があります。
>    キーを `/etc/macos-ddns6/` にコピーしてください：
>    ```bash
>    sudo cp sa-dns-updater.json /etc/macos-ddns6/sa-dns-updater.json
>    sudo chmod 600 /etc/macos-ddns6/sa-dns-updater.json
>    ```
>    そして両方の conf ファイルに `GOOGLE_APPLICATION_CREDENTIALS="/etc/macos-ddns6/sa-dns-updater.json"` を設定します。
>
> 2. **`CLOUDSDK_CORE_PROJECT` で GCP プロジェクトを固定する**
>    `gcloud` は呼び出しシェルでアクティブな configuration のプロジェクトを使います。デーモン環境では意図しないプロジェクトになることがあります。
>    `install.sh --daemon` は現在のプロジェクトを自動検出して plist に注入します。正しいか確認してください：
>    ```bash
>    sudo cat /Library/LaunchDaemons/com.github.macos-ddns6.plist | grep -A1 CLOUDSDK_CORE_PROJECT
>    ```

## 設定

### IPv6 — `ddns6.conf`

`ddns6.conf.example` を `~/.config/macos-ddns6/ddns6.conf` にコピー：

```bash
# DNS プロバイダ: gcloud（デフォルト）
DNS_PROVIDER="gcloud"

# FQDN（Cloud DNS の場合は末尾にドットが必要）
DNS_FQDN="myhost.example.com."

# レコード TTL（秒）
DNS_TTL=300

# Google Cloud DNS マネージドゾーン名
DNS_ZONE="example-com"

# サービスアカウントキーのパス
GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/sa-dns-updater.json"
```

### IPv4 — `ddns4.conf`

`ddns4.conf.example` を `~/.config/macos-ddns6/ddns4.conf` にコピー：

```bash
DNS_PROVIDER="gcloud"
DNS_TYPE="A"
DNS_FQDN="myhost.example.com."
DNS_TTL=300
DNS_ZONE="example-com"
GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/sa-dns-updater.json"
```

`ddns6.conf` との違いは `DNS_TYPE="A"` のみです。両方の設定ファイルで同じサービスアカウントキーを共有できます。

### Google Cloud DNS のセットアップ

1. サービスアカウントを作成：

```bash
gcloud iam service-accounts create dns-updater \
  --project=YOUR_PROJECT \
  --display-name="DNS Updater"
```

2. DNS admin ロールを付与：

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT \
  --member="serviceAccount:dns-updater@YOUR_PROJECT.iam.gserviceaccount.com" \
  --role="roles/dns.admin"
```

3. キーファイルを生成：

```bash
gcloud iam service-accounts keys create ~/.config/gcloud/sa-dns-updater.json \
  --iam-account=dns-updater@YOUR_PROJECT.iam.gserviceaccount.com
chmod 600 ~/.config/gcloud/sa-dns-updater.json
```

### 認証方式

gcloud プロバイダは 2 つの認証方式に対応しています：

**方式 A: キーファイル（デフォルト）** — `GOOGLE_APPLICATION_CREDENTIALS` を設定すると、実行のたびに `gcloud auth activate-service-account` を自動実行します。

```bash
# ddns6.conf / ddns4.conf に設定
GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/sa-dns-updater.json"
```

**方式 B: gcloud configuration** — サービスアカウント専用の gcloud configuration を作成します。毎回の activate が不要になり、他のプロジェクトの認証情報と分離できます。

```bash
# 専用の configuration を作成
gcloud config configurations create example-dns
gcloud auth activate-service-account \
  --key-file=~/.config/gcloud/sa-dns-updater.json
gcloud config set project YOUR_PROJECT

# 環境変数で configuration を切り替え
export CLOUDSDK_ACTIVE_CONFIG_NAME=example-dns
```

方式 B を使う場合、設定ファイルの `GOOGLE_APPLICATION_CREDENTIALS` は空またはコメントアウトしてください。gcloud configuration が認証を担います。

## 手動実行

```bash
# IPv6
ddns6-update.sh
ddns6-update.sh --config /path/to/ddns6.conf

# IPv4
ddns4-update.sh
ddns4-update.sh --config /path/to/ddns4.conf
```

ログを確認：

```bash
tail -f /tmp/ddns6-update.log
tail -f /tmp/ddns4-update.log
```

## プロジェクト構成

```
macos-ddns6/
├── ddns6-update.sh         # IPv6（AAAA）更新スクリプト
├── ddns4-update.sh         # IPv4（A）更新スクリプト
├── ddns6.conf.example      # 設定テンプレート（AAAA）
├── ddns4.conf.example      # 設定テンプレート（A）
├── install.sh              # インストーラ（--daemon で LaunchDaemon）
├── lib/
│   ├── ipv6-addr.sh        # IPv6 アドレス検出ライブラリ
│   └── ipv4-addr.sh        # IPv4 アドレス検出ライブラリ
├── providers/
│   └── gcloud.sh           # Google Cloud DNS プロバイダ（A・AAAA 対応）
├── launchd/
│   ├── com.github.macos-ddns6.plist         # LaunchAgent テンプレート（IPv6）
│   ├── com.github.macos-ddns6.ddns4.plist   # LaunchAgent テンプレート（IPv4）
│   └── com.github.macos-ddns6.daemon.plist  # LaunchDaemon テンプレート（IPv6）
└── README.md
```

## DNS プロバイダの追加

`providers/` に新しいファイル（例: `providers/cloudflare.sh`）を作成し、2 つの関数を実装：

```bash
# dns_get_current — 現在のレコード値を返す（DNS_TYPE に応じて A または AAAA）
dns_get_current() { ... }

# dns_update — レコードを $1（旧）から $2（新）に更新する
dns_update() { ... }
```

レコードタイプは `$DNS_TYPE` で参照できます（デフォルト: `AAAA`）。設定ファイルで `DNS_PROVIDER="cloudflare"` を指定すれば切り替わります。

## 要件

- macOS（IPv6 検出に `ifconfig`、スケジューリングに `launchd` を使用）
- Bash
- `curl`（`checkip.amazonaws.com` 経由の IPv4 検出に使用）
- `gcloud` CLI（Google Cloud DNS プロバイダの場合）

## リリース

リリースは [release-please](https://github.com/googleapis/release-please) で
自動化されている。[Conventional Commits](https://www.conventionalcommits.org/)
（`feat:`、`fix:` 等）を `main` にマージすると、次バージョンと changelog を
持つリリース PR が維持される。その PR をマージすると `vX.Y.Z` がタグ付けされ
GitHub Release が公開される。

> [!IMPORTANT]
> release-please の workflow にはリポジトリシークレット `RELEASE_PLEASE_TOKEN`
> （`contents: write` + `pull-requests: write` を持つ PAT）を設定すること。
> 既定の `GITHUB_TOKEN` は下流の workflow を起動する Release を作成できない
> （GitHub が `GITHUB_TOKEN` 起因の workflow 起動をブロックするため）ので、
> PAT がないと何も公開されない。シークレット未設定時は `GITHUB_TOKEN` に
> フォールバックするので、fork 上でも PR CI は動作する。

## ライセンス

MIT
