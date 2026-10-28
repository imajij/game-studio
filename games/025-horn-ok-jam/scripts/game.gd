extends Node3D
## Horn OK Jam — a gridlocked bazaar lot. Tap a vehicle and it drives straight
## in the direction it faces: clear path = out of the lot, blocked = BUMP,
## honk, wasted tap. Empty the lot before your taps run out. Levels are
## generated then simulation-verified solvable.
## Rewarded ad = +3 taps; interstitial at result screens.

enum State { PLAYING, RESULT }

const GRID: int = 7
const CELL: float = 1.25
const LEVEL_KEY: String = "level"

const SFX_VROOM: AudioStream = preload("res://assets/audio/vroom.wav")
const SFX_HONK: AudioStream = preload("res://assets/audio/honk.wav")
const SFX_WIN: AudioStream = preload("res://assets/audio/win.wav")
const SFX_LOSE: AudioStream = preload("res://assets/audio/lose.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var level: int = 1
var taps_left: int = 0
var vehicles: Array = []  # {node, cells:[Vector2i], dir:Vector2i, gone, moving}
var won_level: bool = false
var extra_used: bool = false
var restarting: bool = false

var cam: Camera3D = null
var level_label: Label = null
var taps_label: Label = null
var overlay: Dictionary = {}

func _ready() -> void:
	randomize()
	level = int(SaveManager.get_value(LEVEL_KEY, 1))
	Kit.sky(self, Kit.SKY, Color(1.0, 0.82, 0.6), Color(0.75, 0.6, 0.5))
	cam = Camera3D.new()
	cam.position = Vector3(0.0, 13.5, 6.0)
	cam.fov = 50.0
	add_child(cam)
	cam.look_at(Vector3(0.0, 0.0, -0.5))
	_build_lot()
	_build_level()
	_build_ui()
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	Analytics.log_event("round_start")
	_refresh()


func cell_pos(c: Vector2i) -> Vector3:
	return Vector3((c.x - GRID / 2.0 + 0.5) * CELL, 0.0, (c.y - GRID / 2.0 + 0.5) * CELL)


func _occupied(skip: Dictionary) -> Dictionary:
	var occ := {}
	for v: Dictionary in vehicles:
		if v.gone or v == skip:
			continue
		for c: Vector2i in v.cells:
			occ[c] = true
	return occ


func _path_clear(v: Dictionary) -> bool:
	var occ := _occupied(v)
	var front: Vector2i = v.cells[0]
	for c: Vector2i in v.cells:
		var d1: Vector2i = v.dir
		if (c - front).sign() == d1 or c == front:
			if (c - front).length() >= 0.0:
				front = c if (c.x * d1.x + c.y * d1.y) > (front.x * d1.x + front.y * d1.y) else front
	var probe: Vector2i = front + v.dir
	while probe.x >= 0 and probe.x < GRID and probe.y >= 0 and probe.y < GRID:
		if occ.has(probe):
			return false
		probe += v.dir
	return true


func _unhandled_input(event: InputEvent) -> void:
	if state == State.RESULT:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			var extra: Button = overlay.panel.get_node_or_null("Extra")
			if extra != null and extra.visible and extra.get_global_rect().has_point(t.position):
				return
			_next(won_level)
		return
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed or taps_left <= 0:
		return
	var pick: Dictionary = {}
	var best_d := 110.0
	for v: Dictionary in vehicles:
		if v.gone or v.moving:
			continue
		var node: Node3D = v.node
		var screen := cam.unproject_position(node.global_position + Vector3.UP * 0.4)
		var d := screen.distance_to(touch.position)
		if d < best_d:
			best_d = d
			pick = v
	if pick.is_empty():
		return
	taps_left -= 1
	_drive(pick)
	_refresh()


func _drive(v: Dictionary) -> void:
	var node: Node3D = v.node
	if _path_clear(v):
		v.gone = true
		v.moving = true
		AudioManager.play_sfx(SFX_VROOM, 0.1)
		Haptics.light()
		var dir3 := Vector3(v.dir.x, 0.0, v.dir.y)
		Kit.burst(self, node.position - dir3 * 0.8 + Vector3.UP * 0.2, Kit.CREAM, 10, 2.5)
		var tween := create_tween()
		tween.tween_property(node, "position", node.position + dir3 * (GRID + 4) * CELL, 1.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			node.queue_free()
			_check_end())
	else:
		v.moving = true
		AudioManager.play_sfx(SFX_HONK)
		Haptics.heavy()
		var dir3 := Vector3(v.dir.x, 0.0, v.dir.y)
		var start := node.position
		var tween := create_tween()
		tween.tween_property(node, "position", start + dir3 * 0.35, 0.12)
		tween.tween_property(node, "position", start, 0.18).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_callback(func() -> void:
			v.moving = false
			_check_end())


func _check_end() -> void:
	if state != State.PLAYING:
		return
	if vehicles.all(func(v: Dictionary) -> bool: return v.gone):
		_finish(true)
	elif taps_left <= 0:
		_finish(false)


func _finish(won: bool) -> void:
	state = State.RESULT
	won_level = won
	AudioManager.play_sfx(SFX_WIN if won else SFX_LOSE)
	Haptics.medium() if won else Haptics.heavy()
	if won:
		for i in 3:
			Kit.burst(self, Vector3(randf_range(-3, 3), 1.0, randf_range(-3, 3)), Kit.CANDY[i], 28, 7.0)
		overlay.title.text = "LOT KHALI!"
		overlay.body.text = "jam %d cleared with %d taps spare\n\ntap for jam %d" \
			% [level, taps_left, level + 1]
	else:
		overlay.title.text = "STILL JAMMED"
		overlay.body.text = "out of taps!\n\ntap to retry jam %d" % level
	Analytics.log_event("game_over", {"won": won, "level": level})
	AdsManager.round_finished()
	overlay.panel.visible = true
	var extra: Button = overlay.panel.get_node_or_null("Extra")
	if extra != null:
		extra.visible = not won and not extra_used and AdsManager.is_rewarded_ready()


func _next(advance: bool) -> void:
	if restarting:
		return
	restarting = true
	if advance:
		level += 1
		SaveManager.set_value(LEVEL_KEY, level)
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "taps" or state != State.RESULT:
		return
	extra_used = true
	taps_left += 3
	state = State.PLAYING
	overlay.panel.visible = false
	Analytics.log_event("extra_taps")
	Haptics.medium()
	_refresh()


# --- lot + level ------------------------------------------------------------

func _build_lot() -> void:
	var span := GRID * CELL
	var ground := Kit.texbox(Vector3(span + 4.0, 0.4, span + 4.0), "tex1", Color(0.45, 0.45, 0.5), 1.0)
	ground.position.y = -0.2
	add_child(ground)
	for i in GRID + 1:
		var o := (i - GRID / 2.0) * CELL
		var l1 := Kit.box(Vector3(0.05, 0.02, span), Color(1, 1, 1, 0.35))
		l1.position = Vector3(o, 0.02, 0.0)
		add_child(l1)
		var l2 := Kit.box(Vector3(span, 0.02, 0.05), Color(1, 1, 1, 0.35))
		l2.position = Vector3(0.0, 0.02, o)
		add_child(l2)
	# bazaar dressing around the lot
	for i in 8:
		var stall := Node3D.new()
		var a := i * TAU / 8.0
		stall.position = Vector3(cos(a) * (span / 2.0 + 2.2), 0.0, sin(a) * (span / 2.0 + 2.2))
		var counter := Kit.box(Vector3(1.2, 0.7, 0.8), Kit.CANDY[i % Kit.CANDY.size()], true)
		counter.position.y = 0.35
		stall.add_child(counter)
		var roof := Kit.cone(0.9, 0.6, Kit.CANDY[(i + 3) % Kit.CANDY.size()])
		roof.position.y = 1.3
		stall.add_child(roof)
		stall.look_at_from_position(stall.position, Vector3(0, 0, 0), Vector3.UP)
		add_child(stall)


func _build_level() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 60013
	var count := mini(5 + level, 12)
	for attempt in 60:
		vehicles.clear()
		var occ := {}
		var specs: Array = []
		var guard := 0
		while specs.size() < count and guard < 400:
			guard += 1
			var length := 2 if rng.randf() < 0.72 else 3
			var horizontal := rng.randf() < 0.5
			var dir := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
			if rng.randf() < 0.5:
				dir = -dir
			var ox := rng.randi_range(0, GRID - (length if horizontal else 1))
			var oy := rng.randi_range(0, GRID - (1 if horizontal else length))
			var cells: Array = []
			var ok := true
			for k in length:
				var c := Vector2i(ox + (k if horizontal else 0), oy + (0 if horizontal else k))
				if occ.has(c):
					ok = false
					break
				cells.append(c)
			if not ok:
				continue
			for c: Vector2i in cells:
				occ[c] = true
			specs.append({ "cells": cells, "dir": dir, "gone": false, "moving": false })
		if specs.size() < count:
			continue
		if _solvable(specs):
			for s: Dictionary in specs:
				vehicles.append(s)
			break
	taps_left = vehicles.size() + 2 + mini(level / 3, 3)
	for v: Dictionary in vehicles:
		v["node"] = _make_vehicle(v)


func _solvable(specs: Array) -> bool:
	var gone := {}
	var progress := true
	while progress:
		progress = false
		for s: Dictionary in specs:
			if gone.has(s):
				continue
			# clear-path check against remaining
			var front: Vector2i = s.cells[0]
			for c: Vector2i in s.cells:
				if (c.x * s.dir.x + c.y * s.dir.y) > (front.x * s.dir.x + front.y * s.dir.y):
					front = c
			var probe: Vector2i = front + s.dir
			var blocked := false
			while probe.x >= 0 and probe.x < GRID and probe.y >= 0 and probe.y < GRID:
				for o: Dictionary in specs:
					if o != s and not gone.has(o) and o.cells.has(probe):
						blocked = true
						break
				if blocked:
					break
				probe += s.dir
			if not blocked:
				gone[s] = true
				progress = true
	return gone.size() == specs.size()


func _make_vehicle(v: Dictionary) -> Node3D:
	var root := Node3D.new()
	var mid := Vector3.ZERO
	for c: Vector2i in v.cells:
		mid += cell_pos(c)
	mid /= v.cells.size()
	root.position = mid
	var horizontal: bool = v.dir.y == 0
	var length: float = v.cells.size() * CELL * 0.88
	var size := Vector3(length, 0.7, CELL * 0.72) if horizontal else Vector3(CELL * 0.72, 0.7, length)
	var color := Kit.CANDY[randi() % Kit.CANDY.size()]
	var body := Kit.box(size, color, true)
	body.position.y = 0.5
	root.add_child(body)
	var cab := Kit.box(size * Vector3(0.4, 0.8, 0.9) if horizontal else size * Vector3(0.9, 0.8, 0.4),
		color.lightened(0.25), true)
	cab.position = Vector3(v.dir.x * length * 0.22, 0.95, v.dir.y * length * 0.22)
	root.add_child(cab)
	# windshield eyes face the drive direction
	for side: float in [-0.18, 0.18]:
		var eye := Kit.sphere(0.09, Color.WHITE)
		var off := Vector3(v.dir.x, 0.0, v.dir.y) * (length * 0.34)
		eye.position = off + Vector3(side if not horizontal else 0.0, 1.0,
			side if horizontal else 0.0)
		root.add_child(eye)
	add_child(root)
	return root


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	level_label = Kit.label("JAM 1", 84, Kit.ORANGE)
	level_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_top = 44.0
	level_label.offset_bottom = 150.0
	layer.add_child(level_label)
	taps_label = Kit.label("", 54, Color.WHITE)
	taps_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	taps_label.offset_top = 152.0
	taps_label.offset_bottom = 225.0
	layer.add_child(taps_label)
	var hint := Kit.label("tap a vehicle — it drives the way it faces", 38, Color(1, 1, 1, 0.8))
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 1760.0
	hint.offset_bottom = 1820.0
	layer.add_child(hint)
	overlay = Kit.overlay("", Kit.MINT)
	var extra := Kit.button("+3 TAPS · AD", 46, Kit.PURPLE)
	extra.name = "Extra"
	extra.position = Vector2(300.0, 1190.0)
	extra.size = Vector2(480.0, 110.0)
	extra.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("taps"))
	overlay.panel.add_child(extra)
	layer.add_child(overlay.panel)


func _refresh() -> void:
	level_label.text = "JAM %d" % level
	taps_label.text = "taps %d" % taps_left
