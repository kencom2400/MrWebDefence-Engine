# OpenAppSec Community Edition 制限事項 - 調査結果

## 実施日時
2026-01-28

## 調査結果サマリー

OpenAppSecの公式ドキュメントを確認した結果、**RateLimit機能はCommunity Edition（Free Edition）で利用可能**であることが確認できました。しかし、重要な制限事項が存在します。

## RateLimit機能の利用可能性

### ✅ Community Editionで利用可能

公式ドキュメント（[Rate Limit | open-appsec](https://docs.openappsec.io/additional-security-engines/rate-limit)）によると：

- **バージョン要件**: Agent version **1.1.2以降**が必要（1.1.32は問題なし）
- **機能**: RateLimit機能自体はCommunity Editionで利用可能
- **設定方法**: Web UI（SaaS）またはLocal Policy File（v1beta2）で設定可能

## Community Editionの制限事項

### 1. Source Identityの制限

**Community Editionでは、Source IdentityとしてIPとX-Forwarded-Forのみがサポートされています。**

- ✅ **利用可能**: IP、X-Forwarded-For
- ❌ **利用不可**: Header Key、Cookie、JWT Key（Premium Editionのみ）

> **出典**: [Rate Limit | open-appsec](https://docs.openappsec.io/additional-security-engines/rate-limit)
> 
> "In the community edition, only IP and X-Forwarded-For are supported as Source Identities."

### 2. **ルール数の制限（重要）**

**Community Editionでは、1つのルールのみサポートされています。**

> **出典**: [Rate Limit | open-appsec](https://docs.openappsec.io/additional-security-engines/rate-limit)
> 
> "In the community edition, only one rule is supported."

### 3. Premium Editionとの比較

| 機能 | Community Edition | Premium Edition |
|------|------------------|-----------------|
| RateLimit機能 | ✅ 利用可能 | ✅ 利用可能 |
| Source Identity | IP、X-Forwarded-Forのみ | カスタムSource Identifier（Header Key、Cookie、JWT Keyなど） |
| ルール数 | **1つのみ** | 複数可能 |
| その他 | - | カスタムSource Identifier、Web UI管理、MFAなど |

## 現在の実装の問題点

### 問題: 複数のルールを定義している

現在の`local_policy.yaml`では、以下の2つのルールを定義しています：

```yaml
accessControlPractices:
  - name: rate-limit-default
    practiceMode: prevent
    rateLimit:
      overrideMode: prevent
      rules:
        - uri: "/login"
          limit: 10
          unit: minute
          action: prevent
          comment: "ログイン試行のレート制限"
        - uri: "/api/*"
          limit: 100
          unit: minute
          action: prevent
          comment: "API呼び出しのレート制限"
```

**Community Editionでは1つのルールのみサポートされているため、2つ目のルールが無視されている可能性があります。**

## 解決策

### オプション1: 1つのルールに統合（推奨）

Community Editionの制限に合わせて、1つのルールに統合します。

```yaml
accessControlPractices:
  - name: rate-limit-default
    practiceMode: prevent
    rateLimit:
      overrideMode: prevent
      rules:
        - uri: "/"
          limit: 100
          unit: minute
          action: prevent
          comment: "全エンドポイントのレート制限（Community Edition制限により1ルールのみ）"
```

### オプション2: より重要なルールを優先

`/login`エンドポイントのみに制限を適用します。

```yaml
accessControlPractices:
  - name: rate-limit-default
    practiceMode: prevent
    rateLimit:
      overrideMode: prevent
      rules:
        - uri: "/login"
          limit: 10
          unit: minute
          action: prevent
          comment: "ログイン試行のレート制限（Community Edition制限により1ルールのみ）"
```

### オプション3: Premium Editionへのアップグレード

複数のルールが必要な場合は、Premium Editionへのアップグレードを検討します。

## 次のステップ

1. ✅ **Community Editionの制限を確認**: 完了
2. ⏳ **1つのルールに統合**: 実装が必要
3. ⏳ **動作確認**: 1つのルールでRateLimitが動作するか確認
4. ⏳ **ドキュメント更新**: 実装設計書に制限事項を追記

## 参考資料

- [Rate Limit | open-appsec](https://docs.openappsec.io/additional-security-engines/rate-limit)
- [open-appsec Pricing | No Hidden Costs | Purchase & Support](https://openappsec.io/pricing)
- [Local Policy File (Advanced) | open-appsec](https://docs.openappsec.io/getting-started/start-with-linux/local-policy-file-advanced)

## 結論

RateLimit機能はCommunity Editionで利用可能ですが、**1つのルールのみサポートされている**という重要な制限があります。現在の実装では2つのルールを定義しているため、これがRateLimit設定が読み込まれない原因である可能性が高いです。

解決策として、1つのルールに統合するか、より重要なルール（例：`/login`）のみを残すことを推奨します。
