# OpenAppSec 動作モード完全ガイド

## 概要

このドキュメントは、OpenAppSecの動作モード（mode）について、包括的に整理したガイドです。

**公式ドキュメント**: https://docs.openappsec.io/getting-started/start-with-linux/local-policy-file-v1beta2-beta

---

## 目次

1. [モード一覧と概要](#モード一覧と概要)
2. [各モードの詳細説明](#各モードの詳細説明)
3. [モードの階層構造](#モードの階層構造)
4. [学習レベルとの関係](#学習レベルとの関係)
5. [モード選択ガイド](#モード選択ガイド)
6. [実装例](#実装例)

---

## モード一覧と概要

OpenAppSecには以下の6つのモードがあります：

| モード | ブロック | 検知/ログ | 学習 | 説明 |
|--------|---------|----------|------|------|
| `detect-learn` | ❌ | ✅ | ✅ | 検知のみ（ブロックしない）、学習データを収集 |
| `prevent-learn` | ✅ | ✅ | ✅ | ブロックしつつ学習データを収集 |
| `detect` | ❌ | ✅ | ❌ | 検知のみ（学習データを収集しない） |
| `prevent` | ✅ | ✅ | ❌ | ブロック（学習データを収集しない） |
| `inactive` | ❌ | ❌ | ❌ | 無効化 |
| `inherited` | - | - | - | 親の設定を継承 |

---

## 各モードの詳細説明

### 1. detect-learn

**動作**:
- 攻撃を検知してログに記録しますが、**ブロックしません**
- 正常なトラフィックと異常なトラフィックの両方から学習データを収集します
- MLエンジンがベースラインを構築し、学習レベルを向上させます

**用途**:
- **初期導入時**: 誤検知を避けるため、まずは検知のみで動作確認
- **学習データ収集**: 十分な学習データを収集してから、prevent-learnに移行
- **新規アプリケーション**: アプリケーションの正常な動作パターンを学習

**推奨期間**: 通常2-3日間（十分な多様なトラフィックがある場合）

**学習レベル**: Kindergarten → Primary School → High School → Graduate → Master → PhD

---

### 2. prevent-learn

**動作**:
- 攻撃を検知して**ブロックします**
- 同時に学習データを収集し続けます
- 信頼度（confidence）が設定された閾値以上の攻撃をブロックします
- 低信頼度の攻撃は検知のみ（ログに記録）の場合があります

**用途**:
- **本番環境での推奨モード**: 十分な学習が完了した後
- **継続的な学習**: 新しい攻撃パターンやアプリケーションの変更に対応
- **Graduateレベル到達後**: 学習レベルがGraduate以上になったら移行推奨

**信頼度の動作**:
- `minimumConfidence: medium` → medium以上の信頼度でブロック
- `minimumConfidence: high` → high以上の信頼度でブロック（デフォルト）
- `minimumConfidence: critical` → criticalのみブロック（誤検知は少ないが、低信頼度の攻撃を通す可能性）

**学習レベル**: 継続的に学習し、検知精度が向上します

---

### 3. detect

**動作**:
- 攻撃を検知してログに記録しますが、**ブロックしません**
- **学習データを収集しません**
- 既存の学習済みモデルに基づいて検知します

**用途**:
- **監視のみ**: ブロックせずに監視したい場合
- **学習を無効化**: 学習を停止したい場合
- **特定のサブプラクティス**: 学習が不要な機能（例: レート制限）

---

### 4. prevent

**動作**:
- 攻撃を検知して**ブロックします**
- **学習データを収集しません**
- 既存の学習済みモデルに基づいてブロックします

**用途**:
- **厳格な防御**: 学習が不要で、確実にブロックしたい場合
- **成熟したシステム**: ベースラインが確立され、誤検知が少ない場合
- **特定のサブプラクティス**: 学習が不要な機能

**注意**: 新しい攻撃パターンやアプリケーションの変更に対応できない可能性があります

---

### 5. inactive

**動作**:
- **すべての機能が無効化されます**
- 検知、ブロック、学習のいずれも行われません
- そのルール/プラクティスは事実上バイパスされます

**用途**:
- **一時的な無効化**: 特定の機能を一時的に無効化したい場合
- **デフォルト設定**: 多くの高度な保護機能はデフォルトで`inactive`（例: `csrfProtection`, `errorDisclosure`, `openRedirect`）
- **トラブルシューティング**: 問題の切り分けのため一時的に無効化

---

### 6. inherited

**動作**:
- 親の設定（ポリシーまたは上位レベルのプラクティス）を継承します
- 明示的にモードを指定しない場合のデフォルト動作

**用途**:
- **シンプルな設定**: 各サブプラクティスで個別に設定する必要がない
- **一貫性の維持**: 親の設定を変更すれば、すべての子要素に反映される
- **柔軟性**: 必要に応じて個別にオーバーライド可能

**階層構造**:
```
policies.default.mode (最上位)
  ↓
threatPreventionPractices[].practiceMode
  ↓
threatPreventionPractices[].webAttacks.overrideMode
  ↓
threatPreventionPractices[].webAttacks.protections.csrfProtection (最下位)
```

---

## モードの階層構造

OpenAppSecでは、モードは以下の階層構造で適用されます：

### 1. ポリシーレベル（最上位）

```yaml
policies:
  default:
    mode: prevent-learn  # すべてのトラフィックに適用されるデフォルトモード
  specificRules:
    - host: "example.com"
      mode: prevent-learn  # 特定のホストに適用されるモード
```

### 2. プラクティスレベル

```yaml
threatPreventionPractices:
  - name: threat-prevention-basic
    practiceMode: inherited  # policies.default.modeを継承
    # または
    practiceMode: prevent  # 明示的にオーバーライド
```

### 3. サブプラクティスレベル

```yaml
threatPreventionPractices:
  - name: threat-prevention-basic
    practiceMode: prevent-learn
    webAttacks:
      overrideMode: inherited  # practiceModeを継承
      # または
      overrideMode: prevent  # 明示的にオーバーライド
```

### 4. 保護機能レベル（最下位）

```yaml
threatPreventionPractices:
  - name: threat-prevention-basic
    practiceMode: prevent-learn
    webAttacks:
      overrideMode: prevent
      protections:
        csrfProtection: inherited  # webAttacks.overrideModeを継承
        # または
        errorDisclosure: prevent  # 明示的にオーバーライド
```

### 継承の優先順位

1. **最下位の設定が最優先**: より具体的な設定が優先されます
2. **inheritedの動作**: 親の設定を継承します
3. **明示的な設定**: `inherited`以外の値を指定すると、親の設定をオーバーライドします

---

## 学習レベルとの関係

OpenAppSecは、学習モード（`detect-learn`, `prevent-learn`）で以下の学習レベルを経ます：

### 学習レベルの段階

1. **Kindergarten**: 初期段階
   - 学習データが不足している
   - 検知精度が低い
   - 誤検知の可能性が高い

2. **Primary School**: 基本的な学習
   - 基本的なパターンを学習
   - 検知精度が向上し始める

3. **High School**: 中級レベル
   - より複雑なパターンを学習
   - 検知精度が向上

4. **Graduate**: 推奨される最小レベル
   - **prevent-learnモードに移行可能**
   - 検知精度が十分に高い
   - 誤検知が減少

5. **Master**: 高度な学習
   - 非常に高い検知精度
   - 複雑な攻撃パターンも検知可能

6. **PhD**: 最高レベル
   - 最高の検知精度
   - ゼロデイ攻撃にも対応可能

### 学習レベルとモードの関係

| 学習レベル | 推奨モード | 説明 |
|-----------|-----------|------|
| Kindergarten | `detect-learn` | 学習データを収集 |
| Primary School | `detect-learn` | 学習データを収集 |
| High School | `detect-learn` | 学習データを収集 |
| Graduate | `prevent-learn` | ブロック開始可能 |
| Master | `prevent-learn` | 高精度でブロック |
| PhD | `prevent-learn` | 最高精度でブロック |

### 学習レベルの確認方法

```bash
# open-appsec-ctlでステータス確認
docker-compose exec openappsec-agent open-appsec-ctl --status --extended
```

---

## モード選択ガイド

### シナリオ別の推奨モード

#### 1. 初期導入時

```yaml
policies:
  default:
    mode: detect-learn  # まずは検知のみで動作確認
```

**理由**:
- 誤検知を避けるため
- アプリケーションの正常な動作パターンを学習
- 十分な学習データを収集

**期間**: 2-3日間（十分な多様なトラフィックがある場合）

---

#### 2. 本番環境（学習完了後）

```yaml
policies:
  default:
    mode: prevent-learn  # ブロックしつつ学習を継続
```

**理由**:
- Graduateレベル以上に達したら移行
- 継続的な学習により、新しい攻撃パターンに対応
- アプリケーションの変更にも対応

---

#### 3. 厳格な防御が必要な場合

```yaml
policies:
  default:
    mode: prevent  # 学習なしで確実にブロック
```

**理由**:
- 学習が不要で、確実にブロックしたい場合
- 成熟したシステムで、ベースラインが確立されている場合

**注意**: 新しい攻撃パターンに対応できない可能性があります

---

#### 4. 監視のみ

```yaml
policies:
  default:
    mode: detect  # 検知のみ、学習なし
```

**理由**:
- ブロックせずに監視したい場合
- 学習を無効化したい場合

---

#### 5. ホスト別の設定

```yaml
policies:
  default:
    mode: prevent-learn  # デフォルト
  specificRules:
    - host: "api.example.com"
      mode: prevent  # APIは厳格にブロック
    - host: "staging.example.com"
      mode: detect-learn  # ステージング環境は学習中
```

**理由**:
- 環境やホストごとに異なるセキュリティ要件に対応
- 本番環境は`prevent-learn`、ステージング環境は`detect-learn`

---

### サブプラクティス別の推奨モード

#### webAttacks

```yaml
webAttacks:
  overrideMode: prevent-learn  # 本番環境
  # または
  overrideMode: detect-learn  # 初期導入時
```

**理由**:
- SQL Injection、XSSなどのWeb攻撃を防御
- MLエンジンによる自動検知・ブロック

---

#### intrusionPrevention (IPS)

```yaml
intrusionPrevention:
  overrideMode: inherited  # デフォルト（ポリシーレベルのモードを継承）
  # または
  overrideMode: prevent  # 明示的にブロック
```

**理由**:
- 既知のCVEや攻撃パターンをブロック
- 学習が不要な場合が多い

---

#### fileSecurity

```yaml
fileSecurity:
  overrideMode: inherited  # デフォルト
  # または
  overrideMode: prevent  # ファイルアップロードを厳格にブロック
```

**理由**:
- マルウェアや不正なファイルをブロック
- 学習が不要な場合が多い

---

#### protections（個別の保護機能）

```yaml
protections:
  csrfProtection: prevent  # CSRF攻撃をブロック
  errorDisclosure: prevent  # エラー情報の漏洩を防止
  openRedirect: prevent  # オープンリダイレクト攻撃を防止
```

**理由**:
- デフォルトは`inactive`（無効化）
- 必要に応じて`prevent`に設定

---

## 実装例

### 例1: 初期導入時の設定

```yaml
apiVersion: v1beta2
policies:
  default:
    mode: detect-learn  # 初期導入時は検知のみ
    threatPreventionPractices: [threat-prevention-basic]
    accessControlPractices: []
    triggers: [log-trigger-basic]
    customResponse: 403

threatPreventionPractices:
  - name: threat-prevention-basic
    practiceMode: inherited  # policies.default.modeを継承（detect-learn）
    webAttacks:
      overrideMode: inherited  # practiceModeを継承（detect-learn）
      minimumConfidence: medium
      protections:
        csrfProtection: prevent  # CSRFは明示的にブロック
        errorDisclosure: prevent
        openRedirect: prevent
```

---

### 例2: 本番環境の設定（学習完了後）

```yaml
apiVersion: v1beta2
policies:
  default:
    mode: prevent-learn  # ブロックしつつ学習を継続
    threatPreventionPractices: [threat-prevention-basic]
    accessControlPractices: []
    triggers: [log-trigger-basic]
    customResponse: 403

threatPreventionPractices:
  - name: threat-prevention-basic
    practiceMode: inherited  # policies.default.modeを継承（prevent-learn）
    webAttacks:
      overrideMode: inherited  # practiceModeを継承（prevent-learn）
      minimumConfidence: high  # 本番環境はhighを推奨
      protections:
        csrfProtection: prevent
        errorDisclosure: prevent
        openRedirect: prevent
```

---

### 例3: ホスト別の設定

```yaml
apiVersion: v1beta2
policies:
  default:
    mode: prevent-learn  # デフォルト
    threatPreventionPractices: [threat-prevention-basic]
    accessControlPractices: []
    triggers: [log-trigger-basic]
    customResponse: 403

  specificRules:
    - host: "api.example.com"
      mode: prevent  # APIは厳格にブロック（学習なし）
      threatPreventionPractices: [threat-prevention-basic]
    - host: "staging.example.com"
      mode: detect-learn  # ステージング環境は学習中
      threatPreventionPractices: [threat-prevention-basic]

threatPreventionPractices:
  - name: threat-prevention-basic
    practiceMode: inherited
    webAttacks:
      overrideMode: inherited
      minimumConfidence: medium
      protections:
        csrfProtection: prevent
        errorDisclosure: prevent
        openRedirect: prevent
```

---

### 例4: サブプラクティスの個別設定

```yaml
apiVersion: v1beta2
policies:
  default:
    mode: prevent-learn
    threatPreventionPractices: [threat-prevention-basic]
    accessControlPractices: []
    triggers: [log-trigger-basic]
    customResponse: 403

threatPreventionPractices:
  - name: threat-prevention-basic
    practiceMode: inherited  # policies.default.modeを継承（prevent-learn）
    webAttacks:
      overrideMode: prevent-learn  # 明示的に設定
      minimumConfidence: high
      protections:
        csrfProtection: prevent
        errorDisclosure: prevent
        openRedirect: prevent
    intrusionPrevention:
      overrideMode: prevent  # IPSは学習なしでブロック
      highConfidenceEventAction: prevent
      mediumConfidenceEventAction: prevent
      lowConfidenceEventAction: detect
    fileSecurity:
      overrideMode: prevent  # ファイルセキュリティは学習なしでブロック
      highConfidenceEventAction: prevent
      mediumConfidenceEventAction: prevent
      lowConfidenceEventAction: detect
```

---

## まとめ

### モード選択のチェックリスト

- [ ] **初期導入時**: `detect-learn`で開始
- [ ] **学習レベル確認**: Graduateレベル以上になったら`prevent-learn`に移行
- [ ] **本番環境**: `prevent-learn`を推奨（継続的な学習）
- [ ] **厳格な防御**: `prevent`（学習が不要な場合）
- [ ] **監視のみ**: `detect`（ブロック不要な場合）
- [ ] **一時的な無効化**: `inactive`
- [ ] **シンプルな設定**: `inherited`で親の設定を継承

### 重要なポイント

1. **学習モード（`-learn`）**: 継続的な学習により、検知精度が向上します
2. **階層構造**: より具体的な設定が優先されます
3. **学習レベル**: Graduateレベル以上で`prevent-learn`に移行推奨
4. **信頼度**: `minimumConfidence`でブロックの閾値を調整可能
5. **柔軟性**: ホスト別、プラクティス別に異なるモードを設定可能

---

## 参考資料

- [OpenAppSec公式ドキュメント](https://docs.openappsec.io/getting-started/start-with-linux/local-policy-file-v1beta2-beta)
- [学習レベルの追跡](https://docs.openappsec.io/how-to/configuration-and-learning/track-learning-and-move-from-learn-detect-to-prevent)
- [OpenAppSec設定値リファレンス](./OPENAPPSEC-CONFIGURATION-REFERENCE.md)
- [OpenAppSec検知パターン](./OPENAPPSEC-DETECTION-PATTERNS.md)
