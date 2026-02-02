# GeoIP機能 アーキテクチャ設計書

## 1. 概要

### 1.1 目的
MaxMindDB GeoLite2-Countryデータベースを使用して、IP/CIDR範囲および国コードに基づくアクセス制御を実装する。

### 1.2 要件
- IP/CIDR範囲のAllow/Blockリスト
- 国コードベースのAllow/Blockリスト
- AllowList優先のロジック
- X-Forwarded-Forヘッダー対応（信頼できるプロキシ設定）
- FQDN別の細かい制御
- GeoIPデータベースの自動更新

### 1.3 制約条件
- Nginx `map`および`geo`ディレクティブは`http`コンテキストでのみ使用可能
- `server`コンテキストでは`if`ディレクティブと変数のみ使用可能
- FQDN別設定ファイル（`*.conf`）は`server`コンテキスト

## 2. アーキテクチャの選択肢

### 2.1 オプション1: 全FQDN共通のGeoIP設定（シンプル）

**構成**:
```
nginx.conf (http context)
├── geoip2 ディレクティブ（データベースロード）
├── geo ディレクティブ（IP判定）
├── map ディレクティブ（国コード判定）
└── include conf.d/*.conf (server context)
    └── if ディレクティブ（アクセス制御）
```

**メリット**:
- 実装が簡単
- 設定の見通しが良い
- nginx.confの変更が最小限

**デメリット**:
- FQDN別の細かい制御ができない
- すべてのFQDNで同じAllow/Blockリストを使用

### 2.2 オプション2: FQDN別のGeoIP設定（動的生成）

**構成**:
```
nginx.conf (http context) - ConfigAgentが動的生成
├── geoip2 ディレクティブ（データベースロード）
├── FQDN1用のgeo/mapディレクティブ
│   ├── geo $fqdn1_ip_allowed { ... }
│   └── map $geoip2_data_country_iso_code $fqdn1_country_blocked { ... }
├── FQDN2用のgeo/mapディレクティブ
│   ├── geo $fqdn2_ip_allowed { ... }
│   └── map $geoip2_data_country_iso_code $fqdn2_country_blocked { ... }
└── include conf.d/*.conf (server context)
    └── if ($fqdn1_ip_allowed) { ... }
```

**メリット**:
- FQDN別の細かい制御が可能
- APIからの設定を完全に反映できる
- スケーラブル

**デメリット**:
- nginx.conf全体を動的生成する必要がある
- 実装が複雑
- Nginxリロード頻度が増える

### 2.3 オプション3: ハイブリッドアプローチ（推奨）

**構成**:
```
nginx.conf (http context)
├── geoip2 ディレクティブ（データベースロード）
├── include geoip/*.conf（FQDN別GeoIP設定）
│   ├── test.example.com-geoip.conf
│   │   ├── geo $test_example_com_ip_allowed { ... }
│   │   └── map $geoip2_data_country_iso_code $test_example_com_country_blocked { ... }
│   └── example1.com-geoip.conf
│       ├── geo $example1_com_ip_allowed { ... }
│       └── map $geoip2_data_country_iso_code $example1_com_country_blocked { ... }
└── include conf.d/*.conf (server context)
    └── if ($test_example_com_ip_allowed) { ... }
```

**メリット**:
- FQDN別の細かい制御が可能
- nginx.confは静的（geoip/ディレクトリのincludeのみ）
- FQDN別GeoIP設定ファイルのみを動的生成
- 既存のFQDN設定ファイルは変更不要

**デメリット**:
- ConfigAgentで2種類のファイルを生成（FQDN設定 + GeoIP設定）
- 変数名の命名規則が必要（FQDNからサニタイズ）

## 3. 採用アーキテクチャ: オプション3（ハイブリッド）

### 3.1 ディレクトリ構成

```
/etc/nginx/
├── nginx.conf（静的、手動管理）
├── geoip/（ConfigAgentが動的生成）
│   ├── test.example.com-geoip.conf
│   ├── example1.com-geoip.conf
│   ├── example2.com-geoip.conf
│   └── example3.com-geoip.conf
└── conf.d/（ConfigAgentが動的生成）
    ├── test.example.com.conf
    ├── example1.com.conf
    ├── example2.com.conf
    └── example3.com.conf
```

### 3.2 nginx.confの修正（手動で1回のみ）

