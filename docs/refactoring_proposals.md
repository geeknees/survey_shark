# Survey Shark アプリケーション リファクタリング提案

## 概要

Survey Sharkアプリケーションの全体的なコード分析を行い、保守性、可読性、拡張性を向上させるためのリファクタリング提案をまとめました。このアプリケーションはRuby on Railsで構築されたインタビューチャットシステムで、プロジェクト管理、会話管理、分析機能を提供しています。

## 1. コントローラー層のリファクタリング

### 1.1 重複コードの削減

**問題点:**
- `InvitesController`、`ThankYousController`、`ConversationsController`で類似した認証処理とプロジェクト取得ロジックが重複している
- `generate_anon_hash`メソッドが複数のコントローラーで重複している

**提案:**
```ruby
# app/controllers/concerns/project_access.rb
module ProjectAccess
  extend ActiveSupport::Concern

  private

  def generate_anon_hash
    Digest::SHA256.hexdigest("#{Time.current.to_f}-#{SecureRandom.hex(8)}")[0..15]
  end

  def find_project_by_token
    @invite_link = InviteLink.find_by!(token: params[:token])
    @project = @invite_link.project
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def check_project_availability
    # 共通のプロジェクト利用可能性チェックロジック
  end
end
```

### 1.2 コントローラーアクションの単純化

**問題点:**
- `InvitesController#create_participant`が長すぎる（30行超）
- `ProjectsController#project_params`で複雑なパラメータ変換処理

**提案:**
```ruby
# app/services/participant_creator.rb
class ParticipantCreator
  def initialize(project, participant_params)
    @project = project
    @participant_params = participant_params
  end

  def call
    ActiveRecord::Base.transaction do
      create_participant
      create_conversation
      start_interview
    end
  end

  private

  def create_participant
    # 参加者作成ロジック
  end

  def create_conversation
    # 会話作成ロジック
  end

  def start_interview
    # インタビュー開始ロジック
  end
end
```

## 2. モデル層のリファクタリング

### 2.1 ビジネスロジックの適切な配置

**問題点:**
- `Project`モデルに状態管理、カウント計算、自動クローズなど多くの責務が集中している
- `Conversation`モデルが薄すぎて、状態管理ロジックがOrchestratorに依存している

**提案:**
```ruby
# app/models/project.rb
class Project < ApplicationRecord
  include ProjectStatusManagement
  include ProjectLimits
  include ProjectAnalytics

  # 基本的な関連とバリデーションのみ残す
end

# app/models/concerns/project_status_management.rb
module ProjectStatusManagement
  extend ActiveSupport::Concern

  def can_accept_responses?
    active? && !at_response_limit?
  end

  def check_and_auto_close!
    update!(status: "closed") if should_auto_close?
  end

  private

  def should_auto_close?
    active? && actual_responses_count >= max_responses
  end
end
```

### 2.2 Conversationモデルの拡充

**問題点:**
- 会話の状態管理ロジックがOrchestratorに分散している
- 会話の進行状況を判定するメソッドがない

**提案:**
```ruby
# app/models/conversation.rb
class Conversation < ApplicationRecord
  include ConversationStateMachine
  include ConversationProgress

  def user_message_count
    messages.where(role: :user).count
  end

  def remaining_turns
    max_turns = project.limits.dig("max_turns") || 12
    [max_turns - user_message_count, 0].max
  end

  def at_turn_limit?
    remaining_turns <= 0
  end

  def should_finish?
    at_turn_limit? || state == "done"
  end
end
```

## 3. サービス層のリファクタリング

### 3.1 Orchestratorクラスの分割

**問題点:**
- `Interview::Orchestrator`が200行を超える大きなクラス
- 複数の責務（状態管理、応答生成、履歴管理、分析等）が混在

