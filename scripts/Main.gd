extends Control

const TITLE_SCENE := preload("res://scenes/TitleScreen.tscn")
const WORLD_SELECT_SCENE := preload("res://scenes/WorldSelect.tscn")
const RUN_SCENE := preload("res://scenes/RunScreen.tscn")

var current_screen: Control


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
	_swap_screen(RUN_SCENE.instantiate())
	current_screen.run_ended.connect(_on_run_ended)


func _swap_screen(next_screen: Control) -> void:
	if current_screen != null:
		current_screen.queue_free()
	current_screen = next_screen
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


func _on_run_ended(soul_gain: int) -> void:
	GameState.apply_end_of_run(soul_gain)
	_show_world_select()
