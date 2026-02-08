extends Control

signal run_ended(soul_gain: int)

@onready var header: Label = $Margin/Root/Header
@onready var body_text: RichTextLabel = $Margin/Root/BodyText
@onready var choices_box: VBoxContainer = $Margin/Root/Choices
@onready var exit_button: Button = $Margin/Root/Bottom/ExitRunButton
@onready var status_label: Label = $Margin/Root/Bottom/StatusLabel

var run_score: int = 0
var current_event_index: int = 0
var current_events: Array = []
var run_complete: bool = false


func _ready() -> void:
	exit_button.pressed.connect(_on_end_run)
	_load_world_run()
	_render_current_event()


func _load_world_run() -> void:
	var world := GameState.get_world_by_id(GameState.selected_world_id)
	var world_name := world.get("name", "Unknown World")
	header.text = "Run - %s" % world_name
	current_events = GameState.get_events_for_world(GameState.selected_world_id)
	if current_events.is_empty():
		current_events = [
			{
				"text": "No events found. A silent corridor stretches ahead.",
				"choices": [
					{"label": "Proceed", "score": 1},
					{"label": "Retreat", "score": 0}
				]
			}
		]


func _render_current_event() -> void:
	for child in choices_box.get_children():
		child.queue_free()

	if run_complete:
		body_text.text = "[b]Run Complete[/b]\nYou can end this run to inherit your score."
		return

	var event: Dictionary = current_events[min(current_event_index, current_events.size() - 1)]
	body_text.text = "[b]Loop %d[/b]\n%s" % [GameState.loop_count, event.get("text", "")]

	var choices: Array = event.get("choices", [])
	for choice in choices:
		var button := Button.new()
		button.text = choice.get("label", "Choose")
		button.pressed.connect(_on_choice_selected.bind(int(choice.get("score", 0))))
		choices_box.add_child(button)


func _on_end_run() -> void:
	var soul_gain := max(1, run_score)
	run_ended.emit(soul_gain)


func _on_choice_selected(score_gain: int) -> void:
	run_score += score_gain
	status_label.text = "Score: %d" % run_score
	if current_event_index >= current_events.size() - 1:
		run_complete = true
	else:
		current_event_index += 1
	_render_current_event()
