class_name Hordeling
extends Node2D
## One falling creature to sort. game.gd owns motion and resolution; this
## node knows its type, disguise, and greybox look.

const RADIUS: float = 110.0

var is_ghoul: bool = false
var variant: int = 0
var disguised: bool = false
var resolved: bool = false

func setup(ghoul: bool, new_variant: int, disguise: bool) -> void:
	is_ghoul = ghoul
	variant = new_variant
	disguised = disguise


func _draw() -> void:
	var tex_index := variant if is_ghoul else 3 + variant
	if tex_index < Horde.TEXTURES.size() and Horde.TEXTURES[tex_index] != null:
		var side := RADIUS * 2.4
		draw_texture_rect(Horde.TEXTURES[tex_index],
			Rect2(Vector2(-side / 2.0, -side / 2.0), Vector2(side, side)), false)
		if disguised:
			_draw_disguise()
		return
	var color := Horde.GHOUL_COLORS[variant] if is_ghoul else Horde.BABY_COLORS[variant]
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, color.darkened(0.35), 6.0, true)
	if is_ghoul:
		# Jagged brow + fangs: reads "ghoul" instantly.
		for ex in [-RADIUS * 0.33, RADIUS * 0.33]:
			draw_circle(Vector2(ex, -RADIUS * 0.15), RADIUS * 0.17, Color(0.95, 0.9, 0.5))
			draw_circle(Vector2(ex, -RADIUS * 0.12), RADIUS * 0.08, Color(0.5, 0.1, 0.1))
		draw_line(Vector2(-RADIUS * 0.5, -RADIUS * 0.42), Vector2(-RADIUS * 0.15, -RADIUS * 0.3),
			Color(0.1, 0.1, 0.15), 7.0)
		draw_line(Vector2(RADIUS * 0.5, -RADIUS * 0.42), Vector2(RADIUS * 0.15, -RADIUS * 0.3),
			Color(0.1, 0.1, 0.15), 7.0)
		for fx in [-RADIUS * 0.18, RADIUS * 0.18]:
			draw_colored_polygon(PackedVector2Array([
				Vector2(fx - 12.0, RADIUS * 0.35), Vector2(fx + 12.0, RADIUS * 0.35),
				Vector2(fx, RADIUS * 0.6)]), Color.WHITE)
	else:
		# Big sparkle eyes + blush: maximum baby.
		for ex in [-RADIUS * 0.3, RADIUS * 0.3]:
			draw_circle(Vector2(ex, -RADIUS * 0.1), RADIUS * 0.2, Color.WHITE)
			draw_circle(Vector2(ex, -RADIUS * 0.06), RADIUS * 0.11, Color(0.15, 0.15, 0.25))
			draw_circle(Vector2(ex + 8.0, -RADIUS * 0.12), RADIUS * 0.045, Color.WHITE)
		draw_circle(Vector2(-RADIUS * 0.55, RADIUS * 0.15), RADIUS * 0.1, Color(0.95, 0.6, 0.6, 0.7))
		draw_circle(Vector2(RADIUS * 0.55, RADIUS * 0.15), RADIUS * 0.1, Color(0.95, 0.6, 0.6, 0.7))
		draw_arc(Vector2(0, RADIUS * 0.3), RADIUS * 0.22, 0.3, PI - 0.3, 14,
			Color(0.15, 0.15, 0.25), 6.0)
	if disguised:
		_draw_disguise()


func _draw_disguise() -> void:
	if is_ghoul:
		# A sweet little bow. Do not be fooled.
		var bow_y := -RADIUS * 0.85
		draw_colored_polygon(PackedVector2Array([
			Vector2(-40.0, bow_y - 22.0), Vector2(0.0, bow_y), Vector2(-40.0, bow_y + 22.0)]),
			Color(0.95, 0.4, 0.6))
		draw_colored_polygon(PackedVector2Array([
			Vector2(40.0, bow_y - 22.0), Vector2(0.0, bow_y), Vector2(40.0, bow_y + 22.0)]),
			Color(0.95, 0.4, 0.6))
		draw_circle(Vector2(0.0, bow_y), 12.0, Color(0.8, 0.25, 0.45))
	else:
		# Fake fangs on a baby. The horde plays dirty.
		for fx in [-RADIUS * 0.15, RADIUS * 0.15]:
			draw_colored_polygon(PackedVector2Array([
				Vector2(fx - 10.0, RADIUS * 0.38), Vector2(fx + 10.0, RADIUS * 0.38),
				Vector2(fx, RADIUS * 0.58)]), Color.WHITE)
