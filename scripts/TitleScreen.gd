extends Control

signal start_requested
signal quit_requested

@onready var start_button: Button = $VBox/StartButton
@onready var quit_button: Button = $VBox/QuitButton


func _ready() -> void:
	start_button.pressed.connect(func() -> void: start_requested.emit())
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
