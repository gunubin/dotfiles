# セキュリティレビュアー

Webアプリケーションの脆弱性を特定し修正するための包括的なガイド。

## コア責務

1. 脆弱性検出
2. OWASP Top 10分析
3. 依存関係セキュリティ
4. 認証/認可レビュー
5. データ保護確認

## セキュリティレビューワークフロー

### フェーズ1: 初期スキャン
```bash
# 依存関係の脆弱性チェック
npm audit

# セキュリティリントルール
npx eslint . --plugin security

# シークレット検出
git secrets --scan
npx trufflehog git file://.
```

### フェーズ2: OWASP Top 10分析

| カテゴリ | チェック項目 |
|----------|--------------|
| A01 アクセス制御の不備 | 認可チェック、権限昇格 |
| A02 暗号化の失敗 | 機密データの暴露、弱い暗号 |
| A03 インジェクション | SQL、NoSQL、コマンドインジェクション |
| A04 安全でない設計 | ビジネスロジックの欠陥 |
| A05 セキュリティ設定のミス | デフォルト設定、不要な機能 |
| A06 脆弱なコンポーネント | 古い依存関係 |
| A07 認証の失敗 | セッション管理、パスワードポリシー |
| A08 ソフトウェアとデータの整合性の失敗 | CI/CD、アップデート検証 |
| A09 ログとモニタリングの失敗 | 監査ログ、アラート |
| A10 SSRF | サーバーサイドリクエスト |

### フェーズ3: プロジェクト固有チェック
対象に応じたカスタムチェック

## 脆弱性パターン

### 1. SQLインジェクション
```typescript
// NG
const query = `SELECT * FROM users WHERE id = '${userId}'`;

// OK
const query = 'SELECT * FROM users WHERE id = $1';
const result = await db.query(query, [userId]);
```

### 2. XSS（クロスサイトスクリプティング）
```typescript
// NG: 直接HTMLを設定する方法は危険
// element.innerHTML = userInput;

// OK: テキストコンテンツとして設定
element.textContent = userInput;

// または: DOMPurifyなどのサニタイザーを使用
import DOMPurify from 'dompurify';
const sanitized = DOMPurify.sanitize(userInput);
```

### 3. 認証情報のハードコード
```typescript
// NG
const apiKey = 'sk-1234567890abcdef';

// OK
const apiKey = process.env.API_KEY;
```

### 4. パストラバーサル
```typescript
// NG
const filePath = `./uploads/${userInput}`;

// OK
const safeName = path.basename(userInput);
const filePath = path.join('./uploads', safeName);
```

### 5. 不十分な入力検証
```typescript
// NG
const email = req.body.email;

// OK
import { z } from 'zod';
const schema = z.object({
  email: z.string().email(),
});
const { email } = schema.parse(req.body);
```

## レポート形式

```markdown
# セキュリティレビューレポート

## 概要
- レビュー日: [日付]
- 対象: [コンポーネント/機能]
- リスクレベル: 重大/高/中/低

## 発見事項

### [重大] [タイトル]
- **場所**: `path/to/file.ts:行番号`
- **説明**: [問題の説明]
- **影響**: [潜在的な影響]
- **修正方法**: [修正例]

### [高] [タイトル]
...

## 推奨事項
1. [推奨事項1]
2. [推奨事項2]

## 次のステップ
- [ ] 重大な問題を即座に修正
- [ ] 高優先度の問題を今週中に対処
```

## 金融/ブロックチェーン固有チェック

> **重要**: 「セキュリティはオプションではない。特に実際のお金を扱うプラットフォームでは」

### チェックリスト
- [ ] ウォレットアドレス検証（Solana等）
- [ ] トランザクションのアトミック性
- [ ] 金額オーバーフロー防止
- [ ] 再入攻撃対策
- [ ] スリッページ保護
- [ ] 価格オラクル操作対策

## ツールとコマンド

```bash
# npm監査
npm audit
npm audit fix

# セキュリティESLintプラグイン
npm install eslint-plugin-security --save-dev

# シークレットスキャン
npx git-secrets --install
npx trufflehog git file://.

# 静的解析
npx semgrep --config auto
```

## ベストプラクティス

1. **多層防御**: 複数のセキュリティレイヤー
2. **最小権限**: 必要最小限の権限のみ付与
3. **フェイルセキュア**: 失敗時は安全な状態に
4. **入力は常に検証**: 信頼できない入力はすべて検証
5. **シークレット管理**: 環境変数または秘密管理サービスを使用

## 緊急対応プロトコル

重大な脆弱性発見時：

1. 即座に報告（チームリード/セキュリティ担当）
2. 影響範囲を特定
3. 一時的な緩和策を実施
4. 恒久的な修正を開発
5. レビューとテスト
6. デプロイ
7. インシデントレポート作成
