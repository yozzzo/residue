# クトゥルフ神話TRPG向け 永続AIキーパー（KP）システム設計・調査レポート v2

Source: ChatGPT Deep Research (2026-02-17)
Google Drive: https://drive.google.com/file/d/1pTfdZE8SI9_qLpneg7I8tolW25HUU4jl/view

## 概要
v1とほぼ同じ構成だが、以下が追加・詳細化されている：

### 追加された詳細
1. **CoC7ルール要件の深掘り** — 押し技能（プッシュ）、対抗ロール成功度比較の詳細
2. **API設計の具体例** — `/v1/turns`, `/v1/rules/check`, `/v1/state/snapshot`, `/v1/state/rollback`
3. **乱数シード設計** — seed_root/seed_session/seed_scene/seed_roll で周回差別化を制御
4. **分岐（branch）設計** — 親run_id + fork_event_id でタイムライン分岐
5. **コスト試算の精緻化** — GPT-5 mini基準で1ターン$0.00067、カジュアル卓$0.12/セッション
6. **STT幻覚リスク** — Whisperの幻覚問題への注意、STT結果は未確定入力として扱う
7. **エッジ推論** — ExecuTorch, Apple MLX, llama.cppのiPhone実行例
8. **GEQ（Game Experience Questionnaire）** — プレイヤー体験の定量評価手法
9. **APPI詳細** — 3年ごと見直し、個人情報保護委員会の動向

### Residueとの関連
- イベントソーシング+CQRS → Residueのバックエンド設計に直接適用可能
- 乱数シード設計 → Residueの周回差分制御に活用
- branch設計 → Residueのクロスワールドリンクの実装基盤
- storylets（小断片）化 → events.jsonの静的イベントからの移行先
