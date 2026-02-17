extends Control

const TITLE_SCENE := preload("res://scenes/TitleScreen.tscn")
const WORLD_SELECT_SCENE := preload("res://scenes/WorldSelect.tscn")
const JOB_SELECT_SCENE := preload("res://scenes/JobSelectScreen.tscn")
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


func _ready() -> void:
	_setup_transition_layer()
	_setup_status_bar()
	_show_title()


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


func _on_job_selected(job_id: String) -> void:
	# Job is already selected in GameState by JobSelectScreen
	_show_run()


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
