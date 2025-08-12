# チャット関連アルゴリズム補足

会話（チャット）機能で用いている主要なアルゴリズム・判定ロジックを簡潔に整理します。実装はレポジトリ内の各サービス/ジョブ/モデルを参照してください。

## 1. ターン制御・完了判定

- 上限: `project.limits["max_turns"]`（デフォルト 12）
- 判定箇所: `ConversationsController#create_message/#skip` と Orchestrator/Fallback 内の先頭でユーザーターン数を算出し、上限到達なら `finished_at` を設定し完了応答を生成。
- 完了時: AnalyzeConversationJob を enqueue、プロジェクトの auto-close 判定 `project.check_and_auto_close!` を呼び出し（StreamingOrchestrator 経由）。

## 2. 会話状態遷移（StreamingOrchestrator）

- 概要: `determine_next_state(user_message)` にて、`intro → enumerate → recommend → choose → deepening → summary_check → done` を推移。
  - `intro`: 初回の合図メッセージなら stay、それ以外は `enumerate` へ。
  - `enumerate`: ユーザー列挙数が3以上、または終了系語（「以上」「それだけ」「終わり」「ない」「特にない」）を含むと `recommend`。
  - `recommend → choose → deepening`: 順送り。
  - `deepening`: `max_deep` 回（プロジェクト設定、デフォルト2）まで深掘り継続、到達で `summary_check`。
  - `summary_check → done`。

## 3. プロンプト生成（PromptBuilder）

- `system_prompt`: トーン（`polite_soft` 等）、深掘り回数 `max_deep`、必ず聞く/聞かない項目、ゴールを統合した「役割/制約/流れ」指示を生成。
- `behavior_prompt_for_state(state)`: 各状態に応じた追加指示。
  - `summary_check` では `{summary}` を会話要約で置換。
  - `recommend` では `{most_important}` を列挙中の最重要候補で置換。

## 4. LLM クライアント（OpenAI）とストリーミング

- `LLM::Client::OpenAI#stream_chat`:
  - `messages` を OpenAI 形式に整形。
  - `stream` ブロックでチャンクを受け取り、蓄積して 400 文字上限を超えた場合は文末（「。」「？」「！」）を優先して安全にトリム。
  - ストリーミング失敗時は非ストリームのフォールバックを実行。
- エラー/例外: 最大全1回のリトライ。失敗は `OpenAIError` として上位へ。

### LLM エラー時のリトライ/フォールバック基準

| 事象 | リトライ回数 | フォールバック条件 | 発火箇所/備考 |
|---|---:|---|---|
| OpenAI::Error（API一時障害等） | 1回 | リトライ後も失敗→`OpenAIError` 発生 | `LLM::Client::OpenAI#generate_response` |
| ネットワーク/その他標準例外 | 1回 | リトライ後も失敗→`OpenAIError` 発生 | 同上 |
| ストリーム中の例外 | 0回 | 非ストリーム呼び出しにフォールバック（失敗なら `OpenAIError`） | `#stream_response` 内部 |
| 非ストリーム呼び出しの失敗 | 0回 | 直ちに `OpenAIError` | `#stream_chat` 非ブロック経路 |
| ジョブ側の最終救済 | — | `OpenAIError` または任意の `StandardError` を捕捉→FallbackOrchestrator | `StreamAssistantResponseJob#process_conversation` |
| APIキー未設定 | — | クライアント初期化で `ArgumentError`→ジョブが捕捉→Fallback | `OpenAI.new` 初期化時 |
| テスト環境での強制エラー | — | `ENV["SIMULATE_LLM_ERROR"] == "true"` → 例外を投げFallbackへ | `StreamingOrchestrator#test_llm_client` |

フォールバック移行時は `conversation.state = "fallback"` と `meta.fallback_mode = true` を付与し、固定3問で完了まで誘導します。

## 5. ストリーミング配信（BroadcastManager）

- 150ms デバウンスで `message_#{id}` の replace を発行（UI のちらつき抑制）。
- 最終確定時は `#messages` を replace し整合性を担保、併せてフォームリセット信号（hidden span と `chat:response-complete` CustomEvent）を append。
- 失敗時は最終手段としてクライアント再読み込みスクリプトを append。

