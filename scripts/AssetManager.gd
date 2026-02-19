extends Node
## AssetManager - Dynamic asset download and caching system (Build 20)
## GDD §24: manifest-based differential delivery + local cache

const CACHE_DIR := "user://cache/assets/"
const LOCAL_MANIFEST_PATH := "user://cache/manifest.json"
const R2_BASE_URL := "https://residue-storage.residue-dev.workers.dev"
const API_BASE_URL := "https://residue-api.residue-dev.workers.dev"

signal update_progress(current: int, total: int)
signal update_completed(success: bool)

var local_manifest: Dictionary = {}
var remote_manifest: Dictionary = {}
var _http_request: HTTPRequest
var _download_queue: Array = []
var _download_index: int = 0
var _download_total: int = 0
var _update_callback: Callable
var _is_updating: bool = false

# Texture cache to avoid reloading
var _texture_cache: Dictionary = {}
var _audio_cache: Dictionary = {}


func _ready() -> void:
	_ensure_cache_dirs()
	_load_local_manifest()
	_http_request = HTTPRequest.new()
	_http_request.timeout = 30
	add_child(_http_request)


func _ensure_cache_dirs() -> void:
	var dirs := [
		"user://cache",
		"user://cache/assets",
		"user://cache/assets/backgrounds",
		"user://cache/assets/silhouettes",
		"user://cache/assets/title",
		"user://cache/assets/buttons",
		"user://cache/assets/audio",
		"user://cache/assets/audio/bgm",
		"user://cache/assets/audio/se",
	]
	for dir_path: String in dirs:
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)


