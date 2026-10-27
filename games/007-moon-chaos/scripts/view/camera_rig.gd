class_name CameraRig
extends Node3D
## Fixed top-down-ish camera: gentle follow, no rotation, no bob, pinch zoom
## between limits. The angle never changes, so the player always reads the
## surface the same way.

const PITCH_DEGREES: float = -62.0
const FOLLOW_SMOOTHING: float = 6.0
const MIN_DISTANCE: float = 8.0
const MAX_DISTANCE: float = 24.0
const ZOOM_SMOOTHING: float = 8.0

var _camera: Camera3D = null
var _distance: float = 11.0
var _target_distance: float = 11.0
## Active touch positions, for pinch detection.
var _touches: Dictionary = {}
var _pinch_reference: float = 0.0


func _ready() -> void:
	rotation_degrees = Vector3(PITCH_DEGREES, 0.0, 0.0)
	_camera = Camera3D.new()
	_camera.fov = 60.0
	# A tall near plane range is pointless here and costs depth precision.
	_camera.near = 0.5
	_camera.far = 200.0
	add_child(_camera)
	_apply_distance()


func snap_to(target: Vector3) -> void:
	global_position = target
	_apply_distance()


func follow(target: Vector3, delta: float) -> void:
	# Exponential smoothing, frame-rate independent.
	var t: float = 1.0 - exp(-FOLLOW_SMOOTHING * delta)
	global_position = global_position.lerp(target, t)
	if not is_equal_approx(_distance, _target_distance):
		var tz: float = 1.0 - exp(-ZOOM_SMOOTHING * delta)
		_distance = lerpf(_distance, _target_distance, tz)
		_apply_distance()


func handle_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = touch.position
		else:
			_touches.erase(touch.index)
		_pinch_reference = _touch_spread()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _touches.has(drag.index):
			_touches[drag.index] = drag.position
		if _touches.size() >= 2:
			var spread: float = _touch_spread()
			if _pinch_reference > 1.0 and spread > 1.0:
				# Fingers apart zooms in, so distance shrinks.
				_set_target(_target_distance * (_pinch_reference / spread))
			_pinch_reference = spread
	elif event is InputEventMouseButton:
		# Desktop convenience while greyboxing.
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_set_target(_target_distance - 1.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_set_target(_target_distance + 1.5)


func _set_target(value: float) -> void:
	_target_distance = clampf(value, MIN_DISTANCE, MAX_DISTANCE)


func _touch_spread() -> float:
	if _touches.size() < 2:
		return 0.0
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _apply_distance() -> void:
	if _camera != null:
		_camera.position = Vector3(0.0, 0.0, _distance)
