extends SceneTree
## Pre-flight check: Validates all scenes load without error and critical paths work.
## Run with: godot --headless -s scripts/build_preflight_check.gd

var errors: Array[String] = []
var warnings: Array[String] = []
var checks_passed: int = 0
var checks_total: int = 0


func _init() -> void:
	print("=== RESIDUE PRE-FLIGHT CHECK ===\n")
	
	_check_all_scenes_load()
	_check_all_scripts_parse()
	_check_font_exists()
	_check_theme_has_japanese_font()
	_check_no_placeholder_text_in_scenes()
	_check_tscn_integrity()
	_check_api_endpoint_reachable()
	_check_no_orphan_onready_vars()
	
	print("\n=== RESULTS ===")
	print("Passed: %d / %d" % [checks_passed, checks_total])
	if warnings.size() > 0:
		print("\nWarnings:")
		for w: String in warnings:
			print("  ⚠️  %s" % w)
	if errors.size() > 0:
		print("\nERRORS:")
		for e: String in errors:
			print("  ❌ %s" % e)
		print("\n=== PRE-FLIGHT FAILED ===")
		quit(1)
	else:
		print("\n=== PRE-FLIGHT PASSED ===")
		quit(0)


func _pass(name: String) -> void:
	checks_total += 1
	checks_passed += 1
	print("  ✅ %s" % name)


func _fail(name: String, reason: String) -> void:
	checks_total += 1
	errors.append("%s: %s" % [name, reason])
	print("  ❌ %s: %s" % [name, reason])


func _warn(name: String, reason: String) -> void:
	warnings.append("%s: %s" % [name, reason])
	print("  ⚠️  %s: %s" % [name, reason])


func _check_all_scenes_load() -> void:
	print("Checking scenes load...")
	var scenes := [
		"res://scenes/Main.tscn",
		"res://scenes/TitleScreen.tscn",
		"res://scenes/WorldSelect.tscn",
		"res://scenes/JobSelectScreen.tscn",
		"res://scenes/VillageScreen.tscn",
		"res://scenes/RunScreen.tscn",
		"res://scenes/BattleScreen.tscn",
		"res://scenes/InheritanceScreen.tscn",
		"res://scenes/TransitionLayer.tscn",
		"res://scenes/StatusBar.tscn",
	]
	for scene_path: String in scenes:
		if not ResourceLoader.exists(scene_path):
			_fail("Scene exists: %s" % scene_path, "File not found")
			continue
		var scene: PackedScene = load(scene_path)
		if scene == null:
			_fail("Scene loads: %s" % scene_path, "Failed to load")
			continue
		var instance: Node = scene.instantiate()
		if instance == null:
			_fail("Scene instantiates: %s" % scene_path, "Failed to instantiate")
			continue
		instance.queue_free()
		_pass("Scene: %s" % scene_path.get_file())


func _check_all_scripts_parse() -> void:
	print("Checking scripts parse...")
	var scripts := [
		"res://scripts/Main.gd",
		"res://scripts/RunScreen.gd",
		"res://scripts/VillageScreen.gd",
		"res://scripts/BattleScreen.gd",
		"res://scripts/GameState.gd",
		"res://scripts/ApiClient.gd",
		"res://scripts/AssetManager.gd",
		"res://scripts/StatusBar.gd",
		"res://scripts/LocaleManager.gd",
		"res://scripts/ThemeManager.gd",
		"res://scripts/UITheme.gd",
		"res://scripts/AudioManager.gd",
	]
	for script_path: String in scripts:
		if not ResourceLoader.exists(script_path):
			_fail("Script exists: %s" % script_path, "File not found")
			continue
		var script: GDScript = load(script_path)
		if script == null:
			_fail("Script parses: %s" % script_path, "Failed to parse")
			continue
		_pass("Script: %s" % script_path.get_file())


func _check_font_exists() -> void:
	print("Checking fonts...")
	var font_path := "res://assets/fonts/NotoSansJP-VariableFont.ttf"
	if ResourceLoader.exists(font_path):
		var font: Font = load(font_path)
		if font != null:
			_pass("Japanese font (NotoSansJP)")
		else:
			_fail("Japanese font", "File exists but failed to load")
	else:
		_fail("Japanese font", "NotoSansJP-VariableFont.ttf not found")


func _check_theme_has_japanese_font() -> void:
	print("Checking theme font setup...")
	var theme_path := "res://assets/fonts/default_theme.tres"
	if not ResourceLoader.exists(theme_path):
		_fail("Theme exists", "default_theme.tres not found")
		return
	var theme: Theme = load(theme_path)
	if theme == null:
		_fail("Theme loads", "Failed to load default_theme.tres")
		return
	if theme.get_default_font() != null:
		_pass("Theme has default font")
	else:
		_fail("Theme default font", "No default font set")


