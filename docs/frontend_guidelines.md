# フロントエンド開発ガイドライン

## JavaScriptコーディング規約

### 1. クラス名の操作

❌ **避けるべき方法**: `.className` の全置換
```javascript
// NG: Tailwindのパージに引っかかる可能性がある
element.className = 'text-red-500 text-sm mt-1'
```

✅ **推奨される方法**: `classList` API の使用
```javascript
// OK: 個別のクラス操作で安定性を確保
element.classList.add('text-red-500', 'text-sm', 'mt-1')
element.classList.remove('text-gray-500')
element.classList.toggle('hidden')
```

### 2. エラーハンドリング

すべての非同期処理には適切なエラーハンドリングを実装する:

```javascript
async handleSubmit(event) {
  event.preventDefault()

  try {
    const res = await fetch(url, options)
    if (!res.ok) {
      dwarn('Request failed with status:', res.status)
      this.handleError()
      return
    }
    // 成功時の処理
  } catch (e) {
    console.error('Request failed:', e)
    this.handleError()
  }
}
```

### 3. タイムアウト処理

長時間処理には必ずフォールバックタイムアウトを設定:

```javascript
connect() {
  this.isSubmitting = false
  this.fallbackResetTimeout = null
}

disconnect() {
  if (this.fallbackResetTimeout) {
    clearTimeout(this.fallbackResetTimeout)
  }
}

async handleSubmit(event) {
  // タイムアウトを設定
  this.fallbackResetTimeout = setTimeout(() => {
    if (this.isSubmitting) {
      dwarn('Timeout reached, resetting form')
      this.resetForm()
    }
  }, 20000) // 20秒

  try {
    // 処理
  } finally {
    if (this.fallbackResetTimeout) {
      clearTimeout(this.fallbackResetTimeout)
      this.fallbackResetTimeout = null
    }
  }
}
```

### 4. デバッグログ

開発時のデバッグには統一されたヘルパーを使用:

```javascript
// Debug helpers (enable by setting window.SURVEY_SHARK_DEBUG = true)
const dlog = (...args) => {
  try { if (window && window.SURVEY_SHARK_DEBUG) console.log(...args) } catch (_) {}
}
const dwarn = (...args) => {
  try { if (window && window.SURVEY_SHARK_DEBUG) console.warn(...args) } catch (_) {}
}

// 使用例
dlog('Form submitted, showing loading state')
dwarn('Timeout reached, resetting form')
```

デバッグを有効にするには、ブラウザのコンソールで:
```javascript
window.SURVEY_SHARK_DEBUG = true
```

### 5. 二重送信防止

フォーム送信時は必ず二重送信を防止:

```javascript
async handleSubmit(event) {
  event.preventDefault()

  if (this.isSubmitting) {
    dwarn('Already submitting, ignoring')
    return
  }

  this.isSubmitting = true
  // 処理
  // 完了後に必ず false に戻す
}
```

### 6. DOM要素の安全な取得

存在しない要素へのアクセスを防ぐ:

```javascript
// NG: エラーになる可能性
document.getElementById('messages').innerHTML = html

// OK: 存在チェック
const container = document.getElementById('messages')
if (!container) {
  dwarn('Messages container not found')
  return
}
container.innerHTML = html
```

## Stimulus コントローラー設計パターン

### 基本構造

```javascript
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['form', 'submit', 'loading']
  static values = {
    timeout: { type: Number, default: 20000 }
  }

  connect() {
    // 初期化処理
    this.isSubmitting = false
    this.setupObservers()
  }

  disconnect() {
    // クリーンアップ処理
    this.cleanupObservers()
    this.clearTimeouts()
  }

  // アクション定義
  async handleSubmit(event) {
    event.preventDefault()
    // 実装
  }

  // プライベートメソッド（慣習的に名前で区別）
  setupObservers() {
    // 実装
  }

  cleanupObservers() {
    // 実装
  }

  clearTimeouts() {
    // 実装
  }
}
```

### ターゲットの安全な使用

```javascript
// hasXxxTarget でチェック
if (this.hasLoadingTarget) {
  this.loadingTarget.classList.remove('hidden')
}

if (this.hasSubmitTarget) {
  this.submitTarget.disabled = true
}
```

## パフォーマンス最適化

### 1. ポーリング処理

過度なポーリングを避け、適切な間隔と制限を設定:

```javascript
async pollForUpdates() {
  const maxAttempts = 10
  const intervalMs = 1000
  let attempt = 0

  while (attempt < maxAttempts && this.isActive) {
    await this.fetchUpdate()
    await new Promise(r => setTimeout(r, intervalMs))
    attempt++
  }
}
```

### 2. イベントリスナー

不要なイベントリスナーは必ず削除:

```javascript
connect() {
  this.boundHandler = this.handleEvent.bind(this)
  this.element.addEventListener('click', this.boundHandler)
}

disconnect() {
  this.element.removeEventListener('click', this.boundHandler)
}
```

## テスト推奨事項

### システムテストで確認すべき項目

1. **フォーム送信の挙動**
   - 送信ボタンのローディング状態
   - 二重送信の防止
   - エラー時の表示

2. **UIフィードバック**
   - ローディングインジケーターの表示/非表示
   - 成功/エラーメッセージの表示
   - ボタンの有効/無効状態

3. **非同期更新**
   - Turbo Streamsによる更新
   - フォールバックポーリング
   - メッセージリストの自動更新

## トラブルシューティング

### よくある問題と解決方法

#### 問題: フォームが送信されたままになる
**原因**: `isSubmitting` フラグがリセットされない
**解決**: `finally` ブロックまたはタイムアウトで確実にリセット

#### 問題: Tailwindクラスが適用されない
**原因**: `.className` による全置換でパージの対象外になった
**解決**: `classList` API を使用

#### 問題: メッセージが表示されない
**原因**: Turbo Streamの更新が失われた
**解決**: フォールバックポーリングの実装を確認

## 改善済みコントローラー一覧

以下のコントローラーは本ガイドラインに準拠しています：

- ✅ `chat_composer_controller.js` - タイムアウト20秒、詳細なエラーログ
- ✅ `skip_form_controller.js` - フォールバック処理、エラーハンドリング
- ✅ `messages_refresher_controller.js` - デバッグログ、エラーハンドリング
- ✅ `copy_button_controller.js` - inline styleによるアニメーション
- ✅ `form_validator.js` - classList API による安全なクラス操作

## 次のステップ

1. **JavaScriptユニットテストの追加**
   - Vitestまたはjestのセットアップ
   - コントローラーのユニットテスト作成

2. **LoadingStateMixinの適用拡大**
   - 共通ロジックをMixinに抽出
   - 各コントローラーで再利用

3. **TypeScriptへの移行検討**
   - 型安全性の向上
   - IDE補完の改善
