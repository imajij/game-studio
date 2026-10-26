class_name NextPreview
extends Node2D
## Fixed-size preview of the upcoming drop, shown in the top-right UI corner.

const DISPLAY_RADIUS: float = 52.0
const OUTLINE_WIDTH: float = 4.0

var tier: int = 1

func set_tier(new_tier: int) -> void:
	tier = new_tier
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, DISPLAY_RADIUS, Tiers.COLORS[tier])
	draw_arc(Vector2.ZERO, DISPLAY_RADIUS, 0.0, TAU, 32,
		Tiers.COLORS[tier].darkened(0.4), OUTLINE_WIDTH, true)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-DISPLAY_RADIUS, DISPLAY_RADIUS * 0.33),
		str(tier),
		HORIZONTAL_ALIGNMENT_CENTER,
		DISPLAY_RADIUS * 2.0,
		int(DISPLAY_RADIUS * 0.9),
		Color(1.0, 1.0, 1.0, 0.95)
	)
