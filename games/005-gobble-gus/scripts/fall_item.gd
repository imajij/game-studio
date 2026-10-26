class_name FallItem
extends Node2D
## One falling snack or hazard. Manual motion; game.gd owns speed ramping.

var kind: int = 0
var radius: float = 80.0
var velocity: Vector2 = Vector2.ZERO
var spin: float = 0.0

func setup(new_kind: int, at: Vector2, vel: Vector2) -> void:
	kind = new_kind
	radius = Items.RADII[kind]
	position = at
	velocity = vel
	spin = randf_range(-1.8, 1.8)


func advance(delta: float) -> void:
	position += velocity * delta
	rotation += spin * delta
	queue_redraw()


func _draw() -> void:
	if kind < Items.TEXTURES.size() and Items.TEXTURES[kind] != null:
		var side := radius * 2.3
		draw_texture_rect(Items.TEXTURES[kind],
			Rect2(Vector2(-side / 2.0, -side / 2.0), Vector2(side, side)), false)
		return
	var color := Items.COLORS[kind]
	if Items.IS_GOOD[kind]:
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color.darkened(0.35), 5.0, true)
		for ex in [-radius * 0.3, radius * 0.3]:
			draw_circle(Vector2(ex, -radius * 0.15), radius * 0.15, Color.WHITE)
			draw_circle(Vector2(ex, -radius * 0.1), radius * 0.07, Color(0.1, 0.1, 0.15))
		draw_arc(Vector2(0, radius * 0.25), radius * 0.28, 0.3, PI - 0.3, 14,
			Color(0.1, 0.1, 0.15), 4.0)
	else:
		# Hazards are angular so they read as "nope" at a glance.
		var half := radius * 0.9
		draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), color)
		draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), color.darkened(0.4), false, 6.0)
		if kind == 5:  # Spiky Boi gets spikes
			for i in 8:
				var dir := Vector2.from_angle(TAU * i / 8.0)
				draw_line(dir * half, dir * (half + 26.0), color.darkened(0.3), 6.0)
		for ex in [-radius * 0.3, radius * 0.3]:
			draw_circle(Vector2(ex, -radius * 0.1), radius * 0.14, Color.WHITE)
			draw_circle(Vector2(ex, -radius * 0.1), radius * 0.07, Color(0.6, 0.1, 0.1))
		draw_line(Vector2(-radius * 0.3, radius * 0.4), Vector2(radius * 0.3, radius * 0.35),
			Color(0.1, 0.1, 0.15), 5.0)
