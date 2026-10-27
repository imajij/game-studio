extends Node
## TEMPORARY store-screenshot runner — copied into a game, never committed.
## Env SHOT_SCRIPT points at a JSON array of events, coords in 1080x1920
## design space: {t, type: press|release|move|tap|shot|quit, x, y, path}.

var _events: Array = []
var _t: float = 0.0
var _scale: Vector2 = Vector2.ONE

func _ready() -> void:
	var overlay := get_node_or_null("/root/DebugOverlay")
	if overlay != null:
		overlay.visible = false
	add_child(load("res://scenes/main.tscn").instantiate())
	var f := FileAccess.open(OS.get_environment("SHOT_SCRIPT"), FileAccess.READ)
	_events = JSON.parse_string(f.get_as_text())
	_scale = Vector2(DisplayServer.window_get_size()) / Vector2(1080.0, 1920.0)

func _process(delta: float) -> void:
	_t += delta
	while not _events.is_empty() and float(_events[0]["t"]) <= _t:
		_do(_events.pop_front())

func _do(e: Dictionary) -> void:
	var pos := Vector2(float(e.get("x", 0.0)), float(e.get("y", 0.0))) * _scale
	match String(e["type"]):
		"press":
			_touch(pos, true)
		"release":
			_touch(pos, false)
		"tap":
			_touch(pos, true)
			_touch(pos, false)
		"move":
			var ev := InputEventScreenDrag.new()
			ev.index = 0
			ev.position = pos
			Input.parse_input_event(ev)
		"shot":
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png(String(e["path"]))
			print("SHOT ", img.get_width(), "x", img.get_height(), " ", e["path"])
		"wave":
			# Snack Slasher only: force an extra lob wave so the air is busy.
			var gw: Node = get_tree().root.find_child("Game", true, false)
			if gw != null and gw.has_method("_spawn_wave"):
				gw.call("_spawn_wave")
		"slash":
			# Snack Slasher only: slice through the real airborne snacks,
			# skipping Sir Soap (kind 5).
			var game: Node = get_tree().root.find_child("Game", true, false)
			var cont: Node = game.get_node_or_null("Snacks") if game != null else null
			if cont != null:
				var pts: Array = []
				for s in cont.get_children():
					var kind_v = s.get("kind")
					var p: Vector2 = s.position
					if kind_v != null and int(kind_v) != 5 and p.y > 250.0 and p.y < 1650.0:
						pts.append(p)
				pts.sort_custom(func(a, b): return a.x < b.x)
				if pts.size() > 3:
					pts = pts.slice(0, 3)
				if not pts.is_empty():
					_touch((pts[0] + Vector2(-150.0, 100.0)) * _scale, true)
					for p2 in pts:
						var ev2 := InputEventScreenDrag.new()
						ev2.index = 0
						ev2.position = p2 * _scale
						Input.parse_input_event(ev2)
					var endp: Vector2 = (pts[pts.size() - 1] + Vector2(150.0, -100.0)) * _scale
					var ev3 := InputEventScreenDrag.new()
					ev3.index = 0
					ev3.position = endp
					Input.parse_input_event(ev3)
					_touch(endp, false)
		"sortswipe":
			# Sort the Horde only: swipe the correct way for the live creature.
			var game2: Node = get_tree().root.find_child("Game", true, false)
			var cur: Object = game2.get("current") if game2 != null else null
			if cur != null and not bool(cur.get("resolved")):
				var dir: float = -1.0 if bool(cur.get("is_ghoul")) else 1.0
				_touch(Vector2(540.0, 1000.0) * _scale, true)
				for dx in [80.0, 180.0, 280.0, 360.0]:
					var ev4 := InputEventScreenDrag.new()
					ev4.index = 0
					ev4.position = Vector2(540.0 + dir * dx, 990.0) * _scale
					Input.parse_input_event(ev4)
				_touch(Vector2(540.0 + dir * 380.0, 990.0) * _scale, false)
		"crane":
			# Stack-a-Freak only: stage the pendulum so it is drifting slowly
			# toward center — a tap exactly 1.0 s later lands on the platform.
			var crane: Node = get_tree().root.find_child("Crane", true, false)
			if crane != null:
				crane.swing_speed = 0.3
				crane._time = PI - 0.47
		"quit":
			get_tree().quit()

func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)
