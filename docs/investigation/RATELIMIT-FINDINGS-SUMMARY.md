# RateLimit設定読み込み処理 - 調査結果サマリー

## 実施日時
2026-01-28

## 調査内容

OpenAppSecのソースコードリポジトリ（https://github.com/openappsec/openappsec）をクローンし、RateLimit設定の読み込み処理を詳細に分析しました。

## 重要な発見

### 1. 処理フロー

```
local_policy.yaml
  ↓
yq eval (YAML → JSON変換)
  ↓
V1beta2AppsecLinuxPolicy::serialize()
  - parseAppsecJSONKey("accessControlPractices", ...)
  ↓
extractAnnotationsNames<NewParsedRule>()
  - parsed_rule.getAccessControlPractices()[0] または
  - default_rule.getAccessControlPractices()[0]
  - rule_annotation[ACCESS_CONTROL_PRACTICE] = "local_policy/rate-limit-default"
  ↓
createPolicyElementsByRule<V1beta2AppsecLinuxPolicy, NewParsedRule>()
  - createRateLimitSection() を常に呼び出し (1651行目)
  ↓
createRateLimitSection()
  - if (rule_annotations[ACCESS_CONTROL_PRACTICE].empty()) return;  ← 早期リターン
  - getAccessControlPracticeSpec("local_policy/rate-limit-default", policy)
  - extractElement() で "rate-limit-default" を検索
  - AccessControlPracticeSpec::getName() == "rate-limit-default" と比較
  - rate_limit[annotation_name] = RateLimitSection(...)
  ↓
convertMapToVector(rate_limit)
  ↓
SecurityAppsWrapper::save() → "accessControlV2"
  ↓
policy.json: accessControlV2.rulebase.rateLimit
```

### 2. 重要なコード箇所

#### 2.1 createRateLimitSection関数（1173行目）

```cpp
void createRateLimitSection(...)
{
    if (rule_annotations[AnnotationTypes::ACCESS_CONTROL_PRACTICE].empty()) {
        return;  // ← ここで早期リターン！
    }
    // ...
}
```

**重要なポイント**: `rule_annotations[ACCESS_CONTROL_PRACTICE]`が空の場合、RateLimitセクションは作成されません。

#### 2.2 extractAnnotationsNames<NewParsedRule>関数（286行目）

```cpp
string access_control_practice_name;
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
```

**重要なポイント**: 
- `parsed_rule`または`default_rule`の`accessControlPractices`から最初の要素を取得
- `policy_name + "/" + access_control_practice_name`の形式でアノテーション名を生成

#### 2.3 extractElement関数

```cpp
template<typename container_it>
container_it extractElement(container_it begin, container_it end, const string &element_name)
{
    string clean_element_name = element_name.substr(element_name.find("/") + 1);
    // "local_policy/rate-limit-default" → "rate-limit-default"
    for (container_it it = begin; it < end; it++) {
        if (clean_element_name == it->getName()) {
            return it;
        }
    }
    return end;  // 見つからない場合
}
```

**重要なポイント**: 
- アノテーション名から`/`以降の部分を抽出
- `AccessControlPracticeSpec::getName()`と比較

#### 2.4 getAccessControlPracticeSpec関数

```cpp
AccessControlPracticeSpec
getAccessControlPracticeSpec(const string &practice_annotation_name, const V1beta2AppsecLinuxPolicy &policy)
{
    auto practices_vec = policy.getAccessControlPracticeSpecs();
    auto practice_it = extractElement(practices_vec.begin(), practices_vec.end(), practice_annotation_name);

    if (practice_it == practices_vec.end()) {
        dbgTrace(D_NGINX_POLICY) << "Failed to retrieve Access control practice";
        return AccessControlPracticeSpec();  // ← 空のオブジェクトを返す
    }
    return *practice_it;
}
```

**重要なポイント**: 
- 見つからない場合、空の`AccessControlPracticeSpec()`を返す
- 空のオブジェクトの場合、`getRateLimit()`も空になる可能性

### 3. 現在の設定の確認

YAMLファイルをJSONに変換した結果：

```json
{
  "policies": {
    "default": {
      "accessControlPractices": ["rate-limit-default"]  // ✅ 設定されている
    },
    "specificRules": [
      {
        "host": "test.example.com",
        "accessControlPractices": ["rate-limit-default"]  // ✅ 設定されている
      }
    ]
  },
  "accessControlPractices": [
    {
      "name": "rate-limit-default"  // ✅ 定義されている
    }
  ]
}
```

設定は正しく設定されています。

### 4. 問題の可能性

#### 4.1 rule_annotations[ACCESS_CONTROL_PRACTICE]が空

`createRateLimitSection`関数は、`rule_annotations[ACCESS_CONTROL_PRACTICE]`が空の場合、早期リターンします。

これは以下の場合に発生する可能性があります：
1. `parsed_rule.getAccessControlPractices()`が空
2. `default_rule.getAccessControlPractices()`が空
3. `access_control_practice_name`が空

しかし、YAMLファイルでは`accessControlPractices: [rate-limit-default]`が設定されているため、これは問題ではないはずです。

#### 4.2 getAccessControlPracticeSpecが空のオブジェクトを返す

`extractElement`で見つからない場合、空の`AccessControlPracticeSpec()`が返されます。

これは以下の場合に発生する可能性があります：
1. `policy_name`が期待と異なる値（例: `"local_policy"`ではなく`""`）
2. `access_control_practices`が正しく読み込まれていない
3. `AccessControlPracticeSpec::getName()`が期待と異なる値

#### 4.3 policy_nameの取得方法

`policy_name`は通常、ファイル名から取得されます。`local_policy.yaml`の場合、`policy_name`は`"local_policy"`になるはずです。

しかし、実際の値が異なる可能性があります。

### 5. 次のステップ

1. **デバッグログの有効化**
   - OpenAppSecのデバッグログを有効化
   - `extractAnnotationsNames`での`access_control_practice_name`の値を確認
   - `createRateLimitSection`が呼び出されているか、早期リターンしているかを確認
   - `getAccessControlPracticeSpec`の戻り値を確認
   - `policy_name`の値を確認

2. **設定ファイルの検証**
   - `yq eval local_policy.yaml -o json`でJSON変換結果を確認
   - `accessControlPractices`が正しく変換されているか確認

3. **OpenAppSecのログを詳細に確認**
   - `"Failed to retrieve Access control practice"`のログを確認
   - `"Element with name ... was not found"`のログを確認

## 参考資料

- OpenAppSec GitHubリポジトリ: https://github.com/openappsec/openappsec
- 主要なファイル:
  - `components/security_apps/local_policy_mgmt_gen/policy_maker_utils.cc`
  - `components/security_apps/local_policy_mgmt_gen/access_control_practice.cc`
  - `components/security_apps/local_policy_mgmt_gen/new_appsec_linux_policy.cc`
  - `components/security_apps/rate_limit/rate_limit_config.cc`
