## 📋 概要

[完成] OpenAppSec Issue #397 対応の安定化: Agent を 1.1.32 に固定し、ログレベルを info に戻す

## 🎯 関連Issue

- Related to [openappsec/openappsec#397](https://github.com/openappsec/openappsec/issues/397)（Policy sync fails with "Wrong number of parameters for 'assetId'" when using AccessControlPractice with empty or inactive rate limit rules）
- タスク: MWD-41（RateLimit 機能）

## 📊 変更内容

### Docker

- **OpenAppSec Agent イメージ**: `latest` から `1.1.32-open-source` に固定
  - Issue #397 により 1.1.33 等で Policy sync 失敗／RateLimit 未反映の報告があるため、解消まで固定
- **ログレベル**: `OPENAPPSEC_LOG_LEVEL` を `info` に戻し（デフォルト）、安定運用に統一

### ドキュメント

- **docs/investigation/OPENAPPSEC-ISSUE-397-RESPONSE.md**: Issue #397 に投稿するコメント案（環境・観察結果・当方の対応）を記載
- **docs/issues/OPENAPPSEC-UPGRADE-AFTER-397.md**: バグ解消確認後に OpenAppSec をバージョンアップするためのチケット定義

## ✅ 実装状況

- [x] docker-compose.yml の Agent バージョン固定
- [x] ログレベルを info に戻す
- [x] Issue #397 対応内容のドキュメント化
- [x] バグ解消後の対応チケット作成

## 📂 変更ファイル

### 新規作成（2 ファイル）

- `docs/investigation/OPENAPPSEC-ISSUE-397-RESPONSE.md`
- `docs/issues/OPENAPPSEC-UPGRADE-AFTER-397.md`

### 更新（1 ファイル）

- `docker/docker-compose.yml` - OpenAppSec Agent を 1.1.32-open-source に固定、OPENAPPSEC_LOG_LEVEL を info に

## 🔍 レビュー観点

### 重点確認項目

- [ ] `docker-compose.yml` の Agent イメージが `ghcr.io/openappsec/agent:1.1.32-open-source` になっていること
- [ ] Issue #397 解消後にバージョンアップする手順が `docs/issues/OPENAPPSEC-UPGRADE-AFTER-397.md` に記載されていること

### 注意点

- Issue #397 がクローズされ次第、`docs/issues/OPENAPPSEC-UPGRADE-AFTER-397.md` に従い Agent のバージョンアップを実施すること
- Issue #397 へのコメント投稿は手動で行う（内容は `docs/investigation/OPENAPPSEC-ISSUE-397-RESPONSE.md` を参照）

## 📝 備考

- 本 PR は「現状の安定化」が目的であり、RateLimit の機能追加や OpenAppSec 本体の修正は含みません。
