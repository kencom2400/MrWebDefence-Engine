# RateLimit設定デバッグログ分析結果

## 実施日時
2026-01-28

## デバッグログの有効化

### 1. ログレベルの変更

`docker-compose.yml`で`OPENAPPSEC_LOG_LEVEL`を`debug`に変更しました。

### 2. デバッグフラグの設定

```bash
open-appsec-ctl --debug --set STDOUT --service orchestration --flags "D_LOCAL_POLICY=Debug"
```

### 3. ログファイルの確認

- `/var/log/nano_agent/cp-nano-orchestration.dbg`: Orchestrationサービスのデバッグログ
- `/var/log/nano_agent/cp-nano-http-transaction-handler.dbg1`: HTTP Transaction Handlerのデバッグログ

## ログ分析結果

### 1. ポリシーファイルの更新

ログから以下のポリシーファイルが正常に更新されていることが確認できました：

```
Successfully updated policy file. Policy name: accessControlV2
Successfully updated policy file. Policy name: exceptions
Successfully updated policy file. Policy name: fileSecurity
Successfully updated policy file. Policy name: ips
Successfully updated policy file. Policy name: rules
Successfully updated policy file. Policy name: snort
Successfully updated policy file. Policy name: triggers
Successfully updated policy file. Policy name: waap
```

**重要なポイント**: `accessControlV2`ポリシーファイルは正常に更新されていますが、内容が空の可能性があります。

### 2. 設定ファイルの確認

YAMLファイルをJSONに変換した結果：

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

### 3. ログに含まれていない情報

以下の情報がログに含まれていませんでした：

- `"Proccesing policy"`（policy_nameの取得）
- `"Creating policy elements"`（createPolicyElementsByRuleの呼び出し）
- `"extractAnnotationsNames"`（アノテーション名の抽出）
- `"createRateLimitSection"`（RateLimitセクションの作成）
- `"getAccessControlPracticeSpec"`（AccessControlPracticeの取得）
- `"Failed to retrieve Access control practice"`（取得失敗のログ）
- `"Element with name ... was not found"`（要素が見つからないログ）

**重要なポイント**: これらのログが出力されていないということは、以下の可能性があります：

1. **デバッグフラグが正しく設定されていない**
   - `D_LOCAL_POLICY=Debug`が正しく適用されていない可能性

2. **ログレベルが不十分**
   - `Trace`レベルが必要な可能性

3. **ログが別のファイルに出力されている**
   - 別のログファイルに出力されている可能性

4. **処理が実行されていない**
   - `createRateLimitSection`が呼び出されていない可能性
   - または、早期リターンしている可能性

### 4. 次のステップ

1. **デバッグフラグの確認**
   - `open-appsec-ctl --debug --show --service orchestration`で現在の設定を確認
   - 利用可能なフラグとレベルを確認

2. **ログレベルの変更**
   - `D_LOCAL_POLICY=Trace`に変更（利用可能な場合）
   - または、`D_ALL=Trace`で全てのログを有効化

3. **別のログファイルの確認**
   - 他のログファイル（例: `cp-nano-local-policy-mgmt-gen.dbg`）を確認

4. **ポリシーの再読み込み**
   - デバッグフラグを設定した後、ポリシーを再読み込み
   - 新しいログを確認

## 参考資料

- OpenAppSecデバッグコマンド: `open-appsec-ctl --debug`
- ログファイル: `/var/log/nano_agent/cp-nano-orchestration.dbg`
- デバッグフラグ: `D_LOCAL_POLICY`, `D_NGINX_POLICY`