## 6. PII 検出・マスキング（PiiDetectJob + PII::Detector）

- 対象: ユーザー投稿メッセージのみ（`Message#user?`）。
- 既処理判定: `message.meta["pii_processed"]`。未処理のみ対象。
- 検出: `PII::Detector#analyze(text)` が LLM（または偽クライアント）で以下を抽出。
  - `PII_DETECTED: true/false`
  - `MASKED_TEXT: ...`（元文に対する置換済みテキスト）
  - 項目一覧（氏名/電話/メール/住所/学校/会社 等）
- 結果反映: `message.update!(content: masked_text, meta: { pii_processed: true, pii_detected: true, ... })`。
- 通知: 対象メッセージの replace、PII 警告バナーの append を Turbo Stream で送出。

### PII 項目別のマスク例（Fake LLM 実装に準拠）

| 項目 | 検出パターン例 | 置換例 |
|---|---|---|
| 氏名 | 田中/佐藤/山田/鈴木/高橋 等 | `[氏名]` |
| 電話番号 | `\d{2,4}-\d{2,4}-\d{4}` | `[電話番号]` |
| メール | `user@example.com` のような一般的メール正規表現 | `[メールアドレス]` |
| 住所 | `東京都..区`/`大阪府..市`/`..県..市..町` | `[住所]` |
| 会社名 | `株式会社◯◯`/`有限会社◯◯` | `[会社名]` |
| 学校名 | `◯◯大学/高校/中学校/小学校` | `[学校名]` |

その他ポイント:
- スキップメッセージ（`"[スキップ]"`）は PII 検出をスキップ。
- `meta.original_content_hash` にはマスク前テキストの SHA-256 が保存され、ログ等に生文を保持しません。
- LLM ベース検出（`PII::Detector`）は `PII_DETECTED`/`MASKED_TEXT`/`DETECTED_ITEMS` をパースして結果を反映します。失敗時は安全側（未検出扱い）で継続します。

## 7. Fallback Orchestrator（固定質問）

- 条件: Streaming ジョブで LLM 例外等が発生した場合、または `conversation.meta["fallback_mode"]`。
- 動作: 固定3問を順に提示。ユーザー「[スキップ]」は列挙に含めず、ユーザー投稿数で次の質問番号を決定。
- 終了: 3問目以降は感謝メッセージで終了し `state: done, finished_at: now`、AnalyzeConversationJob を enqueue。

## 8. 解析（AnalyzeConversationJob + Analysis::ConversationAnalyzer）

- 対象: `finished_at` 設定済みの会話。
- 手順:
  1) ユーザーメッセージ（`[スキップ]` 除く）を連結
  2) 正規化 / 分かち書き（TinySegmenter）
  3) RAKE でキーワード抽出
  4) LLM によるテーマ・要約抽出（`THEME/JTBD/SUMMARY/SEVERITY/EVIDENCE` 形式）
  5) Insight（テーマ）配列を構築
- InsightCard 反映: 既存テーマは頻度/証拠をマージ、新規は作成。
- 信頼度: `0.7*freq(≦1) + 0.3*quotes(≦1)` を H/M/L にラベル化。

## 9. UI 安全網（取りこぼし対策）

- Stimulus の `messages_refresher_controller`: Turbo Stream 購読初期の取りこぼしを想定し、数回だけ `GET /conversations/:id/messages` で部分更新。
- chat_composer_controller の `pollForAssistantResponse`: 投稿後 10 秒間の軽量ポーリングで新規メッセージ到着を検知し、未着ならフォームリセットをフォールバック実行。

## 10. 参照（主な実装ファイル）

- Controller: `app/controllers/conversations_controller.rb`
- Models: `app/models/{conversation.rb,message.rb}`
- Jobs: `app/jobs/{stream_assistant_response_job.rb,pii_detect_job.rb,analyze_conversation_job.rb}`
- Services (Interview):
  - `streaming_orchestrator.rb`, `fallback_orchestrator.rb`, `prompt_builder.rb`, `broadcast_manager.rb`
- Services (LLM/PII/Analysis):
  - `llm/client/openai.rb`, `pii/detector.rb`, `analysis/conversation_analyzer.rb`
- Stimulus: `app/javascript/controllers/*.js`
- Views: `app/views/conversations/*.erb`
