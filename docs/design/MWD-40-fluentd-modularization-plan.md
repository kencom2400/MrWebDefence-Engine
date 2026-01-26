# Fluentd設定ファイルのモジュール化計画

## 概要

Fluentdの設定ファイルを機能別に分割し、モジュール化することで、設定の管理性と拡張性を向上させます。

## 目標

- 設定ファイルの機能別分割
- `label`を使用した設定間の連携
- 設定の再利用性と拡張性の向上
- 設定の可読性と保守性の向上

## ディレクトリ構造

```
docker/fluentd/
├── fluent.conf                    # メイン設定ファイル（Include設定）
├── in.d/                          # インプット設定
│   ├── nginx-access.conf         # Nginxアクセスログ収集
│   ├── nginx-error.conf          # Nginxエラーログ収集
│   ├── openappsec-detection.conf # OpenAppSec検知ログ収集
│   └── docker-logs.conf          # Dockerログドライバ（オプション）
├── process.d/                     # 処理設定
│   ├── nginx-access-process.conf # Nginxアクセスログ処理
│   ├── nginx-error-process.conf  # Nginxエラーログ処理
│   └── openappsec-process.conf   # OpenAppSecログ処理
├── forwarder.d/                   # 転送設定
│   ├── http-output.conf          # HTTP/HTTPS転送（オプション）
│   └── forward-output.conf       # Fluentd Forward転送（オプション）
└── archive.d/                     # アーカイブ設定
    ├── stdout-output.conf        # 標準出力（デフォルト）
    └── file-output.conf          # ファイル出力（オプション）
```

## 設定ファイルの分割方針

### 1. メイン設定ファイル (`fluent.conf`)

**役割**: 他の設定ファイルをIncludeし、全体の構造を定義

**内容**:
- システム設定（ログレベル、バッファ設定等）
- 各ディレクトリの設定ファイルのInclude
- グローバルな設定

### 2. インプット設定 (`in.d/`)

**役割**: ログの収集設定（source、tail、forward等）

**ファイル構成**:
- `nginx-access.conf`: Nginxアクセスログのtail設定
- `nginx-error.conf`: Nginxエラーログのtail設定
- `openappsec-detection.conf`: OpenAppSec検知ログのtail設定
- `docker-logs.conf`: Dockerログドライバのforward設定（オプション）

**label使用方針**:
- 各source設定で`@label`を指定し、対応する処理設定にルーティング
- 例: `@label @nginx_access_process`

### 3. 処理設定 (`process.d/`)

**役割**: ログの処理、タグ付け、データシリアライズ

**ファイル構成**:
- `nginx-access-process.conf`: Nginxアクセスログのメタデータ追加とタグ変換
- `nginx-error-process.conf`: Nginxエラーログのメタデータ追加とタグ変換
- `openappsec-process.conf`: OpenAppSecログのFQDN別タグ付けとメタデータ追加

**label使用方針**:
- `<label>`ブロックで処理を定義
- 処理後、`@label`を使用して転送設定またはアーカイブ設定にルーティング
- 例: `@label @forwarder` または `@label @archive`

### 4. 転送設定 (`forwarder.d/`)

**役割**: 他のFluentd、ストレージ（S3等）への転送

**ファイル構成**:
- `http-output.conf`: HTTP/HTTPS転送設定（オプション）
- `forward-output.conf`: Fluentd Forward転送設定（オプション）

**label使用方針**:
- `<label>`ブロックで転送設定を定義
- 環境変数で有効/無効を切り替え可能

### 5. アーカイブ設定 (`archive.d/`)

**役割**: ローカルホストへの保存設定

**ファイル構成**:
- `stdout-output.conf`: 標準出力設定（デフォルト）
- `file-output.conf`: ファイル出力設定（オプション）

**label使用方針**:
- `<label>`ブロックでアーカイブ設定を定義
- デフォルトでstdout出力を使用

## Label設計

### Label命名規則

```
@<機能>_<処理種別>
```

**例**:
- `@nginx_access_process`: Nginxアクセスログ処理
- `@nginx_error_process`: Nginxエラーログ処理
- `@openappsec_process`: OpenAppSecログ処理
- `@forwarder`: 転送設定
- `@archive`: アーカイブ設定

### Labelフロー

```
Source (in.d/)
  ↓ @label指定
Label (process.d/)
  ↓ @label指定
Label (forwarder.d/ or archive.d/)
  ↓
Output
```

## 実装計画

### Phase 1: ディレクトリ構造の作成

1. `docker/fluentd/`配下にディレクトリを作成
   - `in.d/`
   - `process.d/`
   - `forwarder.d/`
   - `archive.d/`

### Phase 2: インプット設定の分割 (`in.d/`)

#### 2.1 `nginx-access.conf`

**内容**:
- Nginxアクセスログのtail設定
- `@label @nginx_access_process`を指定

#### 2.2 `nginx-error.conf`

