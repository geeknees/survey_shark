Below is a right-sized, test-first build plan for SurveyShark (Rails 8 + Hotwire, SQLite, Solid Queue, Kamal, OpenAI).
It starts broad, narrows into incremental chunks, and finishes with ready-to-paste prompts for a code-generation LLM.
All steps assume Minitest (Rails default), Turbo Streams (SSE), and the MVP v1 spec you approved.

⸻

A. System snapshot (1 page)
	•	Core user flow: Consent → Attribute(年齢+任意カスタム) → Pain列挙(≤3) → AI推奨→ユーザー選択 → 深掘り(≤2) → 要約確認(Yes/No+自由記述1欄) → 送信
	•	Admin: Single admin login, projects CRUD, invite links, dashboard (KPI 3), insight board, conversation full view
	•	Tech: Rails 8, Tailwind, Hotwire (Turbo/Stimulus), SQLite(WAL), Solid Queue, Kamal+Let’s Encrypt, OpenAI gpt-4.1 (temp=0.2)
	•	Constraints: No re-open, no export, no embeddings in MVP, no notifications, no CAPTCHAs
	•	PII: LLM-based detection after display, then mask; logging stores masked text only

⸻

B. End-to-end blueprint (milestones → epics → acceptance)

Milestone 0 — Repo bootstrap & quality rails (0.5–1d)
	•	Rails 8 app (API+HTML), Tailwind, Turbo on, SQLite WAL PRAGMA, Solid Queue set
	•	Auth generator for single admin; bin/rails admin:setup Rake task
	•	Kamal skeleton (staging/production), healthcheck /up

Acceptance
	•	rails test green; /up returns 200; admin can log in and change password

⸻

Milestone 1 — Domain model skeleton (1d)
	•	Models & migrations: projects, invite_links, participants, conversations, messages, insight_cards
	•	Validations, enums, JSON columns, foreign keys
	•	Project states: draft/active/closed

Acceptance
	•	DB schema matches spec; basic model tests pass; seed creates sample project (limit 10)

⸻

Milestone 2 — Admin foundations (1–1.5d)
	•	Admin UI: project list/new/edit/show; state toggle; invite link issue/preview URL
	•	Project form required fields (1–8 per spec)
	•	Enforce max responses (start-time count), auto-close behavior

Acceptance
	•	Admin can create/activate project; common invite URL is visible; starting a session increments counter; auto-closed shows “募集は終了しました…”

⸻

Milestone 3 — Consent → Attributes (0.5–1d)
	•	/i/:token start page (consent text) → attributes form (age int 0–120 + custom attributes short text)
	•	Start button = consent; empty age allowed; empty custom allowed unless “必須”属性

Acceptance
	•	Attributes step renders from project config; validation behavior matches spec

⸻

Milestone 4 — Chat shell (1–1.5d)
	•	Turbo Stream chat page and Stimulus controller; message composer with quick replies
	•	Progress (remaining turns + bar), skip link always shown; max turn default 12 (configurable)

Acceptance
	•	User can post a message; assistant placeholder stream renders; skip increments turn count; empty blocked

⸻

Milestone 5 — Interview orchestration (2d)
	•	Interview::Orchestrator (service) + PromptBuilder with system rules
	•	Flow: 列挙→推奨→選択→深掘り(≤2)→要約確認(ON)→完了
	•	Fixed fallback template (3Q) on LLM error after 1 retry

Acceptance
	•	Happy path produces coherent steps; fallback path works when LLM stub forces failure

⸻

Milestone 6 — OpenAI client & streaming (1–2d)
	•	LLM::Client (streaming chat, non-stream complete), adapters: OpenAI + Null/Fake
	•	Server-sent token streaming to Turbo Streams; enforce 400 char truncation

Acceptance
	•	With Fake adapter, deterministic tests pass; with OpenAI, manual smoke passes and respects latency budget (first token ≤ 3s typical)

⸻

Milestone 7 — PII detect & mask (1–1.5d)
	•	Async PiiDetectJob (LLM call) after each user message
	•	On detection: persist masked content, broadcast Turbo Stream replacement + warning banner; logs store masked only

