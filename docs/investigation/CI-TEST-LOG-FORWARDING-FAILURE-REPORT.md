# CI「Test Log Forwarding」失敗 状況確認報告

## 概要

- **ワークフロー**: `.github/workflows/test-log-forwarding.yml`（Test Log Forwarding）
- **トリガー**: `main` / `develop` への push、またはそれらへの Pull Request（対象 path 変更時）
- **確認日**: 本ドキュメント作成時点で GitHub API からの実行結果取得はタイムアウトのため、コード解析に基づく原因の切り分けを行う。

---

## 修正済み: OpenAppSec Agent イメージが存在しない（ローカル・CI 共通）

### 事象

- `scripts/openappsec/test-log-forwarding.sh` 実行時、ステップ 1「必要なサービスの起動」で失敗。
- エラー: `ghcr.io/openappsec/agent:1.1.32-open-source: not found`

### 原因

- `docker-compose.yml` で指定していた `ghcr.io/openappsec/agent:1.1.32-open-source` が GHCR に存在しない。

### 対応（実施済み）

- `docker-compose.yml` の OpenAppSec Agent イメージを以下に変更した。
  - **変更前**: `image: ghcr.io/openappsec/agent:1.1.32-open-source`
  - **変更後**: `image: ${OPENAPPSEC_AGENT_IMAGE:-ghcr.io/openappsec/agent:latest}`
- デフォルトで `latest` を使用し、必要に応じて `OPENAPPSEC_AGENT_IMAGE` でタグを上書き可能にした。
- 上記のうえで `scripts/openappsec/test-log-forwarding.sh` をローカル実行し、**全ステップ成功・exit 0** を確認した。

---

## 失敗し得る箇所（コード解析）

テストスクリプト `scripts/openappsec/test-log-forwarding.sh` で **exit 1** または **ERROR_COUNT 増加** により失敗する箇所は以下のとおり。

| # | ステップ | 条件 | 結果 |
|---|----------|------|------|
| 1 | 起動前 | `docker-compose` / `docker compose` が無い | exit 1 |
| 2 | 1. サービスの起動（非CI時のみ） | `docker-compose up -d` が失敗 | exit 1 |
| 3 | 2. Fluentd 状態 | Fluentd コンテナが Up/running でない | exit 1 |
| 4 | 3. Fluentd 設定 | `./fluentd/fluent.conf` が無い | exit 1 |
| 5 | **5. ログ生成テスト** | **いずれかの FQDN で `/health` の curl が失敗** | **increment_error → 末尾で exit 1** |
| 6 | **6. Nginx ログ JSON 確認** | **access.log の最終行が JSON でない** | **increment_error → 末尾で exit 1** |
| 7 | 末尾 | ERROR_COUNT > 0 | exit 1 |

CI ではステップ 0/1 をスキップするため、**実質の候補は 5 と 6**。

---

## 想定原因

### A. ステップ 5: ヘルスチェック失敗（いずれかの FQDN）

- **内容**: `curl -s -m 5 -H "Host: ${fqdn}" http://localhost/health` が失敗（非 0 終了）。
- **要因候補**:
  - 対象 FQDN の server がまだ listen していない（起動直後のタイミング）。
  - 一時的な負荷やネットワークで 5 秒以内に応答が返らない。
- **補足**: ワークフロー側の「Wait for services to be healthy」は **test.example.com** のみ。他 FQDN（example1/2/3.com）は未検証のため、CI ではここで初めて叩かれる。

### B. ステップ 6: Nginx アクセスログが JSON でない / 未書き込み

- **内容**: `access.log` が存在し、最終行があるが、`jq empty` でパースできない。
- **要因候補**:
  1. **バッファ未フラッシュ**: Nginx の `access_log` はバッファリングされる。ステップ 5 の直後 3 秒待機では、CI 環境によってはまだディスクに出ていない可能性。
  2. **ログが `/health` のみ**: 各 vhost で `location /health` は `access_log off` のため、**`/health` だけのアクセスでは access.log に 1 行も書かれない**。ステップ 5 では `/health` と `/` の両方を叩くが、`/` は `proxy_pass http://httpbin.org` のため、外部通信が失敗・遅延するとログが書かれない、または遅延する。
  3. **最終行が不完全**: 書き込み途中の行を `tail -n 1` で読むと非 JSON になり得る（レア）。

---

## 設定の整理

- **Nginx**: 各 FQDN で `access_log ... json_combined`、`/health` は `access_log off`。
- **ステップ 5**: 各 FQDN で `/health`（ログなし）と `/`（httpbin へプロキシ、ログあり）を実行。
- **ステップ 6**: `./nginx/logs/${fqdn}/access.log` の最終行が JSON かどうかを検証。

---

## 推奨アクション

### 1. 実失敗箇所の特定（推奨）

以下を共有いただくと原因を特定しやすいです。

- GitHub Actions の「Run log forwarding test」ステップの**標準出力全体**（どの FQDN で「ヘルスチェック: 失敗」や「JSON形式のログではありません」が出ているか）。
- 失敗時の「Collect logs on failure」の内容（Nginx / Fluentd / OpenAppSec のログ末尾）。

### 2. コード側の耐障害化（実施推奨）

- **ステップ 5**: ヘルスチェックを 1 回失敗時はリトライする（例: 最大 2 回、間隔 2 秒）。CI 専用でも可。
- **ステップ 6**:  
  - ログ書き込み待ちを CI 時は 5 秒に延長。  
  - 最終行が JSON でない場合、2 秒待って 1 回だけ再取得・再検証し、それでもダメなときだけ `increment_error` とする。

上記を入れたうえで再度 push し、CI の結果を確認することを推奨する。

---

## 参照

- ワークフロー: `.github/workflows/test-log-forwarding.yml`
- テストスクリプト: `scripts/openappsec/test-log-forwarding.sh`
- Nginx 設定例: `docker/nginx/conf.d/test.example.com.conf`（`access_log off` は `/health` のみ）
