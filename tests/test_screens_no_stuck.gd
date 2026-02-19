extends GutTest
## Tests that verify every screen path creates at least one button,
## preventing "stuck" states where the player has no way to proceed.
##
## These tests work by inspecting the source code patterns rather than
## instantiating full scenes, since RunScreen requires a scene tree with
## UI nodes. We verify the code structure guarantees buttons are added.

const RunScreenScript := preload("res://scripts/RunScreen.gd")

var _source: String = ""


func before_all() -> void:
	var f := FileAccess.open("res://scripts/RunScreen.gd", FileAccess.READ)
	if f:
		_source = f.get_as_text()
		f.close()


## Helper: extract a function body from source (from "func name" to next "func " or EOF)
func _get_func_body(func_name: String) -> String:
	var start := _source.find("func %s" % func_name)
	if start == -1:
		return ""
	var next_func := _source.find("\nfunc ", start + 1)
	if next_func == -1:
		return _source.substr(start)
	return _source.substr(start, next_func - start)


## Helper: check that function body contains button creation
func _has_button_creation(body: String) -> bool:
	return (
		body.contains("create_choice_button") or
		body.contains("create_primary_button") or
		body.contains("create_nav_button") or
		body.contains("_render_navigation_buttons")
	)


func test_source_loaded() -> void:
	assert_true(_source.length() > 0, "RunScreen.gd source should be loaded")


func test_show_trap_message_has_button() -> void:
	var body := _get_func_body("_show_trap_message")
	assert_true(body.length() > 0, "_show_trap_message should exist")
	assert_true(_has_button_creation(body),
		"_show_trap_message must create a continue button")


func test_render_navigation_only_has_buttons() -> void:
	var body := _get_func_body("_render_navigation_only")
	assert_true(body.length() > 0, "_render_navigation_only should exist")
	assert_true(body.contains("_render_navigation_buttons"),
		"_render_navigation_only must call _render_navigation_buttons")


func test_render_navigation_buttons_creates_buttons() -> void:
	var body := _get_func_body("_render_navigation_buttons")
	assert_true(body.length() > 0, "_render_navigation_buttons should exist")
	assert_true(_has_button_creation(body),
		"_render_navigation_buttons must create nav buttons")


func test_show_fallback_event_has_button() -> void:
	var body := _get_func_body("_show_fallback_event")
	assert_true(body.length() > 0, "_show_fallback_event should exist")
	assert_true(_has_button_creation(body),
		"_show_fallback_event must create a back button")


func test_render_event_has_choices_or_navigation() -> void:
	var body := _get_func_body("_render_event")
	assert_true(body.length() > 0, "_render_event should exist")
	assert_true(_has_button_creation(body),
		"_render_event must create choice buttons")


func test_show_result_then_proceed_has_button() -> void:
	var body := _get_func_body("_show_result_then_proceed")
	assert_true(body.length() > 0, "_show_result_then_proceed should exist")
	assert_true(_has_button_creation(body),
		"_show_result_then_proceed must create a continue button")


func test_show_data_error_has_button() -> void:
	var body := _get_func_body("_show_data_error")
	assert_true(body.length() > 0, "_show_data_error should exist")
	assert_true(_has_button_creation(body),
		"_show_data_error must create a back button")


func test_on_turn_limit_reached_has_button() -> void:
	var body := _get_func_body("_on_turn_limit_reached")
	assert_true(body.length() > 0, "_on_turn_limit_reached should exist")
	assert_true(_has_button_creation(body),
		"_on_turn_limit_reached must create a button (boss proceed or defeat)")


func test_show_ending_has_button() -> void:
	var body := _get_func_body("_show_ending")
	assert_true(body.length() > 0, "_show_ending should exist")
	assert_true(_has_button_creation(body),
		"_show_ending must create a done button")


## Bonus: verify _clear_ui exists and cleans up children
func test_clear_ui_removes_children() -> void:
	var body := _get_func_body("_clear_ui")
	assert_true(body.length() > 0, "_clear_ui should exist")
	assert_true(body.contains("queue_free"), "_clear_ui must free children")
