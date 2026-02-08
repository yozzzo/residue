# [A-01] プロジェクト雛形整備

## 背景
Godot開発を始める前に、起動動線と基本ディレクトリを固定する。

## 目的
`Main -> Title -> WorldSelect -> Run` の最小遷移を成立させる。

## スコープ
- `project.godot` の基本設定
- 基本シーン4枚（Main, Title, WorldSelect, Run）
- `scripts/`, `scenes/`, `data/`, `assets/`, `docs/` の構成確認

## 実装タスク
1. 起動シーンを `res://scenes/Main.tscn` に固定
2. `Main` で画面遷移管理を実装
3. `Title` の Start/Quit を接続
4. `WorldSelect` から `Run` 遷移を接続

## 完了条件
- アプリ起動から `Run` 画面まで遷移可能
- エラーなく再起動できる
- ディレクトリ構成が設計書と一致

## 検証手順
1. Godotで実行
2. Startを押してWorldSelectへ
3. 任意世界を選んでRunへ
4. 画面遷移時のエラー有無を確認

## 依存
- なし

## 優先度
- P0
