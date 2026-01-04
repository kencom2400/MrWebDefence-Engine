## 9. スクリプト・ツール開発のベストプラクティス

**優先度レベル**: `03-XX` - **一般（MAY）** - 推奨されるルール

### 9-1. ユーザビリティとヘルプメッセージ

**原則**: ヘルプメッセージは実際の使用方法と完全に一致させる

```bash
# ❌ 悪い例: 実際のステータス名と異なる
echo "例: $0 24 'In Progress'"

# ✅ 良い例: 実際のステータス名（絵文字含む）と一致
echo "例: $0 24 '🚧 In Progress'"
```

**理由**:

- ユーザーがコピー&ペーストで即座に使える
- 絵文字などの特殊文字の使用方法が明確になる
- エラーを未然に防ぐ

### 9-2. 外部API・コマンドのエラーハンドリング

**原則**: 外部APIやコマンドの結果が空の場合は必ずチェック

```bash
# ❌ 悪い例: 結果が空の場合にエラーにならない
FIELD_INFO=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json | \
  jq '.fields[] | select(.name == "Status")')
FIELD_ID=$(echo "$FIELD_INFO" | jq -r '.id')

# ✅ 良い例: 結果が空の場合の明確なエラーハンドリング
FIELD_INFO=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json | \
  jq '.fields[] | select(.name == "Status")')

if [ -z "$FIELD_INFO" ]; then
  echo "❌ エラー: プロジェクトに 'Status' フィールドが見つかりませんでした。"
  exit 1
fi
```

**理由**:

- 堅牢性の向上
- デバッグが容易になる
- 明確なエラーメッセージでユーザーが対応しやすい

### 9-3. 外部コマンド呼び出しの効率化

**原則**: 同じデータから複数の値を取得する場合は、コマンド呼び出しを1回にまとめる

```bash
# ❌ 悪い例: 3回のjq呼び出し
ITEM_ID=$(echo "$ITEM_INFO" | jq -r '.id')
CURRENT_STATUS=$(echo "$ITEM_INFO" | jq -r '.status')
TITLE=$(echo "$ITEM_INFO" | jq -r '.title')

# ✅ 良い例: 1回のjq呼び出し + mapfile
mapfile -t values < <(echo "$ITEM_INFO" | jq -r '.id, .status, .title')
ITEM_ID="${values[0]}"
CURRENT_STATUS="${values[1]}"
TITLE="${values[2]}"
```

**理由**:

- パフォーマンスの向上（3倍の効率化）
- プロセス生成のオーバーヘッドを削減
- コードがより簡潔になる

### 9-4. エラーメッセージのユーザーフレンドリー化

APIから返されるエラーメッセージをそのままユーザーに表示することは避けるべきです。

**❌ 避けるべきパターン**:

```typescript
// ❌ 技術的なエラーメッセージをそのまま表示
catch (error) {
  if (isHttpError(error) && error.statusCode === 401) {
    return Result.failure(error.message); // "Unauthorized: Invalid token format"
  }
}
```

**問題点**:

- APIが返すエラーメッセージは技術的でユーザーにとって分かりにくい
- エラーメッセージの内容がAPIの実装に依存する
- 多言語対応が困難

**✅ 正しい実装**:

```typescript
// ✅ ユーザーフレンドリーな固定メッセージを使用
catch (error) {
  if (isHttpError(error) && error.statusCode === 401) {
    return Result.failure('認証情報が無効です'); // わかりやすい日本語メッセージ
  }
}
```

**改善点**:

- ユーザーが理解しやすい表現
- 一貫性のあるエラーメッセージ
- ログには技術的な詳細を記録しつつ、ユーザーにはわかりやすいメッセージを表示
- 多言語対応が容易

**実装例**:

```typescript
// ログには詳細、ユーザーには簡潔に
catch (error) {
  this.logger.error('認証エラー', {
    error: error instanceof Error ? error.message : String(error),
    statusCode: isHttpError(error) ? error.statusCode : undefined,
  });

  if (isHttpError(error) && (error.statusCode === 401 || error.statusCode === 403)) {
    return {
      success: false,
      needsReauth: true,
      errorMessage: '認証情報が無効です', // ユーザー向け
      errorCode: 'AUTH_ERROR',
    };
  }
}
```

