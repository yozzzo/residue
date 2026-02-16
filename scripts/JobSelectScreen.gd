extends Control

signal back_requested
signal job_selected(job_id: String)

@onready var header: Label = $Margin/RootVBox/Header
@onready var world_info: Label = $Margin/RootVBox/InfoHBox/WorldInfo
@onready var soul_label: Label = $Margin/RootVBox/InfoHBox/SoulLabel
@onready var job_list: VBoxContainer = $Margin/RootVBox/ScrollContainer/JobList
@onready var back_button: Button = $Margin/RootVBox/Footer/BackButton
@onready var confirm_button: Button = $Margin/RootVBox/Footer/ConfirmButton

var selected_job_id: String = ""
var job_buttons: Dictionary = {}  # job_id -> Button


func _ready() -> void:
	back_button.pressed.connect(func() -> void: back_requested.emit())
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.disabled = true
	_setup_screen()
	
	LocaleManager.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_locale: String) -> void:
	_setup_screen()


func _setup_screen() -> void:
	var world: Dictionary = GameState.get_world_by_id(GameState.selected_world_id)
	var world_name: String = LocaleManager.tr_data(world, "name")
	
	header.text = LocaleManager.t("ui.job_select")
	world_info.text = LocaleManager.t("ui.world_label", {"name": world_name})
	back_button.text = LocaleManager.t("ui.back")
	confirm_button.text = LocaleManager.t("ui.confirm")
	
	# Style footer buttons
	_style_footer_buttons()
	
	_update_soul_label()
	_populate_job_list()


func _style_footer_buttons() -> void:
	# Back button
	var back_normal := UITheme.create_button_stylebox(Color(0.2, 0.2, 0.3, 0.8))
	var back_hover := UITheme.create_button_stylebox(Color(0.3, 0.3, 0.4, 0.9))
	var back_pressed := UITheme.create_button_stylebox(Color(0.15, 0.15, 0.25, 1.0))
	back_button.add_theme_stylebox_override("normal", back_normal)
	back_button.add_theme_stylebox_override("hover", back_hover)
	back_button.add_theme_stylebox_override("pressed", back_pressed)
	
	# Confirm button (primary)
	var confirm_normal := UITheme.create_button_stylebox(Color(0.3, 0.4, 0.35, 0.9))
	var confirm_hover := UITheme.create_button_stylebox(Color(0.4, 0.5, 0.45, 0.95))
	var confirm_pressed := UITheme.create_button_stylebox(Color(0.25, 0.35, 0.3, 1.0))
	var confirm_disabled := UITheme.create_button_stylebox(Color(0.15, 0.15, 0.15, 0.5))
	confirm_button.add_theme_stylebox_override("normal", confirm_normal)
	confirm_button.add_theme_stylebox_override("hover", confirm_hover)
	confirm_button.add_theme_stylebox_override("pressed", confirm_pressed)
	confirm_button.add_theme_stylebox_override("disabled", confirm_disabled)


func _update_soul_label() -> void:
	soul_label.text = LocaleManager.t("ui.soul_label", {"amount": GameState.soul_points})


func _populate_job_list() -> void:
	for child: Node in job_list.get_children():
		child.queue_free()
	job_buttons.clear()
	
	var all_jobs: Array = GameState.get_all_jobs()
	
	for job: Variant in all_jobs:
		if job is not Dictionary:
			continue
		var job_id: String = job.get("job_id", "")
		var card := _create_job_card(job)
		job_list.add_child(card)


