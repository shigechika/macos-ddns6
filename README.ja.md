# macos-ddns6

[English](README.md) | 日本語

macOS 向けダイナミック DNS 更新ツール — IPv6 SLAAC アドレスを自動検出して DNS レコードを更新します。

## 特徴

- **IPv6 SLAAC 検出** — 全インターフェースから `autoconf secured`（RFC 7217）アドレスを検出
- **イベント駆動更新** — macOS `launchd` の WatchPaths でネットワーク変化を検知
- **ポーリングフォールバック** — イベント漏れに備えて 5 分ごとにチェック
- **ローカルキャッシュ** — アドレス変化がなければ DNS API 呼び出しをスキップ
- **プロバイダプラグイン** — 現在 Google Cloud DNS に対応、Cloudflare・Route53 等に拡張可能

## 仕組み

macOS は SLAAC で 3 種類の IPv6 アドレスを割り当てます：

| タイプ | フラグ | 安定性 | macos-ddns6 で使用 |
|--------|--------|--------|:---:|
| リンクローカル | `secured` | 安定 | No（ルーティング不可） |
| グローバル安定 | `autoconf secured` | 同じ環境なら安定 | **Yes** |
| グローバル一時 | `autoconf temporary` | 定期的にローテーション | No |

`autoconf secured` アドレス（RFC 7217）はネットワークプレフィックスとホスト固有のシークレットから自動的に生成されます。同じ環境においては安定しているため、DNS 登録に向いています。

## クイックスタート

```bash
git clone https://github.com/shigechika/macos-ddns6.git
cd macos-ddns6
./install.sh
```

設定ファイルを編集：

```bash
vi ~/.config/macos-ddns6/ddns6.conf
```

サービスを開始：

```bash
launchctl load ~/Library/LaunchAgents/com.github.macos-ddns6.plist
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
sudo launchctl load /Library/LaunchDaemons/com.github.macos-ddns6.plist
```

## 設定

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

gcloud プロバイダは `GOOGLE_APPLICATION_CREDENTIALS` で指定されたキーファイルを使って `gcloud auth activate-service-account` を自動実行します。手動での activate は不要です。

## 手動実行

```bash
ddns6-update.sh
# カスタム設定ファイルを指定する場合：
ddns6-update.sh --config /path/to/ddns6.conf
```

ログを確認：

```bash
tail -f /tmp/ddns6-update.log
```

## プロジェクト構成

```
macos-ddns6/
├── ddns6-update.sh         # メイン更新スクリプト
├── ddns6.conf.example      # 設定テンプレート
├── install.sh              # インストーラ（--daemon で LaunchDaemon）
├── lib/
│   └── ipv6-addr.sh        # IPv6 アドレス検出ライブラリ
├── providers/
│   └── gcloud.sh           # Google Cloud DNS プロバイダ
├── launchd/
│   ├── com.github.macos-ddns6.plist         # LaunchAgent テンプレート
│   └── com.github.macos-ddns6.daemon.plist  # LaunchDaemon テンプレート
└── README.md
```

## DNS プロバイダの追加

`providers/` に新しいファイル（例: `providers/cloudflare.sh`）を作成し、2 つの関数を実装：

```bash
# dns_get_current — 現在の AAAA レコードの値を返す
dns_get_current() { ... }

# dns_update — AAAA レコードを $1（旧）から $2（新）に更新する
dns_update() { ... }
```

設定ファイルで `DNS_PROVIDER="cloudflare"` を指定すれば切り替わります。

## 要件

- macOS（`ifconfig` と `launchd` を使用）
- Bash
- `gcloud` CLI（Google Cloud DNS プロバイダの場合）

## ライセンス

MIT
