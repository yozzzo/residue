extends GutTest
## API Client tests — verifies endpoint URLs and data structure expectations.
## These are structural tests (not live network calls) since GUT runs headless.

const ApiClientScript := preload("res://scripts/ApiClient.gd")


func test_api_base_url_defined() -> void:
	assert_true(ApiClientScript.API_BASE.begins_with("https://"),
		"API_BASE should be an HTTPS URL")


func test_api_base_url_has_version() -> void:
	assert_true(ApiClientScript.API_BASE.contains("/api/v"),
		"API_BASE should include versioned path")


func test_request_timeout_reasonable() -> void:
	assert_true(ApiClientScript.REQUEST_TIMEOUT > 0,
		"REQUEST_TIMEOUT should be positive")
	assert_true(ApiClientScript.REQUEST_TIMEOUT <= 30,
		"REQUEST_TIMEOUT should not exceed 30s")


func test_local_worlds_data_exists() -> void:
	var f := FileAccess.open("res://data/worlds/worlds.json", FileAccess.READ)
	assert_not_null(f, "Local worlds.json fallback should exist")
	if f:
		var text := f.get_as_text()
		f.close()
		var json := JSON.new()
		var err := json.parse(text)
		assert_eq(err, OK, "worlds.json should be valid JSON")
		var data: Variant = json.data
		assert_true(data is Dictionary or data is Array,
			"worlds.json root should be Dictionary or Array")


func test_local_events_data_exists() -> void:
	var f := FileAccess.open("res://data/events/events.json", FileAccess.READ)
	assert_not_null(f, "Local events.json fallback should exist")
	if f:
		f.close()


func test_local_enemies_data_exists() -> void:
	var f := FileAccess.open("res://data/enemies/enemies.json", FileAccess.READ)
	assert_not_null(f, "Local enemies.json fallback should exist")
	if f:
		f.close()


func test_manifest_path_constants() -> void:
	assert_true(GameState.WORLDS_PATH.length() > 0, "WORLDS_PATH should be defined")
	assert_true(GameState.EVENTS_PATH.length() > 0, "EVENTS_PATH should be defined")
	assert_true(GameState.ENEMIES_PATH.length() > 0, "ENEMIES_PATH should be defined")
	assert_true(GameState.JOBS_PATH.length() > 0, "JOBS_PATH should be defined")
