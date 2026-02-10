# SurveyShark 企画ブラッシュアップ案（回答精度・UX強化 / 対SurveyMonkey）

最終更新: 2026-02-10  
作成根拠: アプリ実装実査 + 既存docs + SurveyMonkey公開情報

## 1. 現状診断（実装ベース）

### 1-1. 回答精度の弱点

1. 会話状態が単純で、MVP仕様の「列挙→推奨→選択」の誘導が実装されていない  
現状は `intro -> deepening -> must_ask -> summary_check -> done` のみ。  
参照: `app/services/interview/state_machine.rb:6`, `app/services/interview/state_machine.rb:20`

2. 深掘り制御と要約が粗く、分析品質につながる情報抽出が弱い  
- `max_deep`の実効デフォルトが5寄り（仕様意図とのズレ）。  
参照: `app/services/interview/prompt_builder.rb:12`, `db/schema.rb:89`  
- 要約生成が「全発言連結」中心で圧縮品質が低い。  
参照: `app/services/interview/prompt_builder.rb:121`

3. 分析前処理がヒューリスティック中心で、テーマ精度が安定しにくい  
`TextProcessor`が簡易分割（文字長ベース）で、語彙・文脈保持が弱い。  
参照: `app/services/analysis/text_processor.rb:16`

4. PII検知失敗時に「未検出扱い」で通すため、品質/安全両面で揺れる  
参照: `app/services/pii/detector.rb:20`

### 1-2. UXの弱点

1. 動的クイック返信は実装済みだが、効果検証（入力負荷/情報量への寄与）が未実施  
実装参照: `app/helpers/conversations_helper.rb`, `app/views/conversations/_quick_replies.html.erb`

2. 回答中断からの再開ができず、離脱コストが高い  
再開導線・下書き保存の実装なし（会話完了前に離れると実質ロスト）。

3. 属性収集が拡張不能に近い  
`Project#custom_attributes` が常に空配列を返すプレースホルダ。  
参照: `app/models/project.rb:16`

4. フォールバック体験の品質保証が弱い  
フォールバックE2Eがスキップされており、UX回帰を検知しづらい。  
参照: `test/system/fallback_mode_test.rb:4`

### 1-3. 管理者体験の弱点（活用しにくさ）

1. インサイト深掘りの関連会話紐付けが限定的  
`messages.content == evidence` で一致検索しており、表記ゆれに弱い。  
参照: `app/controllers/insights_controller.rb:17`

2. 期間・セグメント・共有・エクスポートが不足  
運用現場での「意思決定に使う」最後の一歩が弱い（既存docsのスコープ外項目とも一致）。

## 2. SurveyMonkeyとの差分（企画上の課題）

SurveyMonkey側の強み（公開情報ベース）:

- AI作成/分析スイート（Analyze with AI, thematic analysis, sentiment, response quality detection）
- 高度なロジック（skip logic / advanced branching / piping / randomization / quotas）
- 配布チャネルの広さ（Webリンク・メール・SNS・QR）
- Question Bank / テンプレート / ベンチマーク機能

SurveyShark側は「会話型で深掘りできる」強みがある一方、  
**調査設計力**・**配布力**・**分析活用力**で差がある。

## 3. 企画ブラッシュアップ（優先度付き）

## P0（最優先: 2〜4週間）「精度と完了率の底上げ」

1. 会話フローを仕様準拠へ再構築  
`列挙 -> 推奨 -> 選択 -> 深掘り -> 要約確認` を明示実装。  
狙い: 回答の構造化、テーマ抽出精度向上。

2. 動的クイック返信（最大3件）導入（実装済み: 2026-02-10）  
状態と直前応答に応じて提示（言い換え/具体化/否定/別理由など）。  
狙い: 入力負荷を下げ、情報量を増やす。

3. 回答中断対策（自動保存 + 再開URL）  
狙い: 完了率改善。特にスマホ離脱で効果が大きい。

4. PIIのフェイルセーフ化  
検知失敗時は「要確認」扱いで保存/表示を分岐し、未検知通過を減らす。

## P1（次点: 4〜8週間）「SurveyMonkey基本機能へのキャッチアップ」

1. ロジックビルダー（条件分岐/スキップ）  
会話導線の途中分岐と除外判定をGUIで設定可能にする。

2. 配布強化（QR生成・チャネル別リンク・最低限のトラッキング）  
どこから回答されたかを可視化し、募集施策を最適化。

3. 結果活用（エクスポート + 期間フィルタ + 再集計）  
報告・共有・再分析を現場運用で回せる状態へ。

4. 品質検知（低品質回答フィルタ）  
短時間連投、文字化け、同文反復などのフラグ付け。

## P2（差別化: 8〜12週間）「会話型ならではの優位性を作る」

1. インサイト根拠トレース  
「このテーマはどの発言群から導いたか」をカードから即辿れるようにする。

2. セグメント比較インサイト  
年齢・属性別でペインの差を自動比較し、施策示唆を出す。

3. アクション提案  
インサイトから「次の検証質問」「改善案」「優先順位」を自動提案。

## 4. KPI再設計（精度とUXを可視化）

現行KPIに加え、以下を追加:

- 回答完了率（開始→完了）
- 有効回答率（低品質フラグ除外後）
- 深掘り充足率（頻度/影響/対処/期待の4観点が埋まった割合）
- 要約修正率（summary_checkでNoになった割合）
- インサイト再現率（同テーマが別会話で再発する割合）

## 5. 直近スプリントで着手すべき実装テーマ（推奨）

1. 会話フロー再構築（P0-1）  
2. 動的クイック返信の効果検証（P0-2フォローアップ）  
3. 自動保存/再開（P0-3）  
4. 分析前処理強化（TextProcessor改善 + テーマ抽出の評価セット整備）  
5. 品質検知ルールの最小版（P1-4の先行）

---

## 参考情報（競合調査ソース）

- SurveyMonkey AI機能: https://www.surveymonkey.com/product/features/surveymonkey-genius/
- AI分析機能: https://www.surveymonkey.com/product/features/ai-survey-analysis/
- ロジック機能: https://help.surveymonkey.com/en/surveymonkey/create/skip-logic/
- 高度分岐: https://help.surveymonkey.com/en/surveymonkey/create/advanced-branching/
- ロジック関連オプション: https://help.surveymonkey.com/en/surveymonkey/create/logic-options/
- 配布（Webリンク/QR）: https://help.surveymonkey.com/en/surveymonkey/send/web-link-collector/
- テンプレート: https://www.surveymonkey.com/mp/sample-survey-questionnaire-templates/
- Question Bank: https://help.surveymonkey.com/en/surveymonkey/create/question-bank/
- ベンチマーク: https://www.surveymonkey.com/product/features/benchmarks/