Acceptance
	•	Message initially shows raw, then flips to masked within a moment; banner text is as specified

⸻

Milestone 8 — Analysis pipeline (2d)
	•	On conversation finish: AnalyzeConversationJob
	•	Normalize → TinySegmenter → RAKE → LLM summary & theme naming
	•	Severity auto-estimation, frequency (会話/発言), confidence = 0.7×freq + 0.3×quotes
	•	Build insight_cards (evidence quotes ≤2)

Acceptance
	•	Insight board lists top 5 by frequency priority; cards show required fields

⸻

Milestone 9 — Dashboards & views (1–1.5d)
	•	KPI header (3 metrics) on project show; Insight board page; Conversation full view
	•	No time filters; no export; no shared links

Acceptance
	•	KPIs reflect data; clicking a card reveals representative quotes and conversation link

⸻

Milestone 10 — Limits, error paths, seeds (0.5–1d)
	•	Max responses at start; auto close; “もう一度回答する” button; sample project seeds
	•	System tests for closed project and error fallback

Acceptance
	•	All specified limits and “thank you” flow work end-to-end

⸻

Milestone 11 — Deploy (0.5–1d)
	•	Kamal with Let’s Encrypt, Rails secrets/ENV, volume for SQLite
	•	Health+smoke in staging; production checklist

Acceptance
	•	Staging URL with TLS; admin login & one full conversation captured

⸻

C. Break it down: smaller, iterative chunks

Below are buildable chunks (1–3h each). Each ends “wired in” (no orphan code).

Chunk 0: Rails/Tailwind/Hotwire/Solid Queue bootstrap
	•	Create app; add Tailwind; enable Solid Queue; add /up
	•	Add SQLite WAL PRAGMAs; rails generate authentication:install & admin:setup

Chunk 1: Models/migrations bare minimum
	•	Create projects, invite_links with constraints
	•	Create participants, conversations, messages
	•	Add insight_cards with minimal fields

Chunk 2: Admin: projects CRUD
	•	Routes, controller, views (Tailwind)
	•	Form fields: 1–8; validations; state select (draft/active/closed)

Chunk 3: Invite link issuance & token endpoint
	•	Generate token; /i/:token route; verify project active/not closed; enforce max responses on start

Chunk 4: Consent and attributes UI
	•	Consent copy from project settings
	•	Form with age (0–120, optional) + custom short-text attributes

Chunk 5: Chat frame + Turbo Stream
	•	ConversationsController#show/create
	•	Stimulus controller for composer & quick replies (static choices); skip button; progress

Chunk 6: Orchestrator skeleton with Fake LLM
	•	Build Interview::PromptBuilder (system rules)
	•	Orchestrator states & persistence; use Fake adapter returning canned lines

Chunk 7: Replace Fake with OpenAI client (stream)
	•	LLM::Client with stream_chat; env key; 400 char limit; latency timers
	•	Fallback to fixed 3Q if error after 1 retry

Chunk 8: PII detect mask
	•	PiiDetectJob calling LLM; mask tokens; Turbo Stream replacement + banner
	•	Logging masked content only

Chunk 9: Analysis job (finish-only)
	•	Normalize → TinySegmenter → RAKE → LLM summary/theme → severity & frequency → cards
	•	Insight board list + card detail

Chunk 10: KPIs and acceptance hardening
	•	KPI header; closed message page; もう一度回答 button; seeds; system tests

Chunk 11: Kamal deploy
	•	Traefik + Let’s Encrypt; env; volume; smoke tests

⸻

D. Break it one step further (unit steps with tests)

