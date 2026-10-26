extends Node
## Player-facing toggles, persisted through SaveManager.
## Other singletons react to setting_changed instead of polling.

signal setting_changed(key: String, enabled: bool)

const KEY_MUSIC: String = "settings.music_on"
const KEY_SFX: String = "settings.sfx_on"
const KEY_HAPTICS: String = "settings.haptics_on"

var music_on: bool:
	get:
		return bool(SaveManager.get_value(KEY_MUSIC, true))
	set(value):
		SaveManager.set_value(KEY_MUSIC, value)
		setting_changed.emit(KEY_MUSIC, value)

var sfx_on: bool:
	get:
		return bool(SaveManager.get_value(KEY_SFX, true))
	set(value):
		SaveManager.set_value(KEY_SFX, value)
		setting_changed.emit(KEY_SFX, value)

var haptics_on: bool:
	get:
		return bool(SaveManager.get_value(KEY_HAPTICS, true))
	set(value):
		SaveManager.set_value(KEY_HAPTICS, value)
		setting_changed.emit(KEY_HAPTICS, value)
