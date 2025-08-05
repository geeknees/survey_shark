# Survey Shark 開発TODO

## 🔧 コードリファクタリング計画 (2025年8月)

*詳細は `docs/refactoring_proposals.md` を参照*

### 🚨 高優先度 - 即座に実装推奨

#### 1. 重複コードの削減
- [ ] `app/controllers/concerns/project_access.rb` の作成
  - [ ] `generate_anon_hash` メソッドの共通化
  - [ ] `find_project_by_token` の統一
  - [ ] `check_project_availability` の実装
- [ ] `InvitesController`, `ThankYousController`, `ConversationsController` への適用

#### 2. Interview::Orchestratorクラスの分割
- [ ] `app/services/interview/state_machine.rb` の作成
- [ ] `app/services/interview/response_generator.rb` の作成
- [ ] `app/services/interview/turn_manager.rb` の作成
- [ ] 既存Orchestratorの簡略化とリファクタリング

#### 3. セキュリティ関連の改善
- [ ] `app/services/security/token_generator.rb` の作成
- [ ] トークン生成ロジックの統一
- [ ] パラメータバリデーションの強化

#### 4. JavaScript層の最適化
- [ ] `hello_controller.js` の削除（未使用）
- [ ] `app/javascript/controllers/mixins/loading_state_mixin.js` の作成
- [ ] `chat_composer_controller.js` の分割とMixin適用

### 🔄 中優先度 - 次のスプリントで実装

#### 5. モデル層の責務分散
- [ ] `app/models/concerns/project_status_management.rb` の作成
- [ ] `app/models/concerns/project_limits.rb` の作成
- [ ] `app/models/concerns/project_analytics.rb` の作成
- [ ] `Project` モデルの簡略化

#### 6. Conversationモデルの拡充
- [ ] `app/models/concerns/conversation_state_machine.rb` の作成
- [ ] `app/models/concerns/conversation_progress.rb` の作成
- [ ] 状態管理ロジックのモデルへの移行

#### 7. LLMクライアントの抽象化改善
- [ ] `app/services/llm/client/mixins/retryable_api_client.rb` の作成
- [ ] `app/services/llm/client/mixins/response_processor.rb` の作成
- [ ] `app/services/llm/message_builder.rb` の作成

#### 8. JavaScript層の統一化
- [ ] `app/javascript/services/chat_event_manager.js` の作成
- [ ] `app/javascript/services/form_validator.js` の作成
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

---

## 🐛 既存の問題と改善案 (2025/8/3)

### 特定された問題点：

#### 1. **Turbo Streamsのブロードキャスト競合**
- `StreamingOrchestrator`と`FallbackOrchestrator`で異なるブロードキャスト処理
- ストリーミング中に複数の`broadcast_replace_to`が同時発生し、DOMの更新が競合する可能性
- 特に`broadcast_streaming_update`と`broadcast_final_update`の間で競合状態発生

#### 2. **JavaScript状態管理の不整合**
- `chat_composer_controller.js`の`isSubmitting`フラグが適切にリセットされない場合
- `chat:response-complete`イベントのタイミングとフォーム状態の同期問題
- ローディング状態の表示/非表示切り替えの競合状態

#### 3. **データベース制約エラー**
- ログで`SQLite3::ConstraintException: FOREIGN KEY constraint failed`が発生
- Conversationとrelatedモデル間の外部キー制約違反
- 特にparticipant_idが削除されたparticipantを参照している可能性

#### 4. **非同期処理の競合**
- `StreamAssistantResponseJob`実行中の状態変更
- 同一conversationに対する複数のジョブ実行
- Turn制限チェックとメッセージ作成の間でrace condition

#### 5. **WebSocketコネクション問題**
- Cable接続の不安定性（特に開発環境のasync adapter）
- ページリロード時のTurbo Streamsサブスクリプション復元失敗

### 改善案：

#### A. **ブロードキャスト処理の改善**
- [x] ストリーミング更新とファイナル更新を統一したインターフェースに変更
- [x] メッセージ更新時のDOM競合を防ぐため、debounce処理を追加
- [x] ブロードキャスト失敗時のフォールバック機能実装

#### B. **JavaScript状態管理強化**
- [x] フォーム状態のより確実なリセット機構実装
- [x] WebSocket切断時の自動再接続とUIフィードバック
- [x] ボタン無効化ロジックの改善（二重送信防止）

#### C. **データベース整合性確保**
- [ ] Conversation作成時のparticipant参照検証
- [ ] 外部キー制約エラーのハンドリング改善
- [ ] データ削除時のカスケード処理見直し

#### D. **非同期処理の安定化**
- [x] 同一conversationへの並行ジョブ実行制限（Redis lock等）
- [x] ジョブ実行前の状態検証強化
- [x] エラー発生時のより詳細なロギング

#### E. **UX改善**
- [ ] WebSocket接続状況の可視化
- [ ] エラー発生時のユーザーフレンドリーなメッセージ表示
- [ ] ページリロード後の状態復元機能

#### F. **モニタリング強化**
- [ ] Conversation状態の異常検知
- [ ] パフォーマンスメトリクス追加
- [ ] エラーアラート機能実装

### 優先度：
1. **高**: D(非同期処理), A(ブロードキャスト処理)
2. **中**: B(JavaScript状態管理), C(データベース整合性)
3. **低**: E(UX改善), F(モニタリング)

## 📈 その他の機能改善・バグ修正

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
- [ ] もう一度回答するボタンから始めると最初の質問が表示されない
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