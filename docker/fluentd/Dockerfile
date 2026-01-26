# Fluentdカスタムイメージ
# 必要なプラグインをインストール

FROM fluent/fluentd:v1.16-debian-1

# 必要なプラグインをインストール
USER root
RUN fluent-gem install fluent-plugin-rewrite-tag-filter && \
    fluent-gem install fluent-plugin-out-file || \
    echo "Warning: fluent-plugin-out-file not found, will use file plugin instead"

# OpenAppSec FQDN別ログ出力用ディレクトリを作成
# 注意: コンテナ起動時にfileプラグインの設定検証が行われるため、
# 検証用のダミーディレクトリを事前に作成しておく必要がある
RUN mkdir -p /var/log/nano_agent && \
    chown -R fluent:fluent /var/log/nano_agent && \
    chmod -R 755 /var/log/nano_agent

USER fluent
