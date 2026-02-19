extends Control

const TITLE_SCENE := preload("res://scenes/TitleScreen.tscn")
const WORLD_SELECT_SCENE := preload("res://scenes/WorldSelect.tscn")
const JOB_SELECT_SCENE := preload("res://scenes/JobSelectScreen.tscn")
const VILLAGE_SCENE := preload("res://scenes/VillageScreen.tscn")
const RUN_SCENE := preload("res://scenes/RunScreen.tscn")
const BATTLE_SCENE := preload("res://scenes/BattleScreen.tscn")
const INHERITANCE_SCENE := preload("res://scenes/InheritanceScreen.tscn")
const TRANSITION_SCENE := preload("res://scenes/TransitionLayer.tscn")
const STATUS_BAR_SCENE := preload("res://scenes/StatusBar.tscn")

var current_screen: Control
var run_screen_instance: Control = null
var transition_layer: TransitionLayer
var status_bar: StatusBar

# Transition settings
var use_transitions: bool = true
var transition_duration: float = 0.25


var _update_label: Label = null
var _update_progress_bar: ProgressBar = null
var _asset_update_timeout_timer: Timer = null
var _asset_update_done: bool = false


func _ready() -> void:
	# Set background color immediately to avoid black screen
	RenderingServer.set_default_clear_color(Color(0.08, 0.08, 0.12, 1.0))
	_apply_japanese_font_to_theme()
	_setup_transition_layer()
	_setup_status_bar()
	_check_asset_updates()


func _apply_japanese_font_to_theme() -> void:
	# Ensure NotoSansJP is used for all controls including RichTextLabel italic/bold
	var font_path := "res://assets/fonts/NotoSansJP-VariableFont.ttf"
	if not ResourceLoader.exists(font_path):
		return
	var font: Font = load(font_path)
	if font == null:
		return
	var theme: Theme = ThemeDB.get_project_theme()
	if theme == null:
		theme = Theme.new()
	theme.set_default_font(font)
	# RichTextLabel font variants
	theme.set_font("normal_font", "RichTextLabel", font)
	theme.set_font("bold_font", "RichTextLabel", font)
	theme.set_font("italics_font", "RichTextLabel", font)
	theme.set_font("bold_italics_font", "RichTextLabel", font)
	theme.set_font("mono_font", "RichTextLabel", font)
	# Label and Button
	theme.set_font("font", "Label", font)
	theme.set_font("font", "Button", font)


func _check_asset_updates() -> void:
	# Show update screen
	var update_panel := ColorRect.new()
	update_panel.name = "UpdatePanel"
	update_panel.color = Color(0.08, 0.08, 0.12, 1.0)
	update_panel.anchors_preset = Control.PRESET_FULL_RECT
	add_child(update_panel)
	move_child(update_panel, 0)
	
	var vbox := VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_CENTER
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.custom_minimum_size = Vector2(300, 100)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	update_panel.add_child(vbox)
	
	_update_label = Label.new()
	_update_label.text = "データ確認中..."
	_update_label.add_theme_font_size_override("font_size", 18)
	_update_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_update_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_update_label)
	
	_update_progress_bar = ProgressBar.new()
	_update_progress_bar.custom_minimum_size = Vector2(280, 8)
	_update_progress_bar.show_percentage = false
	_update_progress_bar.value = 0
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.5, 0.4, 0.6)
	fill_style.set_corner_radius_all(4)
	_update_progress_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	bg_style.set_corner_radius_all(4)
	_update_progress_bar.add_theme_stylebox_override("background", bg_style)
	_update_progress_bar.visible = false
	vbox.add_child(_update_progress_bar)
	
	AssetManager.update_progress.connect(_on_asset_update_progress)
	
	# Timeout: if asset update takes >5s, proceed with local assets
	_asset_update_timeout_timer = Timer.new()
	_asset_update_timeout_timer.wait_time = 5.0
	_asset_update_timeout_timer.one_shot = true
	_asset_update_timeout_timer.timeout.connect(func() -> void:
		if not _asset_update_done:
			push_warning("Main: Asset update timed out, proceeding with local assets")
			_on_asset_update_finished(update_panel)
	)
	add_child(_asset_update_timeout_timer)
	_asset_update_timeout_timer.start()
	
	AssetManager.check_and_update_assets(func() -> void:
		_on_asset_update_finished(update_panel)
	)


