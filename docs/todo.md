## `/conversations/:id` 動作不安定性の問題と改善案 (2025/8/3)

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
- [ ] ストリーミング更新とファイナル更新を統一したインターフェースに変更
- [ ] メッセージ更新時のDOM競合を防ぐため、debounce処理を追加
- [ ] ブロードキャスト失敗時のフォールバック機能実装

#### B. **JavaScript状態管理強化**
- [ ] フォーム状態のより確実なリセット機構実装
- [ ] WebSocket切断時の自動再接続とUIフィードバック
- [ ] ボタン無効化ロジックの改善（二重送信防止）

#### C. **データベース整合性確保**
- [ ] Conversation作成時のparticipant参照検証
- [ ] 外部キー制約エラーのハンドリング改善
- [ ] データ削除時のカスケード処理見直し

#### D. **非同期処理の安定化**
- [ ] 同一conversationへの並行ジョブ実行制限（Redis lock等）
- [ ] ジョブ実行前の状態検証強化
- [ ] エラー発生時のより詳細なロギング

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

## その他の改善点

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
- [ ] 回答のログをすべて見れるようにする
- [ ] AIが会話を終了したと判定したときには回答を完了する
- [ ] もう一度回答するボタンから始めると最初の質問が表示されない
