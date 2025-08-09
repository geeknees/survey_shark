# チャット不安定の原因と修正計画

本ドキュメントは、チャット機能の不安定挙動を改善するための修正点の洗い出しと対応計画です。各項目は小さく分割し、順に修正します。

注: 旧ドキュメント docs/chat_stability_fixes.md の内容を統合しました（本書が最新版）。

## 現状の症状（観察）
- Enter キー送信が不発になるケースがある（ローディングのみ表示）。
- ストリーミング更新と最終更新が競合し、瞬間的なチラつきが出ることがある。
- 会話完了バナーが二重に表示されることがある。

## 修正タスク（チェックリスト）
- [x] Fix#1: Enter 送信で requestSubmit() を使用し、クリック送信とロジックを統一
- [x] Fix#2: Turbo Stream 取りこぼし対策の軽量フォールバック（/messages 部分取得 + Stimulus）
- [x] Fix#3: ストリーミング更新のデバウンス調整（150ms）と最終更新の整流化
- [x] Fix#4: 完了バナーの重複表示を解消（表示箇所の一箇所化）
- [x] Fix#5: Turbo Streams 受信の有効化（ActionCable ルートのマウントと importmap ピン）

## CF-1: PII警告パーシャル不足によりブロードキャスト失敗
- 症状: `PiiDetectJob` が `conversations/pii_warning` パーシャルを `broadcast_append_to` するが、該当パーシャルが存在しないため例外が発生し得る。
- 影響: PII検出時のジョブが失敗し、以降のストリーム更新やUI反映が途切れる可能性。
- 対応: `app/views/conversations/_pii_warning.html.erb` を追加。

## CF-2: 会話完了ブロックの重複表示（リダイレクトスクリプト二重）
- 症状: `app/views/conversations/show.html.erb` で「Conversation Complete Check」が2箇所に重複し、完了バナーやリダイレクトスクリプトが二重実行される。
- 影響: 画面遷移が不安定、UIが重複表示。
- 対応: 冒頭側の重複ブロックを削除し、メッセージ領域下の1箇所に集約。

## CF-3: フォーム送信がフルリロードになりストリームを取りこぼす
- 症状: `local: true` によりフォーム送信でページ遷移（フルリロード）。ActionCable/Turbo Streamsの購読が一時切断され、ストリーミング更新を取りこぼすことがある。
- 影響: 返信の逐次反映が途切れる/遅延する。ローディング解除のタイミングが揺らぐ。
- 対応: Stimulusで `submit` をフックし `fetch` で非遷移POST（CSRF考慮）に切り替え。コントローラは現状どおり `redirect_to` でも問題なし（クライアントはfetchのため遷移しない）。同様にスキップフォームも非遷移化。

## CF-4: `check_and_auto_close!` の二重呼び出し
- 症状: `Interview::StreamingOrchestrator` でターン上限到達時に `check_and_auto_close!` を重複呼び出し。
- 影響: 余計なDBアクセス/ログ出力のノイズ。
- 対応: 重複行を削除。

## CF-5: 互換イベントの二系統混在（解消済み）
- 症状: 旧 `OrchestrateInterviewJob` は `<script>document.dispatchEvent('chat:response-complete')</script>` を送出。一方、新ストリーミング系は `data-form-reset` スパンでフォームリセットをトリガー。
- 影響: 二重リセット/タイミング差による一時的な状態不整合が起き得る。
- 対応: 旧 `OrchestrateInterviewJob` を削除し、`Interview::BroadcastManager` の `data-form-reset` 方式に統一。未使用の `form_reset_controller.js` も削除。

---

対応順序（第一弾）
1) CF-1: PII警告パーシャルの追加
2) CF-2: 会話完了ブロックの重複削除
3) CF-3: フォーム送信の非遷移化（チャット/スキップ）
4) CF-4: `check_and_auto_close!` の重複削除
5) CF-5: リセット方式の統一（旧ジョブと未使用コントローラの削除）

補足（イベント監視の整理）
- `chat_composer_controller.js` と `skip_form_controller.js` の `chat:response-complete` 監視を撤去し、`#messages` 配下への `data-form-reset` 追加を検知する MutationObserver に統一。
- これにより、フォームのリセットは Turbo Stream による `broadcast_final_update` で確実に発火し、ページ遷移やイベント競合の影響を受けにくくなる。

効果確認ポイント
- アシスタント返信のストリーム更新が中断せず、逐次表示される
- 送信後ローディングが確実に解除される（MutationObserver経由のリセットも動作）
- PII検出時に警告バナーが表示され、ジョブエラーが出ない
- 完了時のバナー/リダイレクトが一度だけ表示・実行される

セットアップ変更（Turbo Streams / ActionCable）
- ルートに Cable をマウント: `config/routes.rb` に `mount ActionCable.server => "/cable"`
- レイアウトにメタタグを追加: `app/views/layouts/application.html.erb` に `<%= action_cable_meta_tag %>`
- importmap に ActionCable をピン: `config/importmap.rb` に `pin "@rails/actioncable", to: "actioncable.esm.js"`

小さな改善（UX/堅牢性）
- IME入力時のEnter誤送信防止（`event.isComposing` / compositionフラグで抑止）
- ストリーミング更新のデバウンスを150msに調整（UIのガタつきを軽減）
- ローディング文言の微調整（ユーザー期待値を明確化）
- ログ出力の静音化（`window.SURVEY_SHARK_DEBUG` が true のときのみ debug/warn を表示）
- メッセージ再取得の頻度を緩和（試行2回、1.5s間隔、初回待機0.7s）
- fetch送信のヘッダ強化（`X-Requested-With: XMLHttpRequest` 付与）
- スキップ直後の質問選択のズレを修正（カウント0時は最初の質問を出す）
- メッセージ自動スクロール（最新メッセージが常に見える）
 - フォーム送信成功後に入力欄を即時クリア（放送待ちせずUXを向上）
 - 送信成功後に10秒間の軽量ポーリングを追加し、ストリーム未受信時でも応答を回収
 - ストリーム/部分更新時に自動スクロールする Stimulus コントローラを追加（`messages-scroller`）
 - LLM へのプロンプト重複（直前ユーザーメッセージの二重投入）を解消

追加の安定化（ストリーム不発時のフォールバック）
- まれにストリーミングが発火しない場合でも、LLMクライアントが返す非ストリーム応答を受け取り、
  `StreamingOrchestrator` 側でメッセージを作成して最終ブロードキャストするよう処理を補完。
