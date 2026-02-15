extends Control

const TITLE_SCENE := preload("res://scenes/TitleScreen.tscn")
const WORLD_SELECT_SCENE := preload("res://scenes/WorldSelect.tscn")
const RUN_SCENE := preload("res://scenes/RunScreen.tscn")
const BATTLE_SCENE := preload("res://scenes/BattleScreen.tscn")
const INHERITANCE_SCENE := preload("res://scenes/InheritanceScreen.tscn")

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


func _show_inheritance() -> void:
	var inheritance_screen := INHERITANCE_SCENE.instantiate()
	_swap_screen(inheritance_screen)
	inheritance_screen.inheritance_selected.connect(_on_inheritance_selected)


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
	else:
		# Fallback: return to world select
		_show_world_select()
