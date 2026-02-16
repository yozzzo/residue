extends Node
## AudioManager - Handles SE and BGM playback with crossfade support

const AUDIO_CONFIG_PATH := "res://data/audio/audio_config.json"

# SE categories (GDD 9.2)
enum SECategory { DECISION, FAILURE, DISCOVERY, ANOMALY }

# Audio players
var bgm_player_a: AudioStreamPlayer
var bgm_player_b: AudioStreamPlayer
var active_bgm_player: AudioStreamPlayer
var se_players: Array[AudioStreamPlayer] = []
var max_se_players: int = 8

# State
var current_bgm_id: String = ""
var audio_config: Dictionary = {}
var master_volume: float = 1.0
var bgm_volume: float = 0.8
var se_volume: float = 1.0
var crossfade_duration: float = 1.0


func _ready() -> void:
	_setup_audio_players()
	_load_audio_config()


func _setup_audio_players() -> void:
	# BGM players for crossfade
	bgm_player_a = AudioStreamPlayer.new()
	bgm_player_a.name = "BGM_A"
	bgm_player_a.bus = "Master"
	add_child(bgm_player_a)
	
	bgm_player_b = AudioStreamPlayer.new()
	bgm_player_b.name = "BGM_B"
	bgm_player_b.bus = "Master"
	add_child(bgm_player_b)
	
	active_bgm_player = bgm_player_a
	
	# SE player pool
	for i in range(max_se_players):
		var player := AudioStreamPlayer.new()
		player.name = "SE_%d" % i
		player.bus = "Master"
		add_child(player)
		se_players.append(player)


func _load_audio_config() -> void:
	if not FileAccess.file_exists(AUDIO_CONFIG_PATH):
		push_warning("AudioManager: Config not found at %s" % AUDIO_CONFIG_PATH)
		return
	
	var file := FileAccess.open(AUDIO_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		audio_config = parsed


# === SE Functions ===

func play_se(category: SECategory, variant: int = -1) -> void:
	var category_name: String = _category_to_string(category)
	var se_list: Array = _get_se_list(category_name)
	
	if se_list.is_empty():
		# Placeholder: no actual audio file
		print("[AudioManager] SE: %s (placeholder)" % category_name)
		return
	
	var se_path: String
	if variant >= 0 and variant < se_list.size():
		se_path = se_list[variant]
	else:
		se_path = se_list[randi() % se_list.size()]
	
	_play_se_file(se_path)


func play_se_by_name(se_name: String) -> void:
	var se_data: Dictionary = audio_config.get("se", {})
	var se_path: Variant = se_data.get(se_name)
	
	if se_path is String:
		_play_se_file(se_path)
	elif se_path is Array and se_path.size() > 0:
		_play_se_file(se_path[randi() % se_path.size()])
	else:
		print("[AudioManager] SE: %s (placeholder)" % se_name)


func _play_se_file(path: String) -> void:
	if not ResourceLoader.exists(path):
		print("[AudioManager] SE file not found: %s" % path)
		return
	
	var stream: AudioStream = load(path)
	if stream == null:
		return
	
	var player := _get_available_se_player()
	if player != null:
		player.stream = stream
		player.volume_db = linear_to_db(se_volume * master_volume)
		player.play()


func _get_available_se_player() -> AudioStreamPlayer:
	for player in se_players:
		if not player.playing:
			return player
	# All busy, use first one
	return se_players[0]


func _get_se_list(category: String) -> Array:
	var se_data: Dictionary = audio_config.get("se", {})
	var category_data: Variant = se_data.get(category)
	
	if category_data is Array:
		return category_data
	elif category_data is String:
		return [category_data]
	return []


func _category_to_string(category: SECategory) -> String:
	match category:
		SECategory.DECISION:
			return "decision"
		SECategory.FAILURE:
			return "failure"
		SECategory.DISCOVERY:
			return "discovery"
		SECategory.ANOMALY:
			return "anomaly"
	return "decision"


# === BGM Functions ===

func play_bgm(bgm_id: String, crossfade: bool = true) -> void:
	if bgm_id == current_bgm_id:
		return
	
	var bgm_data: Dictionary = audio_config.get("bgm", {})
	var bgm_path: Variant = bgm_data.get(bgm_id)
	
	if bgm_path == null or not bgm_path is String:
		print("[AudioManager] BGM: %s (placeholder)" % bgm_id)
		current_bgm_id = bgm_id
		return
	
	if not ResourceLoader.exists(bgm_path):
		print("[AudioManager] BGM file not found: %s" % bgm_path)
		current_bgm_id = bgm_id
		return
	
	var stream: AudioStream = load(bgm_path)
	if stream == null:
		return
	
	if crossfade and active_bgm_player.playing:
		_crossfade_to(stream)
	else:
		_play_bgm_immediate(stream)
	
	current_bgm_id = bgm_id


func play_world_bgm(world_id: String, tension: String = "normal") -> void:
	## Play BGM based on world and tension level
	## tension: "normal", "alert", "anomaly"
	var bgm_id: String = "%s_%s" % [world_id, tension]
	play_bgm(bgm_id)


func stop_bgm(fade_out: bool = true) -> void:
	if fade_out:
		var tween := create_tween()
		tween.tween_property(active_bgm_player, "volume_db", -80.0, crossfade_duration)
		tween.tween_callback(active_bgm_player.stop)
	else:
		active_bgm_player.stop()
	current_bgm_id = ""


func _play_bgm_immediate(stream: AudioStream) -> void:
	active_bgm_player.stop()
	active_bgm_player.stream = stream
	active_bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)
	active_bgm_player.play()


func _crossfade_to(stream: AudioStream) -> void:
	var old_player := active_bgm_player
	var new_player := bgm_player_b if active_bgm_player == bgm_player_a else bgm_player_a
	
	new_player.stream = stream
	new_player.volume_db = -80.0
	new_player.play()
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(old_player, "volume_db", -80.0, crossfade_duration)
	tween.tween_property(new_player, "volume_db", linear_to_db(bgm_volume * master_volume), crossfade_duration)
	tween.set_parallel(false)
	tween.tween_callback(old_player.stop)
	
	active_bgm_player = new_player


# === Volume Control ===

func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	_update_volumes()


func set_bgm_volume(volume: float) -> void:
	bgm_volume = clampf(volume, 0.0, 1.0)
	_update_volumes()


func set_se_volume(volume: float) -> void:
	se_volume = clampf(volume, 0.0, 1.0)


func _update_volumes() -> void:
	if active_bgm_player.playing:
		active_bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)
