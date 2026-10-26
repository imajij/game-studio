class_name Jar
extends Node2D
## Greybox jar: two walls and a floor, static bodies built in code and drawn
## as flat rectangles. game.gd owns the layout numbers and calls build().

const WALL_THICKNESS: float = 24.0
## Glassy jar look over the pastel backdrop.
const WALL_FILL: Color = Color(0.72, 0.84, 0.95, 0.4)
const WALL_EDGE: Color = Color(1.0, 1.0, 1.0, 0.8)
const EDGE_WIDTH: float = 4.0

var left_x: float = 0.0
var right_x: float = 0.0
var top_y: float = 0.0
var floor_y: float = 0.0

## Interior is x in [jar_left, jar_right], floor surface at jar_floor.
func build(jar_left: float, jar_right: float, wall_top: float, jar_floor: float) -> void:
	left_x = jar_left
	right_x = jar_right
	top_y = wall_top
	floor_y = jar_floor
	var height := floor_y - top_y
	_add_wall(Vector2(left_x - WALL_THICKNESS / 2.0, top_y + height / 2.0),
		Vector2(WALL_THICKNESS, height))
	_add_wall(Vector2(right_x + WALL_THICKNESS / 2.0, top_y + height / 2.0),
		Vector2(WALL_THICKNESS, height))
	_add_wall(Vector2((left_x + right_x) / 2.0, floor_y + WALL_THICKNESS / 2.0),
		Vector2(right_x - left_x + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	queue_redraw()


func _add_wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = center
	add_child(body)


func _draw() -> void:
	if right_x <= 0.0:
		return
	var height := floor_y - top_y
	draw_rect(Rect2(left_x - WALL_THICKNESS, top_y, WALL_THICKNESS, height), WALL_FILL)
	draw_rect(Rect2(right_x, top_y, WALL_THICKNESS, height), WALL_FILL)
	draw_rect(
		Rect2(left_x - WALL_THICKNESS, floor_y, right_x - left_x + WALL_THICKNESS * 2.0, WALL_THICKNESS),
		WALL_FILL
	)
	# Bright inner rims make the glass read against the backdrop.
	draw_line(Vector2(left_x, top_y), Vector2(left_x, floor_y), WALL_EDGE, EDGE_WIDTH)
	draw_line(Vector2(right_x, top_y), Vector2(right_x, floor_y), WALL_EDGE, EDGE_WIDTH)
	draw_line(Vector2(left_x, floor_y), Vector2(right_x, floor_y), WALL_EDGE, EDGE_WIDTH)
