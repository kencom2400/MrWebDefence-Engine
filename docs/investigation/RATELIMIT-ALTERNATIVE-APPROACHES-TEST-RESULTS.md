# RateLimit設定の別アプローチ - テスト結果

## 実施日時
2026-01-28

## テストしたアプローチ

### アプローチ1: practiceMode/overrideModeをinheritedに変更

#### 1.1 実施内容

OpenAppSecのサンプル設定では`practiceMode: inherited`、`overrideMode: inherited`を使用しているため、現在の設定（`prevent`）を`inherited`に変更してテストしました。

#### 1.2 テスト結果

- **結果**: RateLimit設定は依然として読み込まれませんでした
- `policy.json`の`accessControlV2.rulebase.rateLimit`は空の配列のまま

#### 1.3 結論

`practiceMode`や`overrideMode`の値は問題の原因ではない可能性が高いです。

### アプローチ2: 直接policy.jsonを編集

#### 2.1 実施内容

`policy.json`を直接編集してRateLimit設定を追加しました：

```json
{
  "accessControlV2": {
    "rulebase": {
      "rateLimit": [
        {
          "uri": "/",
          "limit": 100,
          "unit": "minute",
          "action": "prevent"
        }
      ]
    }
  }
}
```

#### 2.2 テスト結果

- **結果**: `policy.json`への直接編集は成功しました
- 設定は正しく反映されました
- ただし、Agentを再起動すると、`local_policy.yaml`から再生成される可能性があります

#### 2.3 動作確認

直接編集した`policy.json`でRateLimitが動作するか確認する必要があります。

#### 2.4 結論

直接`policy.json`を編集する方法は技術的には可能ですが、以下の問題があります：

1. **一時的な解決策**
   - `local_policy.yaml`が更新されると、設定が上書きされる可能性があります

2. **メンテナンス性**
   - 設定の整合性が取れなくなる可能性があります
   - 手動での編集が必要になります

3. **推奨されない方法**
   - 公式ドキュメントでは推奨されていません

## 重要な発見

### 1. OpenAppSecのサンプル設定との比較

#### 1.1 構造の比較

**現在の設定**:
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
```

**サンプル設定**:
```yaml
accessControlPractices:
  - name: access-control-practice-example
    practiceMode: inherited
    rateLimit:
      overrideMode: inherited
      rules: []  # 空の配列
```

#### 1.2 差異

1. **practiceMode/overrideMode**
   - 現在: `prevent`
   - サンプル: `inherited`
   - **結論**: この差異は問題の原因ではない（テスト結果から）

2. **rulesの内容**
   - 現在: ルールが定義されている
   - サンプル: 空の配列
   - **結論**: サンプルは空なので、実際の使用例ではない

### 2. OpenAppSecバージョン

- **現在のバージョン**: 1.1.32-open-source
- **要件**: Agent version 1.1.2以降が必要
- **結論**: バージョン要件は満たしています

### 3. 設定ファイルの構造

現在の設定ファイルの構造は正しく、以下の点で問題ありません：

- ✅ `apiVersion: v1beta2`
- ✅ `policies.default.accessControlPractices`が正しく設定されている
- ✅ `accessControlPractices`の`name`が`policies.default.accessControlPractices`と一致している
- ✅ `rateLimit.rules`の構造が正しい

## 推奨される次のステップ

### 1. 直接policy.json編集の動作確認

直接`policy.json`を編集した場合に、RateLimitが実際に動作するか確認します。

#### 1.1 実施方法

1. `policy.json`を直接編集してRateLimit設定を追加
2. Agentを再起動せずに、HTTPリクエストを送信
3. RateLimitが動作するか確認（100リクエスト/分を超えるとブロックされるか）

#### 1.2 確認事項

- RateLimitが実際に動作するか
- 設定がAgentの再起動後も維持されるか
- `local_policy.yaml`の更新時に設定が上書きされるか

### 2. OpenAppSecコミュニティへの問い合わせ

#### 2.1 実施方法

1. OpenAppSecのGitHubリポジトリでIssuesを検索
2. 同様の問題が報告されていないか確認
3. 必要に応じて新しいIssueを作成

#### 2.2 確認事項

- Community EditionでのLocal Policy File経由のRateLimit設定がサポートされているか
- 既知のバグや制限事項
- 推奨される設定方法

### 3. 一時的な回避策としての直接編集

#### 3.1 実施方法

1. `policy.json`を直接編集するスクリプトを作成
2. `local_policy.yaml`の更新後に自動的に`policy.json`を更新
3. 注意: これは一時的な回避策であり、根本的な解決策ではありません

#### 3.2 リスク

- 設定の整合性が取れなくなる可能性
- メンテナンスが困難
- 公式サポートの対象外になる可能性

## 結論

1. **Local Policy File経由での設定が読み込まれない問題は確認済み**
   - 設定ファイルの構造は正しい
   - YAML → JSON変換も正常
   - しかし、`policy.json`の`rateLimit`配列は空のまま

2. **直接policy.json編集は技術的に可能**
   - 設定は正しく反映される
   - ただし、一時的な回避策であり、推奨されない

3. **根本的な解決には追加の調査が必要**
   - OpenAppSecコミュニティへの問い合わせ
   - または、OpenAppSecのバージョンアップグレード

## 参考資料

- OpenAppSec GitHub: https://github.com/openappsec/openappsec
- OpenAppSec公式ドキュメント: https://docs.openappsec.io/
- サンプル設定ファイル: `/tmp/openappsec-source/config/linux/v1beta2/example/local_policy.yaml`