Each step ~30–60 min, includes tests. Use Minitest (model, controller, system).
Adopt fake adapters for LLM to keep tests deterministic.

	1.	PRAGMAs initializer + /up route & controller test
	2.	admin auth generator + feature test (login required for /projects)
	3.	Project model: validations, state enum; minitest model tests
	4.	InviteLink model: token generation; uniqueness; expiration (though default none); tests
	5.	Admin ProjectsController: index/new/create/edit/update/destroy + system tests
	6.	Project form fields 1–8; validation messages; system tests
	7.	Route /i/:token + guard (draft/closed/limit); request tests
	8.	Participants & Conversations creation on start; test start increments counter
	9.	Consent page render → attributes form; system tests for field behavior (age optional)
	10.	Chat page skeleton with Turbo Stream target + progress; system test ensures presence
	11.	Interview::Orchestrator (no LLM yet): state machine; unit tests for transitions
	12.	LLM::Client::Fake adapter with scripted responses + unit tests
	13.	Integrate orchestrator + Fake; system test: complete conversation no-LLM
	14.	LLM::Client::OpenAI + env config; service tests with VCR-like “stub” (or WebMock)
	15.	Streaming to Turbo Streams; system test: sees stream chunks appended
	16.	Error handling: simulate timeout → fallback to 3Q; system test that flow completes
	17.	PiiDetectJob: enqueue after user message; unit test for masking logic (inject fake response)
	18.	Turbo replacement broadcast + banner UI; system test verifying DOM change
	19.	AnalyzeConversationJob: stub RAKE & LLM; unit test for insight_card creation
	20.	Insight board (top 5 by frequency priority); system tests
	21.	KPIs header; unit test queries; system tests show numbers
	22.	Seeds: sample project; test seed task idempotence
	23.	Close on limit reached; request test for closed behavior
	24.	Kamal config; deploy smoke (outside Rails tests)

⸻

E. Prompts for a code-generation LLM (TDD, no orphans)

Use these in order. Each prompt ends by wiring new code into the app and running tests.
Replace APP_NAME / module paths if necessary. Use Minitest, no RSpec.

⸻

Prompt 1 — Bootstrap, quality gates, /up ✅ COMPLETED

You are coding in a fresh Rails 8 app (HTML + Hotwire). Use Minitest. Tasks:
1) Add Tailwind via rails integration. Add Solid Queue as Active Job adapter.
2) Add an initializer to set SQLite PRAGMAs: WAL, synchronous=NORMAL, busy_timeout=5000ms.
3) Add a healthcheck: GET /up returns 200 and a JSON {status:"ok"}.
4) Add tests:
   - test/controllers/healthcheck_test.rb ensures /up is 200 and JSON.
   - A tiny model test that ActiveRecord can write/read a trivial record.
Run all tests. Do not modify unrelated files. Keep changes minimal but production-safe.


⸻

Prompt 2 — Admin authentication (single admin) + setup task ✅ COMPLETED

Implement admin authentication using Rails 8 auth generator.
Requirements:
- Generate authentication for a single Admin user model.
- Add a rake task bin/rails admin:setup that creates/resets an Admin by prompting for email/password (non-interactive defaults via env allowed).
- Protect /projects routes behind admin login. Add "Sign in" page + "Change password" page.
Tests:
- System test: visiting /projects redirects to sign in when logged out; signs in and reaches index.
- Model test: Admin validations (email presence, uniqueness).
Run tests until green.


⸻

Prompt 3 — Domain models & migrations (projects, invite_links, participants, conversations, messages, insight_cards) ✅ COMPLETED

Create models/migrations per MVP:
- projects(name:string!, goal:text, must_ask:json default[], never_ask:json default[],
  tone:string default:"polite_soft", limits:json default:{max_turns:12,max_deep:2},
  status:string default:"draft", max_responses:integer default:50)
- invite_links(project:ref!, token:string! unique, expires_at:datetime null, reusable:boolean default:true)
- participants(project:ref!, anon_hash:string index, age:integer, attributes:json default:{})
- conversations(project:ref!, participant:ref null, state:string default:"intro", started_at:datetime, finished_at:datetime, ip:string, user_agent:text)
- messages(conversation:ref!, role:integer default:0, content:text!, meta:json default:{})
- insight_cards(project:ref!, conversation:ref null, theme:string, jtbds:text,
  evidence:json default:[], severity:integer, freq_conversations:integer, freq_messages:integer,
  confidence_label:string)
Add basic AR validations (presence for required fields; enum-like helpers for status and role).
Tests:
- Model tests for each: validations, associations, default values.
- Migration test ensures columns exist with expected defaults.
Run tests.


⸻

