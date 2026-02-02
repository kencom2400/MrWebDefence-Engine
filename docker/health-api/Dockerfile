FROM python:3-alpine

WORKDIR /app

# 必要なパッケージをインストール
RUN apk add --no-cache \
    bash \
    docker-cli \
    docker-compose \
    curl \
    jq

# ヘルスチェックAPIサーバーをコピー
COPY health-api-server.py /app/health-api-server.py
RUN chmod +x /app/health-api-server.py

# ヘルスチェックスクリプトは実行時にマウント
# /app/scriptsにマウントされることを想定

EXPOSE 8888

CMD ["python3", "/app/health-api-server.py"]
