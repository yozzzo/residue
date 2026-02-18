# 動的ストーリー生成レイヤー設計書

## 概要
Cloudflare Workers上にLLMベースの動的ストーリー生成パイプラインを構築する。
プレイヤーの行動・性格・周回状態に応じて、イベントテキストと選択肢を動的に生成する。

## アーキテクチャ

```
Godot Client
  ├── GET /api/v1/events/resolve  → 動的イベント取得/生成
  ├── POST /api/v1/actions/log    → 行動ログ記録
  ├── GET /api/v1/player/profile  → プロファイル取得
  └── GET /api/v1/endings/check   → エンディング判定

Cloudflare Workers (residue-api)
  ├── D1: generated_events, player_profiles, event_chains, endings, action_logs
  ├── Workers AI: @cf/meta/llama-3.1-70b-instruct (メイン生成)
  └── 3エージェントパイプライン: Plot → Writer → Reviewer
```

## LLM選定
- **初期**: Workers AI `@cf/meta/llama-3.1-70b-instruct`（無料枠）
- **品質不足時**: Gemini API（長コンテキスト、コスパ）
- **レビュー**: Claude API（将来的に品質ゲート用）

## DBスキーマ（マイグレーション 0003）

### generated_events
生成済みコンテンツプール。condition_keyで正規化検索。

### player_profiles
プレイヤーの行動特性・プレイスタイルを蓄積。

### event_chains
複数ステップにまたがるイベントシーケンス定義。

### endings
7種のエンディング定義（表3/裏3/真1）。

### action_logs
プレイヤー行動の生ログ。プロファイル更新の素材。

## 条件キー正規化
```
condition_key = "{world_id}:{node_id}:ts{truth_stage}:t_{top_trait}:f_{flag1},{flag2},{flag3}"
例: "medieval:m_n03:ts1:t_curious:f_mayor_met,seal_broken"
```

## 3エージェントパイプライン

1. **プロットエージェント**: 世界設定・プレイヤー状態からプロット生成
2. **ライターエージェント**: プロットをゲームイベントJSON形式に変換
3. **レビューエージェント**: GDD整合性・品質スコア判定（0.6未満で再生成）

## エンディング定義

| ID | Layer | Title | 条件 |
|---|---|---|---|
| boss_clear | surface | ボス撃破 | boss defeated |
| flee_end | surface | 逃走エンド | fled from boss |
| death_end | surface | 死亡 | hp=0 |
| residue_accept | hidden | Residue受容 | truth≥3 + flags + 「受け入れる」 |
| residue_reject | hidden | ループ断ち切り | truth≥3 + flags + 「拒絶する」 |
| crosslink_unity | hidden | 両世界統合 | 両世界クロスリンク完全成立 |
| true_end | true | 全痕跡回収 | N-01〜N-07記憶フラグ全回収 + truth=3 + 両世界クリア |

## 実装: Build 18
