# Residue 実装タスク分解（Issue化用）

## 0. 使い方
- 本書はそのままIssue化する前提の粒度。
- 形式: `ID / 優先度 / タスク / 完了条件`
- 優先度: `P0(必須)`, `P1(重要)`, `P2(拡張)`

## 1. Epic A: コア基盤（P0）

### A-01 プロジェクト雛形整備
- 優先度: P0
- タスク: Godotプロジェクト初期化、基本シーン導線、設定ファイル整理
- 完了条件: `Main -> Title -> WorldSelect -> Run` が起動動線で遷移できる

### A-02 データ読み込み基盤
- 優先度: P0
- タスク: `data/worlds`, `data/events` のJSONローダー実装
- 完了条件: JSON更新だけで世界/イベントを差し替え可能

### A-03 セーブ/ロード基盤
- 優先度: P0
- タスク: `MetaState`, `RunState`, `Flags` の保存実装
- 完了条件: アプリ再起動後に状態復元できる

## 2. Epic B: API基盤（P0）

### B-01 APIスケルトン
- 優先度: P0
- タスク: `GET /health`, `GET /v1/config` を実装
- 完了条件: クライアントから疎通可能

### B-02 Manifest API
- 優先度: P0
- タスク: `GET /v1/assets/manifest` を仕様通り実装
- 完了条件: `manifest_version`, `assets`, `deleted_asset_ids` を返す

### B-03 Asset report API
- 優先度: P1
- タスク: `POST /v1/assets/report` でDL失敗収集
- 完了条件: エラー統計が保存される

## 3. Epic C: アセット配信とキャッシュ（P0）

### C-01 通信種別判定
- 優先度: P0
- タスク: 起動時に `wifi/cellular/offline` 判定
- 完了条件: ネットワーク種別に応じてDL方針が切り替わる

### C-02 マニフェスト差分取得
- 優先度: P0
- タスク: `last_manifest_version` 付き取得
- 完了条件: 差分更新で不要DLが発生しない

### C-03 ローカルキャッシュ管理
- 優先度: P0
- タスク: `index.json` と実体ファイルの整合管理
- 完了条件: `asset_id+version+hash` 一致時は再DLしない

### C-04 キャッシュ掃除（LRU）
- 優先度: P1
- タスク: 容量上限を超えたときLRUで削除
- 完了条件: アプリ容量が上限内に維持される

## 4. Epic D: ゲーム進行ロジック（P0）

### D-01 周回ループ実装
- 優先度: P0
- タスク: 世界選択 -> 探索 -> 終了 -> 継承
- 完了条件: 1周が完結し次周へ移行できる

### D-02 魂価値計算
- 優先度: P0
- タスク: 深度/討伐/発見ベースの算出式実装
- 完了条件: 周回ごとに再現性あるポイント加算

### D-03 体験カーブ制御
- 優先度: P0
- タスク: `1-2 / 3-6 / 7+` の出現制御
- 完了条件: 周回帯ごとに表示コンテンツが変化

### D-04 正史/改変分離
- 優先度: P0
- タスク: `world_canon_lock`, `unlock_flag`, `fast_entry_flag` 実装
- 完了条件: 正史を維持しつつ改変ルートへ個別突入可能

## 5. Epic E: AI生成パイプライン（P1）

### E-01 Prompt Runner
- 優先度: P1
- タスク: OpenAI API呼び出し + JSON schema検証
- 完了条件: 生成結果が型安全に保存される

### E-02 再利用優先検索
- 優先度: P1
- タスク: `tags + semantic_hash` で既存資産検索
- 完了条件: 既存候補があれば新規生成しない

### E-03 生成予算ガード
- 優先度: P1
- タスク: 日次上限と優先順位制御
- 完了条件: 上限超過時は再配列のみで継続

## 6. Epic F: 品質レビュー運用（P0）

### F-01 レビュー台帳
- 優先度: P0
- タスク: 音/絵/物語のレビュー結果記録フォーマット作成
- 完了条件: `Draft -> Internal -> Playtest -> Final` が追跡可能

### F-02 差し戻しルール自動チェック
- 優先度: P1
- タスク: タグ矛盾、開示順違反の検査
- 完了条件: NG資産が収録前に検出される

## 7. Epic G: テストと観測（P0）

### G-01 分岐ロジックテスト
- 優先度: P0
- タスク: フラグ成立/不成立のユニットテスト
- 完了条件: 主要分岐が自動検証される

### G-02 セーブ互換テスト
- 優先度: P0
- タスク: 旧バージョンセーブの読み込み検証
- 完了条件: マイグレーション失敗率0%

### G-03 メトリクス送信
- 優先度: P1
- タスク: `cache_hit_rate`, `api_latency`, `run_completion_rate` 計測
- 完了条件: ダッシュボードで確認可能

## 8. Epic H: コンテンツ初期投入（P0）

### H-01 中世世界の固定イベント
- 優先度: P0
- タスク: 核イベント3本、差分イベント6本
- 完了条件: 1-2周帯で違和感導入まで成立

### H-02 未来世界の固定イベント
- 優先度: P0
- タスク: 核イベント3本、差分イベント6本
- 完了条件: クロスリンク前提の伏線が成立

### H-03 Residue初定義シーン
- 優先度: P0
- タスク: `loop>=7` 条件イベント実装
- 完了条件: タイトル回収演出がゲーム内で発火

## 9. 2週間スプリント推奨（最初の3本）

### Sprint 1
- A-01, A-02, A-03, D-01

### Sprint 2
- B-01, B-02, C-01, C-02, C-03

### Sprint 3
- D-02, D-03, D-04, H-01, H-02

## 10. Definition of Done（横断）
- 仕様書参照リンクがIssueに記載されている
- テストまたは手動検証手順がある
- ログが残る（失敗時原因追跡可能）
- レビューゲートのどの段階か明示されている

## 11. Sprint 1 実ファイル
- テンプレ一覧: `/Users/yozo/dev/residue/docs/issues/sprint1/README.md`
- ボード: `/Users/yozo/dev/residue/docs/issues/sprint1/SPRINT_1_BOARD.md`
- A-01: `/Users/yozo/dev/residue/docs/issues/sprint1/A-01_project_bootstrap.md`
- A-02: `/Users/yozo/dev/residue/docs/issues/sprint1/A-02_data_loader.md`
- A-03: `/Users/yozo/dev/residue/docs/issues/sprint1/A-03_save_load.md`
- D-01: `/Users/yozo/dev/residue/docs/issues/sprint1/D-01_run_loop.md`
