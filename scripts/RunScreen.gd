extends Control

signal run_ended(soul_gain: int, is_clear: bool)
signal battle_requested(enemy_id: String)
signal status_updated

@onready var location_label: Label = $Margin/Root/LocationPanel/LocationVBox/LocationName
@onready var direction_label: Label = $Margin/Root/LocationPanel/LocationVBox/DirectionInfo
@onready var body_text: RichTextLabel = $Margin/Root/BodyText
@onready var choices_box: GridContainer = $Margin/Root/Choices
@onready var navigation_box: HBoxContainer = $Margin/Root/Navigation
@onready var gear_button: Button = $GearButton
@onready var gear_menu: PanelContainer = $GearMenu
@onready var feedback_btn: Button = $GearMenu/MenuVBox/FeedbackBtn
@onready var exit_run_btn: Button = $GearMenu/MenuVBox/ExitRunBtn
@onready var close_menu_btn: Button = $GearMenu/MenuVBox/CloseMenuBtn
@onready var background: ColorRect = $Background
@onready var background_image: TextureRect = $BackgroundImage
@onready var silhouette_rect: TextureRect = $SilhouetteRect

const WORLD_BACKGROUND_KEYS := {
	"medieval": "backgrounds/medieval_bg.png",
	"future": "backgrounds/future_bg.png",
}

const SILHOUETTE_KEYS := {
	"elder": "silhouettes/elder.png",
	"warrior": "silhouettes/warrior.png",
	"scholar": "silhouettes/scholar.png",
	"monster": "silhouettes/monster.png",
	"cyborg": "silhouettes/cyborg.png",
	"merchant": "silhouettes/merchant.png",
}

var current_node: Dictionary = {}
var current_event: Dictionary = {}
var event_index: int = 0
var pending_battle_enemy: String = ""
var node_event_queue: Array = []
var showing_effect_result: bool = false
var skip_start_new_run: bool = false  # Build 16: Set by Main when coming from village

# Build 19: Choice timer
var choice_timer: Timer = null
var choice_time_remaining: float = 0.0
var choice_time_limit: float = 0.0
var timer_bar: ProgressBar = null
var timer_label: Label = null
var timer_flash_active: bool = false
var current_filtered_choices: Array = []

# Build 19: Background overlay layers
var overlay_blood: ColorRect = null
var overlay_corruption: ColorRect = null
var overlay_time: ColorRect = null

# Phase 4: Typewriter effect
var typewriter: TypewriterEffect
var text_speed: TypewriterEffect.Speed = TypewriterEffect.Speed.NORMAL
var waiting_for_text: bool = false


signal feedback_requested(data: Dictionary)

func _ready() -> void:
	_setup_gear_menu()
	_setup_typewriter()
	_setup_overlays()
	_setup_choice_timer()
	_apply_theme()
	_update_texts()
	_start_run()
	
	LocaleManager.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_locale: String) -> void:
	_update_texts()
	_update_location_display()
	_update_status()


func _update_texts() -> void:
	pass


func _setup_typewriter() -> void:
	typewriter = TypewriterEffect.new()
	typewriter.setup(body_text)
	add_child(typewriter)
	typewriter.text_completed.connect(_on_text_completed)


func _setup_overlays() -> void:
	# Blood overlay (red splashes)
	overlay_blood = ColorRect.new()
	overlay_blood.color = Color(0.6, 0.05, 0.05, 0.0)
	overlay_blood.anchors_preset = Control.PRESET_FULL_RECT
	overlay_blood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_blood.visible = false
	add_child(overlay_blood)
	move_child(overlay_blood, background_image.get_index() + 1)
	
	# Corruption overlay (distortion tint)
	overlay_corruption = ColorRect.new()
	overlay_corruption.color = Color(0.3, 0.0, 0.4, 0.0)
	overlay_corruption.anchors_preset = Control.PRESET_FULL_RECT
	overlay_corruption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_corruption.visible = false
	add_child(overlay_corruption)
	move_child(overlay_corruption, overlay_blood.get_index() + 1)
	
	# Time/darkness overlay
	overlay_time = ColorRect.new()
	overlay_time.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay_time.anchors_preset = Control.PRESET_FULL_RECT
	overlay_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_time)
	move_child(overlay_time, overlay_corruption.get_index() + 1)


func _update_overlays() -> void:
	var truth_stage: int = GameState.get_truth_stage()
	var node_id: String = current_node.get("node_id", "")
	var world_id: String = GameState.selected_world_id
	
	# Blood: show if deaths > 0 at this node
	var death_count: int = GameState.get_death_count_at_node(world_id, node_id)
	if death_count > 0:
		overlay_blood.visible = true
		var blood_alpha: float = clampf(0.05 + death_count * 0.03, 0.05, 0.2)
		overlay_blood.color.a = blood_alpha
	else:
		overlay_blood.visible = false
	
	# Corruption: truth_stage >= 2
	if truth_stage >= 2:
		overlay_corruption.visible = true
		var corrupt_alpha: float = 0.05 if truth_stage == 2 else 0.12
		overlay_corruption.color.a = corrupt_alpha
	else:
		overlay_corruption.visible = false
	
	# Time darkness: proportional to turn_count
	var darkness: float = float(GameState.run_turn_count) / float(GameState.MAX_TURNS) * 0.35
	overlay_time.color.a = darkness


