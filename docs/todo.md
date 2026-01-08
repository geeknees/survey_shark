# Survey Shark 開発TODO

## 🔧 コードリファクタリング計画 (2025年8月, アップデート)

*詳細は `docs/refactoring_proposals.md` を参照*

### 🚨 高優先度 - 即座に実装推奨（アップデート）

#### 1. 重複コードの削減
- [x] `app/controllers/concerns/project_access.rb` の作成
  - [x] `generate_anon_hash` メソッドの共通化
  - [x] `find_project_by_token` の統一
  - [x] `check_project_availability` の実装
- [x] `InvitesController`, `ThankYousController`, `ConversationsController` への適用

#### 2. Interview::Orchestratorクラスの分割（継続）
- [x] `app/services/interview/state_machine.rb` の作成
- [x] `app/services/interview/response_generator.rb` の作成
- [x] `app/services/interview/turn_manager.rb` の作成
- [x] 既存Orchestratorの簡略化とリファクタリング

#### 3. セキュリティ関連の改善
- [x] `app/services/security/token_generator.rb` の作成
- [x] トークン生成ロジックの統一
- [ ] パラメータバリデーションの強化

#### 4. JavaScript層の最適化（アップデート）
- [x] `hello_controller.js` の削除（未使用）
- [x] `app/javascript/controllers/mixins/loading_state_mixin.js` の作成（済）
- [ ] `chat_composer_controller.js` の分割とMixin適用

### 🔄 中優先度 - 次のスプリントで実装（アップデート）

#### 5. モデル層の責務分散
- [ ] `app/models/concerns/project_status_management.rb` の作成
- [ ] `app/models/concerns/project_limits.rb` の作成
- [ ] `app/models/concerns/project_analytics.rb` の作成
- [ ] `Project` モデルの簡略化

#### 6. Conversationモデルの拡充
- [x] `app/models/concerns/conversation_state_machine.rb` の作成
- [x] `app/models/concerns/conversation_progress.rb` の作成
- [x] 状態管理ロジックのモデルへの移行

#### 7. LLMクライアントの抽象化改善
- [ ] `app/services/llm/client/mixins/retryable_api_client.rb` の作成
- [ ] `app/services/llm/client/mixins/response_processor.rb` の作成
- [ ] `app/services/llm/message_builder.rb` の作成

#### 8. JavaScript層の統一化（アップデート）
- [x] `app/javascript/services/chat_event_manager.js` の作成（済）
- [x] `app/javascript/services/form_validator.js` の作成（済）
- [ ] イベント管理とバリデーションの統一

#### 9. ヘルパーメソッドの整理
- [ ] `app/helpers/navigation_helper.rb` の作成
- [ ] `app/helpers/projects_helper.rb` の拡充
- [ ] `ApplicationHelper` の分割

### 📋 低優先度 - リファクタリング完了後

#### 10. ビュー層の部分テンプレート化
- [ ] `app/views/projects/_project_card.html.erb` の作成
- [ ] `app/views/projects/_project_status.html.erb` の作成
- [ ] `app/views/shared/_authenticated_navigation.html.erb` の作成

#### 11. 設定の外部化
- [ ] `config/application.yml` の作成
- [ ] マジックナンバーの設定ファイルへの移行
- [ ] 環境固有設定の整理

#### 12. バックグラウンドジョブの最適化
- [ ] `app/services/analysis/conversation_pipeline.rb` の作成
- [ ] `AnalyzeConversationJob` の分離
- [ ] エラーハンドリングの改善

#### 13. テストの改善
- [ ] `test/support/interview_test_helpers.rb` の作成
- [ ] JavaScript テストの追加
- [ ] テスト構造の整理

### 未分類
- [ ] 必須回答により回答回数が超えた場合にバーのUIのレイアウトか崩れる
- [ ] 回答が追えた場合も（必須回答により回数が超えた場合）終了に切り替わらない
- [ ] Initial Questionが採用されていない

### ✅ 完了済み
- [x] アンケートの最初に質問が表示されない
- [x] gem "ruby-openai" への移行
- [x] AIからのレスポンスがない
- [x] ターンが終わっても回答を続けられる（終了しない）
- [x] OpenAIからのレスポンスが表示されない（There was an exception - NoMethodError(undefined method 'user' for an instance of Session)）
- [x] スキップボタンが動かない
- [x] チャット入力後、AIから返信ががあるまでローディングアニメーションを表示
- [x] プロジェクトの削除ができない
- [x] Fix error: No route matches [GET] "/conversations/2/skip"
- [x] ナビゲーション用のメニューバーを追加
- [x] Adminのパスワード変更機能
- [x] 回答リンクをコピーボタンをしたときのインタラクションを追加
- [x] 最初に聞く質問はプロジェクト作成時に入力して固定にする
- [x] 回答のログをすべて見れるようにする
- [x] AIが会話を終了したと判定したときには回答を完了する
- [x] チャットをエンターで送信するとAIが返信を生成中...が表示されるが、そこから動かない

### 🔲 未完了
- [x] もう一度回答するボタンから始めると最初の質問が表示されない
- [ ] 終了時のメッセージをもっと自動で終了したことがわかるように
- [ ] 個人情報フィルターが動いていない

---

## 📝 開発ガイドライン

### 実装順序
1. **高優先度**: セキュリティ・安定性に関わる重複コードとOrchestratorの分割
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