**提案:**
```ruby
# app/services/interview/orchestrator.rb（簡略化）
module Interview
  class Orchestrator
    def initialize(conversation, llm_client: nil)
      @conversation = conversation
      @state_machine = StateMachine.new(conversation)
      @response_generator = ResponseGenerator.new(conversation, llm_client)
      @turn_manager = TurnManager.new(conversation)
    end

    def process_user_message(user_message)
      return fallback_if_needed(user_message) if should_use_fallback?
      return finish_if_needed if @turn_manager.at_limit?

      @state_machine.transition(user_message)
      @response_generator.generate(@state_machine.current_state, user_message)
    end
  end
end

# app/services/interview/state_machine.rb
module Interview
  class StateMachine
    def transition(user_message)
      # 状態遷移ロジックのみ
    end
  end
end

# app/services/interview/response_generator.rb
module Interview
  class ResponseGenerator
    def generate(state, user_message)
      # 応答生成ロジックのみ
    end
  end
end
```

### 3.2 LLMクライアントの抽象化改善

**問題点:**
- `LLM::Client::OpenAI`で具体的なAPI呼び出しとエラーハンドリングが混在
- レスポンス処理ロジックが分散している

**提案:**
```ruby
# app/services/llm/client/openai.rb（リファクタリング版）
module LLM
  module Client
    class OpenAI < Base
      include RetryableApiClient
      include ResponseProcessor

      def generate_response(system_prompt:, behavior_prompt:, conversation_history:, user_message:)
        with_retry do
          messages = MessageBuilder.new(system_prompt, behavior_prompt, conversation_history, user_message).build
          raw_response = api_client.chat(build_parameters(messages))
          process_response(raw_response)
        end
      end
    end
  end
end
```

## 4. JavaScript層のリファクタリング

### 4.1 Stimulusコントローラーの最適化

**問題点:**
- `chat_composer_controller.js`が200行を超える大きなファイル
- 複数のコントローラーで類似したローディング状態管理とイベントハンドリング
- `hello_controller.js`が未使用のままサンプルコードが残存

**提案:**
```javascript
// app/javascript/controllers/mixins/loading_state_mixin.js
export const LoadingStateMixin = {
  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden')
    }
    this.updateSubmitButton()
  },

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden')
    }
    this.isSubmitting = false
    this.updateSubmitButton()
  },

  updateSubmitButton() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = this.isSubmitting
      this.submitTarget.classList.toggle('opacity-50', this.isSubmitting)
    }
  }
}

// app/javascript/controllers/chat_composer_controller.js（簡略化版）
import { Controller } from '@hotwired/stimulus'
import { LoadingStateMixin } from './mixins/loading_state_mixin'

export default class extends Controller {
  static targets = ['form', 'textarea', 'submit', 'counter', 'loading']

  connect() {
    this.setupEventHandlers()
    this.setupFormResetObserver()
    this.updateUI()
  }

  // Mixinのメソッドを使用
  showLoading = LoadingStateMixin.showLoading
  hideLoading = LoadingStateMixin.hideLoading
  updateSubmitButton = LoadingStateMixin.updateSubmitButton
}
```

### 4.2 イベント管理の改善

**問題点:**
- カスタムイベント（`chat:response-complete`）の管理が分散している
- フォームリセットのロジックが複数箇所で重複

**提案:**
```javascript
// app/javascript/services/chat_event_manager.js
export class ChatEventManager {
  static EVENTS = {
    RESPONSE_COMPLETE: 'chat:response-complete',
    FORM_RESET: 'chat:form-reset',
    MESSAGE_SENT: 'chat:message-sent'
  }

  static dispatch(eventName, detail = {}) {
    document.dispatchEvent(new CustomEvent(eventName, { detail }))
  }

  static listen(eventName, handler) {
    document.addEventListener(eventName, handler)
    return () => document.removeEventListener(eventName, handler)
  }
}

// 使用例
import { ChatEventManager } from '../services/chat_event_manager'

// イベント送信
ChatEventManager.dispatch(ChatEventManager.EVENTS.RESPONSE_COMPLETE)

// イベント受信
this.cleanup = ChatEventManager.listen(
  ChatEventManager.EVENTS.RESPONSE_COMPLETE,
  this.handleResponseComplete.bind(this)
)
```

### 4.3 フォームバリデーションの統一

**問題点:**
- `chat_composer_controller.js`で文字数制限のハードコーディング
- バリデーションロジックが分散

