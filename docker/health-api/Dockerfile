FROM python:3-alpine

WORKDIR /app

# 必要なパッケージをインストール
# docker-cliパッケージがdockerグループを作成する
RUN apk add --no-cache \
    bash \
    docker-cli \
    docker-compose \
    curl \
    jq

# セキュリティ向上のため、非rootユーザーを作成
# Dockerソケットへのアクセスが必要なため、dockerグループを作成してappuserを追加
# 注意: ホストのdockerグループGID（通常999）とコンテナのdockerグループGIDを一致させる必要がある
# docker.sockのグループIDを確認して、それに合わせてdockerグループを作成
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup && \
    addgroup docker && \
    addgroup appuser docker

# ヘルスチェックAPIサーバーをコピー
COPY --chown=appuser:appgroup health-api-server.py /app/health-api-server.py
RUN chmod +x /app/health-api-server.py

# ヘルスチェックスクリプトは実行時にマウント
# /app/scriptsにマウントされることを想定

# 非rootユーザーとして実行
USER appuser

EXPOSE 8888

CMD ["python3", "/app/health-api-server.py"]
