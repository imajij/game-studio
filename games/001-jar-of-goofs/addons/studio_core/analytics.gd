extends Node
## Minimal local analytics: per-event counters in the save file, printed in
## debug builds. No network, no SDK — swap in a real backend here if ever
## needed so game code never changes.

const COUNT_KEY_PREFIX: String = "analytics.count."

func log_event(event_name: String, props: Dictionary = {}) -> void:
	if OS.is_debug_build():
		print("[analytics] %s %s" % [event_name, props])
	var key := COUNT_KEY_PREFIX + event_name
	SaveManager.set_value(key, int(SaveManager.get_value(key, 0)) + 1)


func event_count(event_name: String) -> int:
	return int(SaveManager.get_value(COUNT_KEY_PREFIX + event_name, 0))
