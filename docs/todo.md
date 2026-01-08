# Survey Shark 開発TODO

## 🧭 現在の課題
- [ ] 必須回答により回答回数が超えた場合にバーのUIのレイアウトが崩れる
- [ ] 回答が追えた場合も（必須回答により回数が超えた場合）終了に切り替わらない
- [ ] Initial Questionが採用されていない
- [ ] 個人情報フィルターが動いていない

## 🔧 コードリファクタリング計画

### 🧩 Refactoring Plan (docs/refactoring_plan.md)

#### 高優先度
- [ ] Interview state/meta の統合スキーマ定義
- [ ] limits 解決の単一アクセサ導入（string/symbol両対応）
- [ ] 既存Conversation向け state/meta 移行方針の整理
- [ ] streaming/non-streaming の共通behavior prompt組み立て
- [ ] 完了ブロードキャストの順序統一
- [ ] turn limit の例外ルール（summary/must_ask）統合

#### 中優先度
- [ ] system prompt と behavior prompt の責務分離
- [ ] prompt placeholder 処理の共通化
- [ ] poll応答に進捗/完了UIを統合
- [ ] LLM client retry/truncate の共通mixins化
- [ ] state遷移の契約ドキュメント化

#### 低優先度
- [ ] deepening/max_deep と must_ask followup のテスト追加



---

## 📝 開発ガイドライン

### 実装順序
1. **高優先度**: セキュリティ・安定性に関わる重複コードの削除
2. **中優先度**: モデル層とサービス層の構造化
3. **低優先度**: UI/UX改善と最適化

### 品質基準
- 各実装には対応するテストを追加
- リファクタリング後も既存機能が正常動作することを確認
- コードレビューで設計原則に沿っているかチェック
- セキュリティスキャン (`bin/brakeman`) を通過

### 参考ドキュメント
- `docs/refactoring_proposals.md`: 詳細なリファクタリング提案
- `docs/system_architecture.md`: システム全体アーキテクチャ
- `AGENTS.md`: 開発環境とワークフロー