func _setup_choice_timer() -> void:
	choice_timer = Timer.new()
	choice_timer.one_shot = false
	choice_timer.wait_time = 0.1
	choice_timer.timeout.connect(_on_choice_timer_tick)
	add_child(choice_timer)


func _start_choice_timer(time_limit: float) -> void:
	choice_time_limit = time_limit
	choice_time_remaining = time_limit
	timer_flash_active = false
	
	# Create timer UI above choices
	if timer_bar != null:
		timer_bar.queue_free()
	if timer_label != null:
		timer_label.queue_free()
	
	timer_bar = ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(0, 8)
	timer_bar.max_value = time_limit
	timer_bar.value = time_limit
	timer_bar.show_percentage = false
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = ThemeManager.get_accent_color()
	fill_style.set_corner_radius_all(4)
	timer_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	bg_style.set_corner_radius_all(4)
	timer_bar.add_theme_stylebox_override("background", bg_style)
	
	# Insert before choices_box
	var root: VBoxContainer = $Margin/Root
	root.add_child(timer_bar)
	root.move_child(timer_bar, choices_box.get_index())
	
	choice_timer.start()


func _stop_choice_timer() -> void:
	choice_timer.stop()
	if timer_bar != null:
		timer_bar.queue_free()
		timer_bar = null
	if timer_label != null:
		timer_label.queue_free()
		timer_label = null


func _on_choice_timer_tick() -> void:
	choice_time_remaining -= 0.1
	if timer_bar != null:
		timer_bar.value = maxf(0.0, choice_time_remaining)
	
	# Flash red at 3 seconds
	if choice_time_remaining <= 3.0 and not timer_flash_active:
		timer_flash_active = true
		if timer_bar != null:
			var fill_style := StyleBoxFlat.new()
			fill_style.bg_color = Color(0.9, 0.2, 0.2)
			fill_style.set_corner_radius_all(4)
			timer_bar.add_theme_stylebox_override("fill", fill_style)
		# Show urgency text
		body_text.text += "\n\n[center][shake rate=20 level=8][color=#ff3333]急げ——[/color][/shake][/center]"
	
	# Time's up
	if choice_time_remaining <= 0.0:
		_stop_choice_timer()
		_on_timer_expired()


func _on_timer_expired() -> void:
	# Select first choice as default
	if current_filtered_choices.size() > 0:
		_on_choice_selected(current_filtered_choices[0])


func _apply_theme() -> void:
	# Apply world-specific background image via AssetManager
	var world_id: String = ThemeManager.current_world
	if WORLD_BACKGROUND_KEYS.has(world_id):
		var tex: Texture2D = AssetManager.get_texture(WORLD_BACKGROUND_KEYS[world_id])
		if tex != null:
			background_image.texture = tex
			background.color = Color(ThemeManager.get_background_color(), 0.6)
		else:
			background_image.texture = null
			background.color = ThemeManager.get_background_color()
	else:
		background_image.texture = null
		background.color = ThemeManager.get_background_color()
	
	# Style gear button
	gear_button.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.6))
	var gear_normal := UITheme.create_button_stylebox(Color(0.1, 0.1, 0.15, 0.5))
	gear_button.add_theme_stylebox_override("normal", gear_normal)
	
	# Style gear menu
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	menu_style.set_corner_radius_all(8)
	menu_style.set_border_width_all(1)
	menu_style.border_color = ThemeManager.get_accent_color() * Color(1, 1, 1, 0.3)
	menu_style.content_margin_left = 8
	menu_style.content_margin_right = 8
	menu_style.content_margin_top = 8
	menu_style.content_margin_bottom = 8
	gear_menu.add_theme_stylebox_override("panel", menu_style)
	
	# Style location panel
	var location_panel: PanelContainer = $Margin/Root/LocationPanel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	location_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Connect to theme changes
	if not ThemeManager.theme_changed.is_connected(_on_theme_changed):
		ThemeManager.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(_world_id: String) -> void:
	background.color = ThemeManager.get_background_color()


func _input(event: InputEvent) -> void:
	# Skip text with any tap/click/key while typewriter is playing
	if not waiting_for_text:
		return
	if event is InputEventMouseButton and event.pressed:
		typewriter.skip()
	elif event is InputEventScreenTouch and event.pressed:
		typewriter.skip()
	elif event is InputEventKey and event.pressed:
		typewriter.skip()


func _on_text_completed() -> void:
	waiting_for_text = false


# Build 16: Track if loop start text has been shown
var _loop_start_shown: bool = false
# Build 16: Track previous truth stage for detecting changes mid-run
var _last_known_truth_stage: int = 0


func _start_run() -> void:
	# Check for empty content (no data from API or local)
	if GameState.content_is_empty and not GameState.content_loaded_from_api:
		_show_data_error()
		return
	if not skip_start_new_run:
		GameState.start_new_run(GameState.selected_world_id)
	_last_known_truth_stage = GameState.get_truth_stage()
	_loop_start_shown = false
	_load_node(GameState.run_current_node_id)


func _show_data_error() -> void:
	_clear_ui()
	var text: String = "[b]データ読み込みエラー[/b]\n\nサーバーからデータを取得できませんでした。\nネットワーク接続を確認してください。"
	body_text.text = text
	var back_btn := UITheme.create_choice_button("戻る")
	back_btn.pressed.connect(_on_exit_run)
	choices_box.add_child(back_btn)


