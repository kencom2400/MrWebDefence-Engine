# OpenAppSec公式ドキュメントまとめ

## ドキュメントURL

- **メインページ**: https://docs.openappsec.io/getting-started/getting-started
- **Docker統合**: https://docs.openappsec.io/getting-started/start-with-docker
- **Linux統合**: https://docs.openappsec.io/getting-started/start-with-linux
- **Kubernetes統合**: https://docs.openappsec.io/getting-started/start-with-kubernetes

## 概要

OpenAppSecは、機械学習ベースのWeb Application Firewall (WAF) です。Nginx、Kubernetes、Dockerなどの環境で動作し、自動的な脅威検出と防御を提供します。

## 主要な概念

### 1. Agent（エージェント）

- OpenAppSecのコアコンポーネント
- 機械学習モデルによる脅威検出を実行
- 複数のデプロイメントモードをサポート（Linux、Docker、Kubernetes）

### 2. Attachment Module（アタッチメントモジュール）

- Nginxなどのリバースプロキシと統合するためのモジュール
- HTTP(S)トラフィックをインターセプトしてAgentに送信
- Agentからの判定結果を受信して適用

### 3. Management Portal（管理ポータル）

- Web UI（SaaS）による集中管理
- ローカルポリシーファイルによる管理も可能

## デプロイメント方法

### Docker統合

#### 必要なコンポーネント

1. **Nginx Attachment Module**
   - イメージ: `ghcr.io/openappsec/nginx-attachment:latest`
   - NginxにAttachment Moduleが組み込まれたイメージ

2. **OpenAppSec Agent**
   - イメージ: `ghcr.io/openappsec/agent:latest`
   - WAFエンジン本体

#### 設定方法

1. **Nginx設定**
   ```nginx
   load_module /usr/lib/nginx/modules/ngx_cp_attachment_module.so;
   ```

2. **共有メモリ設定**
   - Docker Composeで`ipc: host`を使用するか、共有tmpfsボリュームを使用
   - `/dev/shm`をマウントしてコンテナ間で共有

3. **Agent設定**
   - 環境変数で設定
   - ローカルポリシーファイル（`local_policy.yaml`）を使用

#### Docker Compose例

```yaml
services:
  nginx:
    image: ghcr.io/openappsec/nginx-attachment:latest
    ipc: host
    volumes:
      - nginx-shm:/dev/shm
    depends_on:
      - openappsec-agent

  openappsec-agent:
    image: ghcr.io/openappsec/agent:latest
    ipc: host
    volumes:
      - ./local_policy.yaml:/ext/appsec/local_policy.yaml:ro
      - nginx-shm:/dev/shm
    environment:
      - autoPolicyLoad=true

volumes:
  nginx-shm:
    driver: local
    driver_opts:
      type: tmpfs
```

### Linux統合

#### インストール方法

1. **自動インストール**
   ```bash
   wget https://downloads.openappsec.io/open-appsec-install
   chmod +x open-appsec-install
   sudo ./open-appsec-install --auto
   ```

2. **手動インストール**
   ```bash
   ./open-appsec-install --download
   # 手動でモジュールとライブラリを配置
   ```

#### 設定ファイル

- Nginx設定: `/etc/nginx/nginx.conf`
- ポリシーファイル: `/ext/appsec/local_policy.yaml` または `/etc/cp/conf/local_policy.yaml`

### Kubernetes統合

- CRD（Custom Resource Definition）を使用
- Operatorによる自動管理
- ポリシーをKubernetesリソースとして管理

## ポリシー設定

### Local Policy File（v1beta2）

#### 基本構造

```yaml
apiVersion: v1beta2
kind: LocalPolicy
metadata:
  name: example-policy
policies:
  default:
    mode: detect-learn
    customResponse: 403
    threatPreventionPractices: []
    accessControlPractices: []
    triggers: []
  
  specificRules:
    - host: "example.com"
      mode: prevent-learn
      customResponse: 403
```

#### モード

- **detect-learn**: 検知のみ（ブロックしない）、学習データを収集
- **prevent-learn**: ブロックしつつ学習データを収集
- **detect**: 検知のみ（学習データを収集しない）
- **prevent**: ブロック（学習データを収集しない）
- **inactive**: 無効化

#### specificRules

FQDN別の設定を定義できます：

```yaml
specificRules:
  - host: "api.example.com"
    mode: prevent-learn
    threatPreventionPractices: []
    accessControlPractices: []
```

## 重要な設定項目

### 1. 共有メモリ通信

- NginxとAgent間の通信に使用
- Docker環境では`ipc: host`または共有tmpfsボリュームが必要
- `/dev/shm`をマウント

### 2. ポリシーファイルのパス

- Docker: `/ext/appsec/local_policy.yaml`
- Linux: `/ext/appsec/local_policy.yaml` または `/etc/cp/conf/local_policy.yaml`
- `autoPolicyLoad=true`環境変数で自動読み込み

### 3. ログ設定

- Agentログ: `/var/log/nano_agent`
- Nginxログ: 標準のNginxログパス

## トラブルシューティング

### よくある問題

1. **Attachment Moduleが読み込まれない**
   - モジュールパスを確認: `/usr/lib/nginx/modules/ngx_cp_attachment_module.so`
   - Nginxバージョンとの互換性を確認

2. **Agentが起動しない**
   - ポリシーファイルのパスを確認
   - 共有メモリのマウントを確認
   - ログを確認: `docker logs <container-name>`

3. **共有メモリ通信エラー**
   - `ipc: host`の設定を確認
   - 共有ボリュームのマウントを確認

## セキュリティプラクティス

### Threat Prevention Practices

- デフォルトの脅威検出ルール
- 機械学習モデルによる自動検出
- カスタムルールの追加

### Access Control Practices

- レート制限
- IP制限
- 地理的制限

## 管理方法

### Web UI（SaaS）

- 集中管理ポータル
- 複数のAgentを一元管理
- リアルタイム監視

### Local Policy File

- ローカルファイルによる管理
- バージョン管理が容易
- CI/CDパイプラインとの統合が可能

## 参考資料

- [公式ドキュメント](https://docs.openappsec.io/)
- [GitHubリポジトリ](https://github.com/openappsec)
- [Attachment Module](https://github.com/openappsec/attachment)

## 注意事項

### 公式ドキュメントに存在しない設定

以下の設定は公式ドキュメントには記載されていませんが、設計書で言及されている場合があります：

- `openappsec_shared_memory_zone` - NGINXのshared_memory_zoneディレクティブは使用されない
- `openappsec_agent_url` - 公式ドキュメントには存在しない
- `openappsec_enabled` - 公式ドキュメントには存在しない

**実際の動作**: OpenAppSecはモジュールを読み込むことで自動的に有効化され、設定は`local_policy.yaml`で行います。

### 推奨事項

1. **イメージバージョン**: `:latest`タグではなく、特定バージョンを指定（再現性のため）
2. **セキュリティ**: `ipc: host`はセキュリティリスクがあるため、共有ボリュームのみを使用
3. **Dockerソケット**: 本番環境ではマウントを避け、より安全な方法を検討

## 更新履歴

- 2026-01-16: 初版作成
- 公式ドキュメント（https://docs.openappsec.io/）を参照
