# クトゥルフ神話TRPG風 永続AIキーパー（KP）システム設計・調査レポート

Source: ChatGPT Deep Research (2026-02-19)
Google Drive: https://drive.google.com/file/d/1TF3DPpo5ZFXNv_5ZVQY_N6QOXcROsGzH/view

## エグゼクティブサマリー

CoC第7版系のプレイを「AIが長期運用できるKP（永続AI-KP）」として実装するための体系的設計レポート。

最も堅牢な参照設計は3層分離：
- (A) 決定的なルール裁定を担う「ルールエンジン」
- (B) 物語整合性と介入を担う「ドラママネージャ／オーケストレータ」
- (C) 描写・NPC台詞・要約など確率的生成を担う「LLMワーカー」

## 主要アーキテクチャ

```
Player → Client → Gateway → KP Orchestrator
                                ├→ State Store (event + snapshot)
                                ├→ Retriever (lore/scenes/NPC/memory)
                                ├→ Rules Engine (CoC7 adjudication)
                                ├→ Drama Manager
                                └→ LLM Worker (narrate/act/summarize)
```

## LLMの役割制限
- 常用（低コスト）: 情景描写、NPC台詞、次の質問
- 例外（高性能）: 矛盾解消、難しい行動解釈、複雑な伏線回収
- オフライン（バッチ）: セッション要約、整合性評価、埋め込み生成

## 永続データモデル
- イベントソーシング + スナップショット + CQRS
- 識別子: campaign_id → run_id → party_id → session_id → turn_id
- SAN変動は必ずイベント化+台帳化（監査可能に）

## コスト試算（gpt-5-mini基準）
- 1ターン: ~$0.00073 (Standard) / ~$0.000365 (Batch)
- カジュアル卓200ターン/月: $0.146
- 週次キャンペーン1200ターン/月: $0.876

## MYTHOS ENGINE v2との親和性
このレポートの設計思想は、先に共有されたMYTHOS ENGINE v2と高い親和性がある：
- 選択肢駆動（自由入力排除）→ プロンプトインジェクション耐性
- 行動テンプレートシステム → ルールエンジンとの統合
- World State Store → イベントソーシング
- LLMは描写のみ → 3層分離の(C)に対応
- Validation Layer → オーケストレータの検証機能

## Residueとの共通点
- 状態駆動の動的コンテンツ生成
- 周回による世界変化（multi-run）
- プレイヤーモデルによるパーソナライゼーション
- バックエンド必須（静的JSON管理の限界）
