# OpenAppSec 設定値リファレンス（v1beta2）

## 概要

このドキュメントは、OpenAppSecの`local_policy.yaml`（v1beta2スキーマ）におけるすべての設定値とその可能な値、デフォルト値をまとめたリファレンスです。

**公式ドキュメント**: https://docs.openappsec.io/getting-started/start-with-linux/local-policy-file-v1beta2-beta

---

## 目次

1. [基本構造](#基本構造)
2. [policiesセクション](#policiesセクション)
3. [threatPreventionPractices](#threatpreventionpractices)
4. [accessControlPractices](#accesscontrolpractices)
5. [customResponses](#customresponses)
6. [logTriggers](#logtriggers)
7. [exceptions](#exceptions)
8. [trustedSources](#trustedsources)
9. [sourceIdentifiers](#sourceidentifiers)
10. [設定値の決定ガイド](#設定値の決定ガイド)

---

## 基本構造

```yaml
apiVersion: v1beta2  # 必須: v1beta2を指定
policies:
  default: { ... }
  specificRules: [ ... ]
threatPreventionPractices: [ ... ]
accessControlPractices: [ ... ]
customResponses: [ ... ]
logTriggers: [ ... ]
exceptions: [ ... ]
trustedSources: [ ... ]
sourceIdentifiers: [ ... ]
```

---

## policiesセクション

### policies.default

すべてのトラフィックに適用されるデフォルトポリシー。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `mode` | string | **必須** | ポリシーの実行モード | `prevent-learn`, `detect-learn`, `prevent`, `detect`, `inactive`<br>**デフォルト**: `detect-learn` |
| `threatPreventionPractices` | array<string> | **必須** | 適用する脅威防止プラクティスの名前リスト | 空配列可。定義済みプラクティス名を指定 |
| `accessControlPractices` | array<string> | **必須** | 適用するアクセス制御プラクティスの名前リスト | 空配列可 |
| `triggers` | array<string> | **必須** | 適用するログトリガーの名前リスト | 空配列可 |
| `customResponse` | string | オプション | カスタムレスポンス設定の名前 | デフォルト: `403`（HTTPステータスコード） |
| `sourceIdentifiers` | string | オプション | ソース識別子設定の名前 | 空文字列可 |
| `trustedSources` | string | オプション | 信頼できるソース設定の名前 | 空文字列可 |
| `exceptions` | array<string> | オプション | 例外設定の名前リスト | 空配列可 |

#### modeの詳細

| 値 | 説明 | 用途 |
|---|---|---|
| `detect-learn` | 検知のみ（ブロックしない）、学習データを収集 | 初期導入時、誤検知の確認 |
| `prevent-learn` | ブロックしつつ学習データを収集 | 本番環境での推奨モード |
| `detect` | 検知のみ（学習データを収集しない） | 監視のみ |
| `prevent` | ブロック（学習データを収集しない） | 厳格な防御が必要な場合 |
| `inactive` | 無効化 | 一時的な無効化 |

### policies.specificRules

特定のホストに対してデフォルト設定を上書きするルール。

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| `host` | string | **必須** | 適用するホスト名（FQDN） |
| `mode` | string | オプション | デフォルトの`mode`を上書き |
| `threatPreventionPractices` | array<string> | オプション | デフォルトの`threatPreventionPractices`を上書き |
| `accessControlPractices` | array<string> | オプション | デフォルトの`accessControlPractices`を上書き |
| `triggers` | array<string> | オプション | デフォルトの`triggers`を上書き |
| `customResponse` | string | オプション | デフォルトの`customResponse`を上書き |
| `sourceIdentifiers` | string | オプション | デフォルトの`sourceIdentifiers`を上書き |
| `trustedSources` | string | オプション | デフォルトの`trustedSources`を上書き |
| `exceptions` | array<string> | オプション | デフォルトの`exceptions`を上書き |

---

## threatPreventionPractices

脅威防止プラクティスを定義します。

### 基本フィールド

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `name` | string | **必須** | プラクティスの一意な名前 | - |
| `practiceMode` | string | オプション | プラクティスのモード | `inherited`, `prevent-learn`, `detect-learn`, `prevent`, `detect`, `inactive`<br>**デフォルト**: `inherited` |

### webAttacks

Web攻撃（OWASP Top 10など）の検出・防御設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `overrideMode` | string | オプション | Web攻撃専用のモード | `inherited`, `prevent-learn`, `detect-learn`, `prevent`, `detect`, `inactive`<br>**デフォルト**: `inherited` |
| `minimumConfidence` | string | オプション | ブロックするための最小信頼度 | `medium`, `high`, `critical`<br>**デフォルト**: `high` |
| `maxUrlSizeBytes` | integer | オプション | 検査するURLの最大サイズ（バイト） | **デフォルト**: `32768` |
| `maxObjectDepth` | integer | オプション | 検査するJSON/XMLオブジェクトの最大深度 | **デフォルト**: `40` |
| `maxBodySizeKb` | integer | オプション | 検査するHTTPボディの最大サイズ（KB） | **デフォルト**: `1000000` (1GB) |
| `maxHeaderSizeBytes` | integer | オプション | 検査するHTTPヘッダーの最大サイズ（バイト） | **デフォルト**: `102400` |

#### webAttacks.protections

追加の保護機能。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `csrfProtection` | string | オプション | CSRF保護 | `prevent-learn`, `detect-learn`, `prevent`, `detect`, `inactive`, `inherited`<br>**デフォルト**: `inactive` |
| `errorDisclosure` | string | オプション | エラー情報の開示防止 | 同上<br>**デフォルト**: `inactive` |
| `openRedirect` | string | オプション | オープンリダイレクト攻撃の防止 | 同上<br>**デフォルト**: `inactive` |
| `nonValidHttpMethods` | boolean | オプション | 無効なHTTPメソッドのブロック | `true`, `false`<br>**デフォルト**: `false` |

#### minimumConfidenceの詳細

| 値 | 説明 | 推奨用途 |
|---|---|---|
| `medium` | 低い閾値（より多くのイベントが検知される、誤検知の可能性が高い） | 開発環境、初期導入時 |
| `high` | バランスの取れた閾値（デフォルト） | 本番環境の推奨値 |
| `critical` | 非常に高い閾値（誤検知は少ないが、低信頼度の悪意のあるトラフィックを通す可能性） | 厳格な運用が必要な場合 |

### intrusionPrevention

侵入防止システム（IPS）の設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `overrideMode` | string | オプション | IPS専用のモード | `inherited`, `prevent-learn`, `detect-learn`, `prevent`, `detect`, `inactive`<br>**デフォルト**: `inherited` |
| `maxPerformanceImpact` | string | オプション | パフォーマンスへの最大影響 | `low`, `medium`, `high`<br>**デフォルト**: `medium` |
| `minSeverityLevel` | string | オプション | 最小重要度レベル | `low`, `medium`, `high`, `critical`<br>**デフォルト**: `medium` |
| `minCveYear` | integer | オプション | 検査するCVEの最小年 | **デフォルト**: `2016` |
| `highConfidenceEventAction` | string | オプション | 高信頼度イベントのアクション | `prevent`, `detect`, `inactive`, `inherited`<br>**デフォルト**: `inherited` |
| `mediumConfidenceEventAction` | string | オプション | 中信頼度イベントのアクション | 同上<br>**デフォルト**: `inherited` |
| `lowConfidenceEventAction` | string | オプション | 低信頼度イベントのアクション | 同上<br>**デフォルト**: `detect` |

### fileSecurity

ファイルセキュリティ（アップロードファイルの検査）の設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `overrideMode` | string | オプション | ファイルセキュリティ専用のモード | `inherited`, `prevent-learn`, `detect-learn`, `prevent`, `detect`, `inactive`<br>**デフォルト**: `inherited` |
| `minSeverityLevel` | string | オプション | 最小重要度レベル | `low`, `medium`, `high`, `critical`<br>**デフォルト**: `medium` |
| `highConfidenceEventAction` | string | オプション | 高信頼度イベントのアクション | `prevent`, `detect`, `inactive`, `inherited`<br>**デフォルト**: `inherited` |
| `mediumConfidenceEventAction` | string | オプション | 中信頼度イベントのアクション | 同上<br>**デフォルト**: `inherited` |
| `lowConfidenceEventAction` | string | オプション | 低信頼度イベントのアクション | 同上<br>**デフォルト**: `detect` |
| `threatEmulationEnabled` | boolean | オプション | 脅威エミュレーションの有効化 | `true`, `false`<br>**デフォルト**: `false` |

#### fileSecurity.archiveInspection

アーカイブファイルの検査設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `extractArchiveFiles` | boolean | オプション | アーカイブファイルの展開 | `true`, `false`<br>**デフォルト**: `false` |
| `scanMaxFileSize` | integer | オプション | スキャンする最大ファイルサイズ | **デフォルト**: `10` |
| `scanMaxFileSizeUnit` | string | オプション | ファイルサイズの単位 | `bytes`, `KB`, `MB`, `GB`<br>**デフォルト**: `MB` |
| `archivedFilesWithinArchivedFiles` | string | オプション | ネストされたアーカイブの処理 | `prevent`, `detect`, `inactive`, `inherited`<br>**デフォルト**: `inherited` |
| `archivedFilesWhereContentExtractionFailed` | string | オプション | 展開失敗時の処理 | 同上<br>**デフォルト**: `inherited` |

#### fileSecurity.largeFileInspection

大きなファイルの検査設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `fileSizeLimit` | integer | オプション | ファイルサイズの制限 | **デフォルト**: `10` |
| `fileSizeLimitUnit` | string | オプション | ファイルサイズの単位 | `bytes`, `KB`, `MB`, `GB`<br>**デフォルト**: `MB` |
| `filesExceedingSizeLimitAction` | string | オプション | 制限超過時のアクション | `prevent`, `detect`, `inactive`, `inherited`<br>**デフォルト**: `detect` |

### snortSignatures

Snortシグネチャベースの検出設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `overrideMode` | string | オプション | Snortシグネチャ専用のモード | `inherited`, `prevent-learn`, `detect-learn`, `prevent`, `detect`, `inactive`<br>**デフォルト**: `inherited` |
| `configmap` | array<string> | オプション | Kubernetes ConfigMap参照（K8sのみ） | 最大1つ |
| `files` | array<string> | オプション | シグネチャファイルのパス（Linux/Docker） | 最大1つ |

### schemaValidation

APIスキーマ検証（OpenAPI/JSON Schema）の設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `overrideMode` | string | オプション | スキーマ検証専用のモード | `inherited`, `prevent-learn`, `detect-learn`, `prevent`, `detect`, `inactive`<br>**デフォルト**: `inherited` |
| `enforcementLevel` | string | オプション | 強制レベル | `strict`, `moderate`, `loose`（オプション） |
| `configmap` | array<string> | オプション | Kubernetes ConfigMap参照（K8sのみ） | 最大1つ |
| `files` | array<string> | オプション | スキーマファイルのパス（Linux/Docker） | 最大1つ |

### antiBot

ボット検出・防止の設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `overrideMode` | string | オプション | ボット検出専用のモード | `inherited`, `prevent-learn`, `detect-learn`, `prevent`, `detect`, `inactive`<br>**デフォルト**: `inherited` |
| `injectedUris` | array<string> | オプション | ボットチェック用のURIリスト | - |
| `validatedUris` | array<string> | オプション | 検証済みURIリスト | - |

---

## accessControlPractices

アクセス制御プラクティスを定義します。

### 基本フィールド

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `name` | string | **必須** | プラクティスの一意な名前 | - |
| `practiceMode` | string | オプション | プラクティスのモード | `inherited`, `prevent-learn`, `detect-learn`, `prevent`, `detect`, `inactive`<br>**デフォルト**: `inherited` |

### rateLimit

レート制限の設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `overrideMode` | string | オプション | レート制限専用のモード | `inherited`, `prevent-learn`, `detect-learn`, `prevent`, `detect`, `inactive`<br>**デフォルト**: `inherited` |
| `rules` | array<object> | オプション | レート制限ルールのリスト | - |

#### rateLimit.rules

各レート制限ルール。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `action` | string | オプション | 制限超過時のアクション | `inherited`, `prevent`, `detect`<br>**デフォルト**: `inherited` |
| `uri` | string | オプション | 適用するURIパターン | 例: `/api/*`, `/login` |
| `limit` | integer | **必須** | リクエスト数の制限 | - |
| `unit` | string | オプション | 時間単位 | `second`, `minute`<br>**デフォルト**: `minute` |
| `triggers` | array<string> | オプション | 関連するトリガーの名前リスト | - |
| `comment` | string | オプション | 人間が読むためのコメント | - |
| `condition` | array<object> | オプション | 条件（現在はサポートされていない） | - |

---

## customResponses

カスタムレスポンス設定を定義します。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `name` | string | **必須** | レスポンス設定の一意な名前 | - |
| `mode` | string | **必須** | レスポンスモード | `block-page`, `redirect`, `response-code-only`<br>**デフォルト**: `response-code-only` |
| `messageTitle` | string | オプション | ブロックページのタイトル（`block-page`モード時） | - |
| `messageBody` | string | オプション | ブロックページの本文（`block-page`モード時） | - |
| `httpResponseCode` | integer | **必須** | HTTPレスポンスコード | 100-599の範囲<br>**デフォルト**: `403` |
| `redirectUrl` | string | オプション | リダイレクト先URL（`redirect`モード時） | - |
| `redirectAddXEventId` | boolean | オプション | リダイレクト時に`X-Event-ID`ヘッダーを追加 | `true`, `false`<br>**デフォルト**: `false` |

---

## logTriggers

ログトリガー設定を定義します。

### 基本フィールド

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `name` | string | **必須** | ログトリガーの一意な名前 | - |

### accessControlLogging

アクセス制御ログの設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `allowEvents` | boolean | オプション | 許可イベントをログに記録 | `true`, `false`<br>**デフォルト**: `false` |
| `dropEvents` | boolean | オプション | ドロップイベントをログに記録 | `true`, `false`<br>**デフォルト**: `true` |

### appsecLogging

AppSecログの設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `detectEvents` | boolean | オプション | 検知イベントをログに記録 | `true`, `false`<br>**デフォルト**: `true` |
| `preventEvents` | boolean | オプション | 防止イベントをログに記録 | `true`, `false`<br>**デフォルト**: `true` |
| `allWebRequests` | boolean | オプション | すべてのWebリクエストをログに記録 | `true`, `false`<br>**デフォルト**: `false` |

### additionalSuspiciousEventsLogging

追加の不審イベントログの設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `enabled` | boolean | オプション | 有効化 | `true`, `false`<br>**デフォルト**: `true` |
| `minSeverity` | string | オプション | 最小重要度 | `high`, `critical`<br>**デフォルト**: `high` |
| `responseBody` | boolean | オプション | レスポンスボディをログに記録 | `true`, `false`<br>**デフォルト**: `false` |
| `responseCode` | boolean | オプション | レスポンスコードをログに記録 | `true`, `false`<br>**デフォルト**: `true` |

### extendedLogging

拡張ログの設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `urlPath` | boolean | オプション | URLパスをログに記録 | `true`, `false`<br>**デフォルト**: `false` |
| `urlQuery` | boolean | オプション | URLクエリをログに記録 | `true`, `false`<br>**デフォルト**: `false` |
| `httpHeaders` | boolean | オプション | HTTPヘッダーをログに記録 | `true`, `false`<br>**デフォルト**: `false` |
| `requestBody` | boolean | オプション | リクエストボディをログに記録 | `true`, `false`<br>**デフォルト**: `false` |

### logDestination

ログの送信先設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `cloud` | boolean | オプション | クラウド（SaaS）に送信 | `true`, `false`<br>**デフォルト**: `false` |
| `logToAgent` | boolean | オプション | Agentログに記録 | `true`, `false`<br>**デフォルト**: `true` |
| `stdout` | object | オプション | 標準出力への出力設定 | - |
| `syslogService` | array<object> | オプション | Syslogサービスへの送信設定 | - |

#### logDestination.stdout

標準出力の設定。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `format` | string | オプション | ログ形式 | `json`, `json-formatted`<br>**デフォルト**: `json` |

---

## exceptions

例外設定を定義します。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `name` | string | **必須** | 例外設定の一意な名前 | - |
| `action` | string | **必須** | 例外が適用されたときのアクション | `skip`, `accept`, `drop`, `suppressLog`<br>**デフォルト**: `accept` |
| `condition` | array<object> | **必須** | 例外が適用される条件 | - |

### exceptions.condition

各条件オブジェクト。

| フィールド | 型 | 必須 | 説明 | 可能な値 |
|---|---|---|---|---|
| `key` | string | **必須** | 条件のキー | `sourceIp`, `countryCode`, `countryName`, `hostName`, `paramName`, `paramValue`, `protectionName`, `sourceIdentifier`, `url` |
| `value` | string | **必須** | 条件の値 | マッチする値 |

---

## trustedSources

信頼できるソース設定を定義します。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `name` | string | **必須** | 信頼できるソース設定の一意な名前 | - |
| `minNumOfSources` | integer | **必須** | 学習に必要な最小ソース数 | **デフォルト**: `3` |
| `sourcesIdentifiers` | array<string> | **必須** | 参照するソース識別子設定の名前リスト | - |

---

## sourceIdentifiers

ソース識別子設定を定義します。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `name` | string | **必須** | ソース識別子設定の一意な名前 | - |
| `sourcesIdentifiers` | array<object> | **必須** | ソース識別子のリスト | - |

### sourceIdentifiers.sourcesIdentifiers

各ソース識別子オブジェクト。

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `identifier` | string | **必須** | 識別子のタイプ | `headerkey`, `JWTKey`, `cookie`, `sourceip`, `x-forwarded-for`<br>**デフォルト**: `sourceip` |
| `value` | array<string> | **必須** | 識別子の値リスト | - |

---

## 設定値の決定ガイド

### 1. モードの選択

#### 開発環境
- **推奨**: `detect-learn`
- **理由**: 誤検知を確認しながら学習データを収集

#### 本番環境
- **推奨**: `prevent-learn`
- **理由**: 防御しつつ継続的に学習

#### 厳格な防御が必要な場合
- **推奨**: `prevent`
- **理由**: 即座にブロック（学習データは収集しない）

### 2. webAttacks.minimumConfidenceの選択

| 環境 | 推奨値 | 理由 |
|---|---|---|
| 開発環境 | `medium` | より多くの攻撃パターンを検知してテスト |
| 本番環境 | `high` | バランスの取れた検知（デフォルト） |
| 厳格な運用 | `critical` | 誤検知を最小化 |

### 3. サイズ制限の設定

| 設定項目 | デフォルト | 推奨調整 |
|---|---|---|
| `maxUrlSizeBytes` | 32768 (32KB) | API用途に応じて調整 |
| `maxObjectDepth` | 40 | 複雑なJSON構造がある場合は増やす |
| `maxBodySizeKb` | 1000000 (1GB) | アップロードファイルサイズに応じて調整 |
| `maxHeaderSizeBytes` | 102400 (100KB) | 通常はデフォルトで問題なし |

### 4. protectionsの設定

| 保護機能 | 推奨設定 | 理由 |
|---|---|---|
| `csrfProtection` | `prevent` | CSRF攻撃は一般的な脅威 |
| `errorDisclosure` | `prevent` | エラー情報の漏洩を防止 |
| `openRedirect` | `prevent` | オープンリダイレクト攻撃を防止 |
| `nonValidHttpMethods` | `true` | 無効なHTTPメソッドをブロック |

### 5. レート制限の設定例

```yaml
rateLimit:
  rules:
    - uri: "/login"
      limit: 10
      unit: minute
      action: prevent
      comment: "ログイン試行のレート制限"
    - uri: "/api/*"
      limit: 100
      unit: minute
      action: detect
      comment: "API呼び出しのレート制限"
```

### 6. カスタムレスポンスの設定例

```yaml
customResponses:
  - name: web-user-response
    mode: response-code-only
    httpResponseCode: 403
  - name: api-user-response
    mode: block-page
    messageTitle: "アクセスが拒否されました"
    messageBody: "このリクエストはセキュリティポリシーによりブロックされました。"
    httpResponseCode: 403
```

---

## 設定例（完全版）

```yaml
apiVersion: v1beta2
policies:
  default:
    mode: prevent-learn
    threatPreventionPractices: [threat-prevention-basic]
    accessControlPractices: [access-control-basic]
    triggers: [log-trigger-basic]
    customResponse: web-user-response
    sourceIdentifiers: ""
    trustedSources: ""
    exceptions: []

  specificRules:
    - host: "api.example.com"
      mode: prevent
      threatPreventionPractices: [threat-prevention-basic]
      accessControlPractices: [access-control-api]
      triggers: [log-trigger-basic]
      customResponse: api-user-response
      sourceIdentifiers: ""
      trustedSources: ""
      exceptions: []

threatPreventionPractices:
  - name: threat-prevention-basic
    practiceMode: prevent
    webAttacks:
      overrideMode: prevent
      minimumConfidence: high
      maxUrlSizeBytes: 32768
      maxObjectDepth: 40
      maxBodySizeKb: 10000
      maxHeaderSizeBytes: 102400
      protections:
        csrfProtection: prevent
        errorDisclosure: prevent
        openRedirect: prevent
        nonValidHttpMethods: true
    intrusionPrevention:
      overrideMode: inherited
      maxPerformanceImpact: medium
      minSeverityLevel: medium
      minCveYear: 2016
      highConfidenceEventAction: prevent
      mediumConfidenceEventAction: prevent
      lowConfidenceEventAction: detect
    fileSecurity:
      overrideMode: inherited
      minSeverityLevel: medium
      highConfidenceEventAction: prevent
      mediumConfidenceEventAction: prevent
      lowConfidenceEventAction: detect
    snortSignatures:
      overrideMode: inherited
      configmap: []
      files: []
    schemaValidation:
      overrideMode: inherited
      configmap: []
      files: []
    antiBot:
      overrideMode: inherited
      injectedUris: []
      validatedUris: []

accessControlPractices:
  - name: access-control-basic
    practiceMode: inherited
    rateLimit:
      overrideMode: inherited
      rules:
        - uri: "/login"
          limit: 10
          unit: minute
          action: prevent
          comment: "ログイン試行のレート制限"
        - uri: "/api/*"
          limit: 100
          unit: minute
          action: detect
          comment: "API呼び出しのレート制限"

  - name: access-control-api
    practiceMode: prevent
    rateLimit:
      overrideMode: prevent
      rules:
        - uri: "/api/*"
          limit: 1000
          unit: minute
          action: prevent
          comment: "APIの厳格なレート制限"

customResponses:
  - name: web-user-response
    mode: response-code-only
    httpResponseCode: 403

  - name: api-user-response
    mode: block-page
    messageTitle: "アクセスが拒否されました"
    messageBody: "このリクエストはセキュリティポリシーによりブロックされました。"
    httpResponseCode: 403

logTriggers:
  - name: log-trigger-basic
    accessControlLogging:
      allowEvents: false
      dropEvents: true
    appsecLogging:
      detectEvents: true
      preventEvents: true
      allWebRequests: false
    extendedLogging:
      urlPath: true
      urlQuery: true
      httpHeaders: false
      requestBody: false
    additionalSuspiciousEventsLogging:
      enabled: true
      minSeverity: high
      responseBody: false
      responseCode: true
    logDestination:
      cloud: false
      logToAgent: true
      stdout:
        format: json
```

---

## 参考資料

- [公式ドキュメント: Local Policy File v1beta2](https://docs.openappsec.io/getting-started/start-with-linux/local-policy-file-v1beta2-beta)
- [公式サンプルファイル](https://raw.githubusercontent.com/openappsec/openappsec/main/config/linux/v1beta2/example/local_policy.yaml)
- [CRD v1beta2 リファレンス](https://docs.openappsec.io/getting-started/start-with-kubernetes/configuration-using-crds-v1beta2)

---

## 更新履歴

- 2026-01-16: 初版作成
- 公式ドキュメント（v1beta2）に基づく完全な設定値リファレンス
