# チャットワークフロー（Stimulus / View / Controller / Service / Model）

本書は、会話（チャット）機能のリファクタリングに向けて、現行の責務分割とフローを俯瞰できるようにまとめたものです。UI と非同期処理、ストリーミング、PII マスク、会話完了・分析までを一気通貫で示します。

## 全体フローチャート

```mermaid
flowchart LR
  subgraph StimulusUI [Stimulus / UI]
    A1[chat_composer_controller] --> A2[messages_refresher_controller]
    A1 --> A3[messages_scroller_controller]
  end

  subgraph ViewLayer [View ERB/Turbo]
    V1[conversations/show + forms] --> V2[_messages]
    V2 --> V3[_message]
  end

  subgraph Ctrl [Controller Rails]
    C1[ConversationsController#show] --> V1
    C2[ConversationsController#create_message]
    C3[ConversationsController#skip]
  end

  subgraph JobsQ [Jobs ActiveJob]
    J1[PiiDetectJob]
    J2[StreamAssistantResponseJob]
    J3[AnalyzeConversationJob]
  end

  subgraph Svc [Services]
    S1[StreamingOrchestrator]
    S2[FallbackOrchestrator]
    S3[PromptBuilder]
    S4[BroadcastManager]
    S5[PII::Detector]
    S6[ConversationAnalyzer]
    S7[LLM::Client::OpenAI]
  end

  subgraph ModelLayer [Model DB]
    M1[(Conversation)]
    M2[(Message)]
  end

  %% Main flow
  A1 -->|POST create_message| C2 --> M2
  A1 -->|POST skip| C3 --> M2

  C2 --> J1
  C2 --> J2
  C3 --> J2

  J1 --> V3
  J1 --> V1

  J2 --> S1 --> V2
  S1 --> M1
  S1 --> J3

  J2 --> S2 --> V2
  S2 --> M1
  S2 --> J3

  %% UI safety net
  V2 --> A1
  V1 --> A2
```

## 各レイヤの主な責務と参照ファイル

- Stimulus:
  - chat_composer_controller.js: 送信・Enter送信、ローディング、フォームリセット信号検知、失敗時の簡易ポーリング
  - messages_refresher_controller.js: Turbo Stream取りこぼし時の部分更新
  - messages_scroller_controller.js: 新規メッセージで自動スクロール
- View:
  - conversations/show.html.erb, _messages.html.erb, _message.html.erb, _pii_warning.html.erb
- Controller:
  - ConversationsController#show/#create_message/#skip
- Service/Jobs:
  - Interview::StreamingOrchestrator / FallbackOrchestrator / PromptBuilder / BroadcastManager
  - LLM::Client::OpenAI
  - PiiDetectJob, PII::Detector
  - AnalyzeConversationJob, Analysis::ConversationAnalyzer
- Model:
  - Conversation, Message

## 状態遷移（会話の粗い流れ）

```mermaid
stateDiagram-v2
  [*] --> intro
  intro --> enumerate: 最初のユーザー回答
  enumerate --> enumerate: 列挙継続
  enumerate --> recommend: 3件到達 or 終了表明
  recommend --> choose
  choose --> deepening
  deepening --> deepening: 最大回数に達するまで
  deepening --> summary_check: 規定回数(max_deep)
  summary_check --> done
  note right of done: doneでfinished_at設定, 分析Job起動
```

参考: 失敗時は state=fallback に移行し、固定3問で完了に導きます。

## 重要イベントとブロードキャスト

- streaming 中: 最初のチャンクで assistant message を作成し append、その後は内容を更新して replace。BroadcastManager が 150ms デバウンスで置換を送出。
- 完了/確定時: messages 全体を replace してUI整合性を確保し、フォームリセット信号を埋め込み（Hidden span + CustomEvent）。
- PII 検出時: 対象 message の replace、および PII 警告バナーを append。

---

補足のアルゴリズム詳細は docs/chat_algorithms.md を参照してください。

## 詳細: 状態マシン（条件付き）

```mermaid
stateDiagram-v2
  [*] --> intro
  intro --> enumerate: user_message != "[インタビュー開始]"
  enumerate --> enumerate: pain_points < 3 && !completion_words
  enumerate --> recommend: pain_points >= 3 || completion_words
  recommend --> choose
  choose --> deepening
  deepening --> deepening: deep_turns < max_deep
  deepening --> summary_check: deep_turns >= max_deep
  summary_check --> done
  done --> [*]

  note right of enumerate: completion_words ∋ 「以上/それだけ/終わり/ない/特にない」
  note right of deepening: deep_turns はユーザーの深掘り応答数に基づく
```

## 詳細: ストリーミング配信（シーケンス）

```mermaid
sequenceDiagram
  participant U as Stimulus(chat_composer)
  participant V as View(Turbo Streams)
  participant C as Rails Controller
  participant J as StreamAssistantResponseJob
  participant O as StreamingOrchestrator
  participant L as LLM::Client::OpenAI
  participant B as BroadcastManager
  participant DB as DB
  participant P as PiiDetectJob
  participant F as FallbackOrchestrator

  U->>C: POST create_message
  C->>C: 残ターン/完了判定
  C->>DB: Message(user) 作成
  C-->>J: enqueue
  C-->>P: enqueue (並行)
  U-->>U: ローディング表示、軽量ポーリング開始

  J->>O: process_user_message_with_streaming
  O->>O: 次状態判定/Prompt生成
  O->>L: stream_chat(messages)
  L-->>O: token チャンク返却(複数)
  O->>DB: 最初のチャンクで assistant Message 作成
  O->>B: broadcast_streaming_update (デバウンス)
  B-->>V: message_#id replace
  V-->>U: Turbo反映（スクロール）

  L-->>O: 最終確定 or 非stream応答
  O->>B: broadcast_final_update
  B-->>V: #messages replace + フォームリセット信号
  V-->>U: reset signal 受信→フォーム解除

  opt 失敗
    L--xO: 例外
    O->>O: fallback_mode=true
    O->>F: 固定質問/完了処理
    F->>B: broadcast_message_update / final_update
  end
```

## 責務境界（Boundary 図）

```mermaid
flowchart TB
  subgraph UI[Stimulus Controllers]
    ui1[chat_composer]
    ui2[messages_refresher]
    ui3[messages_scroller]
  end

  subgraph Views[ERB + Turbo Streams]
    vw1[show/_messages/_message]
    vw2[_pii_warning]
  end

  subgraph C[Controller]
    cc1[ConversationsController]
  end

  subgraph Jobs[ActiveJob]
    jb1[StreamAssistantResponseJob]
    jb2[PiiDetectJob]
    jb3[AnalyzeConversationJob]
  end

  subgraph Services
    sv1[StreamingOrchestrator]
    sv2[FallbackOrchestrator]
    sv3[PromptBuilder]
    sv4[BroadcastManager]
    sv5[LLM::Client::OpenAI]
    sv6[PII::Detector]
    sv7[Analysis::ConversationAnalyzer]
  end

  subgraph Models
    m1[(Conversation)]
    m2[(Message)]
  end

  %% Allowed directions
  UI -->|submit/enter| C
  C -->|create/find| Models
  C -->|enqueue| Jobs
  Jobs --> Services
  Services --> Models
  Services --> Views
  Views --> UI

  %% PII path
  Jobs -->|mask result| Views
```
