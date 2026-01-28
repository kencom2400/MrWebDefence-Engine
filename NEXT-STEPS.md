# 次のステップ: ファイルパスからのFQDN抽出機能

**作成日時**: 2026-01-24  
**実装タスク**: Task 5.3 - ログ転送機能実装  
**現在の状態**: 実装完了、動作確認中

---

## 1. 現在の状態

### 1.1 実装状況 ✅

- [x] `path_key source_path`の追加（`nginx-access.conf`, `nginx-error.conf`）
- [x] FQDN抽出ロジックの実装（`nginx-access-process.conf`, `nginx-error-process.conf`）
- [x] フォールバック機能の実装
- [x] 設定ファイルの構文確認
- [x] pos_fileの生成確認（ログ監視の開始）

### 1.2 現在の問題 ⚠️

**Fluentdコンテナの再起動**
- 状態: `Restarting (137)`
- 影響: リアルタイムでのログ処理が不安定
- pos_fileは存在しているため、ログ監視は開始されている

---

## 2. 次のステップ

### ステップ1: Fluentdコンテナの再起動原因を特定 🔴 優先度高

#### 2.1.1 エラーログの確認

```bash
cd docker
docker-compose logs fluentd --tail=100 | grep -E "error|Error|ERROR|fatal|Fatal"
```

**確認項目**:
- 設定ファイルの構文エラー
- プラグインのエラー
- リソース不足（メモリ、CPU）
- ファイルアクセス権限の問題

#### 2.1.2 コンテナの詳細状態確認

```bash
docker-compose ps fluentd
docker inspect mwd-fluentd | grep -A 10 "State"
```

**確認項目**:
- 終了コード（137は通常SIGKILLによる強制終了）
- 再起動回数
- リソース使用量

#### 2.1.3 設定ファイルの構文チェック

```bash
docker-compose exec fluentd fluentd --dry-run -c /fluentd/etc/fluent.conf
```

**確認項目**:
- 構文エラーの有無
- プラグインの読み込みエラー

### ステップ2: Fluentdコンテナの安定化 🟡 優先度中

#### 2.2.1 問題の修正

**想定される原因と対応**:

1. **メモリ不足**
   - 対応: Docker Composeでメモリ制限を調整
   - 設定例:
     ```yaml
     fluentd:
       deploy:
         resources:
           limits:
             memory: 512M
     ```

2. **設定ファイルのエラー**
   - 対応: エラーログを確認し、該当箇所を修正

3. **プラグインの不整合**
   - 対応: Fluentdイメージの再ビルド
   ```bash
   cd docker
   docker-compose build fluentd
   docker-compose up -d fluentd
   ```

4. **ファイルアクセス権限**
   - 対応: ボリュームマウントの権限を確認
   ```bash
   ls -la docker/fluentd/log/
   ls -la docker/nginx/logs/
   ```

#### 2.2.2 コンテナの再起動

```bash
cd docker
docker-compose restart fluentd
# または
docker-compose down fluentd
docker-compose up -d fluentd
```

### ステップ3: 実際のログ処理でのFQDN抽出確認 🟢 優先度中

#### 2.3.1 テストリクエストの送信

```bash
# 各FQDNにテストリクエストを送信
for fqdn in test.example.com example1.com example2.com example3.com; do
  curl -H "Host: $fqdn" http://localhost/
  sleep 1
done
```

#### 2.3.2 Fluentdの出力ログを確認

```bash
cd docker
docker-compose logs fluentd --tail=50 | grep "nginx.access"
```

**確認項目**:
- `source_path`フィールドが含まれているか
- `fqdn`フィールドが正しく抽出されているか
- 各FQDNで正しいFQDNが抽出されているか

#### 2.3.3 ログレコードの検証

**期待される出力形式**:
```json
{
  "time": "2026-01-24T12:00:00+00:00",
  "remote_addr": "192.168.1.1",
  "request": "GET / HTTP/1.1",
  "status": 200,
  "host": "test.example.com",
  "customer_name": "default",
  "source_path": "/var/log/nginx/test.example.com/access.log",
  "log_type": "nginx",
  "hostname": "waf-engine-01",
  "fqdn": "test.example.com",
  "year": "2026",
  "month": "01",
  "day": "24",
  "hour": "12",
  "minute": "00",
  "second": "00"
}
```

**検証コマンド**:
```bash
# Fluentdの出力からsource_pathとfqdnを抽出
docker-compose logs fluentd | grep "nginx.access" | tail -1 | \
  jq -r 'select(.source_path != null) | "FQDN: \(.fqdn), Source: \(.source_path)"'
```

### ステップ4: エラーログでのFQDN抽出確認 🟢 優先度低

#### 2.4.1 エラーログの生成

```bash
# 意図的にエラーを発生させる（例: 存在しないパスへのアクセス）
curl -H "Host: test.example.com" http://localhost/nonexistent
```

#### 2.4.2 エラーログの確認

```bash
cd docker
docker-compose logs fluentd --tail=50 | grep "nginx.error"
```

**確認項目**:
- エラーログでも`source_path`フィールドが含まれているか
- エラーログでも`fqdn`フィールドが正しく抽出されているか

### ステップ5: 全FQDNでの動作確認 🟢 優先度低