func _on_asset_update_finished(update_panel: ColorRect) -> void:
	if _asset_update_done:
		return
	_asset_update_done = true
	if _asset_update_timeout_timer != null:
		_asset_update_timeout_timer.stop()
		_asset_update_timeout_timer.queue_free()
		_asset_update_timeout_timer = null
	if is_instance_valid(update_panel):
		update_panel.queue_free()
	_update_label = null
	_update_progress_bar = null
	_show_title()


func _on_asset_update_progress(current: int, total: int) -> void:
	if _update_label != null:
		_update_label.text = "データ更新中... (%d/%d)" % [current + 1, total]
	if _update_progress_bar != null:
		_update_progress_bar.visible = true
		_update_progress_bar.max_value = total
		_update_progress_bar.value = current


func _setup_transition_layer() -> void:
	transition_layer = TRANSITION_SCENE.instantiate()
	add_child(transition_layer)


func _setup_status_bar() -> void:
	status_bar = STATUS_BAR_SCENE.instantiate()
	add_child(status_bar)
	status_bar.hide_bar()


func _show_title() -> void:
	status_bar.hide_bar()
	await _swap_screen(TITLE_SCENE.instantiate())
	current_screen.start_requested.connect(_on_start_requested)
	current_screen.quit_requested.connect(_on_quit_requested)


func _show_world_select() -> void:
	status_bar.hide_bar()
	await _swap_screen(WORLD_SELECT_SCENE.instantiate())
	current_screen.back_requested.connect(_on_back_to_title)
	current_screen.world_selected.connect(_on_world_selected)
	current_screen.scenario_selected.connect(_on_scenario_selected)


func _show_job_select() -> void:
	status_bar.hide_bar()
	await _swap_screen(JOB_SELECT_SCENE.instantiate())
	current_screen.back_requested.connect(_on_back_to_world_select)
	current_screen.job_selected.connect(_on_job_selected)


func _show_run() -> void:
	# Apply theme for selected world
	ThemeManager.set_world(GameState.selected_world_id)
	
	run_screen_instance = RUN_SCENE.instantiate()
	await _swap_screen(run_screen_instance)
	run_screen_instance.run_ended.connect(_on_run_ended)
	run_screen_instance.battle_requested.connect(_on_battle_requested)
	run_screen_instance.status_updated.connect(_on_status_updated)
	run_screen_instance.feedback_requested.connect(_on_feedback_requested)
	
	# Show status bar during runs
	status_bar.show_bar()
	status_bar.update_status()


# Build 16: Show run after village (run already started)
func _show_run_after_village() -> void:
	run_screen_instance = RUN_SCENE.instantiate()
	run_screen_instance.skip_start_new_run = true  # Don't call start_new_run again
	await _swap_screen(run_screen_instance)
	run_screen_instance.run_ended.connect(_on_run_ended)
	run_screen_instance.battle_requested.connect(_on_battle_requested)
	run_screen_instance.status_updated.connect(_on_status_updated)
	run_screen_instance.feedback_requested.connect(_on_feedback_requested)
	
	status_bar.show_bar()
	status_bar.update_status()


func _show_battle(enemy_id: String) -> void:
	var battle_screen := BATTLE_SCENE.instantiate()
	battle_screen.set_enemy(enemy_id)
	
	# Keep run_screen reference, just hide it
	if run_screen_instance != null:
		run_screen_instance.hide()
	
	add_child(battle_screen)
	current_screen = battle_screen
	battle_screen.battle_ended.connect(_on_battle_ended)


