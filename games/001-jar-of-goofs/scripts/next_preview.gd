class_name NextPreview
extends Node2D
## Fixed-size preview of the upcoming drop, shown in the top-right UI corner.

const DISPLAY_SIDE: float = 132.0

var tier: int = 1

func set_tier(new_tier: int) -> void:
	tier = new_tier
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(
		Tiers.TEXTURES[tier],
		Rect2(Vector2(-DISPLAY_SIDE / 2.0, -DISPLAY_SIDE / 2.0), Vector2(DISPLAY_SIDE, DISPLAY_SIDE)),
		false
	)
