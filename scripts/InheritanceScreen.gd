extends Control

signal inheritance_selected

@onready var header: Label = $Margin/Root/Header
@onready var description_label: RichTextLabel = $Margin/Root/Description
@onready var candidates_box: VBoxContainer = $Margin/Root/Candidates
@onready var skip_button: Button = $Margin/Root/Footer/SkipButton
@onready var background: ColorRect = $Background

var candidates: Array = []


func _ready() -> void:
	skip_button.pressed.connect(_on_skip_pressed)
	_apply_theme()
	_setup_screen()
	
	LocaleManager.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_locale: String) -> void:
	_setup_screen()


func _apply_theme() -> void:
	# Use default theme for inheritance (neutral/ethereal)
	ThemeManager.set_world("default")
	background.color = Color(0.06, 0.06, 0.1)  # Slightly different for ethereal feel


func _setup_screen() -> void:
	header.text = LocaleManager.tr("ui.inheritance_header")
	skip_button.text = LocaleManager.tr("ui.inheritance_skip")
	
	var is_clear: bool = GameState.run_is_clear
	var soul_gain: int = GameState.last_run_score
	
	var desc_text: String = """[center][b]%s[/b][/center]

%s: [color=gold]%d[/color]
%s: [color=gold]%d[/color]

""" % [
		LocaleManager.tr("ui.inheritance_run_end", {"loop": GameState.loop_count - 1}),
		LocaleManager.tr("ui.inheritance_soul_gain", {"amount": soul_gain}).split(":")[0],
		soul_gain,
		LocaleManager.tr("ui.inheritance_soul_total", {"amount": GameState.soul_points}).split(":")[0],
		GameState.soul_points
	]
	
	if is_clear:
		desc_text += "[center][color=green]%s[/color][/center]\n\n" % LocaleManager.tr("ui.inheritance_clear")
	
	desc_text += LocaleManager.tr("ui.inheritance_prompt")
	
	# Show dominant traits
	var dominant_traits: Array = GameState.get_dominant_traits(3)
	if dominant_traits.size() > 0:
		desc_text += "\n\n[b]%s[/b] %s" % [
			LocaleManager.tr("ui.inheritance_traits"),
			", ".join(dominant_traits)
		]
	
	# Show acquired memory flags (hints)
	var flags_text: String = _get_recent_flags_text()
	if not flags_text.is_empty():
		desc_text += "\n\n[b]%s[/b] %s" % [
			LocaleManager.tr("ui.inheritance_memories"),
			flags_text
		]
	
	description_label.text = desc_text
	
	# Generate inheritance candidates
	candidates = _generate_localized_candidates()
	_render_candidates()


func _get_recent_flags_text() -> String:
	var flag_keys: Array = [
		"mayor_basement_seen", "well_peeked", "seal_broken", "tome_read",
		"bishop_encountered", "bishop_defeated", "terminal_hacked", "diary_read",
		"core_log_read", "tank_examined", "shelter_message_read", "system_dialogue",
		"prophet_encountered", "prophet_defeated", "residue_truth_revealed"
	]
	
	var acquired: Array = []
	for flag: String in flag_keys:
		if GameState.has_memory_flag(flag):
			acquired.append(LocaleManager.get_memory_flag_label(flag))
	
	if acquired.size() > 5:
		var remaining: int = acquired.size() - 5
		var others_text: String = " +%d" % remaining
		return ", ".join(acquired.slice(0, 5)) + others_text
	
	return ", ".join(acquired)


func _generate_localized_candidates() -> Array:
	var raw_candidates: Array = GameState.generate_inheritance_candidates()
	var localized: Array = []
	
	for candidate: Dictionary in raw_candidates:
		var localized_candidate := candidate.duplicate()
		var candidate_type: String = candidate.get("type", "")
		var value: Variant = candidate.get("value", 0)
		
		match candidate_type:
			"soul_bonus":
				localized_candidate["label"] = LocaleManager.tr("ui.inheritance_soul_bonus", {"amount": value})
				localized_candidate["description"] = LocaleManager.tr("ui.inheritance_soul_bonus_desc", {"amount": value})
			"hp_bonus":
				localized_candidate["label"] = LocaleManager.tr("ui.inheritance_hp_bonus", {"amount": value})
				localized_candidate["description"] = LocaleManager.tr("ui.inheritance_hp_bonus_desc", {"amount": value})
			"gold_start":
				localized_candidate["label"] = LocaleManager.tr("ui.inheritance_gold_start", {"amount": value})
				localized_candidate["description"] = LocaleManager.tr("ui.inheritance_gold_start_desc", {"amount": value})
			"tag_boost":
				localized_candidate["label"] = LocaleManager.tr("ui.inheritance_tag_boost", {"tag": value})
				localized_candidate["description"] = LocaleManager.tr("ui.inheritance_tag_boost_desc", {"tag": value})
			"memory_hint":
				localized_candidate["label"] = LocaleManager.tr("ui.inheritance_memory_hint")
				localized_candidate["description"] = LocaleManager.tr("ui.inheritance_memory_hint_desc")
		
		localized.append(localized_candidate)
	
	return localized


func _render_candidates() -> void:
	for child: Node in candidates_box.get_children():
		child.queue_free()
	
	for i: int in range(candidates.size()):
		var candidate: Dictionary = candidates[i]
		var card := _create_candidate_card(candidate, i)
		candidates_box.add_child(card)


func _create_candidate_card(candidate: Dictionary, index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 90)
	
	# Style the panel
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	stylebox.set_corner_radius_all(6)
	stylebox.set_border_width_all(1)
	stylebox.border_color = Color(0.3, 0.3, 0.4)
	panel.add_theme_stylebox_override("panel", stylebox)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)
	
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 18)
	title.text = "【%s】" % candidate.get("label", LocaleManager.tr("ui.inheritance_header"))
	vbox.add_child(title)
	
	var desc := Label.new()
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc.text = candidate.get("description", "")
	vbox.add_child(desc)
	
	var button := Button.new()
	button.text = LocaleManager.tr("ui.select")
	button.custom_minimum_size = Vector2(100, 40)
	button.pressed.connect(_on_candidate_selected.bind(candidate))
	hbox.add_child(button)
	
	return panel


func _on_candidate_selected(candidate: Dictionary) -> void:
	var bonus_type: String = candidate.get("type", "")
	var value: Variant = candidate.get("value", 0)
	
	match bonus_type:
		"soul_bonus":
			# Apply soul bonus immediately to current total
			GameState.soul_points += int(value)
		"hp_bonus", "gold_start", "tag_boost", "memory_hint":
			# Set pending inheritance for next run
			GameState.set_pending_inheritance(bonus_type, value)
	
	# Special: memory_hint sets a flag
	if bonus_type == "memory_hint":
		GameState.set_memory_flag(str(value))
	
	GameState.save_persistent_state()
	inheritance_selected.emit()


func _on_skip_pressed() -> void:
	inheritance_selected.emit()