func _show_inheritance() -> void:
	status_bar.hide_bar()
	ThemeManager.set_world("default")
	
	var inheritance_screen := INHERITANCE_SCENE.instantiate()
	await _swap_screen(inheritance_screen)
	inheritance_screen.inheritance_selected.connect(_on_inheritance_selected)


func _swap_screen(next_screen: Control) -> void:
	if use_transitions and transition_layer != null:
		await _swap_with_transition(next_screen)
	else:
		_swap_immediate(next_screen)


func _swap_with_transition(next_screen: Control) -> void:
	# Fade out
	await transition_layer.fade_out(transition_duration)
	
	# Swap content
	_swap_immediate(next_screen)
	
	# Fade in
	await transition_layer.fade_in(transition_duration)


func _swap_immediate(next_screen: Control) -> void:
	if current_screen != null:
		current_screen.queue_free()
	current_screen = next_screen
	run_screen_instance = null
	add_child(current_screen)
	# Move screen below transition and status bar layers
	move_child(current_screen, 0)


func _on_start_requested() -> void:
	_show_world_select()


func _on_quit_requested() -> void:
	get_tree().quit()


func _on_back_to_title() -> void:
	_show_title()


func _on_back_to_world_select() -> void:
	_show_world_select()


func _on_world_selected(world_id: String) -> void:
	GameState.select_world(world_id)
	# Phase 3: Go to job select instead of directly to run
	_show_job_select()


# Build 19: Scenario direct entry
func _on_scenario_selected(scenario_id: String, entry_node_id: String, world_id: String) -> void:
	GameState.select_world(world_id)
	ThemeManager.set_world(world_id)
	GameState.start_new_run(world_id)
	GameState.run_current_node_id = entry_node_id
	_show_run_after_village()


func _on_job_selected(job_id: String) -> void:
	# Job is already selected in GameState by JobSelectScreen
	# Build 16: Go to village before run
	_show_village()


func _show_village() -> void:
	# Apply theme for selected world
	ThemeManager.set_world(GameState.selected_world_id)
	
	# Start the run first so village can show stats
	GameState.start_new_run(GameState.selected_world_id)
	
	var village_screen := VILLAGE_SCENE.instantiate()
	await _swap_screen(village_screen)
	village_screen.depart_requested.connect(_on_village_depart)
	village_screen.status_updated.connect(_on_status_updated)
	
	status_bar.show_bar()
	status_bar.update_status()


func _on_village_depart() -> void:
	_show_run_after_village()


func _on_run_ended(soul_gain: int, is_clear: bool) -> void:
	# Phase 2: Show inheritance screen instead of simple result
	_show_inheritance()


func _on_inheritance_selected() -> void:
	# After inheritance selection, go to world select
	_show_world_select()


func _on_battle_requested(enemy_id: String) -> void:
	_show_battle(enemy_id)


func _on_battle_ended(result: String) -> void:
	# Remove battle screen
	if current_screen != null:
		current_screen.queue_free()
	
	# Restore run screen
	if run_screen_instance != null:
		run_screen_instance.show()
		current_screen = run_screen_instance
		run_screen_instance.on_battle_result(result)
		status_bar.update_status()
	else:
		# Fallback: return to world select
		_show_world_select()


func _on_status_updated() -> void:
	status_bar.update_status()


func _on_feedback_requested(data: Dictionary) -> void:
	# Save feedback to user://feedback/ directory
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("feedback"):
		dir.make_dir("feedback")
	
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = "user://feedback/fb_%s.json" % timestamp
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("Feedback saved: %s" % path)
	
	# Show brief confirmation overlay
	var label := Label.new()
	label.text = "📝 フィードバック保存しました"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchors_preset = Control.PRESET_CENTER_BOTTOM
	label.position.y -= 60
	add_child(label)
	
	var tween: Tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
