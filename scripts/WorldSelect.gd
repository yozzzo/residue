extends Control

signal back_requested
signal world_selected(world_id: String)

@onready var world_buttons: VBoxContainer = $Margin/RootVBox/WorldButtons
@onready var back_button: Button = $Margin/RootVBox/Footer/BackButton
@onready var meta_label: Label = $Margin/RootVBox/Footer/MetaLabel
@onready var traits_label: Label = $Margin/RootVBox/TraitsPanel/TraitsLabel
@onready var background: ColorRect = $Background


func _ready() -> void:
	back_button.pressed.connect(func() -> void: back_requested.emit())
	_populate_world_buttons()
	_update_meta_text()
	_update_traits_display()
	_apply_theme()


func _apply_theme() -> void:
	# Use default theme for world select (neutral)
	ThemeManager.set_world("default")
	background.color = ThemeManager.get_background_color()


func _populate_world_buttons() -> void:
	for child: Node in world_buttons.get_children():
		child.queue_free()

	for world: Variant in GameState.get_worlds():
		var button := Button.new()
		var world_id: String = world.get("world_id", "unknown")
		var world_name: String = world.get("name", world_id)
		var blurb: String = world.get("blurb", "")
		
		# Phase 2: Show truth stage for each world
		var truth_stage: int = GameState.get_truth_stage(world_id)
		var truth_text: String = ""
		if truth_stage > 0:
			truth_text = " [真実段階 %d]" % truth_stage
		
		# Add visual indicator based on world type
		var world_icon: String = "🏰" if world_id == "medieval" else "🔮" if world_id == "future" else "⚡"
		
		button.text = "%s %s: %s%s" % [world_icon, world_name, blurb, truth_text]
		button.custom_minimum_size = Vector2(0, 52)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_on_world_button_pressed.bind(world_id))
		world_buttons.add_child(button)


func _update_meta_text() -> void:
	meta_label.text = "Loop: %d  Soul: %d" % [GameState.loop_count, GameState.soul_points]


func _update_traits_display() -> void:
	if traits_label == null:
		return
	
	var dominant_traits: Array = GameState.get_dominant_traits(5)
	if dominant_traits.size() == 0:
		traits_label.text = "傾向: なし（行動を重ねると蓄積されます）"
		return
	
	var traits_with_values: Array = []
	for trait_tag: String in dominant_traits:
		var value: int = GameState.get_trait_tag_value(trait_tag)
		traits_with_values.append("%s(%d)" % [trait_tag, value])
	
	traits_label.text = "傾向: " + ", ".join(traits_with_values)


func _on_world_button_pressed(world_id: String) -> void:
	world_selected.emit(world_id)