func _load_node(node_id: String) -> void:
	print("[RunScreen] _load_node called: node_id=%s, world=%s" % [node_id, GameState.selected_world_id])
	# Set node ID FIRST so StatusBar reads correct location
	GameState.run_current_node_id = node_id
	
	current_node = GameState.get_node_by_id(GameState.selected_world_id, node_id)
	print("[RunScreen] current_node keys: %s, name: %s" % [str(current_node.keys()), current_node.get("name", "EMPTY")])
	if current_node.is_empty():
		print("[RunScreen] ERROR: Node is empty! node_id=%s" % node_id)
		_show_fallback_event()
		return
	
	GameState.record_node_visit()
	event_index = 0
	_dynamic_event_requested = false
	
	# Check turn limit
	if GameState.is_turn_limit_reached():
		_on_turn_limit_reached()
		return
	
	# Random trap damage on exploration (15% chance, 5-15 damage)
	if randf() < 0.15 and current_node.get("node_type", "") != "boss":
		var trap_dmg: int = randi_range(5, 15)
		GameState.take_damage(trap_dmg)
		status_updated.emit()
		if GameState.is_player_dead():
			_on_run_defeat()
			return
		_show_trap_message(trap_dmg)
		return  # Wait for player to tap continue before proceeding
	
	# Random encounter (30% chance on non-battle, non-boss nodes)
	var node_type: String = current_node.get("node_type", "explore")
	if node_type != "battle" and node_type != "boss" and randf() < 0.30:
		var random_enemy: String = GameState.get_random_enemy_for_world(GameState.selected_world_id)
		if not random_enemy.is_empty():
			pending_battle_enemy = random_enemy
			battle_requested.emit(random_enemy)
			return
	
	# Build event queue, filtering by conditions
	node_event_queue = _build_event_queue()
	_continue_load_node()


func _continue_load_node() -> void:
	print("[RunScreen] _continue_load_node called, event_queue size: %d" % node_event_queue.size())
	var world: Dictionary = GameState.get_world_by_id(GameState.selected_world_id)
	var world_name: String = LocaleManager.tr_data(world, "name")
	var truth_stage: int = GameState.get_truth_stage()
	
	_update_location_display()
	status_updated.emit()
	_process_node()


func _update_location_display() -> void:
	var node_name: String = LocaleManager.tr_data(current_node, "name")
	if node_name.is_empty():
		node_name = current_node.get("name", "Unknown Location")
	location_label.text = LocaleManager.t("ui.location", {"name": node_name})
	
	# Show available directions/exits
	var edges: Dictionary = current_node.get("edges", {})
	var directions: Array = []
	var direction_keys := ["forward", "left", "right", "back"]
	
	for key: String in edges.keys():
		var target: Variant = edges[key]
		if target == null or (target is String and target.is_empty()):
			continue
		if direction_keys.has(key):
			match key:
				"forward": directions.append(LocaleManager.t("ui.dir_forward"))
				"left": directions.append(LocaleManager.t("ui.dir_left"))
				"right": directions.append(LocaleManager.t("ui.dir_right"))
				"back": directions.append(LocaleManager.t("ui.dir_back"))
		else:
			directions.append(key)
	
	if direction_label != null:
		if directions.size() > 0:
			direction_label.text = LocaleManager.t("ui.directions", {"dirs": " ".join(directions)})
		else:
			direction_label.text = LocaleManager.t("ui.dead_end")


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


var _dynamic_event_requested: bool = false

func _process_node() -> void:
	print("[RunScreen] _process_node: event_index=%d, queue_size=%d, dynamic_requested=%s" % [event_index, node_event_queue.size(), str(_dynamic_event_requested)])
	if event_index < node_event_queue.size():
		current_event = node_event_queue[event_index]
		print("[RunScreen] Rendering event: %s" % current_event.get("event_id", "???"))
		_render_event()
		return
	
	# Build 18: Try dynamic event generation if not yet requested
	if not _dynamic_event_requested:
		_dynamic_event_requested = true
		print("[RunScreen] Requesting dynamic event...")
		_request_dynamic_event()
		return
	
	# No more events, show navigation
	print("[RunScreen] No events, showing navigation")
	_render_navigation_only()


# Build 18: Request dynamic event from API
func _request_dynamic_event() -> void:
	# Show navigation immediately so player isn't stuck
	_render_navigation_only()
	
	if GameState._api_client == null:
		return
	
	var traits: Array = GameState.get_dominant_traits(3)
	var flags: Array = GameState.memory_flags.keys()
	var truth_stage: int = GameState.get_truth_stage()
	var world_id: String = GameState.selected_world_id
	var node_id: String = current_node.get("node_id", "")
	
	# Async: if dynamic event arrives, replace navigation with event
	GameState._api_client.resolve_event(
		world_id, node_id, GameState.player_id, truth_stage, traits, flags,
		func(result: Dictionary) -> void:
			if result.is_empty() or not result.has("text_ja"):
				return  # Keep navigation as-is
			# Transform to event format and add to queue
			var dynamic_event: Dictionary = {
				"event_id": result.get("gen_event_id", "dynamic"),
				"type": "explore",
				"text_ja": result.get("text_ja", ""),
				"text": result.get("text_ja", ""),
				"choices": result.get("choices", []),
				"conditions": {},
				"effects": {},
				"is_dynamic": true,
			}
			node_event_queue.append(dynamic_event)
			current_event = dynamic_event
			_render_event()
	)


