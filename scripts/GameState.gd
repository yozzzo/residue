extends Node

const WORLDS_PATH := "res://data/worlds/worlds.json"
const EVENTS_PATH := "res://data/events/events.json"
const SAVE_SERVICE := preload("res://scripts/SaveService.gd")

var soul_points: int = 0
var loop_count: int = 1
var selected_world_id: String = ""
var last_run_score: int = 0

var worlds: Array = []
var events_by_world: Dictionary = {}
var _save_service := SAVE_SERVICE.new()

func _ready() -> void:
	load_content()
	load_persistent_state()


func load_content() -> void:
	worlds = _load_json_array(WORLDS_PATH, "worlds")
	events_by_world = _load_json_dictionary(EVENTS_PATH, "events_by_world")


func get_worlds() -> Array:
	return worlds


func get_world_by_id(world_id: String) -> Dictionary:
	for world in worlds:
		if world.get("world_id", "") == world_id:
			return world
	return {}


func get_events_for_world(world_id: String) -> Array:
	return events_by_world.get(world_id, [])


func apply_end_of_run(soul_gain: int) -> void:
	last_run_score = soul_gain
	soul_points += max(0, soul_gain)
	loop_count += 1
	save_persistent_state()


func select_world(world_id: String) -> void:
	selected_world_id = world_id
	save_persistent_state()


func load_persistent_state() -> void:
	var payload := _save_service.load_state()
	if payload.is_empty():
		return
	soul_points = int(payload.get("soul_points", soul_points))
	loop_count = int(payload.get("loop_count", loop_count))
	selected_world_id = str(payload.get("selected_world_id", selected_world_id))
	last_run_score = int(payload.get("last_run_score", 0))


func save_persistent_state() -> void:
	var payload := {
		"soul_points": soul_points,
		"loop_count": loop_count,
		"selected_world_id": selected_world_id,
		"last_run_score": last_run_score
	}
	_save_service.save_state(payload)


func _load_json_array(path: String, key: String) -> Array:
	var data := _read_json(path)
	if data is Dictionary and data.has(key) and data[key] is Array:
		return data[key]
	push_warning("Invalid JSON array key: %s in %s" % [key, path])
	return []


func _load_json_dictionary(path: String, key: String) -> Dictionary:
	var data := _read_json(path)
	if data is Dictionary and data.has(key) and data[key] is Dictionary:
		return data[key]
	push_warning("Invalid JSON dictionary key: %s in %s" % [key, path])
	return {}


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("Missing file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Cannot open file: %s" % path)
		return {}
	var text := file.get_as_text()
	var parsed := JSON.parse_string(text)
	if parsed == null:
		push_warning("Invalid JSON: %s" % path)
		return {}
	return parsed
