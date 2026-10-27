class_name BazaarCreep
extends Node2D
## One wave creature walking the gali path. Movement lives in game.gd;
## this node knows its stats and look. kind: 0 runner, 1 tank, 2 swarmling,
## 3 boss.

var kind: int = 0
var hp: float = 10.0
var max_hp: float = 10.0
var speed: float = 120.0
var reward: int = 8
var progress: float = 0.0
var slow_until_msec: int = 0
var dead: bool = false

const BODY_COLORS: Array[Color] = [
	Color(0.95, 0.6, 0.3), Color(0.55, 0.45, 0.7),
	Color(0.5, 0.8, 0.5), Color(0.85, 0.3, 0.4),
]
const RADII: Array[float] = [44.0, 64.0, 30.0, 96.0]

func setup(new_kind: int, new_hp: float, new_speed: float, new_reward: int) -> void:
	kind = new_kind
	hp = new_hp
	max_hp = new_hp
	speed = new_speed
	reward = new_reward
	queue_redraw()


func radius() -> float:
	return RADII[kind]


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var body := BODY_COLORS[kind]
	var outline := body.darkened(0.45)
	var r := radius()
	var wob := sin(Time.get_ticks_msec() / 90.0 + float(get_instance_id() % 7)) * 0.08
	draw_set_transform(Vector2.ZERO, wob, Vector2.ONE)
	draw_circle(Vector2.ZERO, r + 5.0, outline)
	draw_circle(Vector2.ZERO, r, body)
	match kind:
		0:  # runner — little legs
			for side in [-1.0, 1.0]:
				draw_line(Vector2(side * r * 0.4, r * 0.8), Vector2(side * r * 0.6, r * 1.3),
					outline, 7.0)
		1:  # tank — pot lid helmet
			draw_arc(Vector2(0.0, -r * 0.7), r * 0.72, PI, TAU, 16, Color(0.7, 0.72, 0.78), 16.0)
		2:  # swarmling — single antenna
			draw_line(Vector2(0.0, -r), Vector2(0.0, -r * 1.7), outline, 5.0)
			draw_circle(Vector2(0.0, -r * 1.8), 8.0, outline)
		3:  # boss — crown
			for i in 3:
				var cx := -r * 0.5 + i * r * 0.5
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx - 18.0, -r * 0.9), Vector2(cx + 18.0, -r * 0.9),
					Vector2(cx, -r * 1.4)]), Color(1.0, 0.85, 0.3))
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(side * r * 0.35, -r * 0.15), r * 0.17, Color.WHITE)
		draw_circle(Vector2(side * r * 0.35 - 3.0, -r * 0.12), r * 0.08, Color(0.1, 0.1, 0.15))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# hp bar
	if hp < max_hp:
		var frac := clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-r, -r - 26.0, r * 2.0, 10.0), Color(0.15, 0.12, 0.15))
		draw_rect(Rect2(-r, -r - 26.0, r * 2.0 * frac, 10.0), Color(0.4, 0.9, 0.4))
	if Time.get_ticks_msec() < slow_until_msec:
		draw_arc(Vector2.ZERO, r + 12.0, 0.0, TAU, 20, Color(0.5, 0.8, 1.0, 0.7), 5.0)
