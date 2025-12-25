#!/bin/bash

# Jira設定ファイル
# このファイルはJira操作スクリプト全般から参照されます

# Issueトラッカー設定
readonly ISSUE_TRACKER="jira"
export ISSUE_TRACKER

# Jira設定
readonly JIRA_PROJECT_KEY="MWD"
readonly JIRA_BASE_URL="https://kencom2400.atlassian.net"
export JIRA_PROJECT_KEY JIRA_BASE_URL

# 認証情報（環境変数またはconfig.local.shから取得）
# 注意: これらの値は環境変数またはconfig.local.shで設定する必要があります
# config.local.sh.exampleをコピーしてconfig.local.shを作成してください
readonly JIRA_EMAIL="${JIRA_EMAIL:-}"
readonly JIRA_API_TOKEN="${JIRA_API_TOKEN:-}"
export JIRA_EMAIL JIRA_API_TOKEN

# API Rate Limit対策
readonly API_RATE_LIMIT_WAIT="${API_RATE_LIMIT_WAIT:-1}"  # API rate limit対策の基本待機時間（秒）
export API_RATE_LIMIT_WAIT

# リトライ処理の設定
readonly MAX_RETRIES="${MAX_RETRIES:-5}"  # API反映待機のリトライ最大回数
readonly RETRY_INTERVAL="${RETRY_INTERVAL:-3}"  # リトライ間隔（秒）
export MAX_RETRIES RETRY_INTERVAL

