extends CanvasLayer
class_name TransitionLayer
## Screen transition layer with fade effects

signal fade_completed

@onready var color_rect: ColorRect

var tween: Tween


func _ready() -> void:
	layer = 100  # Above everything
	
	color_rect = ColorRect.new()
	color_rect.name = "FadeRect"
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.anchors_preset = Control.PRESET_FULL_RECT
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(color_rect)


func fade_out(duration: float = 0.3, color: Color = Color.BLACK) -> void:
	_cancel_tween()
	
	var target_color := Color(color.r, color.g, color.b, 1.0)
	color_rect.color = Color(color.r, color.g, color.b, 0.0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	tween = create_tween()
	tween.tween_property(color_rect, "color", target_color, duration)
	await tween.finished
	fade_completed.emit()


func fade_in(duration: float = 0.3) -> void:
	_cancel_tween()
	
	var start_color := color_rect.color
	var target_color := Color(start_color.r, start_color.g, start_color.b, 0.0)
	
	tween = create_tween()
	tween.tween_property(color_rect, "color", target_color, duration)
	await tween.finished
	
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_completed.emit()


func transition(duration: float = 0.3, color: Color = Color.BLACK) -> void:
	## Fade out, emit signal (caller swaps content), then fade in
	await fade_out(duration * 0.5, color)
	# Caller should swap screen here
	fade_completed.emit()


func instant_black() -> void:
	_cancel_tween()
	color_rect.color = Color.BLACK
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP


func instant_clear() -> void:
	_cancel_tween()
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _cancel_tween() -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	tween = null
