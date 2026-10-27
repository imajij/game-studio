extends CanvasLayer
## FPS + memory readout in the top-left corner. Debug builds only —
## frees itself immediately in release builds.

const UPDATE_SEC: float = 0.5
const LAYER_BELOW_TRANSITION: int = 99
const FONT_SIZE: int = 14
const MARGIN_PX: float = 8.0
const BYTES_PER_MB: float = 1048576.0

var _label: Label

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = LAYER_BELOW_TRANSITION
	_label = Label.new()
	_label.position = Vector2(MARGIN_PX, MARGIN_PX)
	_label.add_theme_color_override("font_color", Color.YELLOW)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	var timer := Timer.new()
	timer.wait_time = UPDATE_SEC
	timer.timeout.connect(_refresh)
	add_child(timer)
	timer.start()
	_refresh()


func _refresh() -> void:
	_label.text = "%d fps | %.1f MB" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.MEMORY_STATIC) / BYTES_PER_MB,
	]
