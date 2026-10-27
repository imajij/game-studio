class_name BazaarTower
extends Node2D
## One defense unit on a build spot. Firing logic lives in game.gd.
## type: 0 Chai Cannon (single), 1 Pakora Mortar (splash), 2 Fan Blower (slow).

const NAMES: Array[String] = ["Chai Cannon", "Pakora Mortar", "Fan Blower"]
const COSTS: Array[int] = [100, 160, 140]
const BASE_DAMAGE: Array[float] = [6.0, 9.0, 3.0]
const BASE_RANGE: Array[float] = [330.0, 300.0, 280.0]
const BASE_COOLDOWN: Array[float] = [0.55, 1.5, 0.35]
const SPLASH_RADIUS: float = 130.0
const SLOW_MSEC: int = 1400
const MAX_LEVEL: int = 3
const COLORS: Array[Color] = [
	Color(0.75, 0.5, 0.3), Color(0.9, 0.7, 0.25), Color(0.4, 0.75, 0.8),
]

var type: int = 0
var level: int = 1
var cooldown_left: float = 0.0
var selected: bool = false

func setup(new_type: int) -> void:
	type = new_type
	queue_redraw()


func damage() -> float:
	return BASE_DAMAGE[type] * pow(1.7, level - 1)


func attack_range() -> float:
	return BASE_RANGE[type] + (level - 1) * 40.0

func cooldown() -> float:
	return BASE_COOLDOWN[type] * pow(0.88, level - 1)


func upgrade_cost() -> int:
	return int(COSTS[type] * pow(1.8, level))


func _draw() -> void:
	var body := COLORS[type]
	var outline := body.darkened(0.45)
	if selected:
		draw_circle(Vector2.ZERO, attack_range(), Color(1.0, 1.0, 1.0, 0.07))
		draw_arc(Vector2.ZERO, attack_range(), 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.3), 4.0)
	var evolved := level >= MAX_LEVEL
	# base
	draw_circle(Vector2.ZERO, 62.0, outline)
	draw_circle(Vector2.ZERO, 54.0, body if not evolved else body.lightened(0.2))
	match type:
		0:  # chai cannon — kettle spout
			draw_line(Vector2(30.0, -20.0), Vector2(74.0, -44.0), outline, 16.0)
			draw_arc(Vector2(-30.0, 0.0), 26.0, PI * 0.5, PI * 1.5, 10, outline, 10.0)
		1:  # pakora mortar — kadhai bowl
			draw_arc(Vector2(0.0, -8.0), 40.0, 0.0, PI, 14, Color(0.3, 0.25, 0.2), 14.0)
			draw_circle(Vector2(0.0, -26.0), 14.0, Color(0.85, 0.6, 0.2))
		2:  # fan blower — three blades
			var spin := Time.get_ticks_msec() / 120.0
			for i in 3:
				var a := spin + i * TAU / 3.0
				draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * 42.0, Color(0.9, 0.95, 1.0), 12.0)
			draw_circle(Vector2.ZERO, 12.0, outline)
	if evolved:
		for i in 4:
			var a := i * TAU / 4.0 + PI / 4.0
			var p := Vector2(cos(a), sin(a)) * 76.0
			draw_line(p * 0.86, p, Color(1.0, 0.9, 0.4), 6.0)
	# level pips
	for i in level:
		draw_circle(Vector2(-20.0 + i * 20.0, 76.0), 7.0, Color(1.0, 0.9, 0.4))


func _process(_delta: float) -> void:
	if type == 2 or selected:
		queue_redraw()
