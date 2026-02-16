extends Node

const WORLDS_PATH := "res://data/worlds/worlds.json"
const EVENTS_PATH := "res://data/events/events.json"
const ENEMIES_PATH := "res://data/enemies/enemies.json"
const JOBS_PATH := "res://data/jobs/jobs.json"
const CROSS_LINKS_PATH := "res://data/cross_links/cross_links.json"
const SAVE_SERVICE := preload("res://scripts/SaveService.gd")

# Meta state (persistent across runs)
var soul_points: int = 0
var loop_count: int = 1
var selected_world_id: String = ""
var last_run_score: int = 0

# Phase 2: Trait Tags (persistent across runs) - GDD 4.2
var trait_tags: Dictionary = {}  # tag_name -> accumulated_value

# Phase 2: Memory Flags (persistent across runs) - GDD 4.2
var memory_flags: Dictionary = {}  # flag_name -> bool

# Phase 2: Truth Stages per world (persistent) - GDD 8.3
var world_truth_stages: Dictionary = {}  # world_id -> int (0-3)

# Phase 2: Inheritance bonuses for next run
var pending_inheritance: Dictionary = {}  # bonus_type -> value

# Phase 3: Job System (persistent) - GDD 7.1
var unlocked_jobs: Array = ["wanderer"]  # List of unlocked job_ids
var current_job: String = "wanderer"  # Selected job for current/next run

# Phase 3: Cross-World Links (persistent) - GDD 6
var cross_link_items: Array = []  # List of acquired cross-link item_ids
var cross_link_completed: Array = []  # List of completed link_ids

# Player run state (reset each run)
var run_hp: int = 100
var run_max_hp: int = 100
var run_attack_bonus: int = 0  # Phase 3: From job
var run_defense_bonus: int = 0  # Phase 3: From job
var run_gold: int = 0
var run_current_node_id: String = ""
var run_tags: Array = []
var run_kills: int = 0
var run_discoveries: int = 0
var run_nodes_visited: int = 0
var run_is_clear: bool = false
var run_is_foreign_job: bool = false  # Phase 3: Using job from different world

# Data caches
var worlds: Array = []
var events_by_world: Dictionary = {}
var enemies: Dictionary = {}
var node_maps: Dictionary = {}
var jobs: Dictionary = {}  # Phase 3: job_id -> job_data
var cross_links: Array = []  # Phase 3: List of cross-link definitions
var _save_service := SAVE_SERVICE.new()


func _ready() -> void:
	load_content()
	load_persistent_state()


func load_content() -> void:
	worlds = _load_json_array(WORLDS_PATH, "worlds")
	events_by_world = _load_json_dictionary(EVENTS_PATH, "events_by_world")
	enemies = _load_enemies()
	_load_node_maps()
	_load_jobs()
	_load_cross_links()


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


func _load_jobs() -> void:
	var data: Variant = _read_json(JOBS_PATH)
	if data is Dictionary and data.has("jobs") and data["jobs"] is Array:
		for job: Variant in data["jobs"]:
			if job is Dictionary and job.has("job_id"):
				jobs[job["job_id"]] = job


func _load_cross_links() -> void:
	var data: Variant = _read_json(CROSS_LINKS_PATH)
	if data is Dictionary and data.has("cross_links") and data["cross_links"] is Array:
		cross_links = data["cross_links"]


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


# Phase 3: Job System Functions
func get_all_jobs() -> Array:
	return jobs.values()


func get_job_by_id(job_id: String) -> Dictionary:
	return jobs.get(job_id, {})


func get_unlocked_jobs() -> Array:
	var result: Array = []
	for job_id: String in unlocked_jobs:
		var job: Dictionary = get_job_by_id(job_id)
		if not job.is_empty():
			result.append(job)
	return result


func is_job_unlocked(job_id: String) -> bool:
	return unlocked_jobs.has(job_id)


func can_unlock_job(job_id: String) -> bool:
	if is_job_unlocked(job_id):
		return false
	var job: Dictionary = get_job_by_id(job_id)
	if job.is_empty():
		return false
	var conditions: Dictionary = job.get("unlock_conditions", {})
	if conditions.has("soul_points"):
		if soul_points < int(conditions["soul_points"]):
			return false
	if conditions.has("memory_flag"):
		if not has_memory_flag(str(conditions["memory_flag"])):
			return false
	return true


func unlock_job(job_id: String) -> bool:
	if not can_unlock_job(job_id):
		return false
	var job: Dictionary = get_job_by_id(job_id)
	var conditions: Dictionary = job.get("unlock_conditions", {})
	if conditions.has("soul_points"):
		var cost: int = int(conditions["soul_points"])
		soul_points -= cost
	unlocked_jobs.append(job_id)
	save_persistent_state()
	return true


