extends Node2D
## Template entry scene. Replace with the game's real main scene.
## Greybox first: shapes only, until the core loop is fun on a phone.

func _ready() -> void:
	Analytics.log_event("app_open")
