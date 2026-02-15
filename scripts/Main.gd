extends Control

const TITLE_SCENE := preload("res://scenes/TitleScreen.tscn")
const WORLD_SELECT_SCENE := preload("res://scenes/WorldSelect.tscn")
const RUN_SCENE := preload("res://scenes/RunScreen.tscn")
const BATTLE_SCENE := preload("res://scenes/BattleScreen.tscn")

var current_screen: Control
var run_screen_instance: Control = null


func _ready() -> void:
	_show_title()


func _show_title() -> void:
	_swap_screen(TITLE_SCENE.instantiate())
	current_screen.start_requested.connect(_on_start_requested)
	current_screen.quit_requested.connect(_on_quit_requested)


func _show_world_select() -> void:
	_swap_screen(WORLD_SELECT_SCENE.instantiate())
	current_screen.back_requested.connect(_on_back_to_title)
	current_screen.world_selected.connect(_on_world_selected)


func _show_run() -> void:
	run_screen_instance = RUN_SCENE.instantiate()
	_swap_screen(run_screen_instance)
	run_screen_instance.run_ended.connect(_on_run_ended)
	run_screen_instance.battle_requested.connect(_on_battle_requested)


func _show_battle(enemy_id: String) -> void:
	var battle_screen := BATTLE_SCENE.instantiate()
	battle_screen.set_enemy(enemy_id)
	
	# Keep run_screen reference, just hide it
	if run_screen_instance != null:
		run_screen_instance.hide()
	
	add_child(battle_screen)
	current_screen = battle_screen
	battle_screen.battle_ended.connect(_on_battle_ended)


func _swap_screen(next_screen: Control) -> void:
	if current_screen != null:
		current_screen.queue_free()
	current_screen = next_screen
	run_screen_instance = null
	add_child(current_screen)


func _on_start_requested() -> void:
	_show_world_select()


func _on_quit_requested() -> void:
	get_tree().quit()


func _on_back_to_title() -> void:
	_show_title()


func _on_world_selected(world_id: String) -> void:
	GameState.select_world(world_id)
	_show_run()


func _on_run_ended(soul_gain: int, is_clear: bool) -> void:
	_show_run_result(soul_gain, is_clear)


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
	else:
		# Fallback: return to world select
		_show_world_select()


func _show_run_result(soul_gain: int, is_clear: bool) -> void:
	# Create a simple result screen
	var result_screen := Control.new()
	result_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08, 1)
	result_screen.add_child(bg)
	
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_bottom", 64)
	result_screen.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)
	
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 28)
	if is_clear:
		title.text = "✦ 周回クリア ✦"
		title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	else:
		title.text = "— 周回終了 —"
		title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(title)
	
	var stats := RichTextLabel.new()
	stats.bbcode_enabled = true
	stats.fit_content = true
	stats.custom_minimum_size = Vector2(0, 200)
	
	var stats_text := """[b]周回統計[/b]

深度（訪問ノード数）: %d → [color=cyan]+%d[/color]
討伐数: %d → [color=cyan]+%d[/color]
発見: %d → [color=cyan]+%d[/color]
%s

[b]獲得魂価値: [color=gold]%d[/color][/b]
累計魂価値: %d
周回数: %d""" % [
		GameState.run_nodes_visited,
		GameState.run_nodes_visited * 2,
		GameState.run_kills,
		GameState.run_kills * 3,
		GameState.run_discoveries,
		GameState.run_discoveries * 5,
		"クリアボーナス: [color=gold]+10[/color]" if is_clear else "",
		soul_gain,
		GameState.soul_points,
		GameState.loop_count
	]
	stats.text = stats_text
	vbox.add_child(stats)
	
	var continue_btn := Button.new()
	continue_btn.text = "続ける"
	continue_btn.custom_minimum_size = Vector2(200, 48)
	continue_btn.pressed.connect(func():
		result_screen.queue_free()
		_show_world_select()
	)
	vbox.add_child(continue_btn)
	
	_swap_screen(result_screen)
