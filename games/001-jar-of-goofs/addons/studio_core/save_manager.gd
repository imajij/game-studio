extends Node
## Persistent local save data. One JSON file in user://.
## Writes to disk on every set_value() — data stays tiny and mobile OSes
## kill apps without warning, so "save later" is a lost-progress bug.

signal data_changed(key: String)

const SAVE_PATH: String = "user://save.json"

var _data: Dictionary = {}

func _ready() -> void:
	_load()


func get_value(key: String, default_value: Variant = null) -> Variant:
	return _data.get(key, default_value)


func set_value(key: String, value: Variant) -> void:
	if _data.has(key) and _data[key] == value:
		return
	_data[key] = value
	_save()
	data_changed.emit(key)


## Debug helper — wipes all progress.
func wipe() -> void:
	_data.clear()
	_save()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: could not open %s" % SAVE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_data = parsed
	else:
		push_warning("SaveManager: save file unreadable, starting fresh")


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(_data))