func _render_event() -> void:
	_clear_ui()
	
	var node_type: String = current_node.get("node_type", "explore")
	var event_type: String = current_event.get("type", "explore")
	
	# Show silhouette for dialogue events
	_update_silhouette()
	
	# Build event text with atmosphere and reaction slots
	var desc: String = LocaleManager.tr_data(current_node, "description")
	if desc.is_empty():
		desc = current_node.get("description", "")
	var event_text: String = LocaleManager.tr_data(current_event, "text")
	if event_text.is_empty():
		event_text = current_event.get("text", "")
	
	# Phase 2: Apply reaction slots based on conditions
	var reaction_slots: Array = current_event.get("reaction_slots", [])
	var reaction_text: String = _get_matching_reaction(reaction_slots)
	
	# Build 16: Prefix texts
	var prefix_parts: Array = []
	
	# Build 16: Loop start演出 (only on first node)
	if not _loop_start_shown:
		_loop_start_shown = true
		var loop_text: String = _generate_loop_start_text()
		if not loop_text.is_empty():
			prefix_parts.append(loop_text)
	
	# Build 16: Death trace text
	var trace_text: String = _generate_trace_text()
	if not trace_text.is_empty():
		prefix_parts.append(trace_text)
	
	# Phase 4: Apply BBCode effects for atmosphere
	var formatted_text: String
	var prefix: String = "\n\n".join(prefix_parts)
	if not prefix.is_empty():
		prefix += "\n\n"
	
	if reaction_text.is_empty():
		formatted_text = "%s[color=#aaaaaa]%s[/color]\n\n%s" % [prefix, desc, _apply_atmosphere_effects(event_text)]
	else:
		formatted_text = "%s[color=#aaaaaa]%s[/color]\n\n%s%s" % [prefix, desc, _apply_atmosphere_effects(event_text), reaction_text]
	
	# Build 19: Update background overlays
	_update_overlays()
	
	# Phase 2: Filter choices by conditions
	var all_choices: Array = current_event.get("choices", [])
	var filtered_choices: Array = GameState.filter_choices(all_choices)
	
	# Build 19: Random glitch relic — 10% chance to shuffle choices
	if GameState.has_relic_effect("random_glitch") and randf() < 0.1 and filtered_choices.size() > 1:
		filtered_choices.shuffle()
	
	# Store for timer expiry
	current_filtered_choices = filtered_choices
	
	# Use 2 columns when 3+ choices to keep compact
	choices_box.columns = 2 if filtered_choices.size() >= 3 else 1
	
	# Render filtered choices BEFORE starting typewriter (disabled until text completes)
	for choice: Variant in filtered_choices:
		var choice_label: String = LocaleManager.tr_data(choice, "label")
		if choice_label.is_empty():
			choice_label = choice.get("label", LocaleManager.t("ui.select"))
		var button := UITheme.create_choice_button(choice_label)
		button.pressed.connect(_on_choice_selected.bind(choice))
		choices_box.add_child(button)
	
	# Phase 4: Use typewriter effect (must start AFTER buttons are added)
	waiting_for_text = true
	typewriter.display_text(formatted_text, text_speed)
	
	# Build 18: Record when choices were shown for response_ms
	GameState.choice_shown_at_ms = Time.get_ticks_msec()
	
	# Build 19: Start choice timer if event has time_limit
	var time_limit: Variant = current_event.get("time_limit")
	if time_limit != null and float(time_limit) > 0:
		_start_choice_timer(float(time_limit))
	
	_update_status()


# Build 16: Generate trace text for death locations
func _generate_trace_text() -> String:
	var node_id: String = current_node.get("node_id", "")
	var world_id: String = GameState.selected_world_id
	var death_count: int = GameState.get_death_count_at_node(world_id, node_id)
	
	if death_count == 0:
		return ""
	
	var trace: String
	if death_count >= 10:
		trace = LocaleManager.t("ui.trace_many")
	elif death_count >= 5:
		trace = LocaleManager.t("ui.trace_several")
	elif death_count >= 2:
		trace = LocaleManager.t("ui.trace_few")
	else:
		trace = LocaleManager.t("ui.trace_once")
	
	return "[color=#6a6080]%s[/color]" % trace


# Build 16: Generate loop start text
func _generate_loop_start_text() -> String:
	var parts: Array = []
	var loop: int = GameState.loop_count
	
	if loop == 2:
		parts.append(LocaleManager.t("ui.loop_start_2"))
	elif loop >= 3:
		parts.append(LocaleManager.t("ui.loop_start_3", {"count": loop}))
	
	# Inheritance feedback
	if GameState.pending_inheritance.has("hp_bonus"):
		parts.append(LocaleManager.t("ui.inheritance_feel_hp"))
	if GameState.pending_inheritance.has("gold_start"):
		parts.append(LocaleManager.t("ui.inheritance_feel_gold"))
	
	if parts.is_empty():
		return ""
	return "[color=#8888aa]%s[/color]" % "\n".join(parts)


