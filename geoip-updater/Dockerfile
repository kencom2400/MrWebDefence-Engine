# GeoIP Updater Container
FROM alpine:latest

# メンテナンス情報
LABEL maintainer="MrWebDefence Team"
LABEL description="GeoIP Database Auto Updater"
LABEL version="1.0.0"

# 必要なパッケージのインストール
RUN apk add --no-cache \
    bash \
    curl \
    docker-cli \
    tzdata \
    && rm -rf /var/cache/apk/*

# タイムゾーン設定（JST）
ENV TZ=Asia/Tokyo

# 作業ディレクトリ
WORKDIR /app

# スクリプトとcron設定をコピー
COPY geoip-updater.sh /app/
COPY crontab /etc/crontabs/root

# 実行権限付与
RUN chmod +x /app/geoip-updater.sh

# ログディレクトリ作成
RUN mkdir -p /var/log && \
    touch /var/log/geoip-updater.log

# GeoIPデータベース用ディレクトリ作成
RUN mkdir -p /usr/share/GeoIP

# ヘルスチェック
HEALTHCHECK --interval=1h --timeout=10s --start-period=5s --retries=3 \
    CMD /app/geoip-updater.sh test || exit 1

# cronをフォアグラウンドで起動
CMD ["crond", "-f", "-l", "2"]
