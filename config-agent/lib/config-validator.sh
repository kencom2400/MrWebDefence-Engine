#!/bin/bash

# 設定データ検証スクリプト
# 取得した設定データの妥当性を検証する機能を提供

set -e

# ログ出力関数（config-agent.shから呼び出される場合は、そちらの関数を使用）
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $*"
}

log_warning() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $*" >&2
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $*" >&2
}

# FQDN形式の検証
validate_fqdn_format() {
    local fqdn="$1"
    
    # 基本的なFQDN形式チェック
    # - 英数字、ハイフン、ドットを含む
    # - 先頭と末尾は英数字
    # - 長さは1-253文字
    if echo "$fqdn" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'; then
        local length=${#fqdn}
        if [ $length -gt 253 ]; then
            log_error "FQDNが長すぎます（最大253文字）: $fqdn"
            return 1
        fi
        return 0
    else
        log_error "無効なFQDN形式: $fqdn"
        return 1
    fi
}

# ポート番号の検証
validate_port() {
    local port="$1"
    
    # 数値チェック
    if ! echo "$port" | grep -qE '^[0-9]+$'; then
        log_error "ポート番号が数値ではありません: $port"
        return 1
    fi
    
    # 範囲チェック（1-65535）
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "ポート番号が範囲外です（1-65535）: $port"
        return 1
    fi
    
    return 0
}

# WAFモードの検証
validate_waf_mode() {
    local mode="$1"
    
    # 有効なモード値
    local valid_modes="detect-learn prevent prevent-learn detect"
    
    if echo "$valid_modes" | grep -qw "$mode"; then
        return 0
    else
        log_error "無効なWAFモード: $mode（有効な値: $valid_modes）"
        return 1
    fi
}

# カスタムレスポンスコードの検証
validate_custom_response() {
    local response_code="$1"
    
    # 数値チェック
    if ! echo "$response_code" | grep -qE '^[0-9]+$'; then
        log_error "カスタムレスポンスコードが数値ではありません: $response_code"
        return 1
    fi
    
    # HTTPステータスコードの範囲チェック（400-599）
    if [ "$response_code" -lt 400 ] || [ "$response_code" -gt 599 ]; then
        log_error "カスタムレスポンスコードが範囲外です（400-599）: $response_code"
        return 1
    fi
    
    return 0
}

# 設定データの検証
validate_config_data() {
    local config_data="$1"
    local validation_errors=0
    
    if [ -z "$config_data" ]; then
        log_error "設定データが空です"
        return 1
    fi
    
    # JSON形式の検証
    if ! echo "$config_data" | jq empty 2>/dev/null; then
        local json_error
        json_error=$(echo "$config_data" | jq . 2>&1 | head -5 || echo "JSONパースエラー")
        log_error "設定データが有効なJSON形式ではありません"
        log_error "JSONエラー詳細: $json_error"
        return 1
    fi
    
    # 必須フィールドの確認: version
    if ! echo "$config_data" | jq -e '.version' >/dev/null 2>&1; then
        log_error "必須フィールド 'version' が存在しません"
        validation_errors=$((validation_errors + 1))
    else
        local version
        version=$(echo "$config_data" | jq -r '.version')
        if [ -z "$version" ]; then
            log_error "バージョン番号が空です"
            validation_errors=$((validation_errors + 1))
        fi
    fi
    
    # 必須フィールドの確認: fqdns
    if ! echo "$config_data" | jq -e '.fqdns' >/dev/null 2>&1; then
        log_error "必須フィールド 'fqdns' が存在しません"
        validation_errors=$((validation_errors + 1))
    else
        # fqdnsが配列であることを確認
        if ! echo "$config_data" | jq -e '.fqdns | type == "array"' >/dev/null 2>&1; then
            log_error "'fqdns' は配列である必要があります"
            validation_errors=$((validation_errors + 1))
        else
            # 各FQDN設定の検証
            local fqdn_count
            fqdn_count=$(echo "$config_data" | jq '.fqdns | length')
            
            if [ "$fqdn_count" -eq 0 ]; then
                log_warning "FQDNリストが空です"
            else
                log_info "FQDN設定の検証を開始（${fqdn_count}件）..."
                
                local fqdn_index=0
                while [ $fqdn_index -lt $fqdn_count ]; do
                    local fqdn_config
                    fqdn_config=$(echo "$config_data" | jq -r ".fqdns[$fqdn_index]")
                    
                    # FQDNフィールドの確認
                    local fqdn
                    fqdn=$(echo "$fqdn_config" | jq -r '.fqdn // empty')
                    if [ -z "$fqdn" ]; then
                        log_error "FQDN設定[$fqdn_index]: 'fqdn' フィールドが存在しません"
                        validation_errors=$((validation_errors + 1))
                    else
                        # FQDN形式の検証
                        if ! validate_fqdn_format "$fqdn"; then
                            validation_errors=$((validation_errors + 1))
                        fi
                    fi
                    
                    # is_activeフィールドの確認（オプション、デフォルトはtrue）
                    local is_active
                    is_active=$(echo "$fqdn_config" | jq -r '.is_active // true')
                    if [ "$is_active" != "true" ] && [ "$is_active" != "false" ]; then
                        log_error "FQDN設定[$fqdn_index] ($fqdn): 'is_active' は true または false である必要があります"
                        validation_errors=$((validation_errors + 1))
                    fi
                    
                    # アクティブなFQDNのみ、追加の検証を実行
                    if [ "$is_active" = "true" ]; then
                        # waf_modeの検証（オプション）
                        local waf_mode
                        waf_mode=$(echo "$fqdn_config" | jq -r '.waf_mode // "detect-learn"')
                        if ! validate_waf_mode "$waf_mode"; then
                            validation_errors=$((validation_errors + 1))
                        fi
                        
                        # custom_responseの検証（オプション）
                        local custom_response
                        custom_response=$(echo "$fqdn_config" | jq -r '.custom_response // 403')
                        if ! validate_custom_response "$custom_response"; then
                            validation_errors=$((validation_errors + 1))
                        fi
                        
                        # backend_hostの検証（オプション）
                        local backend_host
                        backend_host=$(echo "$fqdn_config" | jq -r '.backend_host // empty')
                        if [ -n "$backend_host" ]; then
                            # backend_hostはFQDNまたはIPアドレスの形式
                            if ! echo "$backend_host" | grep -qE '^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})$'; then
                                log_error "FQDN設定[$fqdn_index] ($fqdn): 無効なbackend_host形式: $backend_host"
                                validation_errors=$((validation_errors + 1))
                            fi
                        fi
                        
                        # backend_portの検証（オプション）
                        local backend_port
                        backend_port=$(echo "$fqdn_config" | jq -r '.backend_port // 80')
                        if ! validate_port "$backend_port"; then
                            log_error "FQDN設定[$fqdn_index] ($fqdn): 無効なbackend_port"
                            validation_errors=$((validation_errors + 1))
                        fi
                    fi
                    
                    fqdn_index=$((fqdn_index + 1))
                done
            fi
        fi
    fi
    
    # default_modeの検証（オプション）
    local default_mode
    default_mode=$(echo "$config_data" | jq -r '.default_mode // "detect-learn"')
    if ! validate_waf_mode "$default_mode"; then
        validation_errors=$((validation_errors + 1))
    fi
    
    # default_custom_responseの検証（オプション）
    local default_custom_response
    default_custom_response=$(echo "$config_data" | jq -r '.default_custom_response // 403')
    if ! validate_custom_response "$default_custom_response"; then
        validation_errors=$((validation_errors + 1))
    fi
    
    # アクティブなFQDNの存在確認
    local active_fqdn_count
    active_fqdn_count=$(echo "$config_data" | jq '[.fqdns[]? | select(.is_active == true)] | length')
    if [ "$active_fqdn_count" -eq 0 ]; then
        log_warning "アクティブなFQDNが存在しません"
    else
        log_info "アクティブなFQDN: ${active_fqdn_count}件"
    fi
    
    # 検証結果の返却
    if [ $validation_errors -eq 0 ]; then
        log_info "設定データの検証が完了しました（エラーなし）"
        return 0
    else
        log_error "設定データの検証で ${validation_errors} 件のエラーが検出されました"
        return 1
    fi
}

# メイン関数（config-agent.shから呼び出される）
main() {
    # この関数はconfig-agent.shで定義されているため、ここでは定義しない
    # このファイルはライブラリとして使用される
    :
}
