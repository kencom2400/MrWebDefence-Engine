# ConfigAgent用のカスタムDockerイメージ
# 依存パッケージをプリインストールして起動時間を短縮

FROM alpine:latest

# 依存パッケージをインストール
RUN apk add --no-cache \
    curl \
    jq \
    bash \
    docker-cli

# 作業ディレクトリを設定
WORKDIR /app/config-agent

# スクリプトをコピー（docker-compose.ymlでマウントする場合は不要）
# COPY . /app/config-agent

# 実行権限を付与
# RUN chmod +x /app/config-agent/config-agent.sh

# デフォルトコマンド
CMD ["./config-agent.sh"]
