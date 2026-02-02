# OpenAppSec Nginx Attachment with GeoIP2 Module
# Base: OpenAppSec公式のNginxイメージ（Attachment Moduleが組み込まれている）
FROM ghcr.io/openappsec/nginx-attachment:latest

# メンテナンス情報
LABEL maintainer="MrWebDefence Team"
LABEL description="OpenAppSec Nginx with GeoIP2 Module"
LABEL version="1.0.0"

# 環境変数
ENV NGINX_VERSION=1.25.4
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

# libmaxminddbのビルドとインストール
RUN cd /tmp && \
    wget https://github.com/maxmind/libmaxminddb/releases/download/${MAXMINDDB_VERSION}/libmaxminddb-${MAXMINDDB_VERSION}.tar.gz && \
    tar -xzf libmaxminddb-${MAXMINDDB_VERSION}.tar.gz && \
    cd libmaxminddb-${MAXMINDDB_VERSION} && \
    ./configure && \
    make && \
    make install && \
    echo "/usr/local/lib" >> /etc/ld-musl-x86_64.path && \
    cd /tmp && \
    rm -rf libmaxminddb-${MAXMINDDB_VERSION}*

# ngx_http_geoip2_moduleのダウンロード
RUN cd /tmp && \
    wget https://github.com/leev/ngx_http_geoip2_module/archive/${GEOIP2_MODULE_VERSION}.tar.gz && \
    tar -xzf ${GEOIP2_MODULE_VERSION}.tar.gz && \
    mv ngx_http_geoip2_module-${GEOIP2_MODULE_VERSION} /tmp/ngx_http_geoip2_module

# Nginxソースコードのダウンロード
RUN cd /tmp && \
    wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -xzf nginx-${NGINX_VERSION}.tar.gz

# 動的モジュールとしてngx_http_geoip2_moduleをビルド
# 注意: 既存のNginxバイナリと同じ configure オプションを使用する必要がある
RUN cd /tmp/nginx-${NGINX_VERSION} && \
    # 既存のNginxのconfigureオプションを取得（nginx -Vで確認可能）
    ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --add-dynamic-module=/tmp/ngx_http_geoip2_module && \
    make modules && \
    cp objs/ngx_http_geoip2_module.so /usr/lib/nginx/modules/ && \
    cd /tmp && \
    rm -rf nginx-${NGINX_VERSION}*

# クリーンアップ
RUN apk del \
    build-base \
    wget \
    git \
    autoconf \
    automake \
    libtool \
    && rm -rf /tmp/*

# GeoIPデータベース用ディレクトリの作成
RUN mkdir -p /usr/share/GeoIP && \
    chmod 755 /usr/share/GeoIP

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Nginxの起動
CMD ["nginx", "-g", "daemon off;"]
