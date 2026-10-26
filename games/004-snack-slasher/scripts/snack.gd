class_name Snack
extends Node2D
## One lobbed snack. Manual ballistic motion (no physics engine needed),
## slow spin, shrink-and-fade once sliced.

const GRAVITY: float = 2300.0
const SLICE_FADE_SEC: float = 0.22

var kind: int = 0
var radius: float = 90.0
var velocity: Vector2 = Vector2.ZERO
var spin: float = 0.0
var sliced: bool = false
var _slice_t: float = 0.0

func setup(new_kind: int, at: Vector2, vel: Vector2) -> void:
	kind = new_kind
	radius = Snacks.RADII[kind]
	position = at
	velocity = vel
	spin = randf_range(-2.5, 2.5)


## Returns true when the node should be freed.
func advance(delta: float) -> bool:
	if sliced:
		_slice_t += delta
		scale = Vector2.ONE * maxf(1.0 - _slice_t / SLICE_FADE_SEC, 0.01)
		modulate.a = maxf(1.0 - _slice_t / SLICE_FADE_SEC, 0.0)
		return _slice_t >= SLICE_FADE_SEC
	velocity.y += GRAVITY * delta
	position += velocity * delta
	rotation += spin * delta
	queue_redraw()
	return false


func _draw() -> void:
	if kind < Snacks.TEXTURES.size() and Snacks.TEXTURES[kind] != null:
		var side := radius * 2.3
		draw_texture_rect(Snacks.TEXTURES[kind],
			Rect2(Vector2(-side / 2.0, -side / 2.0), Vector2(side, side)), false)
		return
	var color := Snacks.COLORS[kind]
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, color.darkened(0.35), 6.0, true)
	for ex in [-radius * 0.32, radius * 0.32]:
		draw_circle(Vector2(ex, -radius * 0.15), radius * 0.16, Color.WHITE)
		draw_circle(Vector2(ex, -radius * 0.12), radius * 0.08, Color(0.1, 0.1, 0.15))
	if kind == Snacks.SOAP:
		# Monocle + menace, so he reads as "do not slice".
		draw_arc(Vector2(radius * 0.32, -radius * 0.15), radius * 0.24, 0.0, TAU, 20,
			Color(0.15, 0.15, 0.2), 4.0, true)
		draw_line(Vector2(-radius * 0.35, radius * 0.4), Vector2(radius * 0.35, radius * 0.4),
			Color(0.15, 0.15, 0.2), 5.0)
	else:
		draw_arc(Vector2(0, radius * 0.25), radius * 0.3, 0.3, PI - 0.3, 16,
			Color(0.15, 0.15, 0.2), 5.0)