```nginx
http {
    # GeoIP2データベースのロード
    geoip2 /usr/share/GeoIP/GeoLite2-Country.mmdb {
        $geoip2_data_country_iso_code country iso_code;
        $geoip2_data_country_name country names en;
        $geoip2_data_continent_code continent code;
    }

    # FQDN別GeoIP設定を読み込み（ConfigAgentが動的生成）
    include /etc/nginx/geoip/*.conf;

    # FQDN別サーバー設定を読み込み（ConfigAgentが動的生成）
    include /etc/nginx/conf.d/*.conf;

    # ログフォーマット
    log_format json_combined escape=json
      '{'
        '"time":"$time_iso8601",'
        '"remote_addr":"$remote_addr",'
        '"host":"$host",'
        '"request":"$request",'
        '"status":$status,'
        '"body_bytes_sent":$body_bytes_sent,'
        '"request_time":$request_time,'
        '"customer_name":"$customer_name",'
        '"geoip_country_code":"$geoip2_data_country_iso_code",'
        '"geoip_country_name":"$geoip2_data_country_name",'
        '"geoip_continent_code":"$geoip2_data_continent_code"'
      '}';
}
```

### 3.3 GeoIP設定ファイルの生成（例: test.example.com-geoip.conf）

```nginx
# GeoIP設定: test.example.com
# 自動生成: 2026-02-02 15:00:00

# X-Forwarded-Forヘッダー処理（信頼できるプロキシ設定）
set_real_ip_from 192.168.0.0/16;
real_ip_header X-Forwarded-For;
real_ip_recursive on;

# IP/CIDR AllowList判定
geo $test_example_com_ip_allowed {
    default 0;
    192.168.1.0/24 1;
    10.0.0.0/8 1;
}

# IP/CIDR BlockList判定
geo $test_example_com_ip_blocked {
    default 0;
    198.51.100.0/24 1;
    203.0.113.0/24 1;
}

# 国コード AllowList判定
map $geoip2_data_country_iso_code $test_example_com_country_allowed {
    default 0;
    JP 1;
    US 1;
}

# 国コード BlockList判定
map $geoip2_data_country_iso_code $test_example_com_country_blocked {
    default 0;
    KP 1;
    RU 1;
}

# 最終的なアクセス許可判定（AllowList優先）
map "$test_example_com_ip_allowed:$test_example_com_ip_blocked:$test_example_com_country_allowed:$test_example_com_country_blocked" $test_example_com_access_denied {
    # AllowList優先（IP AllowListに一致したら常に許可）
    "~^1:" 0;  # IP AllowListに一致 → 許可
    
    # IP BlockListチェック
    "~^0:1:" 1;  # IP BlockListに一致 → 拒否
    
    # 国コード AllowListチェック（IP AllowList/BlockListに一致しない場合）
    "~^0:0:1:" 0;  # 国コード AllowListに一致 → 許可
    
    # 国コード BlockListチェック
    "~^0:0:0:1" 1;  # 国コード BlockListに一致 → 拒否
    
    # デフォルト（どのリストにも一致しない）
    default 0;  # 許可
}
```

### 3.4 FQDN設定ファイルでの使用（例: test.example.com.conf）