**参考**: PR #237 - Gemini Code Assistレビュー指摘

### 9-5. 設定の外部化と再利用性

**原則**: ハードコードされた設定は環境変数で上書き可能にする

```bash
# ❌ 悪い例: ハードコード
PROJECT_NUMBER=1
OWNER="kencom2400"

# ✅ 良い例: 環境変数で上書き可能
PROJECT_NUMBER="${PROJECT_NUMBER:-1}"
OWNER="${OWNER:-kencom2400}"
```

**使用方法**:

```bash
# デフォルト値を使用
./script.sh

# 環境変数で上書き
PROJECT_NUMBER=2 OWNER="other-user" ./script.sh
```

**理由**:

- 他のプロジェクトやリポジトリでも再利用可能
- テスト環境と本番環境で異なる設定を使える
- 設定変更のためにスクリプトを編集する必要がない

### 9-6. スクリプト開発のチェックリスト

- [ ] ヘルプメッセージは実際の使用方法と一致しているか？
- [ ] 外部API・コマンドの結果が空の場合のエラーハンドリングがあるか？
- [ ] 同じデータへの複数回のアクセスを1回にまとめているか？
- [ ] ハードコードされた設定を環境変数で上書き可能にしているか？
- [ ] エラーメッセージは明確で、ユーザーが対応方法を理解できるか？

### 9-7. DTO設計の原則

**重要**: リクエストDTOとレスポンスDTOで異なる設計パターンを適用

#### リクエストDTO: `class`を使用

**理由**:

- バリデーションデコレータ（`@IsString()`, `@IsOptional()`等）が必要
- class-validatorがclassベースで動作
- インスタンス化され、バリデーションパイプラインで処理される

**実装例**:

```typescript
import { IsBoolean, IsOptional, IsDateString } from 'class-validator';

export class SyncTransactionsDto {
  @IsOptional()
  @IsBoolean()
  forceFullSync?: boolean;
}

export class GetSyncHistoryDto {
  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;
}
```

#### レスポンスDTO: `interface`を使用

**理由**:

- 単なる型定義であり、メソッドやバリデーションロジックを持たない
- インスタンス化されない（コントローラーがオブジェクトリテラルを返す）
- TypeScriptの`strictPropertyInitialization`チェックを回避
- classとして定義するとプロパティの初期化が必須になり、不要な複雑性が増す

**実装例**:

```typescript
// ✅ 正しい: interface
export interface SyncTransactionsResponseDto {
  success: boolean;
  data: {
    syncId: string;
    status: string;
    successCount: number;
    failureCount: number;
  };
}

// ❌ 誤り: class（ビルドエラーが発生）
export class SyncTransactionsResponseDto {
  success: boolean;  // TS2564: Property has no initializer
  data: { ... };     // TS2564: Property has no initializer
}
```

**ビルドエラーの例**:

```
TS2564: Property 'success' has no initializer and is not definitely assigned in the constructor.
TS2564: Property 'data' has no initializer and is not definitely assigned in the constructor.
```

**classで定義した場合の問題**:

1. プロパティに初期化子が必要（`success: boolean = false`）
2. または、コンストラクタですべてのプロパティを初期化する必要
3. レスポンスDTOは型定義のみなので、この複雑性は不要

**まとめ**:

| 用途          | 型          | 理由               |
| ------------- | ----------- | ------------------ |
| リクエストDTO | `class`     | バリデーション必要 |
| レスポンスDTO | `interface` | 型定義のみ         |

**参考**: Issue #22 / PR #262 - Geminiレビュー対応でのCI失敗から学習

#### Swagger/OpenAPI対応のDTO設計（⚠️ 例外ケース）

**重要**: Issue #296 / PR #312のGeminiレビューから、Swagger/OpenAPIドキュメント生成においては、レスポンスDTOも`class`として定義すべき場合があることが判明しました。

**Swagger対応が必要な場合（レスポンスDTOも`class`を使用）**:

