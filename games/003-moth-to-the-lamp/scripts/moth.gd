class_name Moth
extends Node2D
## Mothias. Fixed height on screen; game.gd drives x velocity. Greybox is a
## fuzzy blob with flapping wings; the art pass swaps in a sticker texture.

const RADIUS: float = 42.0
const BODY_COLOR: Color = Color(0.78, 0.72, 0.92)
const WING_COLOR: Color = Color(0.92, 0.88, 1.0, 0.85)
const FLAP_HZ: float = 9.0

## Set by the art pass; null = greybox.
static var texture: Texture2D = null

var invincible: bool = false
var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if invincible and fmod(_time, 0.2) < 0.1:
		return
	if texture != null:
		var side := RADIUS * 3.4
		draw_texture_rect(texture, Rect2(Vector2(-side / 2.0, -side / 2.0),
			Vector2(side, side)), false)
		return
	var flap := sin(_time * TAU * FLAP_HZ) * 0.5 + 0.5
	var wing_y := -10.0 - flap * 26.0
	draw_circle(Vector2(-RADIUS * 0.9, wing_y), RADIUS * 0.72, WING_COLOR)
	draw_circle(Vector2(RADIUS * 0.9, wing_y), RADIUS * 0.72, WING_COLOR)
	draw_circle(Vector2.ZERO, RADIUS, BODY_COLOR)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, BODY_COLOR.darkened(0.4), 5.0, true)
	for ex in [-14.0, 14.0]:
		draw_circle(Vector2(ex, -10.0), 9.0, Color.WHITE)
		draw_circle(Vector2(ex, -8.0), 4.5, Color(0.1, 0.1, 0.15))
	draw_line(Vector2(-10, -RADIUS), Vector2(-20, -RADIUS - 22), BODY_COLOR.darkened(0.4), 4.0)
	draw_line(Vector2(10, -RADIUS), Vector2(20, -RADIUS - 22), BODY_COLOR.darkened(0.4), 4.0)
