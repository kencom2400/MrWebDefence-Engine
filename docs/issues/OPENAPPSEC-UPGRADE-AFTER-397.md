# チケット: OpenAppSec バージョンアップ（Issue #397 解消後）

## 概要

OpenAppSec GitHub [Issue #397](https://github.com/openappsec/openappsec/issues/397)（AccessControlPractice / rateLimit の `assetId` バグ）が解消されたことを確認したうえで、OpenAppSec Agent のバージョンを上げる。

## 前提

- **現状**: Agent イメージを `ghcr.io/openappsec/agent:1.1.32-open-source` に固定している（`docker/docker-compose.yml`）。
- **理由**: Issue #397 により、1.1.33 等で Policy sync が失敗する、または Local Policy File で RateLimit が反映されない事象が報告されているため。

## 受け入れ条件

- [ ] Issue #397 がクローズされている（または修正がリリースされている）。
- [ ] 修正を含む OpenAppSec のバージョン（例: 1.1.34 以降）を特定している。
- [ ] 当リポジトリの Docker 構成で、そのバージョンの Agent イメージを指定している。
- [ ] `local_policy.yaml` の AccessControlPractice（rateLimit ルールあり）でポリシー同期が成功することを確認している。
- [ ] `policy.json` の `accessControlV2.rulebase.rateLimit` にルールが入ることを確認している。
- [ ] （任意）レート制限の動作確認（例: 制限超過で 403 等）を実施している。
- [ ] 変更内容をドキュメント（実装設計・調査メモ等）に反映している。

## 実施内容（案）

1. **Issue #397 の解消確認**
   - GitHub の Issue #397 のステータス・コメントを確認。
   - 修正が含まれるバージョンを確認（CHANGELOG / リリースタグ等）。

2. **docker-compose.yml の更新**
   - `image: ghcr.io/openappsec/agent:1.1.32-open-source` を、修正済みバージョン（例: `1.1.34-open-source` や `latest`）に変更。
   - 変更理由をコメントで記載（「Issue #397 解消のため」等）。

3. **動作確認**
   - `docker-compose up -d` で起動。
   - `open-appsec-ctl --status` 等でポリシー読み込み成功を確認。
   - `policy.json` 内の `accessControlV2.rulebase.rateLimit` に期待どおりのルールが入っていることを確認。
   - （任意）RateLimit の挙動テスト。

4. **ドキュメント更新**
   - `docs/investigation/OPENAPPSEC-ISSUE-397-RESPONSE.md` や MWD-41 関連ドキュメントに「#397 解消後、バージョン X.Y.Z にアップグレード済み」を追記。

## 関連

- **Jira**: [MWD-110](https://kencom2400.atlassian.net/browse/MWD-110)（本チケット）
- **OpenAppSec Issue**: https://github.com/openappsec/openappsec/issues/397
- **現状の固定バージョン**: 1.1.32-open-source（`docker/docker-compose.yml`）
- **Epic**: MWD-41（RateLimit 機能）

## Jira チケット

- **作成済み**: [MWD-110](https://kencom2400.atlassian.net/browse/MWD-110)（OpenAppSec バージョンアップ（Issue #397 解消後））

同内容で Jira にタスクを再作成する場合のコマンド例（**前提**: `scripts/jira/config.local.sh` に `JIRA_EMAIL` と `JIRA_API_TOKEN` を設定済みであること）:

```bash
./scripts/jira/issues/create-issue.sh \
  --title "OpenAppSec バージョンアップ（Issue #397 解消後）" \
  --body-file docs/issues/OPENAPPSEC-UPGRADE-AFTER-397-jira-body.txt \
  --issue-type タスク \
  --status Backlog \
  --project-key MWD \
  --parent MWD-41
```

- **Epic MWD-41** に紐づくタスクとして作成される（`--parent MWD-41`）。プロジェクトの Issue 種別が日本語の場合は `--issue-type タスク` を指定する。
- 本文は `docs/issues/OPENAPPSEC-UPGRADE-AFTER-397-jira-body.txt` を参照。

## 備考

- 解消確認は、Issue のクローズまたはリリースノートで「#397 を修正」と明記されていることをもって行う。
- 本チケットは「バグ解消の確認ができたら対応する」ためのものであり、#397 が未解消の間は実施しない。
