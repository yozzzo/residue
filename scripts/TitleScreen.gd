extends Control

signal start_requested
signal quit_requested

@onready var start_button: Button = $VBox/StartButton
@onready var quit_button: Button = $VBox/QuitButton
@onready var title_label: Label = $VBox/Title
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var background: ColorRect = $Background

var glitch_material: ShaderMaterial


func _ready() -> void:
	start_button.pressed.connect(func() -> void: start_requested.emit())
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	
	_setup_title_style()
	_setup_glitch_effect()
	_update_glitch_intensity()


func _setup_title_style() -> void:
	# Larger font for title
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))


func _setup_glitch_effect() -> void:
	# Load shader
	var shader: Shader = load("res://shaders/glitch_title.gdshader") if ResourceLoader.exists("res://shaders/glitch_title.gdshader") else null
	
	if shader != null:
		glitch_material = ShaderMaterial.new()
		glitch_material.shader = shader
		glitch_material.set_shader_parameter("intensity", 0.0)
		title_label.material = glitch_material
	else:
		push_warning("TitleScreen: Glitch shader not found")


func _update_glitch_intensity() -> void:
	if glitch_material == null:
		return
	
	# Check highest truth stage across all worlds (GDD 21.5)
	var max_truth_stage: int = 0
	for world: Variant in GameState.get_worlds():
		var world_id: String = world.get("world_id", "")
		var stage: int = GameState.get_truth_stage(world_id)
		max_truth_stage = maxi(max_truth_stage, stage)
	
	# Apply glitch based on truth stage
	var intensity: float = 0.0
	match max_truth_stage:
		0, 1:
			intensity = 0.0
		2:
			intensity = 0.15  # Subtle
		3:
			intensity = 0.4   # Moderate
		_:
			intensity = 0.7   # Strong for very high truth stages
	
	glitch_material.set_shader_parameter("intensity", intensity)
	
	# Also adjust title text color for high truth stages
	if max_truth_stage >= 3:
		title_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.7))
		subtitle_label.text = "残痕は消えない"
	elif max_truth_stage >= 2:
		subtitle_label.text = "継承の痕跡"


func _process(_delta: float) -> void:
	# Shader updates automatically via TIME uniform
	pass
