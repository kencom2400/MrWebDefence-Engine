# Fluentdカスタムイメージ
# 必要なプラグインをインストール

FROM fluent/fluentd:v1.16-debian-1

# 必要なプラグインをインストール
USER root
RUN fluent-gem install fluent-plugin-rewrite-tag-filter
USER fluent
