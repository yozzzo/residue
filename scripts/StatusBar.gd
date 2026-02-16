extends CanvasLayer
class_name StatusBar
## Persistent status bar showing HP, Gold, Location, Job

@onready var panel: PanelContainer
@onready var hp_label: Label
@onready var gold_label: Label
@onready var location_label: Label
@onready var job_label: Label
@onready var hp_bar: ProgressBar

var visible_in_game: bool = true


func _ready() -> void:
	layer = 10  # Above normal UI, below transitions
	_create_ui()
	hide_bar()  # Hidden by default
	
	LocaleManager.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_locale: String) -> void:
	update_status()


func _create_ui() -> void:
	# Container
	var container := Control.new()
	container.name = "StatusBarContainer"
	container.anchors_preset = Control.PRESET_TOP_WIDE
	container.offset_bottom = 48
	add_child(container)
	
	# Panel background
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.anchors_preset = Control.PRESET_FULL_RECT
	container.add_child(panel)
	
	# Apply theme color
	_update_panel_style()
	
	# Margin
	var margin := MarginContainer.new()
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	
	# HBox for content
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	margin.add_child(hbox)
	
	# Job icon/name
	job_label = Label.new()
	job_label.name = "JobLabel"
	job_label.add_theme_font_size_override("font_size", 14)
	job_label.text = "【---】"
	hbox.add_child(job_label)
	
	# HP section
	var hp_section := HBoxContainer.new()
	hp_section.add_theme_constant_override("separation", 8)
	hbox.add_child(hp_section)
	
	var hp_icon := Label.new()
	hp_icon.text = "❤️"
	hp_section.add_child(hp_icon)
	
	hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(100, 20)
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	hp_section.add_child(hp_bar)
	
	hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.text = "100/100"
	hp_section.add_child(hp_label)
	
	# Gold section
	var gold_section := HBoxContainer.new()
	gold_section.add_theme_constant_override("separation", 4)
	hbox.add_child(gold_section)
	
	var gold_icon := Label.new()
	gold_icon.text = "💰"
	gold_section.add_child(gold_icon)
	
	gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.add_theme_font_size_override("font_size", 14)
	gold_label.text = "0"
	gold_section.add_child(gold_label)
	
	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	# Location
	location_label = Label.new()
	location_label.name = "LocationLabel"
	location_label.add_theme_font_size_override("font_size", 14)
	location_label.text = "📍 ---"
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(location_label)


func _update_panel_style() -> void:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = ThemeManager.get_status_bar_color() if ThemeManager != null else Color(0.05, 0.05, 0.08, 0.95)
	stylebox.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", stylebox)


func update_status() -> void:
	if not visible_in_game:
		return
	
	# HP
	hp_label.text = "%d/%d" % [GameState.run_hp, GameState.run_max_hp]
	hp_bar.max_value = GameState.run_max_hp
	hp_bar.value = GameState.run_hp
	
	# HP bar color based on health percentage
	var hp_percent: float = float(GameState.run_hp) / float(GameState.run_max_hp)
	var hp_color: Color
	if hp_percent > 0.5:
		hp_color = Color(0.3, 0.7, 0.4)
	elif hp_percent > 0.25:
		hp_color = Color(0.8, 0.7, 0.3)
	else:
		hp_color = Color(0.8, 0.3, 0.3)
	
	var hp_stylebox := StyleBoxFlat.new()
	hp_stylebox.bg_color = hp_color
	hp_bar.add_theme_stylebox_override("fill", hp_stylebox)
	
	# Gold
	gold_label.text = str(GameState.run_gold)
	
	# Job
	var job: Dictionary = GameState.get_job_by_id(GameState.current_job)
	var job_name: String = LocaleManager.tr_data(job, "name")
	if job_name.is_empty():
		job_name = job.get("name", "---")
	var foreign_mark: String = " ✧" if GameState.run_is_foreign_job else ""
	job_label.text = "【%s%s】" % [job_name, foreign_mark]
	
	# Location
	var node: Dictionary = GameState.get_node_by_id(GameState.selected_world_id, GameState.run_current_node_id)
	var node_name: String = LocaleManager.tr_data(node, "name")
	if node_name.is_empty():
		node_name = node.get("name", "---")
	location_label.text = LocaleManager.t("ui.location", {"name": node_name})


func update_location(node_name: String) -> void:
	location_label.text = LocaleManager.t("ui.location", {"name": node_name})


func show_bar() -> void:
	visible_in_game = true
	show()
	_update_panel_style()


func hide_bar() -> void:
	visible_in_game = false
	hide()


func on_theme_changed() -> void:
	_update_panel_style()
