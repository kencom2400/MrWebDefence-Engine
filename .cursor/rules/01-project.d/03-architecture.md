# アーキテクチャ原則

## アーキテクチャ原則

### Onion Architecture（オニオンアーキテクチャ）

レイヤを明確に分離し、依存関係を内側に向けることで拡張性と保守性を確保する。

**依存関係は常に内側に向かいます：**

- **Presentation Layer** は Application Layer に依存
- **Infrastructure Layer** は Application Layer に依存
- **Application Layer** は Domain Layer に依存
- **Domain Layer** は外部に依存しない（最内層）

#### レイヤ構成

1. **Domain Layer**: エンティティ、ドメインロジック、ドメインサービス
2. **Application Layer**: ユースケース、アプリケーションサービス
3. **Infrastructure Layer**: 外部API接続、データ永続化（JSON/DB）
4. **Presentation Layer**: コントローラー、API、UI

#### ディレクトリ構造（backend）

```
apps/backend/src/
├── domain/           # ドメイン層
│   ├── entities/
│   ├── value-objects/
│   └── repositories/ # インターフェース定義
├── application/      # アプリケーション層
│   ├── use-cases/
│   └── services/
├── infrastructure/   # インフラ層
│   ├── api/         # 金融機関API接続
│   ├── persistence/ # JSON/DB永続化
│   └── repositories/ # リポジトリ実装
└── presentation/     # プレゼンテーション層
    └── controllers/
```
