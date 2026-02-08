# Residue アセット配信仕様（Manifest + Cache）

## 1. 目的
- 画像アセットの通信量を抑える。
- 初回体験を壊さず、Wi-Fi時に先読みできる。
- 再ダウンロードを最小化する。

## 2. 基本方針
- APIは画像本体ではなく `manifest` を返す。
- クライアントは `asset_id + version + hash` でローカル管理する。
- 本体DLは差分のみ実行する。

## 3. APIエンドポイント

### 3.1 `GET /v1/assets/manifest`
用途:
- 指定ユーザーに必要なアセット一覧を返す。

クエリ:
- `platform`: `ios|android|pc`
- `app_version`: 例 `0.1.0`
- `locale`: 例 `ja-JP`
- `last_manifest_version`: 任意。差分取得に利用。

レスポンス例:
```json
{
  "manifest_version": 12,
  "generated_at": "2026-02-06T16:00:00Z",
  "required_bytes_wifi": 287654321,
  "required_bytes_cellular": 17892345,
  "assets": [
    {
      "asset_id": "bg_medieval_village_01",
      "type": "image",
      "tags": ["world:medieval", "scene:village", "time:night"],
      "priority": "high",
      "version": 3,
      "hash": "sha256:abc123...",
      "size_bytes": 582341,
      "cdn_url": "https://cdn.example.com/assets/bg_medieval_village_01_v3.webp"
    }
  ],
  "deleted_asset_ids": ["bg_old_unused_01"]
}
```

### 3.2 `POST /v1/assets/presign`
用途:
- 認可付きCDN URLを短時間発行する（必要な場合のみ）。

リクエスト例:
```json
{
  "asset_ids": ["bg_medieval_village_01", "bg_future_factory_02"]
}
```

### 3.3 `POST /v1/assets/report`
用途:
- DL/検証失敗を集約し、破損資産を検出する。

リクエスト例:
```json
{
  "asset_id": "bg_medieval_village_01",
  "version": 3,
  "error_code": "HASH_MISMATCH",
  "network_type": "wifi"
}
```

## 4. クライアントDL戦略（Godot）

### 4.1 初回起動
1. 通信種別判定（`wifi` / `cellular` / `offline`）
2. `manifest` 取得
3. Wi-Fiなら `priority=high` を一括DL
4. セルラーなら最小必須のみDL（タイトル/初回世界）

### 4.2 平常時
- シーン遷移の少し前に必要アセットを先読み。
- キャッシュ済みかつ `hash` 一致ならDLしない。
- 失敗時は低品質代替アセットを表示。

### 4.3 差分更新
- 起動時に `last_manifest_version` 付きで取得。
- `deleted_asset_ids` は端末キャッシュから削除候補へ。
- 新規またはversion更新のみDL。

## 5. ローカルキャッシュ仕様

### 5.1 保存構造
- ルート: `user://asset_cache/`
- 実体: `user://asset_cache/files/<asset_id>_v<version>.webp`
- インデックス: `user://asset_cache/index.json`

`index.json` 例:
```json
{
  "schema_version": 1,
  "manifest_version": 12,
  "max_cache_bytes": 2147483648,
  "entries": {
    "bg_medieval_village_01": {
      "version": 3,
      "hash": "sha256:abc123...",
      "size_bytes": 582341,
      "last_used_at": "2026-02-06T16:05:10Z",
      "path": "user://asset_cache/files/bg_medieval_village_01_v3.webp"
    }
  }
}
```

### 5.2 退避ルール
- 上限超過時は `LRU` で削除。
- `priority=high` は削除優先度を下げる。
- 破損検知時は該当エントリを即無効化。

## 6. 最低限のセキュリティ
- HTTPS必須。
- `hash` 検証後にのみ採用。
- 認可URLは短寿命（推奨10分以内）。
- 不正IDの連続要求はレート制限。

## 7. 運用メトリクス
- `cache_hit_rate`
- `avg_download_bytes_per_user_per_day`
- `first_session_ready_seconds`
- `asset_hash_mismatch_rate`
- `cellular_download_ratio`

## 8. 受け入れ基準
- 初回Wi-Fi時: 開始10分以内に高優先アセット配信完了。
- セルラー時: 初回必要DLを小容量に制限。
- 平常時: 同一アセットの再DL率を低く維持。
