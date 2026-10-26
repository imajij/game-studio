class_name Crane
extends Node2D
## Swinging pendulum that carries the next freak. Child of the camera so it
## stays glued to the top of the view. game.gd reads holder position/velocity.

const ROPE_LENGTH: float = 330.0
const BASE_SPEED: float = 1.5
const MAX_SPEED: float = 3.0
const MAX_ANGLE: float = 1.05

var swing_speed: float = BASE_SPEED
var holding: bool = false
var freak: int = 0
var _time: float = 0.0
var _prev_holder: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	_time += delta * swing_speed
	var holder := holder_global()
	if delta > 0.0:
		_velocity = (holder - _prev_holder) / delta
	_prev_holder = holder
	queue_redraw()


func angle() -> float:
	return sin(_time) * MAX_ANGLE


func holder_local() -> Vector2:
	return Vector2.from_angle(angle() + PI / 2.0) * ROPE_LENGTH


func holder_global() -> Vector2:
	return global_position + holder_local()


func holder_velocity() -> Vector2:
	return _velocity


func set_difficulty(stacked: int) -> void:
	swing_speed = minf(BASE_SPEED + stacked * 0.05, MAX_SPEED)


func _draw() -> void:
	var tip := holder_local()
	draw_circle(Vector2.ZERO, 14.0, Color(0.25, 0.22, 0.35))
	draw_line(Vector2.ZERO, tip, Color(0.25, 0.22, 0.35), 7.0)
	if not holding:
		return
	var side := Freaks.SIZES[freak]
	var half := side / 2.0
	if freak < Freaks.TEXTURES.size() and Freaks.TEXTURES[freak] != null:
		draw_texture_rect(Freaks.TEXTURES[freak],
			Rect2(tip + Vector2(-half, -half) * 1.08, Vector2(side, side) * 1.08), false)
		return
	var color := Freaks.COLORS[freak]
	var rect := Rect2(tip + Vector2(-half, -half), Vector2(side, side))
	draw_rect(rect, color)
	draw_rect(rect, color.darkened(0.35), false, 6.0)
