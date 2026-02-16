extends Node2D
class_name DamagePopup
## Floating damage number popup for battle screen

var damage_value: int = 0
var is_healing: bool = false
var is_critical: bool = false


func _ready() -> void:
	_animate()


func setup(value: int, heal: bool = false, critical: bool = false) -> void:
	damage_value = value
	is_healing = heal
	is_critical = critical


func _animate() -> void:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	
	# Set text and color
	if is_healing:
		label.text = "+%d" % damage_value
		label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	else:
		label.text = "-%d" % damage_value
		if is_critical:
			label.text = "-%d!" % damage_value
			label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
			label.add_theme_font_size_override("font_size", 28)
		else:
			label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			label.add_theme_font_size_override("font_size", 22)
	
	# Animation
	var start_pos := position
	var end_pos := start_pos + Vector2(0, -50)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", end_pos, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