func _create_job_card(job: Dictionary) -> Control:
	var job_id: String = job.get("job_id", "")
	var job_name: String = LocaleManager.tr_data(job, "name")
	var description: String = LocaleManager.tr_data(job, "description")
	var origin: Variant = job.get("origin_world")
	var is_unlocked: bool = GameState.is_job_unlocked(job_id)
	var can_unlock: bool = GameState.can_unlock_job(job_id)
	
	# Use UITheme card panel
	var panel := UITheme.create_card_panel()
	panel.custom_minimum_size = Vector2(0, 120)
	
	# Style based on selection state
	var is_selected: bool = job_id == selected_job_id or (selected_job_id.is_empty() and job_id == GameState.current_job)
	_apply_job_card_style(panel, is_selected, is_unlocked)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UITheme.CARD_PADDING)
	margin.add_theme_constant_override("margin_top", UITheme.CARD_PADDING)
	margin.add_theme_constant_override("margin_right", UITheme.CARD_PADDING)
	margin.add_theme_constant_override("margin_bottom", UITheme.CARD_PADDING)
	panel.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)
	
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(info_vbox)
	
	# Job name with origin indicator
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
	var origin_text: String = ""
	if origin != null and origin is String:
		var is_foreign: bool = GameState.is_foreign_job(job_id, GameState.selected_world_id)
		if is_foreign:
			var origin_world: Dictionary = GameState.get_world_by_id(origin)
			var origin_name: String = LocaleManager.tr_data(origin_world, "name")
			origin_text = " [%s: %s]" % [LocaleManager.t("ui.other_world_mark"), origin_name]
		else:
			var origin_world: Dictionary = GameState.get_world_by_id(origin)
			var origin_name: String = LocaleManager.tr_data(origin_world, "name")
			origin_text = " [%s]" % origin_name
	name_label.text = "【%s】%s" % [job_name, origin_text]
	if not is_unlocked:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	info_vbox.add_child(name_label)
	
	# Description
	var desc_label := Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", UITheme.FONT_STATUS)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_label)
	
	# Stat modifiers
	var stat_modifiers: Dictionary = job.get("stat_modifiers", {})
	var stats_text: String = _format_stat_modifiers(stat_modifiers)
	if not stats_text.is_empty():
		var stats_label := Label.new()
		stats_label.text = stats_text
		stats_label.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
		stats_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		info_vbox.add_child(stats_label)
	
	# Special ability
	var special_ability: Dictionary = job.get("special_ability", {})
	if not special_ability.is_empty():
		var ability_name: String = LocaleManager.tr_data(special_ability, "name")
		var ability_label := Label.new()
		ability_label.text = LocaleManager.t("ui.special_ability", {"name": ability_name})
		ability_label.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
		ability_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		info_vbox.add_child(ability_label)
	
	# Buttons
	var button_vbox := VBoxContainer.new()
	button_vbox.add_theme_constant_override("separation", 8)
	button_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(button_vbox)
	
	if is_unlocked:
		var select_btn := Button.new()
		select_btn.text = LocaleManager.t("ui.select")
		select_btn.custom_minimum_size = Vector2(120, UITheme.BUTTON_MIN_HEIGHT)
		select_btn.add_theme_font_size_override("font_size", UITheme.FONT_BUTTON)
		_style_job_button(select_btn, is_selected)
		select_btn.pressed.connect(_on_job_select_pressed.bind(job_id, select_btn, panel))
		button_vbox.add_child(select_btn)
		job_buttons[job_id] = select_btn
		
		# Highlight if currently selected
		if is_selected:
			select_btn.text = LocaleManager.t("ui.selected")
			selected_job_id = job_id
			confirm_button.disabled = false
	else:
		var unlock_conditions: Dictionary = job.get("unlock_conditions", {})
		var cost: int = int(unlock_conditions.get("soul_points", 0))
		
		var cost_label := Label.new()
		cost_label.text = LocaleManager.t("ui.unlock_cost", {"cost": cost})
		cost_label.add_theme_font_size_override("font_size", UITheme.FONT_STATUS)
		cost_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
		button_vbox.add_child(cost_label)
		
		var unlock_btn := Button.new()
		unlock_btn.text = LocaleManager.t("ui.unlock")
		unlock_btn.custom_minimum_size = Vector2(120, UITheme.BUTTON_MIN_HEIGHT)
		unlock_btn.add_theme_font_size_override("font_size", UITheme.FONT_BUTTON)
		unlock_btn.disabled = not can_unlock
		_style_job_button(unlock_btn, false)
		unlock_btn.pressed.connect(_on_job_unlock_pressed.bind(job_id))
		button_vbox.add_child(unlock_btn)
	
	return panel