```typescript
// ✅ Swagger対応: classで定義
import { ApiProperty } from '@nestjs/swagger';

export class SubcategoryResponseDto {
  @ApiProperty({ description: 'サブカテゴリID', example: 'food_cafe' })
  id: string = '';

  @ApiProperty({ description: 'サブカテゴリ名', example: 'カフェ' })
  name: string = '';

  @ApiProperty({
    description: '子サブカテゴリ',
    type: () => [SubcategoryResponseDto],
    required: false,
  })
  children?: SubcategoryResponseDto[];
}
```

**理由**:

1. **ネストされた構造の正確な表現**: 再帰的なDTO（`children`プロパティ等）の型定義に必須
2. **`@ApiProperty()`デコレータの使用**: Swaggerドキュメントで詳細なメタデータを提供
3. **OpenAPI仕様への正確な出力**: `interface`では型情報が失われる場合がある

**対応方法（プロパティ初期化エラーの回避）**:

```typescript
// 方法1: デフォルト値を設定
export class ClassificationResponseDto {
  @ApiProperty()
  success: boolean = false;

  @ApiProperty()
  data: ClassificationResultDto = new ClassificationResultDto();
}

// 方法2: オプショナルプロパティ（`!`を使用）
export class ClassificationResponseDto {
  @ApiProperty()
  success!: boolean;

  @ApiProperty()
  data!: ClassificationResultDto;
}
```

**判断基準**:

| 条件                            | レスポンスDTOの型 | 理由                             |
| ------------------------------- | ----------------- | -------------------------------- |
| Swagger/OpenAPI生成が必要       | `class`           | `@ApiProperty()`デコレータが必須 |
| ネストされた/再帰的な構造       | `class`           | 正確な型情報の表現               |
| シンプルなレスポンス（内部API） | `interface`       | 型定義のみで十分                 |

**重要な注意点**:

- プロジェクト全体で**Swagger/OpenAPIドキュメントを生成する場合**は、**すべてのレスポンスDTOを`class`として定義**することを推奨
- 一貫性を保つため、プロジェクト初期段階で方針を決定すること
- Issue #296で学習: `interface`と`class`の混在により、Swaggerドキュメントの精度が低下

**参考**:

- Issue #296 / PR #312 - Gemini指摘：レスポンスDTOを`interface`から`class`に変更
- Issue #22 / PR #262 - ビルドエラーから`interface`の使用を決定（Swagger非対応時）

#### レスポンスDTOでの型の厳密化

**原則**: レスポンスDTOでは、可能な限り厳密な型を使用する

**❌ 避けるべきパターン**:

```typescript
export interface ConnectionStatusDto {
  status: string; // ❌ 曖昧すぎる
  institutionType: string; // ❌ 曖昧すぎる
}
```

**✅ 推奨パターン**:

```typescript
export interface ConnectionStatusDto {
  status: 'CONNECTED' | 'DISCONNECTED' | 'NEED_REAUTH'; // ✅ 厳密な型
  institutionType: 'bank' | 'credit-card' | 'securities'; // ✅ 厳密な型
}
```

**改善効果**:

1. **コンパイル時の型チェック強化**
   - 不正な値（例: `'PENDING'`, `'ERROR'`）をコンパイル時に検出
   - タイポやミスを防止

2. **モジュール内での型定義の一貫性向上**
   - Domain層のEnum型と整合性を保証
   - DTO層、Domain層、Application層で同じ値を使用

3. **APIドキュメントの自動生成**
   - 型定義から可能な値が明確になる
   - OpenAPI/Swaggerで正確な型情報が提供される

**実装時の注意点**:

Domain層でEnum型を使用している場合、Application層で**型ガード関数**を使用して安全に変換：