```nginx
server {
    listen 80;
    server_name test.example.com;

    set $customer_name "default";

    # GeoIPアクセス制御（geoip/test.example.com-geoip.confで定義された変数を使用）
    if ($test_example_com_access_denied = 1) {
        return 403;
    }

    # ログにGeoIP情報を含める
    access_log /var/log/nginx/test.example.com/access.log json_combined;
    error_log /var/log/nginx/test.example.com/error.log warn;

    location / {
        # GeoIP情報をバックエンドに転送
        proxy_set_header X-GeoIP-Country $geoip2_data_country_iso_code;
        proxy_set_header X-GeoIP-Continent $geoip2_data_continent_code;
        
        proxy_pass http://httpbin.org:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

## 4. 変数名の命名規則

### 4.1 FQDNのサニタイズ

FQDNをNginx変数名に変換する際のルール：
- `.` → `_`
- `-` → `_`
- 小文字に変換

例:
- `test.example.com` → `test_example_com`
- `api-v2.example.com` → `api_v2_example_com`

### 4.2 変数名のパターン

各FQDNごとに以下の変数を定義：

- `${fqdn_sanitized}_ip_allowed`: IP AllowList判定結果（0/1）
- `${fqdn_sanitized}_ip_blocked`: IP BlockList判定結果（0/1）
- `${fqdn_sanitized}_country_allowed`: 国コード AllowList判定結果（0/1）
- `${fqdn_sanitized}_country_blocked`: 国コード BlockList判定結果（0/1）
- `${fqdn_sanitized}_access_denied`: 最終的なアクセス拒否判定（0=許可、1=拒否）

## 5. ConfigAgentの実装変更

### 5.1 新しい関数

#### `sanitize_fqdn_for_variable()`
```bash
sanitize_fqdn_for_variable() {
    local fqdn="$1"
    echo "$fqdn" | tr '.-' '__' | tr '[:upper:]' '[:lower:]'
}
```

#### `generate_geoip_config_file()`
```bash
generate_geoip_config_file() {
    local fqdn="$1"
    local fqdn_config="$2"
    local output_dir="$3"
    
    local sanitized_fqdn
    sanitized_fqdn=$(sanitize_fqdn_for_variable "$fqdn")
    
    local geoip_file="${output_dir}/geoip/${fqdn}-geoip.conf"
    
    # GeoIP設定が有効かチェック
    local geoip_enabled
    geoip_enabled=$(echo "$fqdn_config" | jq -r '.geoip.enabled // false')
    
    if [[ "$geoip_enabled" != "true" ]]; then
        # GeoIP無効の場合、ファイルを削除（存在すれば）
        rm -f "$geoip_file"
        return 0
    fi
    
    # GeoIP設定ファイルを生成
    cat > "$geoip_file" << EOF
# GeoIP設定: ${fqdn}
# 自動生成: $(date '+%Y-%m-%d %H:%M:%S')

# X-Forwarded-Forヘッダー処理
$(generate_xff_config "$fqdn_config")

# IP/CIDR AllowList判定
geo \$${sanitized_fqdn}_ip_allowed {
    default 0;
$(generate_ip_allowlist "$fqdn_config")
}

# IP/CIDR BlockList判定
geo \$${sanitized_fqdn}_ip_blocked {
    default 0;
$(generate_ip_blocklist "$fqdn_config")
}

# 国コード AllowList判定
map \$geoip2_data_country_iso_code \$${sanitized_fqdn}_country_allowed {
    default 0;
$(generate_country_allowlist "$fqdn_config")
}

# 国コード BlockList判定
map \$geoip2_data_country_iso_code \$${sanitized_fqdn}_country_blocked {
    default 0;
$(generate_country_blocklist "$fqdn_config")
}

# 最終的なアクセス許可判定
$(generate_access_decision_logic "$sanitized_fqdn" "$fqdn_config")
EOF
}
```

#### `generate_fqdn_config_file()` の修正
```bash
generate_fqdn_config_file() {
    # ... 既存のコード ...
    
    local sanitized_fqdn
    sanitized_fqdn=$(sanitize_fqdn_for_variable "$fqdn")
    
    # GeoIPアクセス制御を追加
    local geoip_access_control=""
    if [[ "$geoip_enabled" == "true" ]]; then
        geoip_access_control="    # GeoIPアクセス制御
    if (\$${sanitized_fqdn}_access_denied = 1) {
        return 403;
    }"
    fi
    
    cat > "$config_file" << EOF
server {
    listen 80;
    server_name ${fqdn};
    
    set \$customer_name "${customer_name}";
    
${geoip_access_control}
    
    # ... 残りの設定 ...
}
EOF
}
```

### 5.2 ディレクトリ作成

```bash
# ConfigAgent起動時に geoip ディレクトリを作成
mkdir -p "${OUTPUT_DIR}/geoip"
mkdir -p "${OUTPUT_DIR}/conf.d"
```

### 5.3 処理フロー

1. API設定取得
2. 各FQDNに対して：
   - GeoIP設定ファイル生成（`geoip/${fqdn}-geoip.conf`）
   - FQDN設定ファイル生成（`conf.d/${fqdn}.conf`）
3. Nginx設定テスト（`nginx -t`）
4. Nginxリロード（`nginx -s reload`）

## 6. デプロイメント計画

### 6.1 フェーズ1: 基盤整備（現在完了）
- ✅ Docker統合（カスタムNginxイメージ、GeoIP Updater）
- ✅ GeoIPデータベース自動更新
- ✅ nginx.confにGeoIP2モジュール統合

### 6.2 フェーズ2: ConfigAgent拡張（次のステップ）
1. **nginx.confの手動修正**
   - `include /etc/nginx/geoip/*.conf;` 追加
   - `set_real_ip_from`のグローバル設定を削除（GeoIP設定ファイルに移動）

2. **ConfigAgentスクリプトの拡張**
   - `sanitize_fqdn_for_variable()` 実装
   - `generate_geoip_config_file()` 実装
   - `generate_fqdn_config_file()` 修正

3. **テスト**
   - モックAPI設定にGeoIP設定追加
   - ConfigAgent手動実行テスト
   - テストスクリプト実行

### 6.3 フェーズ3: 検証とドキュメント
1. 統合テスト
2. パフォーマンステスト
3. ドキュメント更新

## 7. テスト戦略

### 7.1 単体テスト
- FQDNサニタイズ関数のテスト
- GeoIP設定ファイル生成のテスト
- 変数名の一意性テスト

### 7.2 統合テスト
- 複数FQDNの同時設定
- IP/CIDR AllowList/BlockListの動作確認
- 国コード AllowList/BlockListの動作確認
- AllowList優先ロジックの確認
- X-Forwarded-For処理の確認

### 7.3 テストケース

| # | テスト内容 | 期待結果 |
|---|-----------|----------|
| 1 | IP AllowListに一致（他はすべてBlock） | 200 OK |
| 2 | IP BlockListに一致（AllowListなし） | 403 Forbidden |
| 3 | 国コード AllowListに一致 | 200 OK |
| 4 | 国コード BlockListに一致（AllowListなし） | 403 Forbidden |
| 5 | どのリストにも一致しない | 200 OK |
| 6 | IP AllowList + 国コード BlockList | 200 OK（AllowList優先）|
| 7 | X-Forwarded-For経由（信頼できるプロキシ） | 正しいIP判定 |

## 8. パフォーマンス考慮事項

### 8.1 Nginx変数の数
- 各FQDNごとに5個の変数を使用
- 100 FQDNの場合: 500変数
- Nginxは数千の変数を扱えるため問題なし

### 8.2 メモリ使用量
- GeoIPデータベース: 約5-10MB（メモリマップ）
- 変数: FQDN数に応じて増加（微小）
- 総メモリ増加: 100 FQDNで約15-20MB程度

### 8.3 リクエスト処理時間
- GeoIPルックアップ: < 1ms
- 変数評価: < 0.1ms
- 総オーバーヘッド: < 2ms（無視できるレベル）

## 9. セキュリティ考慮事項

### 9.1 入力検証
- FQDN名のサニタイズ（Nginx変数名として安全）
- IP/CIDR範囲の検証（Nginx起動時に自動検証）
- 国コードの検証（ISO 3166-1 alpha-2準拠）

### 9.2 DoS対策
- rate-limitと組み合わせ使用
- GeoIPによる国レベルのブロック
- 既知の悪意あるIPレンジのブロック

### 9.3 ログ記録
- すべてのアクセス制御決定をログに記録
- GeoIP情報をログに含める
- 監査証跡の確保

## 10. 運用手順

### 10.1 GeoIP設定の追加・変更
1. 管理APIのFQDN設定にGeoIP設定を追加
2. ConfigAgentが自動的に設定ファイルを生成
3. Nginxが自動的にリロード

### 10.2 緊急時の無効化
1. 管理APIで`geoip.enabled: false`に設定
2. ConfigAgentがGeoIP設定ファイルを削除
3. Nginxリロードでアクセス制御解除

### 10.3 トラブルシューティング
- Nginxエラーログ確認（`/var/log/nginx/error.log`）
- GeoIP設定ファイル確認（`/etc/nginx/geoip/*.conf`）
- ConfigAgentログ確認
- `nginx -t`で設定検証

## 11. まとめ

この設計により、以下を実現します：

1. ✅ **FQDN別の細かい制御**: 各FQDNごとに異なるGeoIP設定
2. ✅ **Nginx設定の制約を遵守**: `http`コンテキストで`map`/`geo`を使用
3. ✅ **動的設定生成**: ConfigAgentでGeoIP設定を自動生成
4. ✅ **最小限の変更**: nginx.confは1回のみ手動修正
5. ✅ **スケーラビリティ**: 多数のFQDNに対応可能
6. ✅ **保守性**: 設定ファイルが明確に分離

次のステップは、この設計に基づいてConfigAgentスクリプトを実装することです。
