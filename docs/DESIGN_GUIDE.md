# Residue デザインガイドライン

## 画面構成（共通）
- **横画面固定** (1280x720, 16:9)
- 背景: 世界別背景画像 + 半透明ColorRectオーバーレイ（テキスト可読性確保）
- シルエット: 会話/バトル時に画面右側（60%〜100%幅）、alpha 0.25、フェードイン/アウト

## 選択肢ボタン
- **2択以下**: 1列表示（縦並び）
- **3択以上**: 2列グリッド表示
- スクロール**禁止** — 全選択肢が画面内に収まること
- ボタン高さ: 44px
- フォントサイズ: 22pt
- 左寄せテキスト
- スタイル: カード風（角丸、半透明背景）

## ステータス表示（画面下部）
- フォントサイズ: **12pt**（極力目立たない）
- 色: 薄い緑 (0.5, 0.65, 0.5, alpha 0.7)
- 「周回を終了」ボタン: 12pt、最小サイズ 80x32

## テキスト表示
- 本文: RichTextLabel、22pt、タイプライター演出
- ロケーション名: 24pt
- ヘッダー: 18pt（世界名、ジョブ、周回数、真実段階）
- 方向情報: 16pt

## 色テーマ（ThemeManager）
| 世界 | 背景色 | アクセント | テキスト |
|------|--------|------------|----------|
| medieval | 暗紫/灰 (0.15, 0.1, 0.2) | 紫 (0.7, 0.5, 0.8) | 暖白 (0.9, 0.85, 0.8) |
| future | 暗青/シアン (0.05, 0.1, 0.15) | シアン (0.3, 0.7, 0.9) | 冷白 (0.8, 0.9, 0.95) |
| default | 暗灰 (0.08, 0.08, 0.1) | 薄紫 (0.6, 0.6, 0.8) | 白 (0.9, 0.9, 0.9) |

## 装飾用TextureRect
- 必ず `mouse_filter = 2` (MOUSE_FILTER_IGNORE) を設定
- タッチイベントをブロックしないこと

## ボタン画像アセット
- 世界別ボタンスプライト: `assets/generated/buttons/medieval_buttons.png`, `future_buttons.png`
- 共通アイコン: `assets/generated/buttons/common_icons.png`
- よく使うボタン（戦う、逃げる、進む等）には世界観に合ったスタイルを適用

## シルエットアセット
| タイプ | ファイル | 用途 |
|--------|----------|------|
| elder | silhouettes/elder.png | 村長、老人、NPC会話 |
| warrior | silhouettes/warrior.png | 戦士、騎士 |
| scholar | silhouettes/scholar.png | 学者、魔術師、修道士 |
| monster | silhouettes/monster.png | バトルイベント（デフォルト） |
| cyborg | silhouettes/cyborg.png | ターミナル、AI、機械系 |
| merchant | silhouettes/merchant.png | 商人、取引 |

## 背景アセット
| ファイル | 用途 |
|----------|------|
| title/title_bg.png | タイトル画面 |
| backgrounds/medieval_bg.png | 中世世界 ラン/バトル |
| backgrounds/future_bg.png | 未来世界 ラン/バトル |

## 禁止事項
- スクロール可能な選択肢リスト
- 大きすぎるステータス表示
- mouse_filterなしの装飾TextureRect
- tscnでのUID手動指定（.importファイルから取得 or load()使用）