Prompt 4 — Admin Projects CRUD + state machine (draft/active/closed) ✅ COMPLETED

Implement ProjectsController (admin area) with index/new/create/edit/update/destroy/show.
- Form inputs: name, goal, must_ask (array), never_ask (array), tone, limits (max_turns, max_deep),
  status (select draft/active/closed), max_responses (integer).
- Strong params handle JSON fields safely.
- Add a simple state helper: Project#draft?, #active?, #closed?.
- View: Tailwind minimal styling, error messages.
Tests:
- System test that creates a project with valid params and sees it in the list.
- Model test for state helpers.
Run tests.


⸻

Prompt 5 — Invite link issuance and public entry /i/:token ✅ COMPLETED

Implement InviteLink issuance:
- Admin on project show can click "Generate Link" to create (or show existing) a reusable token.
- Public route: GET /i/:token
  - Finds project by invite link.
  - Blocks if project is closed OR not active OR max_responses reached.
  - If allowed, shows consent page (start button).
Counting rule:
- On "Start" (continue to attributes), increment project's used count and close when reaching max_responses.
Implement a lightweight counter column or compute from conversations count (your choice but ensure start-time count).
Tests:
- Request tests: closed/over-limit/draft cases return proper pages.
- System test: follow the link, see consent, press Start, see attributes page.
Run tests.


⸻

Prompt 6 — Consent + Attributes form ✅ COMPLETED

Build the attributes step:
- Form after consent: Age (integer, 0..120, optional), plus 0..N custom short-text attributes (from project config; MVP supports label + help + required).
- Persist a Participant record linked to the Project; store attributes JSON.
- Create a Conversation row with state "intro"; store ip and user_agent; redirect to chat view.
Tests:
- Valid age within range; blank allowed.
- Required custom attribute enforced if configured.
- System test: consent -> attributes -> conversation chat page.
Run tests.


⸻

Prompt 7 — Chat shell (Turbo Streams, progress, skip)

Implement chat UI:
- Conversations#show displays message list with Turbo Stream updates, progress bar + remaining turns text.
- Composer: textarea with max 500 chars; "送信", "スキップ", and Quick Replies section (always "質問を言い換えて").
- When user submits text, create a user Message and enqueue orchestration (next prompt will add orchestrator).
- Skip posts a special user message "[スキップ]".
- Progress counts user turns; skip counts as a turn.
Tests:
- System test: posting a message appends to list and updates progress; skip also updates progress.
Run tests.


⸻

Prompt 8 — Orchestrator skeleton with Fake LLM (no OpenAI yet)

Create Interview::PromptBuilder and Interview::Orchestrator.
- PromptBuilder builds system+behavior rules (non-leading, 1-question-per-turn, gentle Keigo, max_deep=2, etc.).
- Orchestrator holds a simple state machine: enumerate -> recommend -> choose -> deepening(<=2) -> summary_check -> done.
- For now, inject LLM::Client::Fake that returns canned assistant prompts for each state.
- On each user message, orchestrator decides next assistant utterance and enqueues it to be displayed.
- Save assistant messages only when complete (final text per turn).
Tests:
- Unit tests: orchestrator transitions given messages sequence.
- System test: run through a minimal happy-path without OpenAI.
Run tests.


⸻

Prompt 9 — OpenAI client (streaming) + fallback template (3Q)

Implement LLM::Client::OpenAI with stream_chat(messages:, **opts, &chunk).
- Read OPENAI_API_KEY from ENV.
- Stream tokens; accumulate; enforce 400-char limit per assistant response (summarize if longer).
- Error handling: 1 retry; if still failing, switch this conversation into “fixed template” mode with exactly 3 generic questions:
  1) 最近直面した課題や不便と、その具体的な場面を教えてください。
  2) 先ほど挙げられた中から、最も重要だと思う1件を選び、その理由を一言で教えてください。
  3) 今思っていることを書いてください。
- Skip summary confirmation in fallback mode.
Wire: orchestrator chooses Fake in test env, OpenAI in production.
Tests:
- Service test stubbing OpenAI errors -> verifies fallback.
- System test: simulate error then show template flow to completion.
Run tests.


⸻

