extends Control

signal inheritance_selected

@onready var header: Label = $Margin/Root/Header
@onready var description_label: RichTextLabel = $Margin/Root/Description
@onready var candidates_box: VBoxContainer = $Margin/Root/ScrollContainer/Candidates
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
	
	# Style skip button
	var normal := UITheme.create_button_stylebox(Color(0.25, 0.25, 0.3, 0.8))
	var hover := UITheme.create_button_stylebox(Color(0.35, 0.35, 0.4, 0.9))
	var pressed := UITheme.create_button_stylebox(Color(0.2, 0.2, 0.25, 1.0))
	skip_button.add_theme_stylebox_override("normal", normal)
	skip_button.add_theme_stylebox_override("hover", hover)
	skip_button.add_theme_stylebox_override("pressed", pressed)


func _setup_screen() -> void:
	header.text = LocaleManager.t("ui.inheritance_header")
	skip_button.text = LocaleManager.t("ui.inheritance_skip")
	
	var is_clear: bool = GameState.run_is_clear
	var soul_gain: int = GameState.last_run_score
	
	var desc_text: String = """[center][b]%s[/b][/center]

%s: [color=gold]%d[/color]
%s: [color=gold]%d[/color]

""" % [
		LocaleManager.t("ui.inheritance_run_end", {"loop": GameState.loop_count - 1}),
		LocaleManager.t("ui.inheritance_soul_gain", {"amount": soul_gain}).split(":")[0],
		soul_gain,
		LocaleManager.t("ui.inheritance_soul_total", {"amount": GameState.soul_points}).split(":")[0],
		GameState.soul_points
	]
	
	if is_clear:
		desc_text += "[center][color=green]%s[/color][/center]\n\n" % LocaleManager.t("ui.inheritance_clear")
	
	desc_text += LocaleManager.t("ui.inheritance_prompt")
	
	# Show dominant traits
	var dominant_traits: Array = GameState.get_dominant_traits(3)
	if dominant_traits.size() > 0:
		desc_text += "\n\n[b]%s[/b] %s" % [
			LocaleManager.t("ui.inheritance_traits"),
			", ".join(dominant_traits)
		]
	
	# Show acquired memory flags (hints)
	var flags_text: String = _get_recent_flags_text()
	if not flags_text.is_empty():
		desc_text += "\n\n[b]%s[/b] %s" % [
			LocaleManager.t("ui.inheritance_memories"),
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
				localized_candidate["label"] = LocaleManager.t("ui.inheritance_soul_bonus", {"amount": value})
				localized_candidate["description"] = LocaleManager.t("ui.inheritance_soul_bonus_desc", {"amount": value})
			"hp_bonus":
				localized_candidate["label"] = LocaleManager.t("ui.inheritance_hp_bonus", {"amount": value})
				localized_candidate["description"] = LocaleManager.t("ui.inheritance_hp_bonus_desc", {"amount": value})
			"gold_start":
				localized_candidate["label"] = LocaleManager.t("ui.inheritance_gold_start", {"amount": value})
				localized_candidate["description"] = LocaleManager.t("ui.inheritance_gold_start_desc", {"amount": value})
			"tag_boost":
				localized_candidate["label"] = LocaleManager.t("ui.inheritance_tag_boost", {"tag": value})
				localized_candidate["description"] = LocaleManager.t("ui.inheritance_tag_boost_desc", {"tag": value})
			"memory_hint":
				localized_candidate["label"] = LocaleManager.t("ui.inheritance_memory_hint")
				localized_candidate["description"] = LocaleManager.t("ui.inheritance_memory_hint_desc")
		
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
	var panel := UITheme.create_card_panel()
	panel.custom_minimum_size = Vector2(0, 110)
	
	# Style the panel with ethereal colors
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.18, 0.9)
	stylebox.set_corner_radius_all(UITheme.CARD_CORNER_RADIUS)
	stylebox.set_border_width_all(1)
	stylebox.border_color = Color(0.4, 0.35, 0.5, 0.6)
	panel.add_theme_stylebox_override("panel", stylebox)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UITheme.CARD_PADDING)
	margin.add_theme_constant_override("margin_top", UITheme.CARD_PADDING)
	margin.add_theme_constant_override("margin_right", UITheme.CARD_PADDING)
	margin.add_theme_constant_override("margin_bottom", UITheme.CARD_PADDING)
	panel.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(vbox)
	
	var title := Label.new()
	title.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	title.text = "【%s】" % candidate.get("label", LocaleManager.t("ui.inheritance_header"))
	vbox.add_child(title)
	
	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", UITheme.FONT_STATUS)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	desc.text = candidate.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)
	
	var button := Button.new()
	button.text = LocaleManager.t("ui.select")
	button.custom_minimum_size = Vector2(120, UITheme.BUTTON_MIN_HEIGHT)
	button.add_theme_font_size_override("font_size", UITheme.FONT_BUTTON)
	
	# Style button
	var btn_normal := UITheme.create_button_stylebox(Color(0.3, 0.35, 0.45, 0.9))
	var btn_hover := UITheme.create_button_stylebox(Color(0.4, 0.45, 0.55, 0.95))
	var btn_pressed := UITheme.create_button_stylebox(Color(0.25, 0.3, 0.4, 1.0))
	button.add_theme_stylebox_override("normal", btn_normal)
	button.add_theme_stylebox_override("hover", btn_hover)
	button.add_theme_stylebox_override("pressed", btn_pressed)
	
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
