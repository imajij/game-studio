extends CanvasLayer
## Fade-to-black scene changes:
##   SceneTransition.change_to("res://scenes/game.tscn")
## Blocks input during the fade so a mid-transition tap can't double-fire.

signal finished

const FADE_SEC: float = 0.25
const LAYER_ABOVE_EVERYTHING: int = 100

var _rect: ColorRect
var _busy: bool = false

func _ready() -> void:
	layer = LAYER_ABOVE_EVERYTHING
	_rect = ColorRect.new()
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func change_to(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 1.0, FADE_SEC)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
	tween = create_tween()
	tween.tween_property(_rect, "color:a", 0.0, FADE_SEC)
	await tween.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	finished.emit()
