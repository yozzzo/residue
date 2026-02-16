extends Node
## Localization manager for multi-language support
## Autoload singleton providing tr() for text lookups

signal locale_changed(locale: String)

const LOCALES_PATH := "res://data/locales/"
const DEFAULT_LOCALE := "ja"

var current_locale: String = DEFAULT_LOCALE
var _locale_data: Dictionary = {}
var _available_locales: Array = ["ja", "en"]


func _ready() -> void:
	_load_locale(current_locale)


func set_locale(locale: String) -> void:
	if locale == current_locale:
		return
	if not _available_locales.has(locale):
		push_warning("LocaleManager: Unknown locale '%s', falling back to '%s'" % [locale, DEFAULT_LOCALE])
		locale = DEFAULT_LOCALE
	
	current_locale = locale
	_load_locale(locale)
	locale_changed.emit(locale)


func get_available_locales() -> Array:
	return _available_locales.duplicate()


func tr(key: String, params: Dictionary = {}) -> String:
	## Translate a key, optionally with parameter substitution
	## Keys use dot notation: "ui.start", "ui.battle_attack", etc.
	## Params replace {param_name} in the string
	
	var value: String = _get_nested_value(key)
	if value.is_empty():
		push_warning("LocaleManager: Missing translation for key '%s' in locale '%s'" % [key, current_locale])
		return key
	
	# Substitute parameters
	for param_key: String in params.keys():
		value = value.replace("{%s}" % param_key, str(params[param_key]))
	
	return value


func tr_data(data: Dictionary, field: String) -> String:
	## Get localized field from data dictionary
	## Looks for field_ja / field_en based on current locale
	## Falls back to base field if localized version not found
	
	var localized_key := "%s_%s" % [field, current_locale]
	if data.has(localized_key):
		return str(data[localized_key])
	
	# Fallback to default locale
	var default_key := "%s_%s" % [field, DEFAULT_LOCALE]
	if data.has(default_key):
		return str(data[default_key])
	
	# Fallback to base field (no locale suffix)
	if data.has(field):
		return str(data[field])
	
	return ""


func get_memory_flag_label(flag: String) -> String:
	## Get localized label for a memory flag
	var key := "memory_flags.%s" % flag
	var label: String = _get_nested_value(key)
	return label if not label.is_empty() else flag


func get_item_name(item_id: String) -> String:
	## Get localized name for an item
	var key := "items.%s" % item_id
	var name: String = _get_nested_value(key)
	return name if not name.is_empty() else item_id


func get_stat_label(stat: String) -> String:
	## Get localized label for a stat (hp_bonus, attack_bonus, etc.)
	var key := "stat_labels.%s" % stat
	var label: String = _get_nested_value(key)
	return label if not label.is_empty() else stat


func _load_locale(locale: String) -> void:
	var path := LOCALES_PATH + locale + ".json"
	if not FileAccess.file_exists(path):
		push_error("LocaleManager: Locale file not found: %s" % path)
		return
	
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("LocaleManager: Cannot open locale file: %s" % path)
		return
	
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("LocaleManager: Invalid JSON in locale file: %s" % path)
		return
	
	_locale_data = parsed


func _get_nested_value(key: String) -> String:
	## Get value from nested dictionary using dot notation
	## e.g., "ui.start" -> _locale_data["ui"]["start"]
	
	var parts: Array = key.split(".")
	var current: Variant = _locale_data
	
	for part: String in parts:
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			return ""
	
	if current is String:
		return current
	
	return ""
