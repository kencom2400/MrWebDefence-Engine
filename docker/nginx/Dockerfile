# OpenAppSec Nginx Attachment with GeoIP2 Module
# Base: OpenAppSec公式のNginxイメージ（Attachment Moduleが組み込まれている）
FROM ghcr.io/openappsec/nginx-attachment:latest AS builder

# メンテナンス情報
LABEL maintainer="MrWebDefence Team"
LABEL description="OpenAppSec Nginx with GeoIP2 Module"
LABEL version="1.0.0"

# 環境変数
ENV GEOIP2_MODULE_VERSION=3.4
ENV MAXMINDDB_VERSION=1.7.1

# 必要なパッケージのインストール（Alpine Linux用）
RUN apk add --no-cache \
    wget \
    ca-certificates \
    build-base \
    pcre-dev \
    zlib-dev \
    openssl-dev \
    git \
    autoconf \
    automake \
    libtool

# libmaxminddb、GeoIP2モジュール、Nginxのビルド（1つのRUNステップで実行）
RUN cd /tmp && \
    # libmaxminddbのビルドとインストール（/usrにインストール）
    wget https://github.com/maxmind/libmaxminddb/releases/download/${MAXMINDDB_VERSION}/libmaxminddb-${MAXMINDDB_VERSION}.tar.gz && \
    tar -xzf libmaxminddb-${MAXMINDDB_VERSION}.tar.gz && \
    cd libmaxminddb-${MAXMINDDB_VERSION} && \
    ./configure --prefix=/usr && \
    make && \
    make install && \
    cd /tmp && \
    rm -rf libmaxminddb-${MAXMINDDB_VERSION}* && \
    \
    # ngx_http_geoip2_moduleのダウンロード
    wget https://github.com/leev/ngx_http_geoip2_module/archive/${GEOIP2_MODULE_VERSION}.tar.gz && \
    tar -xzf ${GEOIP2_MODULE_VERSION}.tar.gz && \
    mv ngx_http_geoip2_module-${GEOIP2_MODULE_VERSION} /tmp/ngx_http_geoip2_module && \
    \
    # 実行中のNginxのバージョンとconfigureオプションを取得
    NGINX_VERSION=$(nginx -v 2>&1 | sed -n 's/.*nginx\/\([0-9.]*\).*/\1/p') && \
    echo "Detected Nginx version: ${NGINX_VERSION}" && \
    NGINX_CONFIGURE_ARGS=$(nginx -V 2>&1 | sed -n 's/configure arguments: \(.*\)/\1/p') && \
    echo "Detected Nginx configure args: ${NGINX_CONFIGURE_ARGS}" && \
    \
    # Nginxソースコードのダウンロード（検出されたバージョン）
    wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -xzf nginx-${NGINX_VERSION}.tar.gz && \
    \
    # 動的モジュールとしてngx_http_geoip2_moduleをビルド
    # 注意: 既存のNginxと同じconfigureオプションを使用
    cd /tmp/nginx-${NGINX_VERSION} && \
    ./configure ${NGINX_CONFIGURE_ARGS} --add-dynamic-module=/tmp/ngx_http_geoip2_module && \
    make modules && \
    cp objs/ngx_http_geoip2_module.so /usr/lib/nginx/modules/ && \
    \
    # クリーンアップ
    cd /tmp && \
    rm -rf nginx-* ${GEOIP2_MODULE_VERSION}.tar.gz && \
    apk del \
    build-base \
    wget \
    git \
    autoconf \
    automake \
    libtool

# GeoIPデータベース用ディレクトリの作成
RUN mkdir -p /usr/share/GeoIP && \
    chmod 755 /usr/share/GeoIP

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Nginxの起動
CMD ["nginx", "-g", "daemon off;"]
