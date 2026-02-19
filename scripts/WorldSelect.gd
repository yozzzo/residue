extends Control

signal back_requested
signal world_selected(world_id: String)
signal scenario_selected(scenario_id: String, entry_node_id: String, world_id: String)

@onready var header_label: Label = $Margin/RootVBox/Header
@onready var world_buttons: VBoxContainer = $Margin/RootVBox/ScrollContainer/WorldButtons
@onready var back_button: Button = $Margin/RootVBox/Footer/BackButton
@onready var meta_label: Label = $Margin/RootVBox/Footer/MetaLabel
@onready var traits_label: Label = $Margin/RootVBox/TraitsPanel/TraitsLabel
@onready var background: ColorRect = $Background


func _ready() -> void:
	back_button.pressed.connect(func() -> void: back_requested.emit())
	_populate_world_buttons()
	_update_meta_text()
	_update_traits_display()
	_apply_theme()
	_update_texts()
	
	LocaleManager.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_locale: String) -> void:
	_update_texts()
	_populate_world_buttons()
	_update_meta_text()
	_update_traits_display()


func _update_texts() -> void:
	if header_label != null:
		header_label.text = LocaleManager.t("ui.world_select")
	back_button.text = LocaleManager.t("ui.back")


func _apply_theme() -> void:
	# Use default theme for world select (neutral)
	ThemeManager.set_world("default")
	background.color = ThemeManager.get_background_color()
	
	# Style back button
	var normal := UITheme.create_button_stylebox(Color(0.2, 0.2, 0.3, 0.8))
	var hover := UITheme.create_button_stylebox(Color(0.3, 0.3, 0.4, 0.9))
	var pressed := UITheme.create_button_stylebox(Color(0.15, 0.15, 0.25, 1.0))
	back_button.add_theme_stylebox_override("normal", normal)
	back_button.add_theme_stylebox_override("hover", hover)
	back_button.add_theme_stylebox_override("pressed", pressed)


# Build 19: Scenario data cache
var _scenarios_cache: Array = []

func _populate_world_buttons() -> void:
	for child: Node in world_buttons.get_children():
		child.queue_free()

	for world: Variant in GameState.get_worlds():
		var world_id: String = world.get("world_id", "unknown")
		var world_name: String = LocaleManager.tr_data(world, "name")
		var blurb: String = LocaleManager.tr_data(world, "blurb")
		
		# Phase 2: Show truth stage for each world
		var truth_stage: int = GameState.get_truth_stage(world_id)
		var truth_text: String = ""
		if truth_stage > 0:
			truth_text = " [%s]" % LocaleManager.t("ui.truth_stage", {"stage": truth_stage})
		
		# Add visual indicator based on world type
		var world_icon: String = "🏰" if world_id == "medieval" else "🔮" if world_id == "future" else "⚡"
		
		# Create card-style button
		var card := _create_world_card(world_id, world_icon, world_name, blurb, truth_text)
		world_buttons.add_child(card)
	
	# Build 19: Scenario section
	_populate_scenario_buttons()


func _create_world_card(world_id: String, icon: String, name: String, blurb: String, truth_text: String) -> Control:
	var card := UITheme.create_world_card()
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	
	# World name with icon
	var name_label := Label.new()
	name_label.text = "%s %s%s" % [icon, name, truth_text]
	name_label.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	vbox.add_child(name_label)
	
	# Blurb
	var blurb_label := Label.new()
	blurb_label.text = blurb
	blurb_label.add_theme_font_size_override("font_size", UITheme.FONT_STATUS)
	blurb_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(blurb_label)
	
	# Make entire card clickable with Button overlay
	var button := Button.new()
	button.anchors_preset = Control.PRESET_FULL_RECT
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_world_button_pressed.bind(world_id))
	
	# Hover effect
	button.mouse_entered.connect(func(): _on_card_hover(card, true))
	button.mouse_exited.connect(func(): _on_card_hover(card, false))
	
	card.add_child(button)
	
	return card