func select_job(job_id: String) -> void:
	if is_job_unlocked(job_id):
		current_job = job_id
		save_persistent_state()


func is_foreign_job(job_id: String, world_id: String) -> bool:
	var job: Dictionary = get_job_by_id(job_id)
	if job.is_empty():
		return false
	var origin: Variant = job.get("origin_world")
	if origin == null:
		return false  # Common jobs are never foreign
	return str(origin) != world_id


# Phase 3: Cross-Link Functions
func get_cross_links() -> Array:
	return cross_links


func get_cross_link_by_id(link_id: String) -> Dictionary:
	for link: Variant in cross_links:
		if link is Dictionary and link.get("link_id", "") == link_id:
			return link
	return {}


func has_cross_link_item(item_id: String) -> bool:
	return cross_link_items.has(item_id)


func acquire_cross_link_item(item_id: String) -> void:
	if not cross_link_items.has(item_id):
		cross_link_items.append(item_id)
		save_persistent_state()


func is_cross_link_completed(link_id: String) -> bool:
	return cross_link_completed.has(link_id)


func complete_cross_link(link_id: String) -> Dictionary:
	if cross_link_completed.has(link_id):
		return {}
	
	var link: Dictionary = get_cross_link_by_id(link_id)
	if link.is_empty():
		return {}
	
	cross_link_completed.append(link_id)
	
	# Apply rewards
	var rewards: Dictionary = link.get("rewards", {})
	
	# Truth stage bonus
	if rewards.has("truth_stage_bonus"):
		var bonus: int = int(rewards["truth_stage_bonus"])
		var target_world: String = link.get("target_world", selected_world_id)
		var current_stage: int = world_truth_stages.get(target_world, 0)
		world_truth_stages[target_world] = current_stage + bonus
	
	# Set flag
	if rewards.has("sets_flag"):
		set_memory_flag(str(rewards["sets_flag"]))
	
	# Mark cross_link_established for truth stage progression
	set_memory_flag("cross_link_established")
	
	# Unlock job if specified
	if rewards.has("unlocks_job") and rewards["unlocks_job"] != null:
		var job_to_unlock: String = str(rewards["unlocks_job"])
		if not is_job_unlocked(job_to_unlock):
			unlocked_jobs.append(job_to_unlock)
	
	save_persistent_state()
	return rewards


func check_and_acquire_cross_link_items() -> Array:
	var acquired: Array = []
	for link: Variant in cross_links:
		if link is not Dictionary:
			continue
		var item: Dictionary = link.get("item", {})
		var item_id: String = item.get("item_id", "")
		if item_id.is_empty() or has_cross_link_item(item_id):
			continue
		
		var obtain_condition: Dictionary = item.get("obtain_condition", {})
		if check_event_conditions(obtain_condition):
			acquire_cross_link_item(item_id)
			acquired.append(item)
	return acquired


# Run lifecycle
func start_new_run(world_id: String) -> void:
	selected_world_id = world_id
	run_max_hp = 100
	run_attack_bonus = 0
	run_defense_bonus = 0
	run_hp = run_max_hp
	run_gold = 0
	run_current_node_id = get_start_node_id(world_id)
	run_tags = []
	run_kills = 0
	run_discoveries = 0
	run_nodes_visited = 0
	run_is_clear = false
	
	# Phase 3: Check if using foreign job
	run_is_foreign_job = is_foreign_job(current_job, world_id)
	if run_is_foreign_job:
		set_memory_flag("using_foreign_job")
		set_memory_flag("foreign_job_" + current_job)
	
	# Phase 3: Apply job stat modifiers
	_apply_job_modifiers()
	
	# Apply pending inheritance bonuses
	_apply_inheritance_bonuses()
	
	save_persistent_state()


func _apply_job_modifiers() -> void:
	var job: Dictionary = get_job_by_id(current_job)
	if job.is_empty():
		return
	
	var modifiers: Dictionary = job.get("stat_modifiers", {})
	
	if modifiers.has("hp_bonus"):
		run_max_hp += int(modifiers["hp_bonus"])
		run_hp = run_max_hp
	
	if modifiers.has("attack_bonus"):
		run_attack_bonus += int(modifiers["attack_bonus"])
	
	if modifiers.has("defense_bonus"):
		run_defense_bonus += int(modifiers["defense_bonus"])


func _apply_inheritance_bonuses() -> void:
	if pending_inheritance.is_empty():
		return
	
	if pending_inheritance.has("hp_bonus"):
		run_max_hp += int(pending_inheritance["hp_bonus"])
		run_hp = run_max_hp
	
	if pending_inheritance.has("gold_start"):
		run_gold += int(pending_inheritance["gold_start"])
	
	if pending_inheritance.has("tag_boost"):
		var tag_name: String = str(pending_inheritance["tag_boost"])
		add_trait_tag(tag_name, 5)
	
	# Clear pending inheritance after applying
	pending_inheritance = {}


