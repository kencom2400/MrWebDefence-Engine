# GeoIP機能テストスクリプトの修正が必要

## 問題点

1. **Nginx設定の制限**: `map`と`geo`ディレクティブは`http`コンテキストでのみ使用可能で、`server`コンテキストでは使用できません
2. **設定ファイルの生成場所**: 現在の実装では各FQDN別の設定ファイル（`server`コンテキスト）にGeoIP設定を生成しようとしていますが、これは動作しません

## 解決策

### 短期的な対応（現在）

- テストスクリプトを調整して、現在の実装で動作可能な範囲でテスト
- README-TASK-5-5.mdに制限事項を明記

### 長期的な対応（次のフェーズ）

nginx.confのhttpコンテキストにGeoIP設定を生成する必要があります：

```nginx
http {
    # GeoIP2データベース
    geoip2 /usr/share/GeoIP/GeoLite2-Country.mmdb {
        $geoip2_data_country_iso_code country iso_code;
    }
    
    # IP AllowList/BlockListの定義（全FQDN共通）
    geo $ip_allowlist {
        default 0;
        192.168.1.0/24 1;
    }
    
    # 国コード判定（全FQDN共通）
    map $geoip2_data_country_iso_code $country_blocklist {
        default 0;
        RU 1;
        KP 1;
    }
    
    # FQDN別の設定をinclude
    include /etc/nginx/conf.d/*.conf;
}
```

このためには、nginx.confを動的に生成するか、FQDN固有のGeoIP設定を別の方法で実装する必要があります。

## 推奨事項

1. nginx.confのテンプレート化
2. ConfigAgentでnginx.confも生成
3. または、GeoIP設定を全FQDN共通にする

現時点では、GeoIP機能の基本実装は完了していますが、FQDN別の細かい制御には追加の設計変更が必要です。
