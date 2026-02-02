# RateLimit設定の別アプローチ調査

## 実施日時
2026-01-28

## 背景

Local Policy File (`local_policy.yaml`)経由でのRateLimit設定が読み込まれない問題が発生しています。
別のアプローチを調査し、代替手段を検討します。

## 調査したアプローチ

### 1. REST API経由での設定

#### 1.1 OpenAppSec Agent REST APIの確認

OpenAppSec Agentはポート7777でREST APIを提供しています。

```bash
curl http://localhost:7777/v1/status
```

#### 1.2 確認結果

- REST APIは利用可能
- ただし、RateLimit設定を直接変更するエンドポイントは見つかりませんでした
- `/v1/status`は読み取り専用で、設定変更はサポートしていない可能性があります

### 2. 直接policy.jsonの編集

#### 2.1 policy.jsonの構造確認

```json
{
  "accessControlV2": {
    "rulebase": {
      "rateLimit": []  // 現在は空
    }
  }
}
```

#### 2.2 直接編集の試行

`policy.json`を直接編集してRateLimit設定を追加する方法を検討しましたが、以下の問題があります：

1. **ファイルの再生成**
   - OpenAppSec Agentは`local_policy.yaml`から`policy.json`を自動生成します
   - 直接編集した内容は、次回のポリシー再読み込み時に上書きされる可能性があります

2. **設定の整合性**
   - `policy.json`と`local_policy.yaml`の整合性が取れなくなる可能性があります

3. **推奨されない方法**
   - 公式ドキュメントでは、`policy.json`の直接編集は推奨されていません

### 3. accessControlV2/rulebase.jsonの編集

#### 3.1 ファイル構造の確認

```
/etc/cp/conf/accessControlV2/
  └── accessControlV2.policy  (存在するが、rulebase.jsonは存在しない)
```

#### 3.2 確認結果

- `accessControlV2/rulebase.json`は存在しません
- `accessControlV2.policy`は存在しますが、バイナリ形式の可能性があります

### 4. OpenAppSecソースコードのサンプル設定確認

#### 4.1 調査方法

OpenAppSecのソースコードリポジトリ内で、RateLimit設定のサンプルファイルを検索しました。

#### 4.2 確認結果

以下のサンプルファイルが見つかりました：

1. **`config/linux/v1beta2/example/local_policy.yaml`**
   - Linux環境用のサンプル設定
   - RateLimit設定の例が含まれている可能性

2. **`config/k8s/v1beta2/open-appsec-k8s-full-example-config-v1beta2.yaml`**
   - Kubernetes環境用のサンプル設定
   - RateLimit設定の例が含まれています

3. **`config/linux/v1beta2/prevent/local_policy.yaml`**
   - Preventモード用のサンプル設定

#### 4.3 サンプル設定の内容

Kubernetes用のサンプル設定から、以下の形式が確認できました：

```yaml
apiVersion: openappsec.io/v1beta2
kind: AccessControlPractice
metadata:
  name: access-control-practice-example
spec:
  practiceMode: inherited
  rateLimit:
    overrideMode: inherited
    rules:
    - action: prevent
      comment: Limiting access to the resource
      limit: 100
      triggers:
      - log-trigger-example
      unit: minute
      uri: /api/resource
```

**重要なポイント**: Kubernetes用の設定では、`triggers`フィールドが含まれていますが、Linux用のLocal Policy Fileでは`triggers`フィールドは不要の可能性があります。

### 5. 環境変数経由での設定

#### 5.1 確認方法

OpenAppSec Agentの環境変数を確認しました。

#### 5.2 確認結果

- RateLimit設定を環境変数で指定する方法は見つかりませんでした
- `OPENAPPSEC_LOG_LEVEL`などの環境変数は存在しますが、RateLimit関連はありません

### 6. SaaS管理UIの使用

#### 6.1 確認事項

- Community EditionではSaaS管理UIが利用できない可能性があります
- または、制限付きで利用できる可能性があります

#### 6.2 確認結果

- 現在の環境ではSaaS管理UIは使用していません
- `autoPolicyLoad=true`でローカル管理モードを使用しています

## 推奨されるアプローチ

### アプローチ1: OpenAppSecのサンプル設定と比較

#### 1.1 実施方法

1. OpenAppSecの公式サンプル設定ファイルを確認
2. 現在の設定と比較
3. 差異を特定して修正

#### 1.2 確認事項

- `apiVersion`が正しいか（`v1beta2`）
- `accessControlPractices`の構造が正しいか
- `rateLimit`の構造が正しいか
- 必須フィールドがすべて含まれているか

### アプローチ2: OpenAppSecのバージョン確認とアップグレード

#### 2.1 確認事項

- 現在のOpenAppSecバージョン
- 最新バージョンでのRateLimit設定のサポート状況
- 既知のバグや制限事項

#### 2.2 実施方法

1. 現在のバージョンを確認: `open-appsec-ctl --version` または `open-appsec-ctl --status`
2. 最新バージョンのリリースノートを確認
3. 必要に応じてアップグレードを検討

### アプローチ3: OpenAppSecコミュニティへの問い合わせ

#### 3.1 確認事項

- GitHub Issuesで同様の問題が報告されていないか
- コミュニティフォーラムでの解決方法
- 公式サポートへの問い合わせ

#### 3.2 実施方法

1. OpenAppSecのGitHubリポジトリでIssuesを検索
2. コミュニティフォーラムで質問
3. 必要に応じて公式サポートに問い合わせ

### アプローチ4: 一時的な回避策（直接policy.json編集）

#### 4.1 実施方法

1. `policy.json`を直接編集してRateLimit設定を追加
2. Agentを再起動して設定を反映
3. 注意: この方法は一時的な回避策であり、`local_policy.yaml`が更新されると上書きされる可能性があります

#### 4.2 リスク

- 設定の整合性が取れなくなる可能性
- ポリシー再読み込み時に設定が失われる可能性
- メンテナンスが困難

### アプローチ5: 設定形式の再確認

#### 5.1 実施方法

1. OpenAppSecの公式サンプル設定と現在の設定を比較
2. 必須フィールドの確認
3. オプションフィールドの確認
4. 設定形式の修正

#### 5.2 確認事項

- `apiVersion: v1beta2`が正しいか
- `policies.default.accessControlPractices`が正しく設定されているか
- `accessControlPractices`の`name`が`policies.default.accessControlPractices`と一致しているか
- `rateLimit.rules`の構造が正しいか

## 次のステップ

1. **OpenAppSecのサンプル設定を確認**
   - `config/linux/v1beta2/example/local_policy.yaml`を確認
   - 現在の設定と比較

2. **OpenAppSecのバージョンを確認**
   - 現在のバージョンと最新バージョンを比較
   - アップグレードの必要性を判断

3. **コミュニティリソースを確認**
   - GitHub Issues
   - コミュニティフォーラム
   - 公式ドキュメント

4. **一時的な回避策の検討**
   - 直接`policy.json`編集（非推奨）
   - または、RateLimit機能を一時的に無効化

## 参考資料

- OpenAppSec GitHub: https://github.com/openappsec/openappsec
- OpenAppSec公式ドキュメント: https://docs.openappsec.io/
- OpenAppSecコミュニティ: https://github.com/openappsec/openappsec/discussions
- サンプル設定ファイル:
  - `config/linux/v1beta2/example/local_policy.yaml`
  - `config/k8s/v1beta2/open-appsec-k8s-full-example-config-v1beta2.yaml`
