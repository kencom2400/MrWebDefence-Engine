# Fluentdカスタムイメージ
# 必要なプラグインをインストール

FROM fluent/fluentd:v1.16-debian-1

# 必要なプラグインをインストール
USER root
RUN fluent-gem install fluent-plugin-rewrite-tag-filter && \
    fluent-gem install fluent-plugin-out-file || \
    echo "Warning: fluent-plugin-out-file not found, will use file plugin instead"

USER fluent
