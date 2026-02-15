extends Control

signal back_requested
signal world_selected(world_id: String)

@onready var world_buttons: VBoxContainer = $Margin/RootVBox/WorldButtons
@onready var back_button: Button = $Margin/RootVBox/Footer/BackButton
@onready var meta_label: Label = $Margin/RootVBox/Footer/MetaLabel


func _ready() -> void:
	back_button.pressed.connect(func() -> void: back_requested.emit())
	_populate_world_buttons()
	_update_meta_text()


func _populate_world_buttons() -> void:
	for child: Node in world_buttons.get_children():
		child.queue_free()

	for world: Variant in GameState.get_worlds():
		var button := Button.new()
		var world_id: String = world.get("world_id", "unknown")
		var world_name: String = world.get("name", world_id)
		var blurb: String = world.get("blurb", "")
		button.text = "%s: %s" % [world_name, blurb]
		button.pressed.connect(_on_world_button_pressed.bind(world_id))
		world_buttons.add_child(button)


func _update_meta_text() -> void:
	meta_label.text = "Loop: %d  Soul: %d" % [GameState.loop_count, GameState.soul_points]


func _on_world_button_pressed(world_id: String) -> void:
	world_selected.emit(world_id)
