class_name Joystick
extends Control
## Dynamic virtual joystick: the base appears wherever the thumb lands inside
## this control's area, rather than at a fixed spot a player has to find.
## One-thumb control is the whole point, so the touch area is deliberately
## large and the visuals only appear while it is held.

const MAX_RADIUS: float = 130.0
const KNOB_RADIUS: float = 46.0
const DEAD_ZONE: float = 0.12

var vector: Vector2 = Vector2.ZERO

var _index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func is_active() -> bool:
	return _index != -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _index == -1:
			_index = touch.index
			_origin = touch.position
			_current = touch.position
			accept_event()
		elif not touch.pressed and touch.index == _index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _index:
			_current = drag.position
			accept_event()
	_recompute()


func _release() -> void:
	_index = -1
	vector = Vector2.ZERO
	queue_redraw()


func _recompute() -> void:
	if _index == -1:
		vector = Vector2.ZERO
		return
	var offset: Vector2 = _current - _origin
	var length: float = offset.length()
	if length < MAX_RADIUS * DEAD_ZONE:
		vector = Vector2.ZERO
	elif length > MAX_RADIUS:
		vector = offset / length
	else:
		vector = offset / MAX_RADIUS
	queue_redraw()


func _draw() -> void:
	if _index == -1:
		return
	draw_circle(_origin, MAX_RADIUS, Color(1.0, 1.0, 1.0, 0.07))
	draw_arc(_origin, MAX_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.18), 3.0)
	var knob: Vector2 = _origin + vector * MAX_RADIUS
	draw_circle(knob, KNOB_RADIUS, Color(1.0, 1.0, 1.0, 0.26))
