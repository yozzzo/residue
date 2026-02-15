extends Node

const WORLDS_PATH := "res://data/worlds/worlds.json"
const EVENTS_PATH := "res://data/events/events.json"
const ENEMIES_PATH := "res://data/enemies/enemies.json"
const SAVE_SERVICE := preload("res://scripts/SaveService.gd")

# Meta state (persistent across runs)
var soul_points: int = 0
var loop_count: int = 1
var selected_world_id: String = ""
var last_run_score: int = 0

# Player run state (reset each run)
var run_hp: int = 100
var run_max_hp: int = 100
var run_gold: int = 0
var run_current_node_id: String = ""
var run_tags: Array = []
var run_kills: int = 0
var run_discoveries: int = 0
var run_nodes_visited: int = 0
var run_is_clear: bool = false

# Data caches
var worlds: Array = []
var events_by_world: Dictionary = {}
var enemies: Dictionary = {}
var node_maps: Dictionary = {}
var _save_service := SAVE_SERVICE.new()


func _ready() -> void:
	load_content()
	load_persistent_state()


func load_content() -> void:
	worlds = _load_json_array(WORLDS_PATH, "worlds")
	events_by_world = _load_json_dictionary(EVENTS_PATH, "events_by_world")
	enemies = _load_enemies()
	_load_node_maps()


func _load_enemies() -> Dictionary:
	var data: Variant = _read_json(ENEMIES_PATH)
	if data is Dictionary and data.has("enemies") and data["enemies"] is Array:
		var result: Dictionary = {}
		for enemy: Variant in data["enemies"]:
			if enemy is Dictionary and enemy.has("enemy_id"):
				result[enemy["enemy_id"]] = enemy
		return result
	return {}


func _load_node_maps() -> void:
	for world: Variant in worlds:
		var world_id: String = world.get("world_id", "")
		if world_id.is_empty():
			continue
		var path := "res://data/worlds/%s_nodes.json" % world_id
		var data: Variant = _read_json(path)
		if data is Dictionary and data.has("nodes"):
			node_maps[world_id] = data
		else:
			node_maps[world_id] = {"nodes": [], "start_node": ""}


func get_worlds() -> Array:
	return worlds


func get_world_by_id(world_id: String) -> Dictionary:
	for world: Variant in worlds:
		if world.get("world_id", "") == world_id:
			return world
	return {}


func get_events_for_world(world_id: String) -> Array:
	return events_by_world.get(world_id, [])


func get_event_by_id(world_id: String, event_id: String) -> Dictionary:
	var events: Array = get_events_for_world(world_id)
	for event: Variant in events:
		if event.get("event_id", "") == event_id:
			return event
	return {}


func get_enemy_by_id(enemy_id: String) -> Dictionary:
	return enemies.get(enemy_id, {})


func get_node_map(world_id: String) -> Dictionary:
	return node_maps.get(world_id, {"nodes": [], "start_node": ""})


func get_node_by_id(world_id: String, node_id: String) -> Dictionary:
	var map: Dictionary = get_node_map(world_id)
	var nodes: Array = map.get("nodes", [])
	for node: Variant in nodes:
		if node.get("node_id", "") == node_id:
			return node
	return {}


func get_start_node_id(world_id: String) -> String:
	var map: Dictionary = get_node_map(world_id)
	return map.get("start_node", "")


# Run lifecycle
func start_new_run(world_id: String) -> void:
	selected_world_id = world_id
	run_hp = run_max_hp
	run_gold = 0
	run_current_node_id = get_start_node_id(world_id)
	run_tags = []
	run_kills = 0
	run_discoveries = 0
	run_nodes_visited = 0
	run_is_clear = false
	save_persistent_state()


func apply_end_of_run(is_clear: bool = false) -> void:
	run_is_clear = is_clear
	last_run_score = calculate_soul_gain()
	soul_points += max(0, last_run_score)
	loop_count += 1
	save_persistent_state()


func calculate_soul_gain() -> int:
	# 深度(到達ノード数)×2 + 討伐数×3 + 発見(特殊イベント)×5 + クリアボーナス10
	var depth_score := run_nodes_visited * 2
	var kill_score := run_kills * 3
	var discovery_score := run_discoveries * 5
	var clear_bonus := 10 if run_is_clear else 0
	return depth_score + kill_score + discovery_score + clear_bonus


func add_run_tag(tag: String) -> void:
	if not run_tags.has(tag):
		run_tags.append(tag)


func record_kill() -> void:
	run_kills += 1


func record_discovery() -> void:
	run_discoveries += 1


func record_node_visit() -> void:
	run_nodes_visited += 1


func take_damage(amount: int) -> void:
	run_hp = max(0, run_hp - amount)


func heal(amount: int) -> void:
	run_hp = min(run_max_hp, run_hp + amount)


func add_gold(amount: int) -> void:
	run_gold += max(0, amount)


func is_player_dead() -> bool:
	return run_hp <= 0


func select_world(world_id: String) -> void:
	selected_world_id = world_id
	save_persistent_state()


func load_persistent_state() -> void:
	var payload: Dictionary = _save_service.load_state()
	if payload.is_empty():
		return
	soul_points = int(payload.get("soul_points", soul_points))
	loop_count = int(payload.get("loop_count", loop_count))
	selected_world_id = str(payload.get("selected_world_id", selected_world_id))
	last_run_score = int(payload.get("last_run_score", 0))


func save_persistent_state() -> void:
	var payload: Dictionary = {
		"soul_points": soul_points,
		"loop_count": loop_count,
		"selected_world_id": selected_world_id,
		"last_run_score": last_run_score
	}
	_save_service.save_state(payload)


func _load_json_array(path: String, key: String) -> Array:
	var data: Variant = _read_json(path)
	if data is Dictionary and data.has(key) and data[key] is Array:
		return data[key]
	push_warning("Invalid JSON array key: %s in %s" % [key, path])
	return []


func _load_json_dictionary(path: String, key: String) -> Dictionary:
	var data: Variant = _read_json(path)
	if data is Dictionary and data.has(key) and data[key] is Dictionary:
		return data[key]
	push_warning("Invalid JSON dictionary key: %s in %s" % [key, path])
	return {}


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("Missing file: %s" % path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Cannot open file: %s" % path)
		return {}
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_warning("Invalid JSON: %s" % path)
		return {}
	return parsed
