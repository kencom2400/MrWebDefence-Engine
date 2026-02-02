# RateLimit設定読み込み処理の調査結果

## 実施日時
2026-01-28

## 調査内容

OpenAppSecのRateLimit設定が`local_policy.yaml`から`policy.json`にどのように読み込まれているかを調査しました。

## 調査結果

### 1. policy.jsonの構造

`policy.json`の構造を確認した結果：

```json
{
  "accessControlV2": {
    "rulebase": {
      "accessControl": [],
      "traditionalFirewall": [],
      "l4firewall": [],
      "rateLimit": []  // 空の配列
    }
  },
  "policies": null,  // 存在しない
  "accessControlPractices": null  // 存在しない
}
```

### 2. 重要な発見

1. **`accessControlV2.rulebase.rateLimit`は存在するが空**
   - 構造自体は存在している
   - しかし、ルールが読み込まれていない

2. **`policies`キーが存在しない**
   - `local_policy.yaml`の`policies`セクションは`policy.json`には直接反映されていない
   - 別の形式に変換されている可能性

3. **`accessControlPractices`キーが存在しない**
   - `local_policy.yaml`の`accessControlPractices`セクションは`policy.json`には直接反映されていない
   - `accessControlV2`に変換されている可能性

### 3. OpenAppSecのソースコードリポジトリ

ユーザーが提供したGitHubリポジトリ：
- https://github.com/openappsec/openappsec/tree/main/components/security_apps/rate_limit

このリポジトリには、RateLimit機能の実装コードが含まれていますが、このプロジェクト（MrWebDefence-Engine）にはOpenAppSecのソースコードは含まれていません。

### 4. 設定ファイルの読み込み処理

OpenAppSecの設定ファイル読み込み処理は、以下のような流れになっていると推測されます：

1. **YAMLファイルの読み込み**
   - `/ext/appsec/local_policy.yaml`（マウントされたファイル）
   - または `/etc/cp/conf/local_policy.yaml`（デフォルト）

2. **YAMLからJSONへの変換**
   - OpenAppSecの内部処理でYAMLをパース
   - `accessControlPractices`の`rateLimit`ルールを`accessControlV2.rulebase.rateLimit`に変換

3. **policy.jsonへの書き込み**
   - 変換されたJSONを`/etc/cp/conf/policy.json`に保存

### 5. 問題の可能性

現在、`rateLimit`配列が空のままである理由として、以下の可能性が考えられます：

1. **YAMLパースエラー**
   - `local_policy.yaml`の構造に問題がある可能性
   - しかし、`open-appsec-ctl --view-policy`では正しく表示されている

2. **変換処理のバグ**
   - OpenAppSecの内部処理で`accessControlPractices`から`accessControlV2`への変換が正しく動作していない可能性

3. **Community Editionの制限**
   - Local Policy File経由でのRateLimit設定がサポートされていない可能性
   - Web UI（SaaS）経由でのみ設定可能な可能性

4. **設定の適用タイミング**
   - ポリシーの再読み込みが必要な可能性
   - しかし、`open-appsec-ctl -lc http-transaction-handler`を実行しても変化なし

### 6. 次のステップ

1. **OpenAppSecのソースコードを確認**
   - GitHubリポジトリ（https://github.com/openappsec/openappsec）をクローン
   - `components/security_apps/rate_limit`ディレクトリのコードを確認
   - YAMLからJSONへの変換処理を特定

2. **OpenAppSecのログを詳細に確認**
   - エラーログや警告ログを確認
   - RateLimit設定の読み込みに関するログを探す

3. **OpenAppSecのサポートに問い合わせ**
   - Community EditionでのLocal Policy File経由のRateLimit設定がサポートされているか確認
   - 設定が読み込まれない原因を特定

4. **代替案の検討**
   - Web UI（SaaS）経由での設定を検討
   - または、Premium Editionへのアップグレードを検討

## 参考資料

- OpenAppSec GitHubリポジトリ: https://github.com/openappsec/openappsec
- RateLimitコンポーネント: https://github.com/openappsec/openappsec/tree/main/components/security_apps/rate_limit
- OpenAppSec公式ドキュメント: https://docs.openappsec.io/
