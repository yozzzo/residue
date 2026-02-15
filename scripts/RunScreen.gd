extends Control

signal run_ended(soul_gain: int, is_clear: bool)
signal battle_requested(enemy_id: String)

@onready var header: Label = $Margin/Root/Header
@onready var location_label: Label = $Margin/Root/LocationPanel/LocationName
@onready var body_text: RichTextLabel = $Margin/Root/BodyText
@onready var choices_box: VBoxContainer = $Margin/Root/Choices
@onready var navigation_box: HBoxContainer = $Margin/Root/Navigation
@onready var status_label: Label = $Margin/Root/Bottom/StatusLabel
@onready var exit_button: Button = $Margin/Root/Bottom/ExitRunButton

var current_node: Dictionary = {}
var current_event: Dictionary = {}
var event_index: int = 0
var pending_battle_enemy: String = ""
var node_event_queue: Array = []


func _ready() -> void:
	exit_button.pressed.connect(_on_exit_run)
	_start_run()


func _start_run() -> void:
	GameState.start_new_run(GameState.selected_world_id)
	_load_node(GameState.run_current_node_id)


func _load_node(node_id: String) -> void:
	current_node = GameState.get_node_by_id(GameState.selected_world_id, node_id)
	if current_node.is_empty():
		_show_fallback_event()
		return
	
	GameState.run_current_node_id = node_id
	GameState.record_node_visit()
	event_index = 0
	
	# Build event queue, filtering by conditions
	node_event_queue = _build_event_queue()
	
	var world: Dictionary = GameState.get_world_by_id(GameState.selected_world_id)
	var truth_stage: int = GameState.get_truth_stage()
	header.text = "Run - %s | Loop %d | 真実段階 %d" % [world.get("name", "???"), GameState.loop_count, truth_stage]
	location_label.text = "📍 %s" % current_node.get("name", "Unknown Location")
	
	_process_node()


func _build_event_queue() -> Array:
	var event_ids: Array = current_node.get("event_ids", [])
	var queue: Array = []
	
	for event_id: Variant in event_ids:
		var event: Dictionary = GameState.get_event_by_id(GameState.selected_world_id, str(event_id))
		if event.is_empty():
			continue
		
		# Check event-level conditions
		var conditions: Dictionary = event.get("conditions", {})
		if conditions.is_empty() or GameState.check_event_conditions(conditions):
			queue.append(event)
	
	return queue


func _process_node() -> void:
	if event_index < node_event_queue.size():
		current_event = node_event_queue[event_index]
		_render_event()
		return
	
	# No more events, show navigation
	_render_navigation_only()


func _render_event() -> void:
	_clear_ui()
	
	var node_type: String = current_node.get("node_type", "explore")
	var event_type: String = current_event.get("type", "explore")
	
	# Build event text with atmosphere and reaction slots
	var desc: String = current_node.get("description", "")
	var event_text: String = current_event.get("text", "")
	
	# Phase 2: Apply reaction slots based on conditions
	var reaction_slots: Array = current_event.get("reaction_slots", [])
	var reaction_text: String = _get_matching_reaction(reaction_slots)
	
	if reaction_text.is_empty():
		body_text.text = "[i]%s[/i]\n\n%s" % [desc, event_text]
	else:
		body_text.text = "[i]%s[/i]\n\n%s%s" % [desc, event_text, reaction_text]
	
	# Phase 2: Filter choices by conditions
	var all_choices: Array = current_event.get("choices", [])
	var filtered_choices: Array = GameState.filter_choices(all_choices)
	
	# Render filtered choices
	for choice: Variant in filtered_choices:
		var button := Button.new()
		button.text = choice.get("label", "選択")
		button.pressed.connect(_on_choice_selected.bind(choice))
		choices_box.add_child(button)
	
	_update_status()


func _get_matching_reaction(reaction_slots: Array) -> String:
	# Return the first matching reaction text
	for slot: Variant in reaction_slots:
		if slot is Dictionary:
			var conditions: Dictionary = slot.get("conditions", {})
			if GameState.check_event_conditions(conditions):
				return str(slot.get("text", ""))
	return ""


func _render_navigation_only() -> void:
	_clear_ui()
	
	var desc: String = current_node.get("description", "")
	var node_type: String = current_node.get("node_type", "explore")
	
	if node_type == "boss" and _has_boss_enemy():
		# Boss node without event means boss defeated
		body_text.text = "[i]%s[/i]\n\n静寂。終わりの気配。この世界の核心に辿り着いた。" % desc
	else:
		body_text.text = "[i]%s[/i]\n\nどこへ向かう？" % desc
	
	_render_navigation_buttons()
	_update_status()


func _has_boss_enemy() -> bool:
	var enemy_ids: Array = current_node.get("enemy_ids", [])
	for eid: Variant in enemy_ids:
		if str(eid).contains("boss"):
			return true
	return false


