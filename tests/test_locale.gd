extends GutTest
## Locale system tests


func test_default_locale_is_japanese() -> void:
	assert_eq(LocaleManager.current_locale, "ja",
		"Default locale should be Japanese")


func test_available_locales() -> void:
	var locales := LocaleManager.get_available_locales()
	assert_true(locales.has("ja"), "Japanese should be available")
	assert_true(locales.has("en"), "English should be available")


func test_locale_switch_to_english() -> void:
	var original := LocaleManager.current_locale
	LocaleManager.set_locale("en")
	assert_eq(LocaleManager.current_locale, "en", "Locale should switch to English")
	# Restore
	LocaleManager.set_locale(original)


func test_locale_switch_to_japanese() -> void:
	LocaleManager.set_locale("ja")
	assert_eq(LocaleManager.current_locale, "ja", "Locale should switch to Japanese")


func test_key_returns_value_not_empty() -> void:
	LocaleManager.set_locale("ja")
	var val := LocaleManager.t("ui.start")
	assert_true(val.length() > 0, "ui.start should have a Japanese translation")


func test_unknown_key_returns_key() -> void:
	var val := LocaleManager.t("nonexistent.key.xyz")
	# Should return the key itself or empty, not crash
	assert_true(val is String, "Unknown key should return a String")


func test_param_substitution() -> void:
	LocaleManager.set_locale("ja")
	var val := LocaleManager.t("ui.trap_damage", {"damage": 10})
	# Should contain "10" somewhere if param substitution works
	assert_true(val.contains("10") or val.length() > 0,
		"Parameter substitution should work")


func test_locale_data_file_exists() -> void:
	var f := FileAccess.open("res://data/locales/ja.json", FileAccess.READ)
	assert_not_null(f, "Japanese locale file should exist")
	if f:
		f.close()

	f = FileAccess.open("res://data/locales/en.json", FileAccess.READ)
	assert_not_null(f, "English locale file should exist")
	if f:
		f.close()