# Build 16: Show truth stage change演出
func _show_truth_stage_change(old_stage: int, new_stage: int) -> void:
	var text: String = ""
	if old_stage == 0 and new_stage >= 1:
		text = LocaleManager.t("ui.truth_advance_1")
	elif old_stage == 1 and new_stage >= 2:
		text = LocaleManager.t("ui.truth_advance_2")
	elif old_stage == 2 and new_stage >= 3:
		text = LocaleManager.t("ui.truth_advance_3")
	
	if text.is_empty():
		return
	
	# Flash effect
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.3)
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 1.0)
	tween.tween_callback(flash.queue_free)
	
	# Prepend truth text to body
	body_text.text = "[center][shake rate=10 level=5][color=#c0a0e0]%s[/color][/shake][/center]\n\n%s" % [text, body_text.text]


# Build 16: Cross-link item acquisition演出
func _show_cross_link_item_effect(item: Dictionary) -> void:
	var item_name: String = LocaleManager.tr_data(item, "name")
	if item_name.is_empty():
		item_name = item.get("name", "???")
	
	# Flash with other-world color
	var flash := ColorRect.new()
	var other_world: String = item.get("target_world", "")
	if other_world == "medieval":
		flash.color = Color(0.7, 0.5, 0.8, 0.3)
	else:
		flash.color = Color(0.3, 0.7, 0.9, 0.3)
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.8)
	tween.tween_callback(flash.queue_free)
	
	# Add text
	var effect_text: String = "\n\n[center][color=#c0a0e0]%s[/color]\n[b][wave amp=15 freq=2]%s[/wave][/b][/center]" % [
		LocaleManager.t("ui.crosslink_item_get"),
		item_name
	]
	body_text.text += effect_text


# Build 16: Cross-link completion演出
func _show_cross_link_complete_effect() -> void:
	# Wave effect using tween on body_text position
	var original_pos: Vector2 = body_text.position
	var tween: Tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(body_text, "position:x", original_pos.x + 4, 0.05)
	tween.tween_property(body_text, "position:x", original_pos.x - 4, 0.1)
	tween.tween_property(body_text, "position:x", original_pos.x, 0.05)
	
	body_text.text += "\n\n[center][shake rate=15 level=8][color=#e0c060]%s[/color][/shake][/center]" % LocaleManager.t("ui.crosslink_complete")


func _apply_atmosphere_effects(text: String) -> String:
	## Apply BBCode effects based on truth stage and event type
	var truth_stage: int = GameState.get_truth_stage()
	
	# High truth stage: Add subtle shake/wave to certain keywords
	if truth_stage >= 2:
		# Replace specific keywords with effects
		text = text.replace("異変", "[shake rate=10 level=3]異変[/shake]")
		text = text.replace("真実", "[wave amp=20 freq=3]真実[/wave]")
		text = text.replace("残痕", "[shake rate=15 level=5][color=#a060a0]残痕[/color][/shake]")
		text = text.replace("Residue", "[shake rate=20 level=8][color=#9050a0]Residue[/color][/shake]")
	
	# Apply color based on event type
	var event_type: String = current_event.get("type", "explore")
	if event_type == "anomaly" or current_event.get("is_anomaly", false):
		text = "[color=#a080c0]%s[/color]" % text
	
	return text


func _get_matching_reaction(reaction_slots: Array) -> String:
	# Return the first matching reaction text (localized if available)
	# Build 16: Enhanced with color styling and new reaction detection
	var event_id: String = current_event.get("event_id", "")
	for i: int in range(reaction_slots.size()):
		var slot: Variant = reaction_slots[i]
		if slot is Dictionary:
			var conditions: Dictionary = slot.get("conditions", {})
			if GameState.check_event_conditions(conditions):
				var text: String = LocaleManager.tr_data(slot, "text")
				if text.is_empty():
					text = str(slot.get("text", ""))
				if text.is_empty():
					continue
				
				# Build 16: Check if this reaction is new
				var is_new: bool = not GameState.is_reaction_seen(event_id, i)
				GameState.mark_reaction_seen(event_id, i)
				
				# Build 16: Style reaction text
				var prefix: String = "\n\n——"
				if is_new:
					prefix = "\n\n[color=#8070a0]%s[/color]\n——" % LocaleManager.t("ui.reaction_new")
				return "%s[color=#a080c0]%s[/color]" % [prefix, text]
	return ""


