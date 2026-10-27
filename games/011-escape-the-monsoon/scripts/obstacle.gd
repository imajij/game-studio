class_name MonsoonObstacle
extends Node2D
## One scrolling hazard or pickup. Themes: 0 flood, 1 aunty stampede, 2 baraat.
## kind: 0 solid (dodge), 1 low (jumpable), 2 umbrella pickup.

var theme_id: int = 0
var kind: int = 0
var done: bool = false

func setup(new_theme: int, new_kind: int) -> void:
	theme_id = new_theme
	kind = new_kind
	queue_redraw()


func _draw() -> void:
	if kind == 2:
		# umbrella pickup
		draw_arc(Vector2(0, -8), 56.0, PI, TAU, 20, Color(0.95, 0.45, 0.55), 16.0)
		draw_line(Vector2(0, -8), Vector2(0, 52), Color(0.45, 0.3, 0.25), 8.0)
		draw_circle(Vector2(0, -8), 10.0, Color(0.95, 0.45, 0.55))
		return
	match theme_id:
		0:  # flood
			if kind == 0:  # drum barrel
				draw_rect(Rect2(-62, -78, 124, 156), Color(0.35, 0.45, 0.75))
				draw_rect(Rect2(-62, -78, 124, 156), Color(0.2, 0.26, 0.45), false, 8.0)
				draw_line(Vector2(-62, -26), Vector2(62, -26), Color(0.2, 0.26, 0.45), 8.0)
				draw_line(Vector2(-62, 26), Vector2(62, 26), Color(0.2, 0.26, 0.45), 8.0)
			else:  # puddle (jump it)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
				draw_circle(Vector2.ZERO, 95.0, Color(0.30, 0.55, 0.80, 0.85))
				draw_circle(Vector2(-20, -16), 26.0, Color(0.55, 0.75, 0.95, 0.7))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		1:  # aunty stampede
			if kind == 0:  # aunty (solid)
				draw_circle(Vector2(0, 10), 78.0, Color(0.85, 0.45, 0.60))
				draw_circle(Vector2(0, -62), 44.0, Color(0.90, 0.72, 0.55))
				draw_arc(Vector2(0, -78), 40.0, PI, TAU, 16, Color(0.25, 0.22, 0.25), 18.0)
				for side in [-1.0, 1.0]:
					draw_circle(Vector2(side * 16.0, -66.0), 7.0, Color(0.15, 0.12, 0.15))
				draw_line(Vector2(-14, -48), Vector2(14, -48), Color(0.5, 0.25, 0.3), 5.0)
			else:  # flying chappal (jump it)
				draw_set_transform(Vector2.ZERO, -0.4, Vector2.ONE)
				draw_rect(Rect2(-70, -30, 140, 60), Color(0.65, 0.45, 0.3))
				draw_rect(Rect2(-70, -30, 140, 60), Color(0.4, 0.28, 0.2), false, 7.0)
				draw_line(Vector2(-30, -30), Vector2(10, 30), Color(0.4, 0.28, 0.2), 10.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		2:  # baraat
			if kind == 0:  # dhol drummer (solid)
				draw_circle(Vector2(0, -40), 46.0, Color(0.9, 0.75, 0.5))
				draw_rect(Rect2(-70, -10, 140, 95), Color(0.85, 0.3, 0.3))
				draw_rect(Rect2(-70, -10, 140, 95), Color(0.5, 0.15, 0.15), false, 8.0)
				draw_circle(Vector2(-70, 38), 30.0, Color(0.95, 0.9, 0.8))
				draw_circle(Vector2(70, 38), 30.0, Color(0.95, 0.9, 0.8))
				draw_rect(Rect2(-30, -92, 60, 26), Color(0.95, 0.65, 0.2))
			else:  # garland rope (jump it)
				for i in 7:
					var x := -84.0 + i * 28.0
					var y := 20.0 - absf(i - 3.0) * 10.0
					var colors: Array[Color] = [Color(0.95, 0.6, 0.2), Color(0.9, 0.3, 0.4),
						Color(0.95, 0.85, 0.3)]
					draw_circle(Vector2(x, y), 20.0, colors[i % 3])
