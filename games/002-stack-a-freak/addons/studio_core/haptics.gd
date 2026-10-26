extends Node
## One-line haptic feedback, gated by the player's setting.
## No-op on desktop and web, so calls are always safe.

const LIGHT_MS: int = 15
const MEDIUM_MS: int = 30
const HEAVY_MS: int = 60

func light() -> void:
	_vibrate(LIGHT_MS)


func medium() -> void:
	_vibrate(MEDIUM_MS)


func heavy() -> void:
	_vibrate(HEAVY_MS)


func _vibrate(ms: int) -> void:
	if not Settings.haptics_on:
		return
	if not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(ms)