func _on_card_hover(card: PanelContainer, hovered: bool) -> void:
	var stylebox := StyleBoxFlat.new()
	if hovered:
		stylebox.bg_color = Color(0.18, 0.18, 0.25, 0.95)
		stylebox.set_border_width_all(2)
		stylebox.border_color = Color(0.5, 0.5, 0.6, 0.8)
	else:
		stylebox.bg_color = Color(0.12, 0.12, 0.18, 0.9)
		stylebox.set_border_width_all(1)
		stylebox.border_color = Color(0.35, 0.35, 0.45, 0.6)
	stylebox.set_corner_radius_all(UITheme.CARD_CORNER_RADIUS)
	stylebox.content_margin_left = UITheme.CARD_PADDING
	stylebox.content_margin_right = UITheme.CARD_PADDING
	stylebox.content_margin_top = UITheme.CARD_PADDING
	stylebox.content_margin_bottom = UITheme.CARD_PADDING
	card.add_theme_stylebox_override("panel", stylebox)


func _update_meta_text() -> void:
	meta_label.text = LocaleManager.t("ui.loop_soul", {
		"loop": GameState.loop_count,
		"soul": GameState.soul_points
	})


func _update_traits_display() -> void:
	if traits_label == null:
		return
	
	var dominant_traits: Array = GameState.get_dominant_traits(5)
	if dominant_traits.size() == 0:
		traits_label.text = LocaleManager.t("ui.traits_none")
		return
	
	var traits_with_values: Array = []
	for trait_tag: String in dominant_traits:
		var value: int = GameState.get_trait_tag_value(trait_tag)
		traits_with_values.append("%s(%d)" % [trait_tag, value])
	
	traits_label.text = LocaleManager.t("ui.traits_label", {
		"traits": ", ".join(traits_with_values)
	})


func _populate_scenario_buttons() -> void:
	# Fetch scenarios from API if available, else use cached
	if GameState._api_client != null:
		GameState._api_client.fetch_scenarios(func(scenarios: Array) -> void:
			_scenarios_cache = scenarios
			_render_scenario_buttons()
		)
	else:
		_render_scenario_buttons()


func _render_scenario_buttons() -> void:
	if _scenarios_cache.is_empty():
		return
	
	# Section header
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 16)
	world_buttons.add_child(separator)
	
	var section_label := Label.new()
	section_label.text = "改変シナリオ"
	section_label.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
	section_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.8))
	section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_buttons.add_child(section_label)
	
	for scenario: Variant in _scenarios_cache:
		if scenario is not Dictionary:
			continue
		var sid: String = scenario.get("scenario_id", "")
		var conditions: Dictionary = {}
		var cond_str: String = scenario.get("unlock_conditions_json", "{}")
		var parsed: Variant = JSON.parse_string(cond_str)
		if parsed is Dictionary:
			conditions = parsed
		
		var unlocked: bool = GameState.check_event_conditions(conditions)
		var name_text: String = scenario.get("name_ja", "???") if unlocked else "???"
		var desc_text: String = scenario.get("description_ja", "") if unlocked else "条件未達成"
		var world_id: String = scenario.get("world_id", "")
		var entry_node: String = scenario.get("entry_node_id", "")
		
		var card := UITheme.create_world_card()
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)
		
		var title := Label.new()
		title.text = "📜 %s" % name_text
		title.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
		title.add_theme_color_override("font_color", Color(0.8, 0.7, 0.9) if unlocked else Color(0.4, 0.4, 0.45))
		vbox.add_child(title)
		
		var desc := Label.new()
		desc.text = desc_text
		desc.add_theme_font_size_override("font_size", UITheme.FONT_STATUS)
		desc.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7) if unlocked else Color(0.35, 0.35, 0.4))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)
		
		if unlocked:
			var button := Button.new()
			button.anchors_preset = Control.PRESET_FULL_RECT
			button.flat = true
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.pressed.connect(_on_scenario_pressed.bind(sid, entry_node, world_id))
			card.add_child(button)
		
		world_buttons.add_child(card)


func _on_scenario_pressed(scenario_id: String, entry_node_id: String, world_id: String) -> void:
	GameState.mark_scenario_played(scenario_id)
	scenario_selected.emit(scenario_id, entry_node_id, world_id)


func _on_world_button_pressed(world_id: String) -> void:
	world_selected.emit(world_id)
