FROM certbot/certbot:v2.8.0

# 必要なパッケージをインストール
RUN apk add --no-cache \
    bash \
    docker-cli \
    tzdata

# タイムゾーン設定（JST）
ENV TZ=Asia/Tokyo

# スクリプトをコピー
COPY certbot-manager.sh /app/certbot-manager.sh
COPY crontab /etc/crontabs/root

# 実行権限を付与
RUN chmod +x /app/certbot-manager.sh

# crondをフォアグラウンドで実行
CMD ["crond", "-f", "-l", "2"]
