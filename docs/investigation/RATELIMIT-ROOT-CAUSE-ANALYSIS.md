# RateLimit設定が読み込まれない原因分析

## 実施日時
2026-01-28

## ソースコード分析結果

OpenAppSecのソースコードを分析した結果、以下の処理フローが判明しました。

### 処理フロー

1. **YAML → JSON変換**
   - `yq eval local_policy.yaml -o json`でYAMLをJSONに変換

2. **JSONパース**
   - `new_appsec_linux_policy.cc`: `V1beta2AppsecLinuxPolicy::serialize()`
   - `parseAppsecJSONKey<vector<AccessControlPracticeSpec>>("accessControlPractices", ...)`
   - `accessControlPractices`セクションを読み込み

3. **アノテーション名の抽出**
   - `policy_maker_utils.cc`: `extractAnnotationsNames<NewParsedRule>()`
   - `parsed_rule.getAccessControlPractices()[0]`または`default_rule.getAccessControlPractices()[0]`から取得
   - `rule_annotation[ACCESS_CONTROL_PRACTICE] = policy_name + "/" + access_control_practice_name`
   - 例: `"local_policy/rate-limit-default"`

4. **RateLimitセクションの作成**
   - `policy_maker_utils.cc`: `createPolicyElementsByRule<V1beta2AppsecLinuxPolicy, NewParsedRule>()`
   - **常に`createRateLimitSection()`が呼び出される**（1651行目）

5. **createRateLimitSection関数内の処理**
   ```cpp
   void createRateLimitSection(...)
   {
       if (rule_annotations[AnnotationTypes::ACCESS_CONTROL_PRACTICE].empty()) {
           return;  // ← ここで早期リターン！
       }
       // ...
   }
   ```

6. **AccessControlPracticeの取得**
   - `getAccessControlPracticeSpec(practice_annotation_name, policy)`
   - `extractElement()`で`access_control_practices`から検索
   - `element_name.substr(element_name.find("/") + 1)`で`/`以降を抽出（例: `"rate-limit-default"`）
   - `AccessControlPracticeSpec::getName()`と比較

7. **RateLimitルールの作成**
   - `access_control_practice.getRateLimit().createRateLimitRulesSection(trigger)`
   - `RateLimitSection`を作成して`rate_limit`マップに追加

8. **policy.jsonへの書き込み**
   - `convertMapToVector(rate_limit)`でマップからベクターに変換
   - `SecurityAppsWrapper::save()`で`"accessControlV2"`として保存

### 問題の原因

**`rule_annotations[AnnotationTypes::ACCESS_CONTROL_PRACTICE]`が空になっている可能性が高いです。**

これは以下の場合に発生します：

1. **`parsed_rule.getAccessControlPractices()`が空**
   - `policies.specificRules[].accessControlPractices`が空または未設定

2. **`default_rule.getAccessControlPractices()`が空**
   - `policies.default.accessControlPractices`が空または未設定

3. **`access_control_practice_name`が空**
   - 上記の両方が空の場合

### 現在の設定の確認

現在の`local_policy.yaml`では：

```yaml
policies:
  default:
    accessControlPractices: [rate-limit-default]  # ← 設定されている
  specificRules:
    - host: "test.example.com"
      accessControlPractices: [rate-limit-default]  # ← 設定されている

accessControlPractices:
  - name: rate-limit-default  # ← 定義されている
    rateLimit:
      overrideMode: prevent
      rules:
        - uri: "/"
          limit: 100
          unit: minute
          action: prevent
```

設定は正しいように見えますが、実際には読み込まれていません。

### 考えられる原因

1. **YAMLパースエラー**
   - `yq eval`での変換時にエラーが発生している可能性
   - しかし、`open-appsec-ctl --view-policy`では正しく表示されている

2. **JSONパースエラー**
   - `parseAppsecJSONKey`でのパース時にエラーが発生している可能性
   - エラーハンドリングで空の値が返されている可能性

3. **アノテーション名の不一致**
   - `policy_name`が期待と異なる値になっている可能性
   - `access_control_practice_name`が正しく取得できていない可能性

4. **AccessControlPracticeの検索失敗**
   - `getAccessControlPracticeSpec()`で`AccessControlPracticeSpec()`（空のオブジェクト）が返されている可能性
   - `extractElement()`で見つからない場合、空のオブジェクトが返される

### 次のステップ

1. **デバッグログの確認**
   - OpenAppSecのデバッグログを有効化
   - `extractAnnotationsNames`での`access_control_practice_name`の値を確認
   - `createRateLimitSection`が呼び出されているか、早期リターンしているかを確認
   - `getAccessControlPracticeSpec`の戻り値を確認

2. **設定ファイルの検証**
   - `yq eval local_policy.yaml -o json`でJSON変換結果を確認
   - `accessControlPractices`が正しく変換されているか確認

3. **policy_nameの確認**
   - `policy_name`が`"local_policy"`になっているか確認
   - ファイル名から取得されている可能性

## 参考資料

- OpenAppSec GitHubリポジトリ: https://github.com/openappsec/openappsec
- 主要なファイル:
  - `components/security_apps/local_policy_mgmt_gen/policy_maker_utils.cc` (1651行目: createRateLimitSection呼び出し)
  - `components/security_apps/local_policy_mgmt_gen/policy_maker_utils.cc` (1173行目: createRateLimitSection実装)
  - `components/security_apps/local_policy_mgmt_gen/policy_maker_utils.cc` (286行目: extractAnnotationsNames<NewParsedRule>)
  - `components/security_apps/local_policy_mgmt_gen/access_control_practice.cc` (237行目: AccessControlRateLimit::load)