func _apply_job_card_style(panel: PanelContainer, is_selected: bool, is_unlocked: bool) -> void:
	var stylebox := StyleBoxFlat.new()
	if is_selected:
		stylebox.bg_color = Color(0.15, 0.18, 0.25, 0.95)
		stylebox.set_border_width_all(2)
		stylebox.border_color = Color(0.6, 0.7, 0.9, 0.9)
	elif is_unlocked:
		stylebox.bg_color = Color(0.1, 0.1, 0.15, 0.9)
		stylebox.set_border_width_all(1)
		stylebox.border_color = Color(0.3, 0.3, 0.4, 0.6)
	else:
		stylebox.bg_color = Color(0.08, 0.08, 0.1, 0.7)
		stylebox.set_border_width_all(1)
		stylebox.border_color = Color(0.2, 0.2, 0.25, 0.4)
	stylebox.set_corner_radius_all(UITheme.CARD_CORNER_RADIUS)
	panel.add_theme_stylebox_override("panel", stylebox)


func _style_job_button(button: Button, is_selected: bool) -> void:
	var normal: StyleBoxFlat
	var hover: StyleBoxFlat
	var pressed: StyleBoxFlat
	
	if is_selected:
		normal = UITheme.create_button_stylebox(Color(0.3, 0.5, 0.4, 0.9))
		hover = UITheme.create_button_stylebox(Color(0.35, 0.55, 0.45, 0.95))
		pressed = UITheme.create_button_stylebox(Color(0.25, 0.45, 0.35, 1.0))
	else:
		normal = UITheme.create_button_stylebox(Color(0.25, 0.25, 0.35, 0.9))
		hover = UITheme.create_button_stylebox(Color(0.35, 0.35, 0.45, 0.95))
		pressed = UITheme.create_button_stylebox(Color(0.2, 0.2, 0.3, 1.0))
	
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)


func _format_stat_modifiers(modifiers: Dictionary) -> String:
	var parts: Array = []
	if modifiers.has("hp_bonus") and int(modifiers["hp_bonus"]) != 0:
		var hp: int = int(modifiers["hp_bonus"])
		var label: String = LocaleManager.get_stat_label("hp_bonus")
		parts.append("%s%s%d" % [label, "+" if hp > 0 else "", hp])
	if modifiers.has("attack_bonus") and int(modifiers["attack_bonus"]) != 0:
		var atk: int = int(modifiers["attack_bonus"])
		var label: String = LocaleManager.get_stat_label("attack_bonus")
		parts.append("%s%s%d" % [label, "+" if atk > 0 else "", atk])
	if modifiers.has("defense_bonus") and int(modifiers["defense_bonus"]) != 0:
		var def: int = int(modifiers["defense_bonus"])
		var label: String = LocaleManager.get_stat_label("defense_bonus")
		parts.append("%s%s%d" % [label, "+" if def > 0 else "", def])
	return ", ".join(parts)


func _on_job_select_pressed(job_id: String, button: Button, panel: PanelContainer = null) -> void:
	# Deselect previous - refresh list to update all cards
	selected_job_id = job_id
	confirm_button.disabled = false
	_populate_job_list()


func _on_job_unlock_pressed(job_id: String) -> void:
	if GameState.unlock_job(job_id):
		# Show unlock notification
		_show_unlock_notification(job_id)
		# Refresh the list
		_update_soul_label()
		_populate_job_list()


func _show_unlock_notification(job_id: String) -> void:
	var job: Dictionary = GameState.get_job_by_id(job_id)
	var job_name: String = LocaleManager.tr_data(job, "name")
	
	# Simple notification overlay
	var notification := Label.new()
	notification.text = LocaleManager.t("ui.unlocked_notification", {"name": job_name})
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification.add_theme_font_size_override("font_size", 28)
	notification.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	notification.anchors_preset = Control.PRESET_CENTER
	add_child(notification)
	
	# Fade out after delay
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(notification, "modulate:a", 0.0, 0.5)
	tween.tween_callback(notification.queue_free)


func _on_confirm_pressed() -> void:
	if selected_job_id.is_empty():
		return
	GameState.select_job(selected_job_id)
	job_selected.emit(selected_job_id)
