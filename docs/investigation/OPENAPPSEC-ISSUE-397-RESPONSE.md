# OpenAppSec GitHub Issue #397 への対応内容

## 参照

- **Issue**: [Policy sync fails with "Wrong number of parameters for 'assetId'" when using AccessControlPractice with empty or inactive rate limit rules](https://github.com/openappsec/openappsec/issues/397)
- **日付**: 2026-01-30

---

## Issue #397 に投稿するコメント（英語）

以下を [Issue #397](https://github.com/openappsec/openappsec/issues/397) のコメント欄に貼り付けて投稿してください。

```markdown
### Environment (additional report)

- **Deployment**: Docker Compose (standalone), Local Policy File (v1beta2)
- **open-appsec version**: 1.1.32-open-source (pinned to avoid regression)
- **OS**: Linux (Docker host)

### Observation

We use an AccessControlPractice with **non-empty** rate limit rules in `local_policy.yaml`:

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

Policy sync completes without the "Wrong number of parameters for 'assetId'" error, but the generated `policy.json` has **empty** `accessControlV2.rulebase.rateLimit` (`[]`). So rate limiting does not take effect even though the YAML is valid.

This may be a related code path (e.g. same policy generator producing empty/invalid context for rateLimit in our setup). We have pinned the agent image to `1.1.32-open-source` until this issue is resolved and will upgrade once a fix is released.

### Actions taken on our side

- Pinned image to `ghcr.io/openappsec/agent:1.1.32-open-source` for stable behavior.
- Documented this issue and created an internal follow-up task to upgrade OpenAppSec when the fix is available.

Thanks for tracking this.
```

---

## Issue #397 に投稿するコメント（日本語・参考用）

```markdown
### 環境（追加報告）

- **デプロイ**: Docker Compose（スタンドアロン）、Local Policy File（v1beta2）
- **open-appsec バージョン**: 1.1.32-open-source（リグレッション回避のため固定）
- **OS**: Linux（Docker ホスト）

### 観察結果

`local_policy.yaml` で、**空でない** RateLimit ルールを持つ AccessControlPractice を使用しています。

（上記英語の YAML スニペットと同様）

ポリシー同期は「Wrong number of parameters for 'assetId'」エラーなく完了しますが、生成される `policy.json` の `accessControlV2.rulebase.rateLimit` は **空**（`[]`）のままです。このため、YAML は有効でもレート制限が効いていません。

同一のポリシー生成処理で、当方の環境では rateLimit が空になる／コンテキストが不正になる別経路の可能性があります。本件が解消されるまで Agent イメージを `1.1.32-open-source` に固定し、修正リリース後にバージョンアップする予定です。

### 当方での対応

- 安定動作のためイメージを `ghcr.io/openappsec/agent:1.1.32-open-source` に固定。
- 本 Issue をドキュメント化し、修正版が出た際のバージョンアップ用のフォローアップチケットを自社で作成済みです。
```

---

## 本リポジトリでの対応まとめ

| 項目 | 内容 |
|------|------|
| **docker-compose.yml** | OpenAppSec Agent イメージを `1.1.32-open-source` に固定、ログレベルを `info` に戻す |
| **Issue #397** | 上記コメントを GitHub に投稿（環境・観察結果・対応の共有） |
| **フォローアップ** | バグ解消確認後に実施する「OpenAppSec バージョンアップ」チケットを作成済み（`docs/issues/OPENAPPSEC-UPGRADE-AFTER-397.md`） |
