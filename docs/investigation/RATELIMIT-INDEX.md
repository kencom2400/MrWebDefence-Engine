# RateLimit 関連調査ドキュメント 索引

RateLimit 機能（MWD-41 / PR #46）に関する調査ドキュメントの一覧と読み方です。

## 推奨読む順序

1. **概要・結論**  
   - [RATELIMIT-FINDINGS-SUMMARY.md](./RATELIMIT-FINDINGS-SUMMARY.md) — 処理フローと重要な発見のサマリー  
   - [RATELIMIT-FINAL-ANALYSIS.md](./RATELIMIT-FINAL-ANALYSIS.md) — 最終分析と確認できたこと

2. **原因分析**  
   - [RATELIMIT-ROOT-CAUSE-ANALYSIS.md](./RATELIMIT-ROOT-CAUSE-ANALYSIS.md) — 読み込まれない原因の整理  
   - [RATELIMIT-SOURCE-CODE-ANALYSIS.md](./RATELIMIT-SOURCE-CODE-ANALYSIS.md) — OpenAppSec ソースコード上の根拠

3. **検証・代替案**  
   - [RATELIMIT-LOADING-INVESTIGATION.md](./RATELIMIT-LOADING-INVESTIGATION.md) — 読み込み処理の調査  
   - [RATELIMIT-DEBUG-LOG-ANALYSIS.md](./RATELIMIT-DEBUG-LOG-ANALYSIS.md) — デバッグログの分析  
   - [RATELIMIT-ALTERNATIVE-APPROACHES.md](./RATELIMIT-ALTERNATIVE-APPROACHES.md) — REST API / policy.json 直接編集などの代替案  
   - [RATELIMIT-ALTERNATIVE-APPROACHES-TEST-RESULTS.md](./RATELIMIT-ALTERNATIVE-APPROACHES-TEST-RESULTS.md) — 代替案のテスト結果

4. **関連**  
   - [OPENAPPSEC-COMMUNITY-EDITION-LIMITATIONS.md](./OPENAPPSEC-COMMUNITY-EDITION-LIMITATIONS.md) — Community Edition の制限  
   - [OPENAPPSEC-ISSUE-397-RESPONSE.md](./OPENAPPSEC-ISSUE-397-RESPONSE.md) — GitHub Issue #397 への対応方針  
   - [PR46-GEMINI-REVIEW-SUMMARY.md](./PR46-GEMINI-REVIEW-SUMMARY.md) — PR #46 の Gemini Code Assist レビュー要約

## 結論の要約

- **現象**: `local_policy.yaml` に RateLimit を定義しても、Agent の `policy.json` の `accessControlV2.rulebase.rateLimit` が空のままになることがある。
- **想定原因**: OpenAppSec 側で `rule_annotations[ACCESS_CONTROL_PRACTICE]` が空のときに `createRateLimitSection` が早期リターンしており、その状態になっている可能性が高い。
- **対応**: Issue #397 の動向を追い、必要に応じて Agent バージョンアップや設定見直しを行う。現状のポリシー（`config-agent/lib/policy-generator.sh`）は `uri: "/"`, `limit: 100`, `action: prevent` の 1 ルールに統一済み。

## 更新履歴

- 2026-01: 索引作成。上記ファイルは個別に維持し、この索引で参照を集約。