func _render_navigation_only() -> void:
	_clear_ui()
	_update_overlays()
	
	var desc: String = LocaleManager.tr_data(current_node, "description")
	if desc.is_empty():
		desc = current_node.get("description", "")
	var node_type: String = current_node.get("node_type", "explore")
	
	var nav_text: String
	if node_type == "boss" and _has_boss_enemy():
		# Boss node without event means boss defeated
		nav_text = "[color=#aaaaaa]%s[/color]\n\n%s" % [desc, LocaleManager.t("ui.nav_boss_cleared")]
	else:
		nav_text = "[color=#aaaaaa]%s[/color]\n\n%s" % [desc, LocaleManager.t("ui.nav_where")]
	
	typewriter.display_text(nav_text, TypewriterEffect.Speed.FAST)
	
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
	var direction_keys := ["forward", "left", "right", "back"]
	var direction_labels := {
		"forward": LocaleManager.t("ui.nav_forward"),
		"left": LocaleManager.t("ui.nav_left"),
		"right": LocaleManager.t("ui.nav_right"),
		"back": LocaleManager.t("ui.nav_back")
	}
	
	for key: String in edges.keys():
		var target_node: Variant = edges[key]
		if target_node == null or (target_node is String and target_node.is_empty()):
			continue
		
		if direction_keys.has(key):
			# Dungeon-style directional navigation
			var btn := UITheme.create_nav_button(direction_labels[key])
			btn.pressed.connect(_on_navigate.bind(str(target_node)))
			navigation_box.add_child(btn)
		else:
			# Named edge — use key as label (skip self-referencing edges)
			if str(target_node) == current_node.get("node_id", ""):
				continue
			var btn := UITheme.create_choice_button(key)
			btn.pressed.connect(_on_navigate.bind(str(target_node)))
			navigation_box.add_child(btn)
	
	# Build 19: Route overrides from cross-links
	var overrides: Dictionary = GameState.get_route_overrides(current_node.get("node_id", ""))
	for label: String in overrides.keys():
		var target: String = str(overrides[label])
		var override_btn := UITheme.create_choice_button("[color=#c0a0e0]%s[/color]" % label)
		override_btn.pressed.connect(_on_navigate.bind(target))
		navigation_box.add_child(override_btn)
	
	# Check if this is the final boss node and boss is defeated
	var node_type: String = current_node.get("node_type", "")
	if node_type == "boss":
		var clear_btn := UITheme.create_primary_button(LocaleManager.t("ui.run_clear"))
		clear_btn.pressed.connect(_on_run_clear)
		navigation_box.add_child(clear_btn)


func _on_choice_selected(choice: Dictionary) -> void:
	# Build 19: Stop choice timer
	_stop_choice_timer()
	
	# Skip typewriter if still playing
	if waiting_for_text:
		typewriter.skip()
		waiting_for_text = false
	
	# Build 18: Log action with response time
	var response_ms: int = Time.get_ticks_msec() - GameState.choice_shown_at_ms
	GameState.log_action_to_api("choice", {
		"choice_label": choice.get("label", ""),
		"response_ms": response_ms,
		"node_id": current_node.get("node_id", ""),
		"event_id": current_event.get("event_id", ""),
	})
	
	# Build 16: Record choice and check for different previous choice
	var choice_label: String = choice.get("label", "")
	var event_id: String = current_event.get("event_id", "")
	var node_id: String = current_node.get("node_id", "")
	var prev_choice: String = GameState.get_previous_choice(node_id, event_id)
	GameState.record_choice(node_id, event_id, choice_label)
	
	# Apply score
	var score := int(choice.get("score", 0))
	# Score is now handled by soul calculation
	
	# Phase 5: Apply effect from choice
	var effect: Variant = choice.get("effect")
	if effect != null and effect is Dictionary:
		_apply_choice_effect(effect)
		if GameState.is_player_dead():
			_on_run_defeat()
			return
	
	# Legacy: Apply direct damage field
	var damage: Variant = choice.get("damage")
	if damage != null:
		GameState.take_damage(int(damage))
		status_updated.emit()
		if GameState.is_player_dead():
			_on_run_defeat()
			return
	
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
		# Phase 3: Check for cross-link delivery completion
		_check_cross_link_delivery(sets_flag)
	
	# Phase 2: Set memory flag from event (after completing it)
	var event_sets_flag: Variant = current_event.get("sets_flag")
	if event_sets_flag != null and event_sets_flag is String and not event_sets_flag.is_empty():
		GameState.set_memory_flag(event_sets_flag)
	
	# Build 19: Handle relic_grant effect
	if effect != null and effect is Dictionary and str(effect.get("type", "")) == "relic_grant":
		var relic_id: String = str(effect.get("relic_id", ""))
		if not relic_id.is_empty() and not GameState.has_relic(relic_id):
			var relic_data: Dictionary = effect.get("relic_data", {})
			GameState.grant_relic(relic_id, relic_data)
	
	# Build 16: Check for cross-link item acquisition after flag changes
	var acquired_items: Array = GameState.check_and_acquire_cross_link_items()
	for acq_item: Variant in acquired_items:
		if acq_item is Dictionary:
			_show_cross_link_item_effect(acq_item)
	
	# Build 16: Check truth stage change
	var current_truth: int = GameState.get_truth_stage()
	if current_truth > _last_known_truth_stage:
		_show_truth_stage_change(_last_known_truth_stage, current_truth)
		_last_known_truth_stage = current_truth
	
	# Handle special actions
	if choice.has("flee") and choice["flee"] == true:
		_on_flee_choice()
		return
	
	if choice.has("start_battle"):
		var enemy_id: String = choice["start_battle"]
		pending_battle_enemy = enemy_id
		battle_requested.emit(enemy_id)
		return
	
	# Check if effect triggered a battle
	if effect != null and effect is Dictionary and str(effect.get("type", "")) == "battle":
		return  # battle_requested already emitted
	
	# Build 16: Prepend different-choice memory text
	var diff_choice_prefix: String = ""
	if not prev_choice.is_empty() and prev_choice != choice_label:
		diff_choice_prefix = "[color=#6a6080]%s[/color]\n\n" % LocaleManager.t("ui.trace_different_choice")
	
	# Show result text if available, then proceed
	var result_text: String = _get_result_text(choice)
	if not diff_choice_prefix.is_empty():
		result_text = diff_choice_prefix + result_text
	if not result_text.is_empty():
		_show_result_then_proceed(result_text)
		return
	
	# Move to next event or navigation
	event_index += 1
	status_updated.emit()
	_process_node()


