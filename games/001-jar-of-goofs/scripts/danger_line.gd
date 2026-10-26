class_name DangerLine
extends Node2D
## Dashed line creatures must stay below. Pulses red while anything settled
## sits above it (the 2-second countdown to game over is running).

const IDLE_COLOR: Color = Color(0.4, 0.3, 0.5, 0.4)
const ARMED_COLOR: Color = Color(0.95, 0.25, 0.2)
const LINE_WIDTH: float = 6.0
const DASH_LENGTH: float = 24.0
const PULSE_HZ: float = 3.0

var armed: bool = false:
	set(value):
		armed = value
		queue_redraw()
var x_from: float = 0.0
var x_to: float = 0.0

func build(from_x: float, to_x: float) -> void:
	x_from = from_x
	x_to = to_x
	queue_redraw()


func _process(_delta: float) -> void:
	if armed:
		queue_redraw()


func _draw() -> void:
	var color := IDLE_COLOR
	if armed:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * PULSE_HZ)
		color = Color(ARMED_COLOR.r, ARMED_COLOR.g, ARMED_COLOR.b, 0.4 + 0.6 * pulse)
	draw_dashed_line(Vector2(x_from, 0.0), Vector2(x_to, 0.0), color, LINE_WIDTH, DASH_LENGTH)