func apply_end_of_run(is_clear: bool = false) -> void:
	run_is_clear = is_clear
	last_run_score = calculate_soul_gain()
	soul_points += max(0, last_run_score)
	loop_count += 1
	
	# Phase 3: Check for cross-link item acquisition
	check_and_acquire_cross_link_items()
	
	# Phase 2: Update truth stage based on loop count and flags
	_update_truth_stage()
	
	save_persistent_state()


func _update_truth_stage() -> void:
	var current_stage: int = world_truth_stages.get(selected_world_id, 0)
	var new_stage: int = current_stage
	
	# Advance truth stage based on conditions (GDD 8.3)
	# Stage 1: After 3 loops in this world
	if current_stage == 0 and loop_count >= 3:
		new_stage = 1
	# Stage 2: After 7 loops + specific memory flags
	elif current_stage == 1 and loop_count >= 7:
		if selected_world_id == "medieval" and memory_flags.get("mayor_basement_seen", false):
			new_stage = 2
		elif selected_world_id == "future" and memory_flags.get("core_log_read", false):
			new_stage = 2
	# Stage 3: Cross-world flags required
	elif current_stage == 2:
		if memory_flags.get("cross_link_established", false):
			new_stage = 3
	
	world_truth_stages[selected_world_id] = new_stage


func calculate_soul_gain() -> int:
	# 深度(到達ノード数)×2 + 討伐数×3 + 発見(特殊イベント)×5 + クリアボーナス10
	var depth_score := run_nodes_visited * 2
	var kill_score := run_kills * 3
	var discovery_score := run_discoveries * 5
	var clear_bonus := 10 if run_is_clear else 0
	
	# Phase 3: Scholar job bonus for discoveries
	if current_job == "scholar":
		discovery_score = int(discovery_score * 1.5)
	
	# Apply soul_bonus from inheritance if any
	var soul_bonus := 0
	if pending_inheritance.has("soul_bonus"):
		soul_bonus = int(pending_inheritance["soul_bonus"])
	
	return depth_score + kill_score + discovery_score + clear_bonus + soul_bonus


# Phase 2: Trait Tag System (GDD 4.2)
func add_trait_tag(tag: String, amount: int = 1) -> void:
	if tag.is_empty():
		return
	var current: int = trait_tags.get(tag, 0)
	trait_tags[tag] = current + amount


func get_trait_tag_value(tag: String) -> int:
	return trait_tags.get(tag, 0)


func has_significant_trait(tag: String, threshold: int = 3) -> bool:
	return get_trait_tag_value(tag) >= threshold


func get_dominant_traits(count: int = 3) -> Array:
	var sorted_tags: Array = []
	for tag: String in trait_tags.keys():
		sorted_tags.append({"tag": tag, "value": trait_tags[tag]})
	sorted_tags.sort_custom(func(a, b): return a["value"] > b["value"])
	
	var result: Array = []
	for i: int in range(min(count, sorted_tags.size())):
		result.append(sorted_tags[i]["tag"])
	return result


# Phase 2: Memory Flags (GDD 4.2)
func set_memory_flag(flag: String, value: bool = true) -> void:
	if flag.is_empty():
		return
	memory_flags[flag] = value


func has_memory_flag(flag: String) -> bool:
	return memory_flags.get(flag, false)


# Phase 2: Truth Stage (GDD 8.3)
func get_truth_stage(world_id: String = "") -> int:
	if world_id.is_empty():
		world_id = selected_world_id
	return world_truth_stages.get(world_id, 0)


# Phase 2: Condition Checking for Events
func check_event_conditions(conditions: Dictionary) -> bool:
	# Check requires_flag
	if conditions.has("requires_flag"):
		var flag: String = str(conditions["requires_flag"])
		if not has_memory_flag(flag):
			return false
	
	# Check requires_flags (array)
	if conditions.has("requires_flags"):
		var flags: Array = conditions["requires_flags"]
		for flag: Variant in flags:
			if not has_memory_flag(str(flag)):
				return false
	
	# Check requires_tag
	if conditions.has("requires_tag"):
		var tag: String = str(conditions["requires_tag"])
		var threshold: int = int(conditions.get("tag_threshold", 3))
		if not has_significant_trait(tag, threshold):
			return false
	
	# Check requires_truth_stage
	if conditions.has("requires_truth_stage"):
		var required_stage: int = int(conditions["requires_truth_stage"])
		if get_truth_stage() < required_stage:
			return false
	
	# Check min_loop
	if conditions.has("min_loop"):
		if loop_count < int(conditions["min_loop"]):
			return false
	
	# Check excludes_flag (event hidden if flag set)
	if conditions.has("excludes_flag"):
		var flag: String = str(conditions["excludes_flag"])
		if has_memory_flag(flag):
			return false
	
	# Phase 3: Check requires_foreign_job
	if conditions.has("requires_foreign_job"):
		if not run_is_foreign_job:
			return false
	
	# Phase 3: Check requires_job
	if conditions.has("requires_job"):
		var required_job: String = str(conditions["requires_job"])
		if current_job != required_job:
			return false
	
	# Phase 3: Check requires_cross_link_item
	if conditions.has("requires_cross_link_item"):
		var item_id: String = str(conditions["requires_cross_link_item"])
		if not has_cross_link_item(item_id):
			return false
	
	return true