#### 2.5.1 各FQDNでのテスト

```bash
# 各FQDNに複数のリクエストを送信
for fqdn in test.example.com example1.com example2.com example3.com; do
  echo "Testing $fqdn"
  for i in {1..5}; do
    curl -H "Host: $fqdn" http://localhost/ > /dev/null
    sleep 0.5
  done
done
```

#### 2.5.2 各FQDNのログを確認

```bash
# 各FQDNのログファイルを確認
for fqdn in test.example.com example1.com example2.com example3.com; do
  echo "=== $fqdn ==="
  tail -1 docker/nginx/logs/$fqdn/access.log | jq -r '.host'
done
```

#### 2.5.3 Fluentdの出力で各FQDNを確認

```bash
# Fluentdの出力から各FQDNを抽出
docker-compose logs fluentd | grep "nginx.access" | \
  jq -r 'select(.fqdn != null) | .fqdn' | sort | uniq -c
```

---

## 3. 検証チェックリスト

### 3.1 基本動作確認

- [ ] Fluentdコンテナが安定起動している
- [ ] pos_fileが正常に更新されている
- [ ] ログファイルが正常に生成されている

### 3.2 FQDN抽出機能の確認

- [ ] `source_path`フィールドがレコードに含まれている
- [ ] `fqdn`フィールドが正しく抽出されている
- [ ] ファイルパスからFQDNが正しく抽出されている
- [ ] フォールバック機能が正常に動作している（`source_path`がない場合）

### 3.3 全FQDNでの動作確認

- [ ] `test.example.com`でFQDN抽出が正常
- [ ] `example1.com`でFQDN抽出が正常
- [ ] `example2.com`でFQDN抽出が正常
- [ ] `example3.com`でFQDN抽出が正常

### 3.4 エラーログでの動作確認

- [ ] エラーログでも`source_path`が含まれている
- [ ] エラーログでも`fqdn`が正しく抽出されている

---

## 4. トラブルシューティング

### 4.1 Fluentdコンテナが起動しない場合

**確認項目**:
1. 設定ファイルの構文エラー
2. プラグインのインストール状況
3. ファイルアクセス権限
4. リソース不足

**対応方法**:
```bash
# 設定ファイルの構文チェック
docker-compose exec fluentd fluentd --dry-run -c /fluentd/etc/fluent.conf

# コンテナのログを確認
docker-compose logs fluentd

# コンテナを再ビルド
docker-compose build fluentd
docker-compose up -d fluentd
```

### 4.2 FQDNが抽出されない場合

**確認項目**:
1. `path_key source_path`が正しく設定されているか
2. ファイルパスの形式が正しいか（`/var/log/nginx/{FQDN}/access.log`）
3. `record_transformer`のRuby式が正しいか

**対応方法**:
```bash
# Fluentdの出力を確認
docker-compose logs fluentd | grep "source_path"

# 設定ファイルを確認
cat docker/fluentd/in.d/nginx-access.conf
cat docker/fluentd/process.d/nginx-access-process.conf
```

### 4.3 ログが処理されない場合

**確認項目**:
1. pos_fileが存在しているか
2. ログファイルが正しいパスに存在するか
3. Fluentdがログファイルを読み取れる権限があるか

**対応方法**:
```bash
# pos_fileの確認
ls -la docker/fluentd/log/*.pos

# ログファイルの確認
ls -la docker/nginx/logs/*/access.log

# ファイルアクセス権限の確認
docker-compose exec fluentd ls -la /var/log/nginx/
```

---

## 5. 完了条件

以下のすべての条件が満たされた場合、実装は完了とみなします：

1. ✅ Fluentdコンテナが安定起動している
2. ✅ すべてのFQDNでログファイルが正常に生成されている
3. ✅ Fluentdの出力ログに`source_path`フィールドが含まれている
4. ✅ Fluentdの出力ログに`fqdn`フィールドが正しく抽出されている
5. ✅ ファイルパスからFQDNが正しく抽出されている
6. ✅ エラーログでもFQDN抽出が正常に動作している

---

## 6. 参考情報

### 6.1 関連ファイル

- `docker/fluentd/in.d/nginx-access.conf`: アクセスログ収集設定
- `docker/fluentd/in.d/nginx-error.conf`: エラーログ収集設定
- `docker/fluentd/process.d/nginx-access-process.conf`: アクセスログ処理設定
- `docker/fluentd/process.d/nginx-error-process.conf`: エラーログ処理設定

### 6.2 関連ドキュメント

- `TEST-REPORT-FQDN-EXTRACTION.md`: テストレポート
- `FINAL-VERIFICATION-REPORT.md`: 最終検証レポート

### 6.3 実装の詳細

**FQDN抽出ロジック**:
```ruby
fqdn ${(record["source_path"] && File.dirname(record["source_path"]).split('/').last) || record["fqdn"] || record["host"] || record["hostname"] || "unknown"}
```

**優先順位**:
1. `source_path`から抽出（最優先）
2. レコードの`fqdn`フィールド
3. レコードの`host`フィールド
4. レコードの`hostname`フィールド
5. デフォルト値: `"unknown"`

---

**ドキュメント作成者**: AI Assistant  
**最終更新**: 2026-01-24  
**ステータス**: 実装完了、動作確認中
