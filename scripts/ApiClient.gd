extends Node
## API Client for Residue backend (Cloudflare Workers)
## Falls back to local JSON on failure.

signal content_loaded(success: bool)

const API_BASE := "https://residue-api.residue-dev.workers.dev/api/v1"
const REQUEST_TIMEOUT := 10.0  # seconds

var _http_requests: Array[HTTPRequest] = []
var _pending_requests: int = 0
var _api_available: bool = true
var _loaded_data: Dictionary = {}  # key -> data


func _ready() -> void:
	pass


func fetch_all_content(callback: Callable) -> void:
	## Fetch worlds, enemies, jobs from API. On completion calls callback(data: Dictionary).
	## data keys: "worlds", "enemies", "jobs", "events_by_world", "node_maps"
	_loaded_data = {}
	_pending_requests = 0

	# Try API first
	_fetch_json(API_BASE + "/worlds", "_on_worlds_received", callback)
	_fetch_json(API_BASE + "/enemies", "_on_enemies_received", callback)
	_fetch_json(API_BASE + "/jobs", "_on_jobs_received", callback)


func _fetch_json(url: String, handler: String, final_callback: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	_http_requests.append(http)
	_pending_requests += 1

	http.request_completed.connect(
		func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
			_http_requests.erase(http)
			http.queue_free()
			if result == HTTPRequest.RESULT_SUCCESS and code == 200:
				var text := body.get_string_from_utf8()
				var parsed: Variant = JSON.parse_string(text)
				if parsed != null:
					call(handler, parsed, final_callback)
					return
			# Failed
			push_warning("API request failed: %s (result=%d, code=%d)" % [url, result, code])
			_api_available = false
			_pending_requests -= 1
			_check_all_done(final_callback)
	)
	var err := http.request(url)
	if err != OK:
		push_warning("HTTPRequest.request() failed for %s: %d" % [url, err])
		_api_available = false
		_pending_requests -= 1
		http.queue_free()
		_http_requests.erase(http)
		_check_all_done(final_callback)


func _on_worlds_received(data: Variant, final_callback: Callable) -> void:
	if data is Dictionary and data.has("worlds"):
		var worlds_raw: Array = data["worlds"]
		var worlds: Array = []
		for w: Variant in worlds_raw:
			worlds.append(_transform_world(w))
		_loaded_data["worlds"] = worlds

		# Now fetch events and nodes for each world
		for w: Variant in worlds_raw:
			var wid: String = w.get("world_id", "")
			if wid.is_empty():
				continue
			_fetch_json(API_BASE + "/worlds/%s/events" % wid, "_on_events_received", final_callback)
			_fetch_json(API_BASE + "/worlds/%s/nodes" % wid, "_on_nodes_received", final_callback)

	_pending_requests -= 1
	_check_all_done(final_callback)


func _on_enemies_received(data: Variant, final_callback: Callable) -> void:
	if data is Dictionary and data.has("enemies"):
		var enemies_raw: Array = data["enemies"]
		var enemies: Array = []
		for e: Variant in enemies_raw:
			enemies.append(_transform_enemy(e))
		_loaded_data["enemies"] = enemies
	_pending_requests -= 1
	_check_all_done(final_callback)


func _on_jobs_received(data: Variant, final_callback: Callable) -> void:
	if data is Dictionary and data.has("jobs"):
		var jobs_raw: Array = data["jobs"]
		var jobs: Array = []
		for j: Variant in jobs_raw:
			jobs.append(_transform_job(j))
		_loaded_data["jobs"] = jobs
	_pending_requests -= 1
	_check_all_done(final_callback)


func _on_events_received(data: Variant, final_callback: Callable) -> void:
	if data is Dictionary and data.has("events"):
		var events_raw: Array = data["events"]
		if events_raw.size() > 0:
			var world_id: String = events_raw[0].get("world_id", "")
			if not world_id.is_empty():
				if not _loaded_data.has("events_by_world"):
					_loaded_data["events_by_world"] = {}
				var events: Array = []
				for e: Variant in events_raw:
					events.append(_transform_event(e))
				_loaded_data["events_by_world"][world_id] = events
	_pending_requests -= 1
	_check_all_done(final_callback)


func _on_nodes_received(data: Variant, final_callback: Callable) -> void:
	if data is Dictionary and data.has("nodes"):
		var nodes_raw: Array = data["nodes"]
		if nodes_raw.size() > 0:
			var world_id: String = nodes_raw[0].get("world_id", "")
			if not world_id.is_empty():
				if not _loaded_data.has("node_maps"):
					_loaded_data["node_maps"] = {}
				var nodes: Array = []
				var start_node: String = ""
				for n: Variant in nodes_raw:
					var transformed := _transform_node(n)
					nodes.append(transformed)
					# First node or node with no back edge is likely start
				# Determine start_node: first node in list
				if nodes.size() > 0:
					start_node = nodes[0].get("node_id", "")
				_loaded_data["node_maps"][world_id] = {
					"world_id": world_id,
					"start_node": start_node,
					"nodes": nodes
				}
	_pending_requests -= 1
	_check_all_done(final_callback)


func _check_all_done(final_callback: Callable) -> void:
	if _pending_requests <= 0:
		if not _api_available or _loaded_data.is_empty():
			# Signal fallback needed
			final_callback.call({})
		else:
			final_callback.call(_loaded_data)


# --- Transform functions: D1 row format -> local JSON format ---

func _transform_world(row: Dictionary) -> Dictionary:
	return {
		"world_id": row.get("world_id", ""),
		"name": row.get("name_en", row.get("name_ja", "")),
		"name_ja": row.get("name_ja", ""),
		"name_en": row.get("name_en", ""),
		"blurb": row.get("setting", ""),
		"blurb_ja": row.get("setting", ""),
		"blurb_en": row.get("setting", ""),
		"tags": []
	}


func _transform_enemy(row: Dictionary) -> Dictionary:
	var rewards: Variant = _parse_json_field(row, "rewards_json", {})
	return {
		"enemy_id": row.get("enemy_id", ""),
		"name": row.get("name_en", row.get("name_ja", "")),
		"name_ja": row.get("name_ja", ""),
		"name_en": row.get("name_en", ""),
		"description": row.get("description_en", row.get("description_ja", "")),
		"description_ja": row.get("description_ja", ""),
		"description_en": row.get("description_en", ""),
		"hp": int(row.get("hp", 50)),
		"attack": int(row.get("attack", 10)),
		"defense": int(row.get("defense", 0)),
		"rewards": rewards
	}


func _transform_job(row: Dictionary) -> Dictionary:
	var stat_modifiers: Variant = _parse_json_field(row, "stat_modifiers_json", {})
	var unlock_conditions: Variant = _parse_json_field(row, "unlock_conditions_json", {})
	var special_ability: Variant = _parse_json_field(row, "special_ability_json", {})
	return {
		"job_id": row.get("job_id", ""),
		"name": row.get("name_en", row.get("name_ja", "")),
		"name_ja": row.get("name_ja", ""),
		"name_en": row.get("name_en", ""),
		"origin_world": row.get("origin_world"),
		"unlock_conditions": unlock_conditions,
		"stat_modifiers": stat_modifiers,
		"special_ability": special_ability,
	}


func _transform_event(row: Dictionary) -> Dictionary:
	var choices: Variant = _parse_json_field(row, "choices_json", [])
	var reaction_slots: Variant = _parse_json_field(row, "reaction_slots_json", [])
	var conditions: Variant = _parse_json_field(row, "conditions_json", {})
	var effects: Variant = _parse_json_field(row, "effects_json", {})

	# Map text_ja/text_en to text field
	var text_ja: String = str(row.get("text_ja", ""))
	var text_en: String = str(row.get("text_en", ""))

	return {
		"event_id": row.get("event_id", ""),
		"type": row.get("type", "explore"),
		"text": text_ja if not text_ja.is_empty() else text_en,
		"text_ja": text_ja,
		"text_en": text_en,
		"speaker": row.get("speaker"),
		"choices": choices,
		"reaction_slots": reaction_slots if reaction_slots is Array else [],
		"conditions": conditions if conditions is Dictionary else {},
		"effects": effects if effects is Dictionary else {},
	}


func _transform_node(row: Dictionary) -> Dictionary:
	var edges: Variant = _parse_json_field(row, "edges_json", {})
	var event_ids: Variant = _parse_json_field(row, "event_ids_json", [])
	var enemy_ids: Variant = _parse_json_field(row, "enemy_ids_json", [])

	var name_ja: String = str(row.get("name_ja", ""))
	var name_en: String = str(row.get("name_en", ""))

	return {
		"node_id": row.get("node_id", ""),
		"node_type": row.get("node_type", "explore"),
		"name": name_ja if not name_ja.is_empty() else name_en,
		"name_ja": name_ja,
		"name_en": name_en,
		"description": str(row.get("description_ja", row.get("description_en", ""))),
		"description_ja": str(row.get("description_ja", "")),
		"description_en": str(row.get("description_en", "")),
		"edges": edges if edges is Dictionary else {},
		"event_ids": event_ids if event_ids is Array else [],
		"enemy_ids": enemy_ids if enemy_ids is Array else [],
	}


# --- Dynamic Story Generation API ---

func resolve_event(world_id: String, node_id: String, player_id: String, truth_stage: int, traits: Array, flags: Array, callback: Callable) -> void:
	var traits_str: String = ",".join(traits)
	var flags_str: String = ",".join(flags)
	var url: String = "%s/events/resolve?world_id=%s&node_id=%s&player_id=%s&truth_stage=%d&traits=%s&flags=%s" % [
		API_BASE, world_id, node_id, player_id, truth_stage, traits_str, flags_str
	]
	var http := HTTPRequest.new()
	http.timeout = 25.0  # LLM generation may take longer
	add_child(http)
	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			if result == HTTPRequest.RESULT_SUCCESS and code == 200:
				var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
				if parsed != null and parsed is Dictionary:
					callback.call(parsed)
					return
			callback.call({})
	)
	http.request(url)