func _render_navigation_buttons() -> void:
	var edges: Dictionary = current_node.get("edges", {})
	
	var directions := {
		"forward": "前へ進む",
		"left": "左へ",
		"right": "右へ",
		"back": "戻る"
	}
	
	for dir: String in directions.keys():
		var target_node: Variant = edges.get(dir)
		if target_node != null and target_node is String and not target_node.is_empty():
			var btn := Button.new()
			btn.text = directions[dir]
			btn.pressed.connect(_on_navigate.bind(str(target_node)))
			navigation_box.add_child(btn)
	
	# Check if this is the final boss node and boss is defeated
	var node_type: String = current_node.get("node_type", "")
	if node_type == "boss":
		var clear_btn := Button.new()
		clear_btn.text = "✦ 周回クリア ✦"
		clear_btn.pressed.connect(_on_run_clear)
		navigation_box.add_child(clear_btn)


func _on_choice_selected(choice: Dictionary) -> void:
	# Apply score
	var score := int(choice.get("score", 0))
	# Score is now handled by soul calculation
	
	# Phase 2: Apply trait tags from choice
	var tags: Variant = choice.get("tags")
	if tags != null and tags is Array:
		for tag: Variant in tags:
			GameState.add_trait_tag(str(tag), 1)
	
	# Legacy: Apply single tag (backward compatibility)
	var tag: Variant = choice.get("tag")
	if tag != null and tag is String and not tag.is_empty():
		GameState.add_run_tag(tag)
		GameState.add_trait_tag(tag, 1)
	
	# Record discovery
	if choice.get("discovery", false):
		GameState.record_discovery()
	
	# Phase 2: Set memory flag from choice
	var sets_flag: Variant = choice.get("sets_flag")
	if sets_flag != null and sets_flag is String and not sets_flag.is_empty():
		GameState.set_memory_flag(sets_flag)
	
	# Phase 2: Set memory flag from event (after completing it)
	var event_sets_flag: Variant = current_event.get("sets_flag")
	if event_sets_flag != null and event_sets_flag is String and not event_sets_flag.is_empty():
		GameState.set_memory_flag(event_sets_flag)
	
	# Handle special actions
	if choice.has("flee") and choice["flee"] == true:
		_on_flee_choice()
		return
	
	if choice.has("start_battle"):
		var enemy_id: String = choice["start_battle"]
		pending_battle_enemy = enemy_id
		battle_requested.emit(enemy_id)
		return
	
	# Move to next event or navigation
	event_index += 1
	_process_node()


func _on_flee_choice() -> void:
	var edges: Dictionary = current_node.get("edges", {})
	var back_node: Variant = edges.get("back")
	if back_node != null and back_node is String and not back_node.is_empty():
		_load_node(str(back_node))
	else:
		# Can't flee, just proceed
		event_index += 1
		_process_node()


func _on_navigate(target_node_id: String) -> void:
	_load_node(target_node_id)


func on_battle_result(result: String) -> void:
	match result:
		"victory":
			# Set victory flag for boss battles
			if pending_battle_enemy.contains("boss"):
				var flag_name: String = pending_battle_enemy.replace("_boss", "") + "_defeated"
				GameState.set_memory_flag(flag_name)
				# Also set specific boss defeat flags
				if pending_battle_enemy == "m_boss_sealed_bishop":
					GameState.set_memory_flag("bishop_defeated")
				elif pending_battle_enemy == "f_boss_core_prophet":
					GameState.set_memory_flag("prophet_defeated")
			
			# Continue with node
			event_index += 1
			_process_node()
		"defeat":
			# Run ends
			_on_run_defeat()
		"flee":
			# Return to previous node
			_on_flee_choice()


func _on_run_clear() -> void:
	GameState.apply_end_of_run(true)
	run_ended.emit(GameState.last_run_score, true)


func _on_run_defeat() -> void:
	GameState.apply_end_of_run(false)
	run_ended.emit(GameState.last_run_score, false)


func _on_exit_run() -> void:
	GameState.apply_end_of_run(false)
	run_ended.emit(GameState.last_run_score, false)


func _show_fallback_event() -> void:
	_clear_ui()
	body_text.text = "[b]このノードは存在しません。[/b]\n\nワールドデータを確認してください。"
	
	var back_btn := Button.new()
	back_btn.text = "周回を終了"
	back_btn.pressed.connect(_on_exit_run)
	choices_box.add_child(back_btn)


func _clear_ui() -> void:
	for child: Node in choices_box.get_children():
		child.queue_free()
	for child: Node in navigation_box.get_children():
		child.queue_free()


func _update_status() -> void:
	# Show dominant traits in status
	var dominant_traits: Array = GameState.get_dominant_traits(2)
	var traits_text: String = ""
	if dominant_traits.size() > 0:
		traits_text = " | 傾向: " + ", ".join(dominant_traits)
	
	status_label.text = "HP: %d/%d | Gold: %d | 深度: %d | 討伐: %d%s" % [
		GameState.run_hp,
		GameState.run_max_hp,
		GameState.run_gold,
		GameState.run_nodes_visited,
		GameState.run_kills,
		traits_text
	]
