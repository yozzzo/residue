# Residue セットアップ手順

## 1. 現在の準備状態
- Godotクライアント雛形あり（タイトル->世界選択->周回画面）
- 周回終了で魂ポイント加算あり
- セーブ/ロード（最新 + バックアップ）あり
- Backend API雛形あり（manifest配信含む）

## 2. Godotクライアント
前提:
- Godot 4.x をインストール

手順:
1. Godotで `/Users/yozo/dev/residue/project.godot` を開く
2. 実行して `Start -> WorldSelect -> Run` を確認
3. Run画面で選択後、`End Run` で魂ポイントが加算されることを確認

注意:
- この環境では `godot` CLIが未インストールのため、GUIで確認する

## 3. Backend API
前提:
- Python 3.10+

手順:
```bash
cd /Users/yozo/dev/residue/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8080
```

動作確認:
```bash
curl http://127.0.0.1:8080/health
curl "http://127.0.0.1:8080/v1/assets/manifest?platform=ios&app_version=0.1.0&locale=ja-JP"
```

## 4. 主要ファイル
- Godot状態管理: `/Users/yozo/dev/residue/scripts/GameState.gd`
- Godot保存処理: `/Users/yozo/dev/residue/scripts/SaveService.gd`
- API本体: `/Users/yozo/dev/residue/backend/app/main.py`
- Manifestデータ: `/Users/yozo/dev/residue/backend/data/manifest.json`
- タスク分解: `/Users/yozo/dev/residue/docs/IMPLEMENTATION_TASK_BREAKDOWN_ja.md`