func log_action(player_id: String, run_id: String, action_type: String, detail: Dictionary) -> void:
	var url: String = API_BASE + "/actions/log"
	var payload: Dictionary = {
		"player_id": player_id,
		"run_id": run_id,
		"action_type": action_type,
		"action_detail": detail,
		"world_id": detail.get("world_id", ""),
		"node_id": detail.get("node_id", ""),
	}
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	http.request_completed.connect(
		func(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
			http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_POST, JSON.stringify(payload))


func check_ending(player_id: String, world_id: String, flags: Array, truth_stage: int, hp_zero: bool, callback: Callable) -> void:
	var flags_str: String = ",".join(flags)
	var url: String = "%s/endings/check?player_id=%s&world_id=%s&flags=%s&truth_stage=%d&hp_zero=%s" % [
		API_BASE, player_id, world_id, flags_str, truth_stage, "true" if hp_zero else "false"
	]
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			if result == HTTPRequest.RESULT_SUCCESS and code == 200:
				var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
				if parsed != null and parsed is Dictionary:
					callback.call(parsed)
					return
			callback.call({"endings": []})
	)
	http.request(url)


# Build 19: Fetch scenarios
func fetch_scenarios(callback: Callable) -> void:
	var url: String = API_BASE + "/scenarios"
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			if result == HTTPRequest.RESULT_SUCCESS and code == 200:
				var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
				if parsed is Dictionary and parsed.has("scenarios"):
					callback.call(parsed["scenarios"])
					return
			callback.call([])
	)
	http.request(url)


# Build 19: Fetch relics
func fetch_relics(callback: Callable, world_id: String = "") -> void:
	var url: String = API_BASE + "/relics"
	if not world_id.is_empty():
		url += "?world_id=" + world_id
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			if result == HTTPRequest.RESULT_SUCCESS and code == 200:
				var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
				if parsed is Dictionary and parsed.has("relics"):
					callback.call(parsed["relics"])
					return
			callback.call([])
	)
	http.request(url)


func _parse_json_field(row: Dictionary, field: String, default_value: Variant) -> Variant:
	var raw: Variant = row.get(field)
	if raw == null or raw is bool:
		return default_value
	if raw is Dictionary or raw is Array:
		return raw
	var text: String = str(raw)
	if text.is_empty() or text == "null":
		return default_value
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return default_value
	return parsed