**内容**:
- Nginxエラーログのtail設定
- `@label @nginx_error_process`を指定

#### 2.3 `openappsec-detection.conf`

**内容**:
- OpenAppSec検知ログのtail設定
- `@label @openappsec_process`を指定

#### 2.4 `docker-logs.conf` (オプション)

**内容**:
- Dockerログドライバのforward設定
- 環境変数で有効/無効を切り替え可能

### Phase 3: 処理設定の分割 (`process.d/`)

#### 3.1 `nginx-access-process.conf`

**内容**:
- `<label @nginx_access_process>`ブロック
- メタデータ追加（record_transformer）
- タグ変換（rewrite_tag_filter）
- 処理後、`@label @forwarder`または`@label @archive`にルーティング

#### 3.2 `nginx-error-process.conf`

**内容**:
- `<label @nginx_error_process>`ブロック
- メタデータ追加（record_transformer）
- タグ変換（rewrite_tag_filter）
- 処理後、`@label @forwarder`または`@label @archive`にルーティング

#### 3.3 `openappsec-process.conf`

**内容**:
- `<label @openappsec_process>`ブロック
- FQDN別タグ付け（rewrite_tag_filter）
- メタデータ追加（record_transformer）
- タグ変換（rewrite_tag_filter）
- 処理後、`@label @forwarder`または`@label @archive`にルーティング

### Phase 4: 転送設定の分割 (`forwarder.d/`)

#### 4.1 `http-output.conf` (オプション)

**内容**:
- `<label @forwarder>`ブロック
- HTTP/HTTPS転送設定
- 環境変数で有効/無効を切り替え可能

#### 4.2 `forward-output.conf` (オプション)

**内容**:
- `<label @forwarder>`ブロック
- Fluentd Forward転送設定
- 環境変数で有効/無効を切り替え可能

### Phase 5: アーカイブ設定の分割 (`archive.d/`)

#### 5.1 `stdout-output.conf`

**内容**:
- `<label @archive>`ブロック
- 標準出力設定（デフォルト）

#### 5.2 `file-output.conf` (オプション)

**内容**:
- `<label @archive>`ブロック
- ファイル出力設定
- FQDN別ファイル出力等

### Phase 6: メイン設定ファイルの更新 (`fluent.conf`)

**内容**:
- システム設定
- 各ディレクトリの設定ファイルのInclude
- グローバルな設定

## 設定ファイルのInclude方法

### FluentdのInclude構文

```aconf
@include /fluentd/etc/in.d/*.conf
@include /fluentd/etc/process.d/*.conf
@include /fluentd/etc/forwarder.d/*.conf
@include /fluentd/etc/archive.d/*.conf
```

### 条件付きInclude（オプション）

環境変数で有効/無効を切り替える場合は、設定ファイル内で条件分岐を使用するか、ファイル名で制御する。

## 実装時の注意点

### 1. Labelの一意性

- 各labelは一意である必要がある
- 命名規則に従い、重複を避ける

### 2. 設定ファイルの読み込み順序

- Includeの順序に注意
- 依存関係を考慮した順序でInclude

### 3. 環境変数の使用

- 環境変数で有効/無効を切り替え可能にする
- デフォルト動作を明確にする

### 4. エラーハンドリング

- 設定ファイルの構文エラーを早期に検出
- ログでエラーを確認できるようにする

### 5. 後方互換性

- 既存の設定との互換性を維持
- 段階的な移行を可能にする

## 移行手順

### Step 1: ディレクトリ構造の作成

```bash
mkdir -p docker/fluentd/{in.d,process.d,forwarder.d,archive.d}
```

### Step 2: 既存設定のバックアップ

```bash
cp docker/fluentd/fluent.conf docker/fluentd/fluent.conf.backup
```

### Step 3: 設定ファイルの分割

1. インプット設定を`in.d/`に分割
2. 処理設定を`process.d/`に分割
3. 転送設定を`forwarder.d/`に分割
4. アーカイブ設定を`archive.d/`に分割

### Step 4: メイン設定ファイルの更新

- Include設定を追加
- システム設定を追加

### Step 5: 動作確認

1. Fluentdコンテナの再起動
2. ログの確認
3. エラーの確認

### Step 6: テスト

1. 各機能の動作確認
2. Labelの連携確認
3. 環境変数による切り替え確認

## 期待される効果

1. **設定の管理性向上**: 機能別に分割することで、設定の管理が容易になる
2. **拡張性向上**: 新しい機能の追加が容易になる
3. **可読性向上**: 各設定ファイルが小さくなり、理解しやすくなる
4. **再利用性向上**: 設定の再利用が容易になる
5. **保守性向上**: 変更の影響範囲が明確になる

## 参考資料

- [Fluentd Configuration File Syntax](https://docs.fluentd.org/configuration/config-file)
- [Fluentd Label Directive](https://docs.fluentd.org/configuration/label-section)
- [Fluentd Include Directive](https://docs.fluentd.org/configuration/include)