func _load_local_manifest() -> void:
	if not FileAccess.file_exists(LOCAL_MANIFEST_PATH):
		local_manifest = {}
		return
	var file := FileAccess.open(LOCAL_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		local_manifest = {}
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		local_manifest = parsed
	else:
		local_manifest = {}


func _save_local_manifest() -> void:
	var file := FileAccess.open(LOCAL_MANIFEST_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(local_manifest, "\t"))


## Check for updates and download changed assets
func check_and_update_assets(callback: Callable) -> void:
	if _is_updating:
		return
	_is_updating = true
	_update_callback = callback
	
	# Fetch remote manifest
	var url := API_BASE_URL + "/api/v1/assets/manifest"
	_http_request.request_completed.connect(_on_manifest_received, CONNECT_ONE_SHOT)
	var err := _http_request.request(url)
	if err != OK:
		push_warning("AssetManager: Failed to request manifest: %d" % err)
		_finish_update(true)  # Continue with local assets


func _on_manifest_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("AssetManager: Manifest fetch failed (result=%d, code=%d)" % [result, response_code])
		_finish_update(true)
		return
	
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is not Dictionary:
		push_warning("AssetManager: Invalid manifest JSON")
		_finish_update(true)
		return
	
	remote_manifest = parsed
	
	# Calculate diff
	_download_queue = _calculate_diff()
	_download_total = _download_queue.size()
	_download_index = 0
	
	if _download_queue.is_empty():
		print("[AssetManager] All assets up to date")
		_finish_update(true)
		return
	
	print("[AssetManager] %d assets to download" % _download_total)
	_download_next()


func _calculate_diff() -> Array:
	var to_download: Array = []
	var remote_assets: Array = remote_manifest.get("assets", [])
	var local_assets: Dictionary = {}
	
	# Build local lookup by path
	for asset: Variant in local_manifest.get("assets", []):
		if asset is Dictionary:
			local_assets[asset.get("path", "")] = asset
	
	for remote_asset: Variant in remote_assets:
		if remote_asset is not Dictionary:
			continue
		var path: String = remote_asset.get("path", "")
		var remote_hash: String = remote_asset.get("hash", "")
		
		if path.is_empty():
			continue
		
		var local_asset: Variant = local_assets.get(path)
		if local_asset == null or (local_asset is Dictionary and local_asset.get("hash", "") != remote_hash):
			to_download.append(remote_asset)
	
	return to_download


func _download_next() -> void:
	if _download_index >= _download_queue.size():
		# All downloads complete - save manifest
		local_manifest = remote_manifest.duplicate(true)
		_save_local_manifest()
		_finish_update(true)
		return
	
	var asset: Dictionary = _download_queue[_download_index]
	var path: String = asset.get("path", "")
	var url: String = API_BASE_URL + "/api/v1/assets/file/" + path
	
	update_progress.emit(_download_index, _download_total)
	
	_http_request.request_completed.connect(_on_asset_downloaded.bind(path), CONNECT_ONE_SHOT)
	var err := _http_request.request(url)
	if err != OK:
		push_warning("AssetManager: Failed to request asset: %s" % path)
		_download_index += 1
		_download_next()


func _on_asset_downloaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, asset_path: String) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		# Ensure subdirectory exists
		var full_path: String = CACHE_DIR + asset_path
		var dir_path: String = full_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)
		
		# Save file
		var file := FileAccess.open(full_path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(body)
			file.close()
			print("[AssetManager] Downloaded: %s (%d bytes)" % [asset_path, body.size()])
		else:
			push_warning("AssetManager: Failed to save: %s" % full_path)
	else:
		push_warning("AssetManager: Download failed for %s (result=%d, code=%d)" % [asset_path, result, response_code])
	
	_download_index += 1
	_download_next()


func _finish_update(success: bool) -> void:
	_is_updating = false
	update_completed.emit(success)
	if _update_callback.is_valid():
		_update_callback.call()


## Get texture from cache or fallback to res://
func get_texture(asset_path: String) -> Texture2D:
	# Check memory cache
	if _texture_cache.has(asset_path):
		return _texture_cache[asset_path]
	
	# Check disk cache
	var cache_path: String = CACHE_DIR + asset_path
	if FileAccess.file_exists(cache_path):
		var image := Image.new()
		var err := image.load(cache_path)
		if err == OK:
			var tex := ImageTexture.create_from_image(image)
			_texture_cache[asset_path] = tex
			return tex
	
	# Fallback: bundled asset in res://assets/generated/
	var res_path: String = "res://assets/generated/" + asset_path
	if ResourceLoader.exists(res_path):
		var tex: Texture2D = load(res_path)
		_texture_cache[asset_path] = tex
		return tex
	
	return null


## Get audio stream from cache or fallback to res://
func get_audio(asset_path: String) -> AudioStream:
	# Check memory cache
	if _audio_cache.has(asset_path):
		return _audio_cache[asset_path]
	
	# Check disk cache
	var cache_path: String = CACHE_DIR + asset_path
	if FileAccess.file_exists(cache_path):
		var file := FileAccess.open(cache_path, FileAccess.READ)
		if file != null:
			var data := file.get_buffer(file.get_length())
			file.close()
			if asset_path.ends_with(".ogg"):
				var ogg_packet := OggPacketSequence.new()
				# For Godot 4.x, we use AudioStreamOggVorbis.load_from_buffer
				var stream := AudioStreamOggVorbis.load_from_buffer(data)
				if stream != null:
					_audio_cache[asset_path] = stream
					return stream
	
	# Fallback: bundled asset
	var res_path: String = "res://assets/audio/" + asset_path
	if ResourceLoader.exists(res_path):
		var stream: AudioStream = load(res_path)
		_audio_cache[asset_path] = stream
		return stream
	
	# Also try res://assets/generated/ for non-audio paths
	var res_path2: String = "res://assets/generated/" + asset_path
	if ResourceLoader.exists(res_path2):
		var stream: AudioStream = load(res_path2)
		_audio_cache[asset_path] = stream
		return stream
	
	return null


## Clear all cached assets
func clear_cache() -> void:
	_texture_cache.clear()
	_audio_cache.clear()
	# Delete cached files
	var dir := DirAccess.open(CACHE_DIR)
	if dir != null:
		_delete_recursive(CACHE_DIR)
	local_manifest = {}
	if FileAccess.file_exists(LOCAL_MANIFEST_PATH):
		DirAccess.remove_absolute(LOCAL_MANIFEST_PATH)


func _delete_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			_delete_recursive(path + file_name + "/")
			DirAccess.remove_absolute(path + file_name)
		else:
			DirAccess.remove_absolute(path + file_name)
		file_name = dir.get_next()