func _check_cross_link_delivery(flag: String) -> void:
	# Check if this flag completes a cross-link
	var cross_links: Array = GameState.get_cross_links()
	
	for link: Variant in cross_links:
		if link is not Dictionary:
			continue
		
		var link_id: String = link.get("link_id", "")
		if GameState.is_cross_link_completed(link_id):
			continue
		
		# Check if the delivery flag matches
		var delivery: Dictionary = link.get("delivery", {})
		var delivery_event_id: String = delivery.get("target_event_id", "")
		
		# Match flag pattern: cross_X_delivered
		if flag == "cross_quantum_delivered" and link_id == "quantum_circuit_link":
			_complete_cross_link_with_notification(link_id)
		elif flag == "cross_cipher_delivered" and link_id == "ancient_cipher_link":
			_complete_cross_link_with_notification(link_id)


func _complete_cross_link_with_notification(link_id: String) -> void:
	var rewards: Dictionary = GameState.complete_cross_link(link_id)
	if rewards.is_empty():
		return
	
	var link: Dictionary = GameState.get_cross_link_by_id(link_id)
	var link_name: String = LocaleManager.tr_data(link, "name")
	if link_name.is_empty():
		link_name = link.get("name", "Cross-Link")
	
	# Build 16: Show cross-link completion演出
	_show_cross_link_complete_effect()
	
	# Build 16: Check truth stage change
	var new_truth: int = GameState.get_truth_stage()
	if new_truth > _last_known_truth_stage:
		_show_truth_stage_change(_last_known_truth_stage, new_truth)
		_last_known_truth_stage = new_truth
	
	print("[Cross-Link] %s completed! Truth stage bonus: %d" % [
		link_name,
		rewards.get("truth_stage_bonus", 0)
	])


func _get_result_text(choice: Dictionary) -> String:
	var key: String = "result_text_ja" if LocaleManager.current_locale == "ja" else "result_text_en"
	var text: String = choice.get(key, "")
	if text.is_empty():
		text = choice.get("result_text", "")
	
	# Append effect feedback
	var eff: Variant = choice.get("effect")
	if eff != null and eff is Dictionary:
		var etype: String = str(eff.get("type", ""))
		var val: int = int(eff.get("value", 0))
		if etype == "heal" and val > 0:
			text += "\n" + LocaleManager.t("ui.effect_heal", {"value": val})
		elif etype == "damage" and val > 0:
			text += "\n" + LocaleManager.t("ui.effect_damage", {"value": val})
		elif etype == "gold" and val > 0:
			text += "\n" + LocaleManager.t("ui.effect_gold", {"value": val})
	
	var dmg: Variant = choice.get("damage")
	if dmg != null and int(dmg) > 0:
		text += "\n" + LocaleManager.t("ui.effect_damage", {"value": int(dmg)})
	
	return text


func _show_result_then_proceed(result_text: String) -> void:
	_clear_ui()
	waiting_for_text = true
	typewriter.display_text(result_text, TypewriterEffect.Speed.FAST)
	
	var continue_btn := UITheme.create_choice_button(LocaleManager.t("ui.nav_forward"))
	continue_btn.pressed.connect(func() -> void:
		event_index += 1
		status_updated.emit()
		_process_node()
	)
	choices_box.add_child(continue_btn)


func _apply_choice_effect(effect: Dictionary) -> void:
	var effect_type: String = str(effect.get("type", ""))
	match effect_type:
		"heal":
			var value: int = int(effect.get("value", 0))
			GameState.heal(value)
		"damage":
			var value: int = int(effect.get("value", 0))
			GameState.take_damage(value)
		"gold":
			var value: int = int(effect.get("value", 0))
			GameState.add_gold(value)
		"battle":
			var enemy_id: String = str(effect.get("enemy_id", ""))
			if not enemy_id.is_empty():
				pending_battle_enemy = enemy_id
				battle_requested.emit(enemy_id)
	status_updated.emit()


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
	
	status_updated.emit()


func _on_run_clear() -> void:
	# Build 18: Check for special endings before standard clear
	if GameState._api_client != null:
		var flags: Array = GameState.memory_flags.keys()
		var truth_stage: int = GameState.get_truth_stage()
		GameState._api_client.check_ending(
			GameState.player_id, GameState.selected_world_id, flags, truth_stage, false,
			func(result: Dictionary) -> void:
				var endings: Array = result.get("endings", [])
				if endings.size() > 0:
					_show_ending(endings[0])
				else:
					GameState.apply_end_of_run(true)
					run_ended.emit(GameState.last_run_score, true)
		)
		return
	GameState.apply_end_of_run(true)
	run_ended.emit(GameState.last_run_score, true)