**提案:**
```javascript
// app/javascript/services/form_validator.js
export class FormValidator {
  constructor(options = {}) {
    this.maxLength = options.maxLength || 500
    this.minLength = options.minLength || 1
  }

  validate(content) {
    const trimmed = content.trim()
    return {
      isValid: trimmed.length >= this.minLength && trimmed.length <= this.maxLength,
      length: trimmed.length,
      errors: this.getErrors(trimmed)
    }
  }

  getErrors(content) {
    const errors = []
    if (content.length < this.minLength) {
      errors.push('メッセージを入力してください')
    }
    if (content.length > this.maxLength) {
      errors.push(`文字数が上限（${this.maxLength}文字）を超えています`)
    }
    return errors
  }
}
```

## 5. ビュー層のリファクタリング

### 5.1 部分テンプレートの活用

**問題点:**
- プロジェクト一覧とフォームで重複するHTML構造
- ナビゲーションでの認証状態による条件分岐が複雑

**提案:**
```erb
<!-- app/views/projects/_project_card.html.erb -->
<div class="project-card">
  <%= render "projects/project_status", project: project %>
  <%= render "projects/project_actions", project: project %>
</div>

<!-- app/views/shared/_authenticated_navigation.html.erb -->
<!-- app/views/shared/_unauthenticated_navigation.html.erb -->
```

### 5.2 ヘルパーメソッドの整理

**問題点:**
- `ApplicationHelper`に認証関連とナビゲーション関連が混在
- プロジェクト固有のヘルパーメソッドが空のまま

**提案:**
```ruby
# app/helpers/navigation_helper.rb
module NavigationHelper
  def navigation_link_class(path)
    # ナビゲーション関連のみ
  end
end

# app/helpers/projects_helper.rb
module ProjectsHelper
  def project_status_badge(project)
    case project.status
    when "active" then content_tag(:span, "Active", class: "badge badge-success")
    when "closed" then content_tag(:span, "Closed", class: "badge badge-secondary")
    when "draft" then content_tag(:span, "Draft", class: "badge badge-warning")
    end
  end

  def project_progress_percentage(project)
    return 0 if project.max_responses.zero?
    ((project.actual_responses_count.to_f / project.max_responses) * 100).round
  end
end
```

## 6. バックグラウンドジョブの最適化

### 6.1 AnalyzeConversationJobの分離

**問題点:**
- 1つのジョブで複数の分析タスクを実行している
- エラーハンドリングが不十分

**提案:**
```ruby
# app/jobs/analyze_conversation_job.rb
class AnalyzeConversationJob < ApplicationJob
  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    return unless conversation.finished_at.present?

    Analysis::ConversationPipeline.new(conversation).process
  end
end

# app/services/analysis/conversation_pipeline.rb
module Analysis
  class ConversationPipeline
    def process
      steps = [
        ExtractInsightsStep.new(@conversation),
        CreateInsightCardsStep.new(@conversation),
        UpdateProjectAnalyticsStep.new(@conversation)
      ]

      steps.each(&:execute)
    end
  end
end
```

## 7. テストの改善

### 7.1 テストファイルの整理

**問題点:**
- 統合テストとユニットテストが混在
- モックとスタブの使い方が一貫していない
- JavaScript関連のテストが不足している

**提案:**
```ruby
# test/services/interview/orchestrator_test.rb
class Interview::OrchestratorTest < ActiveSupport::TestCase
  include Interview::TestHelpers

  setup do
    @conversation = create_test_conversation
    @orchestrator = Interview::Orchestrator.new(@conversation, llm_client: fake_llm_client)
  end

  test "processes user message correctly" do
    # より明確なテストケース
  end
end

# test/support/interview_test_helpers.rb
module Interview::TestHelpers
  def create_test_conversation(state: "intro")
    # テスト用の会話作成ヘルパー
  end

  def fake_llm_client
    # 一貫したフェイククライアント
  end
end
```

### 7.2 JavaScript テストの追加

**問題点:**
- Stimulusコントローラーにユニットテストがない
- ユーザーインタラクションのテストが不足

