# RateLimit設定が読み込まれない問題 - 最終分析結果

## 実施日時
2026-01-28

## 調査のまとめ

### 1. 実施した調査

1. ✅ **OpenAppSec公式ドキュメントの確認**
   - Community Editionの制限を確認
   - 1つのルールのみサポートされていることを確認

2. ✅ **設定ファイルの確認**
   - `local_policy.yaml`は正しく設定されている
   - YAML → JSON変換も正常

3. ✅ **ソースコードの分析**
   - OpenAppSecのソースコードリポジトリをクローン
   - `createRateLimitSection`関数の処理フローを確認
   - `rule_annotations[ACCESS_CONTROL_PRACTICE]`が空の場合に早期リターンすることを確認

4. ✅ **デバッグログの有効化**
   - `D_LOCAL_POLICY=Debug`を設定
   - `D_LOCAL_POLICY=Trace`を設定
   - `D_RATE_LIMIT=Trace`を設定

### 2. 確認できたこと

#### 2.1 設定ファイル

```json
{
  "policy_name": "local_policy",
  "default_access_control": "rate-limit-default",
  "specific_rule_access_control": "rate-limit-default",
  "access_control_practice_name": "rate-limit-default",
  "expected_annotation": "local_policy/rate-limit-default",
  "rateLimit_overrideMode": "prevent",
  "rateLimit_rules_count": 1
}
```

設定は正しく設定されています。

#### 2.2 ポリシーファイルの更新

ログから、以下のポリシーファイルが正常に更新されていることが確認できました：

```
Successfully updated policy file. Policy name: accessControlV2
```

**重要なポイント**: `accessControlV2`ポリシーファイルは更新されていますが、内容が空の可能性があります。

#### 2.3 policy.jsonの状態

```json
{
  "accessControlV2": {
    "rulebase": {
      "rateLimit": []  // 空の配列
    }
  }
}
```

### 3. 確認できなかったこと

デバッグログに以下の情報が含まれていませんでした：

- `"Proccesing policy"`（policy_nameの取得）
- `"Creating policy elements"`（createPolicyElementsByRuleの呼び出し）
- `"extractAnnotationsNames"`（アノテーション名の抽出）
- `"createRateLimitSection"`（RateLimitセクションの作成）
- `"getAccessControlPracticeSpec"`（AccessControlPracticeの取得）
- `"Failed to retrieve Access control practice"`（取得失敗のログ）
- `"Element with name ... was not found"`（要素が見つからないログ）
- `"Loading Appsec V1Beta2 Linux Policy"`（YAMLパースの開始）
- `"Loading Access control"`（AccessControlPracticeの読み込み）

**重要なポイント**: これらのログが出力されていないということは、以下の可能性があります：

1. **デバッグフラグが正しく適用されていない**
   - `D_LOCAL_POLICY=Trace`が設定されているが、ログが出力されていない

2. **処理が実行されていない**
   - `createRateLimitSection`が呼び出されていない
   - または、早期リターンしている

3. **ログが別の場所に出力されている**
   - 別のログファイルに出力されている可能性
   - または、STDOUTに出力されているが、docker-compose logsで取得できていない

### 4. 問題の根本原因（推測）

ソースコードの分析結果から、以下の可能性が高いです：

1. **`rule_annotations[ACCESS_CONTROL_PRACTICE]`が空**
   - `extractAnnotationsNames<NewParsedRule>`関数で、`access_control_practice_name`が空になっている
   - その結果、`rule_annotation[ACCESS_CONTROL_PRACTICE]`が設定されない
   - `createRateLimitSection`関数で早期リターン

2. **`getAccessControlPracticeSpec`が空のオブジェクトを返す**
   - `extractElement`で`AccessControlPracticeSpec`が見つからない
   - 空の`AccessControlPracticeSpec()`が返される
   - `getRateLimit()`も空になる

3. **`policy_name`が期待と異なる値**
   - `policy_name`が`"local_policy"`ではなく、別の値（例: `""`）になっている可能性
   - その結果、アノテーション名が`"/rate-limit-default"`のようになり、`extractElement`で見つからない

### 5. 次のステップ

1. **`policy_name`の確認**
   - `getPolicyName()`関数がどのようにファイル名から取得しているか確認
   - 実際の`policy_name`の値を確認

2. **`extractAnnotationsNames`の動作確認**
   - `parsed_rule.getAccessControlPractices()`と`default_rule.getAccessControlPractices()`の値を確認
   - `access_control_practice_name`が正しく取得できているか確認

3. **`getAccessControlPracticeSpec`の動作確認**
   - `policy.getAccessControlPracticeSpecs()`の内容を確認
   - `extractElement`で正しく検索できているか確認

4. **OpenAppSecのサポートに問い合わせ**
   - Community EditionでのLocal Policy File経由のRateLimit設定がサポートされているか確認
   - 設定が読み込まれない原因を特定

## 参考資料

- OpenAppSec GitHubリポジトリ: https://github.com/openappsec/openappsec
- 主要なファイル:
  - `components/security_apps/local_policy_mgmt_gen/policy_maker_utils.cc`
  - `components/security_apps/local_policy_mgmt_gen/access_control_practice.cc`
  - `components/security_apps/local_policy_mgmt_gen/new_appsec_linux_policy.cc`
  - `components/security_apps/rate_limit/rate_limit_config.cc`