func _show_ending(ending: Dictionary) -> void:
	_clear_ui()
	var title: String = ending.get("title_ja", "")
	var epilogue: String = ending.get("epilogue_ja", "")
	var layer: String = ending.get("ending_layer", "surface")
	
	var color: String = "#c0c0c0"
	if layer == "hidden":
		color = "#c0a0e0"
	elif layer == "true":
		color = "#e0c060"
	
	var text: String = "[center][color=%s][b]— %s —[/b][/color][/center]\n\n%s" % [color, title, epilogue]
	waiting_for_text = true
	typewriter.display_text(text, TypewriterEffect.Speed.NORMAL)
	
	var done_btn := UITheme.create_primary_button("終わり")
	done_btn.pressed.connect(func() -> void:
		GameState.apply_end_of_run(true)
		run_ended.emit(GameState.last_run_score, true)
	)
	choices_box.add_child(done_btn)


func _on_run_defeat() -> void:
	# Build 16: Record death location
	GameState.record_death("defeat")
	GameState.apply_end_of_run(false)
	run_ended.emit(GameState.last_run_score, false)


func _setup_gear_menu() -> void:
	gear_button.pressed.connect(_toggle_gear_menu)
	feedback_btn.pressed.connect(_on_feedback)
	exit_run_btn.pressed.connect(_on_exit_run)
	close_menu_btn.pressed.connect(_toggle_gear_menu)


func _toggle_gear_menu() -> void:
	gear_menu.visible = not gear_menu.visible


func _on_feedback() -> void:
	gear_menu.visible = false
	var data := {
		"screen": "RunScreen",
		"world": GameState.selected_world_id,
		"node_id": current_node.get("node_id", ""),
		"node_name": current_node.get("name", ""),
		"event_id": current_event.get("event_id", ""),
		"event_type": current_event.get("type", ""),
		"event_text": current_event.get("text", "").substr(0, 100),
		"loop": GameState.loop_count,
		"truth_stage": GameState.get_truth_stage(),
		"hp": GameState.run_hp,
		"max_hp": GameState.run_max_hp,
		"gold": GameState.run_gold,
		"job": GameState.current_job,
		"depth": GameState.run_nodes_visited,
		"kills": GameState.run_kills,
		"flags": GameState.memory_flags.keys(),
		"traits": GameState.get_dominant_traits(5),
		"cross_items": GameState.cross_link_items,
	}
	feedback_requested.emit(data)


func _on_exit_run() -> void:
	gear_menu.visible = false
	GameState.apply_end_of_run(false)
	run_ended.emit(GameState.last_run_score, false)


func _show_trap_message(damage: int) -> void:
	_clear_ui()
	var text: String = LocaleManager.t("ui.trap_damage", {"damage": damage})
	waiting_for_text = true
	typewriter.display_text(text, TypewriterEffect.Speed.FAST)
	
	# Add continue button so player sees trap damage before proceeding
	var continue_btn := UITheme.create_choice_button(LocaleManager.t("ui.nav_forward"))
	continue_btn.pressed.connect(func() -> void:
		# Now build event queue and proceed with normal node processing
		node_event_queue = _build_event_queue()
		_continue_load_node()
	)
	choices_box.add_child(continue_btn)


func _on_turn_limit_reached() -> void:
	var boss_node: String = GameState.get_boss_node_id(GameState.selected_world_id)
	if not boss_node.is_empty() and boss_node != current_node.get("node_id", ""):
		# Force move to boss
		_clear_ui()
		var text: String = LocaleManager.t("ui.turn_limit_boss")
		typewriter.display_text(text, TypewriterEffect.Speed.NORMAL)
		# Add button to proceed to boss
		var btn := UITheme.create_primary_button(LocaleManager.t("ui.proceed_boss"))
		btn.pressed.connect(_load_node.bind(boss_node))
		choices_box.add_child(btn)
	else:
		_on_run_defeat()


func _show_fallback_event() -> void:
	_clear_ui()
	var text: String = "[b]%s[/b]\n\n%s" % [
		LocaleManager.t("ui.node_missing"),
		LocaleManager.t("ui.node_missing_hint")
	]
	typewriter.display_text(text, TypewriterEffect.Speed.INSTANT)
	
	var back_btn := UITheme.create_choice_button(LocaleManager.t("ui.run_exit"))
	back_btn.pressed.connect(_on_exit_run)
	choices_box.add_child(back_btn)


func _clear_ui() -> void:
	for child: Node in choices_box.get_children():
		child.queue_free()
	for child: Node in navigation_box.get_children():
		child.queue_free()


func _update_silhouette() -> void:
	var event_type: String = current_event.get("type", "explore")
	var speaker: String = current_event.get("speaker", "")
	
	# For battle events, show monster silhouette
	if event_type == "battle" and speaker.is_empty():
		speaker = "monster"
	
	# Show silhouette if speaker is set and image exists
	if speaker != "" and SILHOUETTE_KEYS.has(speaker):
		var tex: Texture2D = AssetManager.get_texture(SILHOUETTE_KEYS[speaker])
		if tex != null:
			silhouette_rect.texture = tex
			silhouette_rect.visible = true
			# Fade in
			var tween: Tween = create_tween()
			silhouette_rect.modulate.a = 0.0
			tween.tween_property(silhouette_rect, "modulate:a", 0.25, 0.5)
			return
	
	# Hide silhouette for non-dialogue events
	if silhouette_rect.visible:
		var tween: Tween = create_tween()
		tween.tween_property(silhouette_rect, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func() -> void: silhouette_rect.visible = false)


func _update_status() -> void:
	status_updated.emit()


## Set text display speed (for settings menu)
func set_text_speed(speed: TypewriterEffect.Speed) -> void:
	text_speed = speed
