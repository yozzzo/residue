extends Node
class_name TypewriterEffect
## Typewriter effect for RichTextLabel - displays text character by character

signal text_completed
signal char_revealed(char_index: int)

enum Speed { NORMAL, FAST, INSTANT }

# Characters per second for each speed mode
const SPEED_VALUES := {
	Speed.NORMAL: 30.0,
	Speed.FAST: 80.0,
	Speed.INSTANT: 9999.0
}

var target_label: RichTextLabel
var current_speed: Speed = Speed.NORMAL
var full_text: String = ""
var visible_chars: int = 0
var total_chars: int = 0
var elapsed: float = 0.0
var is_playing: bool = false
var skip_requested: bool = false


func _ready() -> void:
	set_process(false)


func setup(label: RichTextLabel) -> void:
	target_label = label


func display_text(text: String, speed: Speed = Speed.NORMAL) -> void:
	if target_label == null:
		push_error("TypewriterEffect: No target label set")
		return
	
	full_text = text
	current_speed = speed
	
	# Set BBCode text but hide all characters initially
	target_label.text = full_text
	total_chars = target_label.get_total_character_count()
	
	if speed == Speed.INSTANT or total_chars == 0:
		# Show all immediately
		target_label.visible_characters = -1
		is_playing = false
		text_completed.emit()
		return
	
	visible_chars = 0
	target_label.visible_characters = 0
	elapsed = 0.0
	is_playing = true
	skip_requested = false
	set_process(true)


func _process(delta: float) -> void:
	if not is_playing:
		set_process(false)
		return
	
	if skip_requested:
		_complete_immediately()
		return
	
	elapsed += delta
	var chars_per_second: float = SPEED_VALUES[current_speed]
	var target_visible: int = int(elapsed * chars_per_second)
	
	if target_visible > visible_chars:
		visible_chars = mini(target_visible, total_chars)
		target_label.visible_characters = visible_chars
		char_revealed.emit(visible_chars)
	
	if visible_chars >= total_chars:
		_complete_immediately()


func _complete_immediately() -> void:
	target_label.visible_characters = -1
	is_playing = false
	set_process(false)
	text_completed.emit()


func skip() -> void:
	if is_playing:
		skip_requested = true


func is_finished() -> bool:
	return not is_playing


func set_speed(speed: Speed) -> void:
	current_speed = speed
