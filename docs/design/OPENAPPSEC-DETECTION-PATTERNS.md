# OpenAppSec 検知対象パターン（公式ドキュメント調査結果）

## 概要

このドキュメントは、OpenAppSecの公式ドキュメントとWeb検索結果に基づいて、OpenAppSecが検知する攻撃パターンをまとめたものです。

**参考資料**:
- [OpenAppSec公式ドキュメント](https://docs.openappsec.io/)
- [OpenAppSec ML技術の詳細](https://www.openappsec.io/post/deep-dive-into-open-appsec-machine-learning-technology)
- [SQL Injection検知技術](https://www.openappsec.io/post/open-appsec-ml-based-waf-effectively-defeats-modern-sqli-evasion-techniques)

---

## SQL Injection検知パターン

### 基本的なパターン

OpenAppSecは以下のようなSQL Injectionパターンを検知します：

1. **基本的なOR条件**
   - `' OR 1=1`
   - `' OR '1'='1'`
   - `OR 1=1`
   - `OR 1 LIKE 1`

2. **UNION SELECT**
   - `' UNION SELECT * FROM users --`
   - `' UNION SELECT NULL, user, password FROM users --`
   - `1' UNION SELECT NULL--`

3. **DROP TABLE**
   - `'; DROP TABLE users; --`
   - `'; DROP TABLE users--`

4. **コメント挿入**
   - `admin'--`
   - `' OR 1=1#`
   - `' OR 1=1/*`
   - `OR/**/1=1`

5. **エンコーディング**
   - URLエンコード: `%27%20OR%201%3D1` (`' OR 1=1`)
   - Base64エンコード: `YmFzZTY0X29yIDE9MQ==` (`or 1=1`)

6. **大文字小文字混在**
   - `SeLeCt * FrOm users`
   - `oR  1=1` (空白挿入)

7. **時間ベースのSQLi**
   - `SLEEP(5)`
   - `BENCHMARK(1000000, MD5('test'))`

8. **システム関数・メタデータ**
   - `INFORMATION_SCHEMA`
   - `mysql.db`
   - `database()`, `user()`

### 検知メカニズム

OpenAppSecは以下の方法でSQL Injectionを検知します：

1. **ペイロードのデコードと正規化**
   - URLエンコード、Base64エンコードを再帰的にデコード
   - 大文字小文字の正規化
   - 空白やコメントの除去

2. **攻撃インジケーターの検出**
   - SQLキーワード: `UNION`, `DROP`, `INSERT`, `DELETE`, `SELECT`, `WHERE`, `AND`, `OR`, `LIKE`, `GROUP BY`
   - 演算子: `=`, `LIKE`, `IN`
   - 特殊文字: `'`, `"`, `--`, `#`, `/*`, `*/`

3. **信頼度スコアリング**
   - 複数のインジケーターが存在する場合、信頼度が高くなる
   - コンテキスト評価エンジンが信頼度を調整

---

## XSS（Cross-Site Scripting）検知パターン

### 基本的なパターン

OpenAppSecは以下のようなXSSパターンを検知します：

1. **スクリプトタグ**
   - `<script>alert('XSS')</script>`
   - `<SCRIPT SRC="...">`
   - `<script>document.cookie</script>`

2. **イベントハンドラ**
   - `<img src=x onerror=alert(1)>`
   - `<svg onload=alert(1)>`
   - `<body onload=alert('XSS')>`
   - `" onmouseover="alert('XSS')"`

3. **JavaScript URI**
   - `javascript:alert('XSS')`
   - `javascript:alert(document.domain)`
   - `<a href="javascript:alert('XSS')">Click</a>`

4. **iframe**
   - `<iframe src="javascript:alert(1)"></iframe>`
   - `<iframe src=javascript:alert(1)>`

5. **エンコーディング**
   - URLエンコード: `%3Cscript%3Ealert%281%29%3C%2Fscript%3E`
   - HTMLエンティティ: `&lt;script&gt;alert(1)&lt;/script&gt;`

6. **コンテキスト破壊**
   - `"><script>alert(1)</script>`
   - `</title><script>alert(1)</script>`

7. **CSSインジェクション**
   - `/style/background:url("javascript:alert('XSS')")`

8. **ポリグロットペイロード**
   - 複数のコンテキストで動作するペイロード

### 検知メカニズム

OpenAppSecは以下の方法でXSSを検知します：

1. **ペイロードのデコードと正規化**
   - HTMLエンティティ、URLエンコードを再帰的にデコード

2. **攻撃インジケーターの検出**
   - スクリプトタグ: `<script>`, `<SCRIPT>`
   - イベントハンドラ: `onerror`, `onload`, `onmouseover`
   - JavaScript URI: `javascript:`
   - 危険な関数: `alert()`, `document.cookie`, `eval()`

3. **信頼度スコアリング**
   - 複数のインジケーターが存在する場合、信頼度が高くなる
   - コンテキスト評価エンジンが信頼度を調整

---

## minimumConfidenceの動作

### 信頼度レベル

OpenAppSecは各リクエストに信頼度スコアを割り当てます：

- **medium**: 低い閾値（より多くのイベントが検知される、誤検知の可能性が高い）
- **high**: バランスの取れた閾値（デフォルト）
- **critical**: 非常に高い閾値（誤検知は少ないが、低信頼度の悪意のあるトラフィックを通す可能性）

### 動作例

| 攻撃パターン | モデルが割り当てる信頼度 | minimumConfidence: medium | minimumConfidence: high | minimumConfidence: critical |
|------------|----------------------|-------------------------|------------------------|---------------------------|
| `' OR 1=1` | high | ✅ ブロック | ✅ ブロック | ❌ ブロックされない可能性 |
| `<script>alert(1)</script>` | medium | ✅ ブロック | ❌ ブロックされない | ❌ ブロックされない |
| `1 OR 1=1` (クォートなし) | medium | ✅ ブロック | ❌ ブロックされない | ❌ ブロックされない |
| `' UNION SELECT * FROM users --` | high/critical | ✅ ブロック | ✅ ブロック | ✅ ブロック |

---

## prevent-learnモードでの動作

### 学習レベル

OpenAppSecは以下の学習レベルを持ちます：

1. **Kindergarten**: 初期段階
2. **Primary School**: 基本的な学習
3. **High School**: 中級レベル
4. **Graduate**: 推奨される最小レベル（Preventモードに移行可能）
5. **Master**: 高度な学習
6. **PhD**: 最高レベル

### 学習中の動作

- **prevent-learnモード**では、学習しつつブロックも行います
- 学習レベルが低い（Kindergarten/Primary School）場合、検知精度が低い可能性があります
- **Graduateレベル**に達するまで、検知精度が低い可能性があります

### 推奨事項

1. **初期導入時**: `detect-learn`モードで学習データを収集
2. **Graduateレベル到達後**: `prevent-learn`モードでCritical信頼度のイベントをブロック
3. **Master/PhDレベル到達後**: `prevent-learn`モードでHigh信頼度以上のイベントをブロック

---

## テストパターンの推奨

### SQL Injectionテストパターン（推奨）

```bash
# 基本的なパターン
' OR 1=1
' OR '1'='1'
OR 1=1
admin'--

# UNION SELECT
' UNION SELECT * FROM users --
' UNION SELECT NULL, user, password FROM users --
1' UNION SELECT NULL--

# DROP TABLE
'; DROP TABLE users; --
'; DROP TABLE users--

# エンコーディング
%27%20OR%201%3D1  # URLエンコード
OR/**/1=1         # コメント挿入
SeLeCt * FrOm users  # 大文字小文字混在

# 時間ベース
SLEEP(5)
BENCHMARK(1000000, MD5('test'))
```

### XSSテストパターン（推奨）

```bash
# スクリプトタグ
<script>alert('XSS')</script>
<script>document.cookie</script>

# イベントハンドラ
<img src=x onerror=alert(1)>
<svg onload=alert(1)>
<body onload=alert('XSS')>

# JavaScript URI
javascript:alert('XSS')
javascript:alert(document.domain)

# iframe
<iframe src="javascript:alert(1)"></iframe>

# コンテキスト破壊
"><script>alert(1)</script>
</title><script>alert(1)</script>

# エンコーディング
%3Cscript%3Ealert%281%29%3C%2Fscript%3E  # URLエンコード
```

---

## 現在の設定との比較

### 現在の設定

```yaml
webAttacks:
  overrideMode: prevent
  minimumConfidence: medium
```

### 推奨設定（初期導入時）

```yaml
webAttacks:
  overrideMode: prevent-learn
  minimumConfidence: medium
```

### 推奨設定（本番環境）

```yaml
webAttacks:
  overrideMode: prevent-learn
  minimumConfidence: high  # デフォルト
```

---

## まとめ

1. **OpenAppSecはMLベースのWAF**で、エンコーディングや難読化にも対応
2. **minimumConfidence: medium**は最も低い閾値で、より多くの攻撃を検知
3. **prevent-learnモード**では学習中で、検知精度が低い可能性がある
4. **学習レベル**が低い場合、検知精度が低い可能性がある
5. **より明確な攻撃パターン**を使用することで、検知率が向上する可能性がある

---

## 参考リンク

- [OpenAppSec公式ドキュメント](https://docs.openappsec.io/)
- [OpenAppSec ML技術の詳細](https://www.openappsec.io/post/deep-dive-into-open-appsec-machine-learning-technology)
- [SQL Injection検知技術](https://www.openappsec.io/post/open-appsec-ml-based-waf-effectively-defeats-modern-sqli-evasion-techniques)
- [OWASP Top 10対策](https://www.openappsec.io/post/how-to-deal-with-owasp-top-10-attacks-using-open-appsec-open-source-waf)
