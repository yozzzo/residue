extends RefCounted

const SAVE_DIR := "user://saves"
const PRIMARY_SAVE_PATH := "user://saves/save_current.json"
const BACKUP_SAVE_PATH := "user://saves/save_backup.json"


func save_state(payload: Dictionary) -> void:
	_ensure_save_dir()
	_rotate_backup()
	_write_json(PRIMARY_SAVE_PATH, payload)


func load_state() -> Dictionary:
	var primary := _read_json(PRIMARY_SAVE_PATH)
	if not primary.is_empty():
		return primary
	return _read_json(BACKUP_SAVE_PATH)


func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _rotate_backup() -> void:
	if FileAccess.file_exists(PRIMARY_SAVE_PATH):
		DirAccess.copy_absolute(PRIMARY_SAVE_PATH, BACKUP_SAVE_PATH)


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open save file: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed := JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}
