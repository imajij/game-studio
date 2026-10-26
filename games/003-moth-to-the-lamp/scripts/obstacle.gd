class_name MothObstacle
extends Node2D
## One scrolling hazard or pickup. game.gd moves everything down; each kind
## adds its own motion. Hit tests are manual (circle vs rect/circle) — no
## physics engine needed at this scale.

enum Kind { FAN, PAW, ORB, SPARKLE }

const FAN_SIZE := Vector2(320.0, 70.0)
const FAN_SWAY_PX: float = 160.0
const PAW_SIZE := Vector2(430.0, 95.0)
const ORB_RADIUS: float = 70.0
const SPARKLE_RADIUS: float = 26.0

## Keyed by Kind; sparkle stays hand-drawn.
static var textures: Array = [
	preload("res://assets/art/characters/fan-bro.png"),
	preload("res://assets/art/characters/pawl.png"),
	preload("res://assets/art/characters/dusty.png"),
	null,
]

var kind: Kind = Kind.ORB
## PAW only: -1 = left wall, 1 = right wall.
var side: int = 1
var base_x: float = 0.0
var _time: float = 0.0

func setup(new_kind: Kind, x: float, y: float) -> void:
	kind = new_kind
	base_x = x
	position = Vector2(x, y)
	_time = randf() * TAU


func advance(delta: float, fall: float) -> void:
	_time += delta
	position.y += fall
	match kind:
		Kind.FAN:
			position.x = base_x + sin(_time * 1.4) * FAN_SWAY_PX
		Kind.PAW:
			var extend := (0.5 + 0.5 * sin(_time * 2.2)) * PAW_SIZE.x
			position.x = (extend / 2.0) if side == -1 else (1080.0 - extend / 2.0)
	queue_redraw()


## Current axis-aligned hitbox half-extents (rect kinds) or radius.
func hits(center: Vector2, radius: float) -> bool:
	match kind:
		Kind.FAN, Kind.PAW:
			var half := (FAN_SIZE if kind == Kind.FAN else _paw_size()) / 2.0
			var diff := center - position
			var clamped := Vector2(clampf(diff.x, -half.x, half.x), clampf(diff.y, -half.y, half.y))
			return diff.distance_to(clamped) < radius
		Kind.ORB:
			return center.distance_to(position) < radius + ORB_RADIUS
		Kind.SPARKLE:
			return center.distance_to(position) < radius + SPARKLE_RADIUS
	return false


func _paw_size() -> Vector2:
	var extend := (0.5 + 0.5 * sin(_time * 2.2)) * PAW_SIZE.x
	return Vector2(maxf(extend, 40.0), PAW_SIZE.y)


func _draw() -> void:
	match kind:
		Kind.FAN:
			var half := FAN_SIZE / 2.0
			draw_rect(Rect2(-half, FAN_SIZE), Color(0.55, 0.6, 0.7, 0.85))
			var blade_angle := _time * 6.0
			for i in 3:
				var dir := Vector2.from_angle(blade_angle + TAU * i / 3.0)
				draw_line(Vector2.ZERO, dir * half.x * 0.85, Color(0.8, 0.85, 0.95), 10.0)
			if textures[Kind.FAN] != null:
				draw_texture_rect(textures[Kind.FAN], Rect2(-85.0, -85.0, 170.0, 170.0), false)
			else:
				draw_circle(Vector2.ZERO, 18.0, Color(0.3, 0.33, 0.42))
		Kind.PAW:
			var size := _paw_size()
			var rect := Rect2(-size / 2.0, size)
			draw_rect(rect, Color(0.95, 0.68, 0.45))
			var tip_x := (size.x / 2.0) * -side
			if textures[Kind.PAW] != null:
				draw_texture_rect(textures[Kind.PAW],
					Rect2(tip_x - 100.0, -100.0, 200.0, 200.0), false)
			else:
				draw_circle(Vector2(tip_x, 0.0), size.y / 2.0, Color(0.95, 0.68, 0.45))
		Kind.ORB:
			if textures[Kind.ORB] != null:
				var s := ORB_RADIUS * 2.3
				draw_texture_rect(textures[Kind.ORB],
					Rect2(Vector2(-s / 2.0, -s / 2.0), Vector2(s, s)), false)
			else:
				draw_circle(Vector2.ZERO, ORB_RADIUS, Color(0.5, 0.42, 0.62, 0.9))
		Kind.SPARKLE:
			var pulse := 0.8 + 0.2 * sin(_time * 8.0)
			draw_circle(Vector2.ZERO, SPARKLE_RADIUS * pulse, Color(1.0, 0.9, 0.45))
			draw_circle(Vector2.ZERO, SPARKLE_RADIUS * 0.45 * pulse, Color(1.0, 1.0, 0.85))
