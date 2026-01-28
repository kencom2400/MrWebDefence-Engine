# RateLimit設定読み込み処理 - ソースコード分析結果

## 実施日時
2026-01-28

## 調査内容

OpenAppSecのソースコードリポジトリ（https://github.com/openappsec/openappsec）をクローンし、RateLimit設定の読み込み処理を分析しました。

## 重要な発見

### 1. 主要なファイル

1. **`components/security_apps/local_policy_mgmt_gen/access_control_practice.cc`**
   - `accessControlPractices`のYAMLからJSONへの変換処理
   - `AccessControlRateLimit::load()`: RateLimit設定の読み込み
   - `AccessControlRateLimiteRules::load()`: RateLimitルールの読み込み

2. **`components/security_apps/local_policy_mgmt_gen/policy_maker_utils.cc`**
   - `createRateLimitSection()`: RateLimitセクションの作成
   - `getAccessControlPracticeSpec()`: AccessControlPracticeの取得
   - `convertMapToVector(rate_limit)`: RateLimitマップからベクターへの変換

3. **`components/security_apps/rate_limit/rate_limit_config.cc`**
   - RateLimit設定の実際の処理ロジック

### 2. 処理フロー

```
local_policy.yaml
  ↓
YAML → JSON変換 (yq eval)
  ↓
new_appsec_linux_policy.cc: parseMandatoryAppsecJSONKey("accessControlPractices", ...)
  ↓
access_control_practice.cc: AccessControlPracticeSpec::load()
  ↓
access_control_practice.cc: AccessControlRateLimit::load()
  ↓
access_control_practice.cc: AccessControlRateLimiteRules::load() (各ルール)
  ↓
policy_maker_utils.cc: extractAnnotationsNames() → rule_annotations[ACCESS_CONTROL_PRACTICE]
  ↓
policy_maker_utils.cc: createRateLimitSection() (rule_annotations[ACCESS_CONTROL_PRACTICE]が空でない場合のみ)
  ↓
policy_maker_utils.cc: convertMapToVector(rate_limit)
  ↓
policy_maker_utils.cc: SecurityAppsWrapper::save() → "accessControlV2"
  ↓
policy.json: accessControlV2.rulebase.rateLimit
```

### 3. 重要なコード

#### 3.1 createRateLimitSection関数

```cpp
void
PolicyMakerUtils::createRateLimitSection(
    const string &asset_name,
    const string &url,
    const string &uri,
    const string &trigger_id,
    const std::string &default_mode,
    const V1beta2AppsecLinuxPolicy &policy,
    map<AnnotationTypes, string> &rule_annotations)
{
    if (rule_annotations[AnnotationTypes::ACCESS_CONTROL_PRACTICE].empty()) {
        return;  // ← ここで早期リターン！
    }
    // ...
}
```

**重要なポイント**: `rule_annotations[AnnotationTypes::ACCESS_CONTROL_PRACTICE]`が空の場合、RateLimitセクションは作成されません。

#### 3.2 extractAnnotationsNames関数

```cpp
map<AnnotationTypes, string>
extractAnnotationsNames(...)
{
    // ...
    string access_control_practice_name;
    // TBD: support multiple practices
    if (!parsed_rule.getAccessControlPractices().empty() && 
        !parsed_rule.getAccessControlPractices()[0].empty()) {
        access_control_practice_name = parsed_rule.getAccessControlPractices()[0];
    } else if (!default_rule.getAccessControlPractices().empty() &&
               !default_rule.getAccessControlPractices()[0].empty()) {
        access_control_practice_name = default_rule.getAccessControlPractices()[0];
    }

    if (!access_control_practice_name.empty()) {
        rule_annotation[AnnotationTypes::ACCESS_CONTROL_PRACTICE] = 
            policy_name + "/" + access_control_practice_name;
    }
    // ...
}
```

**重要なポイント**: 
- `parsed_rule.getAccessControlPractices()`から最初の要素を取得
- `default_rule.getAccessControlPractices()`から取得（ルールに指定がない場合）
- `policy_name + "/" + access_control_practice_name`の形式でアノテーション名を生成

#### 3.3 AccessControlRateLimit::load関数

```cpp
void
AccessControlRateLimit::load(cereal::JSONInputArchive &archive_in)
{
    dbgTrace(D_LOCAL_POLICY) << "Loading Access control rate limit";
    parseMandatoryAppsecJSONKey<string>("overrideMode", mode, archive_in, "inactive");
    if (valid_modes.find(mode) == valid_modes.end()) {
        dbgWarning(D_LOCAL_POLICY) << "AppSec access control rate limit override mode invalid: " << mode;
        throw PolicyGenException("AppSec access control rate limit override mode invalid: " + mode);
    }
    parseAppsecJSONKey<std::vector<AccessControlRateLimiteRules>>("rules", rules, archive_in);
}
```

**重要なポイント**: 
- `overrideMode`のデフォルト値は`"inactive"`
- `rules`はオプショナル（`parseAppsecJSONKey`を使用）

### 4. 問題の可能性

#### 4.1 rule_annotations[ACCESS_CONTROL_PRACTICE]が空

`createRateLimitSection`関数は、`rule_annotations[AnnotationTypes::ACCESS_CONTROL_PRACTICE]`が空の場合、早期リターンします。

これは以下の場合に発生する可能性があります：
1. `parsed_rule.getAccessControlPractices()`が空
2. `default_rule.getAccessControlPractices()`が空
3. `access_control_practice_name`が空

#### 4.2 overrideModeが"inactive"

`AccessControlRateLimit::load()`のデフォルト値は`"inactive"`です。しかし、現在の設定では`overrideMode: prevent`を明示的に指定しているため、これは問題ではないはずです。

#### 4.3 rulesが空

`parseAppsecJSONKey`はオプショナルなので、`rules`が空でもエラーにはなりません。しかし、現在の設定では`rules`に1つのルールを定義しているため、これは問題ではないはずです。

### 5. 次のステップ

1. **ログの確認**
   - `createRateLimitSection`が呼び出されているか
   - `rule_annotations[ACCESS_CONTROL_PRACTICE]`の値
   - `getAccessControlPracticeSpec`の戻り値

2. **設定の確認**
   - `local_policy.yaml`の`accessControlPractices`が正しく読み込まれているか
   - `policies.default.accessControlPractices`と`policies.specificRules[].accessControlPractices`の両方が設定されているか

3. **デバッグログの有効化**
   - OpenAppSecのデバッグログを有効にして、詳細な処理フローを確認

## 参考資料

- OpenAppSec GitHubリポジトリ: https://github.com/openappsec/openappsec
- RateLimitコンポーネント: https://github.com/openappsec/openappsec/tree/main/components/security_apps/rate_limit
- Local Policy Management Generator: https://github.com/openappsec/openappsec/tree/main/components/security_apps/local_policy_mgmt_gen