Prompt 10 — PII detect+mask (LLM) with Turbo replacement

Implement PII detection:
- After each user message creation, enqueue PiiDetectJob with the raw text.
- PiiDetectJob calls LLM classifier; if PII found, compute masked version (replace spans like names/phones with [氏名] etc).
- Persist masked content back into the same message and append a notice banner to the chat.
- Broadcast a Turbo Stream update to replace the DOM of that message + inject the banner near the composer.
Logging:
- Log only masked content (ensure logger filter).
Tests:
- Unit: given sample PII strings, detector flags and masks correctly (use a Fake).
- System: observe raw text briefly then updated node shows masked text and banner.
Run tests.


⸻

Prompt 11 — AnalyzeConversationJob (finish-only) + Insight board

On conversation completion:
- AnalyzeConversationJob pipeline: normalize -> tokenize (TinySegmenter) -> RAKE keywords -> LLM summary/theme -> severity auto -> frequency counts -> confidence label (0.7 freq + 0.3 quotes).
- Create/merge InsightCards for the project; keep up to 2 quotes per theme.
Build views:
- Project insights page lists top 5 themes by frequency priority (会話単位降順, tie-break by 発言単位).
- Card partial shows: theme, 1–2 quotes, severity 1–5, frequencies, confidence L/M/H.
Tests:
- Unit test: job creates expected card with counts.
- System test: finishing a conversation creates insights visible on the page.
Run tests.


⸻

Prompt 12 — KPIs, seeds, closing behavior, “もう一度回答”

Add KPIs to project show:
- 総回答/上限/残り枠
- 強いペイン出現率（深刻度>=4 の会話比）
- 平均ターン数
Thank-you page: “ご協力ありがとうございました。回答は無事に送信されました。” + “もう一度回答する” button.
Seeds: a sample project with limit 10 and template Qs, age attribute on.
Tests:
- System: hitting the limit auto-closes and shows the fixed closed message.
- System: thank-you shows and “もう一度回答” starts a new conversation.
Run tests.


⸻

Prompt 13 — Kamal deploy configs

Add Kamal config for production with Traefik + Let’s Encrypt:
- Dockerfile, kamal.yml, Traefik labels for TLS, volume for /app/storage (SQLite + ActiveStorage if present).
- Healthcheck at /up. ENV OPENAI_API_KEY required.
- Document a one-page README: deploy steps, initial admin setup.
No tests; provide config and docs only.


⸻

F. Guardrails & testing notes
	•	Adapters: default to LLM::Client::Fake in test to avoid network; integration smoke for OpenAI behind ENV flag.
	•	SQLite concurrency: Batch DB writes only for finalized assistant messages; set busy_timeout and short transactions.
	•	Turbo Streams tests: assert presence of stream targets and final DOM content; do not rely on actual SSE in unit tests.
	•	Security: Ensure invite token is unguessable; controller guards respect project status & limits; log filtering masks PII.
	•	Performance: Keep orchestrator stateless per request (read from DB), push long-running tasks to ActiveJob.

⸻

G. Optional “plan.md” outline (copy/paste)
	•	Intro, Scope, Non-goals
	•	Architecture diagram (text), Models, States
	•	Build milestones (as above)
	•	Test matrix (unit / request / system)
	•	Deployment notes, ENV, secrets
	•	Future roadmap (M1: embeddings/sqlite-vss, export, filters)

⸻

H. Optional “todo.md” (copy/paste starter)
	•	M0: Bootstrap + /up
	•	M1: Models + tests
	•	M2: Admin projects + invite links
	•	M3: Consent/Attributes
	•	M4: Chat shell
	•	M5: Orchestrator + Fake
	•	M6: OpenAI stream + fallback
	•	M7: PII detect/mask job
	•	M8: Analysis job + insight pages
	•	M9: KPIs + seeds + close
	•	M10: Kamal deploy

⸻

I. Final reminder
	•	Keep each prompt focused: code + tests + wiring, no dead code.
	•	Prefer Fake adapters in tests; defer OpenAI to minimal integration checks.
	•	Validate every spec choice made earlier (turn limits, labels, messages) via system tests.