**提案:**
```javascript
// test/javascript/controllers/chat_composer_controller_test.js
import { Application } from '@hotwired/stimulus'
import ChatComposerController from '../../../app/javascript/controllers/chat_composer_controller'

describe('ChatComposerController', () => {
  let application
  let controller
  let element

  beforeEach(() => {
    application = Application.start()
    application.register('chat-composer', ChatComposerController)

    document.body.innerHTML = `
      <div data-controller="chat-composer">
        <form data-chat-composer-target="form">
          <textarea data-chat-composer-target="textarea"></textarea>
          <button data-chat-composer-target="submit">Send</button>
          <span data-chat-composer-target="counter">0</span>
        </form>
      </div>
    `

    element = document.querySelector('[data-controller="chat-composer"]')
    controller = application.getControllerForElementAndIdentifier(element, 'chat-composer')
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ''
  })

  test('updates counter when text is entered', () => {
    const textarea = element.querySelector('[data-chat-composer-target="textarea"]')
    const counter = element.querySelector('[data-chat-composer-target="counter"]')

    textarea.value = 'Hello'
    textarea.dispatchEvent(new Event('input'))

    expect(counter.textContent).toBe('5')
  })

  test('disables submit button when text is too long', () => {
    const textarea = element.querySelector('[data-chat-composer-target="textarea"]')
    const submit = element.querySelector('[data-chat-composer-target="submit"]')

    textarea.value = 'a'.repeat(501)
    textarea.dispatchEvent(new Event('input'))

    expect(submit.disabled).toBe(true)
  })
})
```

## 8. 設定とセキュリティの改善

### 8.1 設定の外部化

**問題点:**
- マジックナンバーがコード内に散在
- 環境固有の設定が不明確

**提案:**
```ruby
# config/application.yml
interview:
  default_max_turns: 12
  default_max_deep: 2
  max_response_length: 400
  fallback_questions_count: 3

# app/models/project.rb
class Project < ApplicationRecord
  def max_turns
    limits.dig("max_turns") || Rails.application.config.interview[:default_max_turns]
  end
end
```

### 8.2 セキュリティの強化

**問題点:**
- トークン生成のロジックが分散
- パラメータバリデーションが不十分

**提案:**
```ruby
# app/services/security/token_generator.rb
module Security
  class TokenGenerator
    def self.generate_invite_token
      SecureRandom.urlsafe_base64(32)
    end

    def self.generate_anon_hash
      Digest::SHA256.hexdigest("#{Time.current.to_f}-#{SecureRandom.hex(16)}")[0..15]
    end
  end
end
```

## 実装優先度

### 高優先度（即座に実装推奨）
1. 重複コードの削減（Concernsの作成）
2. Orchestratorクラスの分割
3. セキュリティ関連の改善
4. **chat_composer_controller.jsの分割とMixin適用**
5. **未使用のhello_controller.jsの削除**

### 中優先度（次のスプリントで実装）
1. モデルの責務分散
2. ヘルパーメソッドの整理
3. テストの改善
4. **JavaScriptイベント管理の統一**
5. **フォームバリデーションの外部化**

### 低優先度（リファクタリング完了後）
1. ビューの部分テンプレート化
2. 設定の外部化
3. バックグラウンドジョブの最適化
4. **JavaScriptテストの追加**

## まとめ

このリファクタリングにより以下の改善が期待できます：

- **保守性の向上**: 各クラスの責務が明確になり、修正時の影響範囲が限定される
- **テスタビリティの向上**: 単一責務のクラスによりユニットテストが書きやすくなる
- **拡張性の向上**: 新機能追加時に既存コードへの影響を最小限に抑える
- **可読性の向上**: コードの意図がより明確になり、新しい開発者のオンボーディングが容易になる
- **フロントエンドの一貫性**: JavaScriptコードの構造化により、UIインタラクションの保守が容易になる
- **パフォーマンス向上**: 重複処理の削減とイベント管理の最適化

段階的な実装により、既存機能を維持しながら徐々にコード品質を向上させることができます。