func _check_no_placeholder_text_in_scenes() -> void:
	print("Checking for placeholder text in scenes...")
	# Check that tscn files don't have broken placeholder text
	var files_to_check := {
		"res://scenes/RunScreen.tscn": ["StatusLabel"],  # Should be removed
		"res://scenes/VillageScreen.tscn": ["StatusLabel", "Header"],  # Should be removed
	}
	for path: String in files_to_check.keys():
		if not FileAccess.file_exists(path):
			_fail("File exists: %s" % path, "Not found")
			continue
		var content: String = FileAccess.open(path, FileAccess.READ).get_as_text()
		var forbidden: Array = files_to_check[path]
		var found_issues: Array = []
		for keyword: String in forbidden:
			if content.contains('name="%s"' % keyword):
				found_issues.append(keyword)
		if found_issues.size() > 0:
			_fail("No forbidden nodes in %s" % path.get_file(), "Found: %s" % str(found_issues))
		else:
			_pass("No forbidden nodes in %s" % path.get_file())


func _check_tscn_integrity() -> void:
	print("Checking tscn integrity...")
	var scene_dir := DirAccess.open("res://scenes/")
	if scene_dir == null:
		_fail("Scenes directory", "Cannot open res://scenes/")
		return
	scene_dir.list_dir_begin()
	var file_name: String = scene_dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn"):
			var path: String = "res://scenes/" + file_name
			var content: String = FileAccess.open(path, FileAccess.READ).get_as_text()
			# Check basic tscn structure
			if not content.begins_with("[gd_scene"):
				_fail("TSCN integrity: %s" % file_name, "Missing [gd_scene header")
			elif content.count("[node") == 0:
				_fail("TSCN integrity: %s" % file_name, "No nodes found")
			else:
				_pass("TSCN integrity: %s" % file_name)
		file_name = scene_dir.get_next()


func _check_api_endpoint_reachable() -> void:
	print("Checking API...")
	# Can't do async HTTP in _init, just verify URL constant exists
	var api_script_path := "res://scripts/ApiClient.gd"
	if not FileAccess.file_exists(api_script_path):
		_fail("ApiClient exists", "File not found")
		return
	var content: String = FileAccess.open(api_script_path, FileAccess.READ).get_as_text()
	if content.contains("residue-api.residue-dev.workers.dev"):
		_pass("API URL configured")
	else:
		_fail("API URL", "Expected URL not found in ApiClient.gd")


func _check_no_orphan_onready_vars() -> void:
	print("Checking @onready vars match scene nodes...")
	# Check RunScreen
	var run_script: String = FileAccess.open("res://scripts/RunScreen.gd", FileAccess.READ).get_as_text()
	var run_scene: String = FileAccess.open("res://scenes/RunScreen.tscn", FileAccess.READ).get_as_text()
	
	# Extract @onready var paths
	var orphans: Array = []
	for line: String in run_script.split("\n"):
		if not line.begins_with("@onready"):
			continue
		# Extract node path after $
		var dollar_idx: int = line.find("$")
		if dollar_idx == -1:
			continue
		var node_path: String = line.substr(dollar_idx + 1).strip_edges()
		# Get the last node name
		var parts: Array = node_path.split("/")
		var node_name: String = parts[parts.size() - 1]
		if not run_scene.contains('name="%s"' % node_name):
			orphans.append(node_name)
	
	if orphans.size() > 0:
		_fail("RunScreen @onready vars", "Orphan nodes: %s" % str(orphans))
	else:
		_pass("RunScreen @onready vars match scene")
	
	# Check VillageScreen
	var village_script: String = FileAccess.open("res://scripts/VillageScreen.gd", FileAccess.READ).get_as_text()
	var village_scene: String = FileAccess.open("res://scenes/VillageScreen.tscn", FileAccess.READ).get_as_text()
	
	orphans = []
	for line: String in village_script.split("\n"):
		if not line.begins_with("@onready"):
			continue
		var dollar_idx: int = line.find("$")
		if dollar_idx == -1:
			continue
		var node_path: String = line.substr(dollar_idx + 1).strip_edges()
		var parts: Array = node_path.split("/")
		var node_name: String = parts[parts.size() - 1]
		if not village_scene.contains('name="%s"' % node_name):
			orphans.append(node_name)
	
	if orphans.size() > 0:
		_fail("VillageScreen @onready vars", "Orphan nodes: %s" % str(orphans))
	else:
		_pass("VillageScreen @onready vars match scene")