# Phase 2: Get applicable reaction text based on tags
func get_reaction_text(reaction_slots: Array) -> String:
	for slot: Variant in reaction_slots:
		if slot is Dictionary:
			var slot_conditions: Dictionary = slot.get("conditions", {})
			if check_event_conditions(slot_conditions):
				return str(slot.get("text", ""))
	return ""


# Phase 2: Filter choices by conditions
func filter_choices(choices: Array) -> Array:
	var result: Array = []
	for choice: Variant in choices:
		if choice is Dictionary:
			var conditions: Dictionary = choice.get("conditions", {})
			if conditions.is_empty() or check_event_conditions(conditions):
				result.append(choice)
	return result


# Phase 2: Inheritance System (GDD 4.4)
func set_pending_inheritance(bonus_type: String, value: Variant) -> void:
	pending_inheritance[bonus_type] = value


func generate_inheritance_candidates() -> Array:
	var candidates: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	# Pool of possible inheritance types
	var pool: Array = [
		{"type": "soul_bonus", "label": "魂価値+15", "value": 15, "description": "次周の魂価値に+15"},
		{"type": "hp_bonus", "label": "HP+20", "value": 20, "description": "次周の最大HPが20増加"},
		{"type": "gold_start", "label": "初期ゴールド+50", "value": 50, "description": "次周開始時にゴールド50所持"},
	]
	
	# Add tag_boost based on current run tags
	var dominant_traits := get_dominant_traits(2)
	for trait_tag: String in dominant_traits:
		pool.append({
			"type": "tag_boost",
			"label": "「%s」強化" % trait_tag,
			"value": trait_tag,
			"description": "次周で「%s」タグ+5" % trait_tag
		})
	
	# Add memory_hint if discoveries were made
	if run_discoveries > 0:
		pool.append({
			"type": "memory_hint",
			"label": "記憶の断片",
			"value": "hint_" + selected_world_id,
			"description": "次周で追加のヒントが出現"
		})
	
	# Shuffle and pick 3
	pool.shuffle()
	for i: int in range(min(3, pool.size())):
		candidates.append(pool[i])
	
	return candidates


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
	
	# Phase 2: Load persistent meta state
	if payload.has("trait_tags") and payload["trait_tags"] is Dictionary:
		trait_tags = payload["trait_tags"]
	if payload.has("memory_flags") and payload["memory_flags"] is Dictionary:
		memory_flags = payload["memory_flags"]
	if payload.has("world_truth_stages") and payload["world_truth_stages"] is Dictionary:
		world_truth_stages = payload["world_truth_stages"]
	if payload.has("pending_inheritance") and payload["pending_inheritance"] is Dictionary:
		pending_inheritance = payload["pending_inheritance"]
	
	# Phase 3: Load job system state
	if payload.has("unlocked_jobs") and payload["unlocked_jobs"] is Array:
		unlocked_jobs = payload["unlocked_jobs"]
	if payload.has("current_job"):
		current_job = str(payload["current_job"])
	
	# Phase 3: Load cross-link state
	if payload.has("cross_link_items") and payload["cross_link_items"] is Array:
		cross_link_items = payload["cross_link_items"]
	if payload.has("cross_link_completed") and payload["cross_link_completed"] is Array:
		cross_link_completed = payload["cross_link_completed"]


func save_persistent_state() -> void:
	var payload: Dictionary = {
		"soul_points": soul_points,
		"loop_count": loop_count,
		"selected_world_id": selected_world_id,
		"last_run_score": last_run_score,
		# Phase 2: Save persistent meta state
		"trait_tags": trait_tags,
		"memory_flags": memory_flags,
		"world_truth_stages": world_truth_stages,
		"pending_inheritance": pending_inheritance,
		# Phase 3: Save job system state
		"unlocked_jobs": unlocked_jobs,
		"current_job": current_job,
		# Phase 3: Save cross-link state
		"cross_link_items": cross_link_items,
		"cross_link_completed": cross_link_completed
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
