# 技術スタック

## 技術スタック

### モノレポ構成

- `apps/frontend`: Next.js（フロントエンド）
- `apps/backend`: NestJS（バックエンド）
- `libs/types`: 共通型定義（TypeScript）

### 環境管理

- env環境を使用し、プロジェクト内で完結した言語環境を構築
- パッケージマネージャー: pnpm推奨（モノレポ構成のため）

#### ローカル環境でのpnpm使用方法

このプロジェクトは`nodeenv`を使用しており、Node.js、pnpm、その他のツールは`.nodeenv`ディレクトリ内にローカルインストールされています。

**重要**: ターミナルで直接`pnpm`や`node`コマンドを実行する前に、必ずnodeenv環境をアクティベートする必要があります。

##### 環境のアクティベート

```bash
# プロジェクトルートで実行
cd /path/to/account-book
source scripts/setup/activate.sh
```

アクティベート後、以下のコマンドが使用可能になります：

- `node`
- `pnpm`
- `npm`
- `npx`

##### よく使うコマンド

```bash
# 環境をアクティベート
source scripts/setup/activate.sh

# 依存関係のインストール
pnpm install

# 開発サーバーの起動
pnpm dev

# Lint実行
pnpm lint

# Lint自動修正
pnpm run lint -- --fix

# テスト実行
pnpm test

# ビルド
pnpm build
```

##### トラブルシューティング

**問題**: `command not found: pnpm` や `command not found: node` が表示される

**原因**: nodeenv環境がアクティベートされていない

**解決方法**:

```bash
source scripts/setup/activate.sh
```

**問題**: `Error: .nodeenv directory not found`

**原因**: `.nodeenv`ディレクトリが存在しない

**解決方法**: セットアップスクリプトを実行

```bash
./scripts/full-setup.sh
```

##### AIアシスタント向けの注意

- ターミナルコマンドを実行する際は、必ず`source scripts/setup/activate.sh`を最初に実行すること
- サンドボックス環境の問題ではなく、PATHの問題であることに注意
- `required_permissions: ["all"]`を指定して実行すること