```typescript
// Domain層: 共通の型定義ファイル (connection.types.ts)
export type ConnectionStatusType = 'CONNECTED' | 'DISCONNECTED' | 'NEED_REAUTH';

// 型ガード関数
export function isPublicConnectionStatus(
  status: string,
): status is ConnectionStatusType {
  return ['CONNECTED', 'DISCONNECTED', 'NEED_REAUTH'].includes(status);
}

// Domain層: Enum型
export enum ConnectionStatus {
  CONNECTED = 'CONNECTED',
  DISCONNECTED = 'DISCONNECTED',
  NEED_REAUTH = 'NEED_REAUTH',
  CHECKING = 'CHECKING',  // 内部状態
}

// Application層: 型ガードを使用した安全な変換
private toResult(history: ConnectionHistory): ConnectionHistoryResult {
  // 型ガードで安全に型変換
  if (!isPublicConnectionStatus(history.status)) {
    this.logger.warn(
      `内部ステータス '${history.status}' は公開APIでは使用できません。DISCONNECTEDとして扱います。`,
    );
    // 内部ステータスはDISCONNECTEDとして扱う
    return {
      status: 'DISCONNECTED',
      // ...
    };
  }

  return {
    status: history.status, // 型ガードにより安全に代入可能
    // ...
  };
}
```

**❌ 避けるべきパターン（型アサーションの危険性）**:

```typescript
// ❌ 型アサーション (as) は型安全性を損なう
private toResult(history: ConnectionHistory): ConnectionHistoryResult {
  return {
    status: history.status as 'CONNECTED' | 'DISCONNECTED' | 'NEED_REAUTH',
    // history.statusが'CHECKING'の場合、型チェックをすり抜けてしまう
  };
}
```

**型アサーションのリスク**:

- コンパイラはエラーを検知できない
- ランタイムで予期しない値がクライアントに渡る可能性
- Enumに新しい値が追加された際に気づかない
- 永続化されたデータに内部状態が含まれる場合、検出できない

**型ガードのメリット**:

- 実行時に値を検証し、不正な値を検出
- 型安全性を保ちながら、フォールバック処理が可能
- コードの意図が明確になる
- デバッグ時にログで問題を追跡できる

#### 型エイリアスによる型定義の一元管理

**原則**: 文字列リテラルユニオン型は型エイリアスとして定義し、一元管理する

**❌ 避けるべきパターン**:

```typescript
// ファイル1: check-connection.dto.ts
export interface ConnectionStatusDto {
  status: 'CONNECTED' | 'DISCONNECTED' | 'NEED_REAUTH'; // 型を直接記述
}

// ファイル2: get-connection-history.dto.ts
export interface ConnectionHistoryDto {
  status: 'CONNECTED' | 'DISCONNECTED' | 'NEED_REAUTH'; // 同じ型を重複定義
}

// ファイル3: connection-status-result.type.ts
export interface ConnectionStatusResult {
  status: 'CONNECTED' | 'DISCONNECTED' | 'NEED_REAUTH'; // 同じ型を重複定義
}
```

**問題点**:

- 型定義が分散し、変更時に複数箇所を修正する必要
- タイポのリスク
- 一貫性が保てない

**✅ 推奨パターン**:

```typescript
// connection.types.ts（共通定義ファイル）
export type ConnectionStatusType = 'CONNECTED' | 'DISCONNECTED' | 'NEED_REAUTH';
export type InstitutionType = 'bank' | 'credit-card' | 'securities';

// check-connection.dto.ts
import type { ConnectionStatusType, InstitutionType } from '../../domain/types/connection.types';

export interface ConnectionStatusDto {
  status: ConnectionStatusType; // 型エイリアスを使用
  institutionType: InstitutionType;
}

// get-connection-history.dto.ts
import type { ConnectionStatusType, InstitutionType } from '../../domain/types/connection.types';

export interface ConnectionHistoryDto {
  status: ConnectionStatusType; // 型エイリアスを使用
  institutionType: InstitutionType;
}
```

**メリット**:

1. **型定義の変更が1箇所で済む**
   - 値を追加・削除する際、1ファイルのみ修正
   - 変更の影響範囲が明確

2. **タイポの防止**
   - 型エイリアスを使用するため、スペルミスが起きない

3. **一貫性の保証**
   - すべての箇所で同じ型定義を使用
   - Domain層からPresentation層まで統一

4. **保守性の向上**
   - 型の意味が名前から明確
   - リファクタリングが容易

**配置場所**:

- Domain層の `types/` ディレクトリ
- 例: `modules/health/domain/types/connection.types.ts`

#### 内部状態と公開状態の分離

**原則**: Domain層の内部状態と、公開APIで使用する状態を明確に分離する

**背景**:

- Domain層では処理中の状態（`CHECKING`, `PROCESSING`等）を含む完全なEnum
- 公開APIでは確定した状態のみを返す
- この差分を安全に変換する必要がある

**実装パターン**:

```typescript
// Domain層: 完全な状態を持つEnum
export enum ConnectionStatus {
  CONNECTED = 'CONNECTED',
  DISCONNECTED = 'DISCONNECTED',
  NEED_REAUTH = 'NEED_REAUTH',
  CHECKING = 'CHECKING', // ⚠️ 内部状態（公開しない）
}

// 公開用の型定義（内部状態を含まない）
export type ConnectionStatusType = 'CONNECTED' | 'DISCONNECTED' | 'NEED_REAUTH';

// 型ガード関数で安全に変換
export function isPublicConnectionStatus(
  status: string,
): status is ConnectionStatusType {
  return ['CONNECTED', 'DISCONNECTED', 'NEED_REAUTH'].includes(status);
}

// Application層での使用
private toResult(entity: SomeEntity): SomeResult {
  if (!isPublicConnectionStatus(entity.status)) {
    // 内部状態を適切なフォールバック値に変換
    this.logger.warn(`内部ステータス '${entity.status}' を公開値に変換します`);
    return { status: 'DISCONNECTED', ... };
  }
  return { status: entity.status, ... };
}
```

**なぜ重要か**:

1. **意図しない状態の露出を防止**
   - 処理中の状態がクライアントに渡らない
   - APIの安定性が向上

2. **永続化データの問題を検出**
   - 予期せぬプロセス中断で内部状態のまま保存されたデータを検出
   - ログで追跡可能

3. **将来の拡張性**
   - 内部状態の追加が公開APIに影響しない
   - Domain層とPresentation層の疎結合

#### 既存コードへの適用（リファクタリング指針）

**原則**: 新規実装時は最初から、既存コードは段階的に改善

**リファクタリングの優先順位**:

1. **高優先度**（すぐに対応）
   - `as`による型アサーションを使用している箇所
   - `string`型で本来は限定的な値しか取らないプロパティ
   - 公開API（外部に影響）の型定義

2. **中優先度**（次のタスクで対応）
   - 内部APIの型定義
   - 重複している型定義

3. **低優先度**（機会があれば対応）
   - 古いコードで動作が安定している箇所

**リファクタリング手順**:

```bash
# 1. 型アサーション使用箇所を検索
grep -r " as " apps/backend/src/

# 2. string型で限定値を持つプロパティを検索
grep -r ": string" apps/backend/src/modules/*/presentation/dto/

# 3. 優先順位をつけて段階的に対応
# - まず公開APIのDTO
# - 次にDomain層の型定義
# - 最後にApplication層の変換処理
```

**注意点**:

- **一度に大量の変更をしない**
  - 1つのモジュールずつ対応
  - テストを確実に実行
- **既存の動作を変えない**
  - 型定義の厳密化は行うが、実行時の振る舞いは維持
  - ログ追加は良いが、エラーハンドリングの変更は慎重に

- **レビューを活用**
  - Geminiのコードレビューで指摘された箇所を優先
  - ルールファイルに学びを追加

**参考**: Issue #265 / PR #274 - Geminiレビュー指摘から学習

---

## 10. push前の必須チェック

```

╔═══════════════════════════════════════════════════════════════╗
║ 🚨 CRITICAL RULE - PUSH前の4ステップチェック 🚨 ║
║ ║
║ 詳細は `.cursor/rules/03-git-workflow.d/03-push-check.md` を参照 ║
╚═══════════════════════════════════════════════════════════════╝

```

**必須4ステップ**:

```bash
1. poetry run black scripts/ tests/  # コードフォーマット
2. poetry run black --check scripts/ tests/  # フォーマットチェック
3. poetry run flake8 scripts/ tests/  # リントチェック
4. poetry run pytest tests/  # テスト実行
```

**実行時間**: 約4-6分

**なぜ重要か**:

- ビルドエラーはすべてのCI jobをブロックする
- ローカルでの早期発見により時間節約（実例: Issue #22で20分の損失を防げた）

**詳細**: `.cursor/rules/03-git-workflow.d/03-push-check.md` 参照

---
