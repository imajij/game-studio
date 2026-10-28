extends Node3D
## Mob Mela — crowd runner. Drag to steer your mob through multiplier gates
## (×2! +10!) and around the red walls that thin it out; at the finish line
## your mob sumo-shoves the rival mob — bigger crowd wins the mela. Smiling
## blobs only, nobody gets hurt: losers bounce away with a pop.
## Rewarded ad = start with double crowd; interstitial after each result.

enum State { READY, RUNNING, BATTLE, RESULT }

const TRACK_LEN: float = 320.0
const RUN_SPEED: float = 10.0
const STEER_LIMIT: float = 2.9
const VISUAL_CAP: int = 60
const LEVEL_KEY: String = "level"

const SFX_GATE: AudioStream = preload("res://assets/audio/gate.wav")
const SFX_POP: AudioStream = preload("res://assets/audio/pop.wav")
const SFX_WIN: AudioStream = preload("res://assets/audio/win.wav")
const SFX_LOSE: AudioStream = preload("res://assets/audio/lose.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.READY
var level: int = 1
var count: int = 10
var enemy_count: int = 0
var center: Node3D = null
var blobs: Array = []
var cam: Camera3D = null
var gates: Array = []   # {z, x, op, value, node, used}
var walls: Array = []   # {z, x, w, node, used}
var enemy_root: Node3D = null
var enemy_blobs: Array = []
var battle_tick: float = 0.0
var doubled: bool = false
var restarting: bool = false
var drag_x: float = 0.0
var touching: bool = false
var touch_start: Vector2 = Vector2.ZERO
var start_x: float = 0.0

var count_label: Label = null
var level_label: Label = null
var overlay: Dictionary = {}
var start_panel: Control = null

func _ready() -> void:
	randomize()
	level = int(SaveManager.get_value(LEVEL_KEY, 1))
	_build_world()
	_build_ui()
	_build_track()
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	Analytics.log_event("round_start")
	_set_count(10)


func _process(delta: float) -> void:
	match state:
		State.RUNNING:
			_run(delta)
		State.BATTLE:
			_battle(delta)
	count_label.text = "%d" % count
	level_label.text = "MELA %d" % level


func _run(delta: float) -> void:
	center.position.z -= RUN_SPEED * delta
	center.position.x = lerpf(center.position.x, drag_x, 10.0 * delta)
	_layout_blobs(delta)
	cam.position = Vector3(center.position.x * 0.5, 7.5, center.position.z + 10.0)
	cam.look_at(Vector3(center.position.x * 0.5, 0.6, center.position.z - 6.0))
	var pz := center.position.z
	for g: Dictionary in gates:
		if g.used or absf(pz - g.z) > 0.6:
			continue
		# the row is decided by which side the crowd centre is on
		var row: Array = gates.filter(func(o: Dictionary) -> bool: return absf(o.z - g.z) < 1.0)
		var pick: Dictionary = row[0]
		for o: Dictionary in row:
			if absf(o.x - center.position.x) < absf(pick.x - center.position.x):
				pick = o
		for o: Dictionary in row:
			o.used = true
			o.node.visible = o == pick
		var before := count
		match String(pick.op):
			"x": _set_count(count * int(pick.value))
			"+": _set_count(count + int(pick.value))
			"-": _set_count(count - int(pick.value))
		AudioManager.play_sfx(SFX_GATE if count >= before else SFX_POP)
		Haptics.medium()
		Kit.burst(self, Vector3(center.position.x, 1.2, pz), Kit.SUN if count >= before else Kit.RED, 22, 5.0)
	for w: Dictionary in walls:
		if w.used or absf(pz - w.z) > 0.5:
			continue
		if absf(center.position.x - w.x) < w.w / 2.0 + 0.8:
			w.used = true
			_set_count(int(count * 0.7))
			AudioManager.play_sfx(SFX_POP)
			Haptics.heavy()
			Kit.burst(self, Vector3(w.x, 1.0, pz), Kit.RED, 18, 4.0)
	if count <= 0:
		_finish(false, "the mela ate your whole mob!")
		return
	if pz <= -TRACK_LEN:
		_start_battle()


func _layout_blobs(delta: float) -> void:
	for i in blobs.size():
		var node: Node3D = blobs[i]
		var r := 0.42 * sqrt(float(i))
		var a := float(i) * 2.4
		var target := Vector3(cos(a) * r, 0.0, sin(a) * r * 0.7)
		node.position = node.position.lerp(target, 8.0 * delta)
		node.rotation.y = 0.0
		var child := node.get_child(0) as Node3D
		if child != null:
			child.position.y = absf(sin((center.position.z * 1.4) + i)) * 0.12 + 0.3


func _set_count(new_count: int) -> void:
	count = maxi(new_count, 0)
	var visual := mini(count, VISUAL_CAP)
	while blobs.size() < visual:
		var b := Node3D.new()
		var body := Kit.blobby(Kit.CANDY[blobs.size() % Kit.CANDY.size()], 0.2)
		b.add_child(body)
		center.add_child(b)
		blobs.append(b)
	while blobs.size() > visual:
		var dead: Node3D = blobs.pop_back()
		dead.queue_free()


func _start_battle() -> void:
	state = State.BATTLE
	enemy_count = 18 + level * 14
	battle_tick = 0.0
	AudioManager.play_sfx(SFX_GATE)
	# enemy crowd appears ahead
	enemy_root.position = Vector3(0.0, 0.0, center.position.z - 16.0)
	enemy_root.visible = true
	var visual := mini(enemy_count, VISUAL_CAP)
	for i in visual:
		var b := Kit.blobby(Kit.RED, 0.2)
		var r := 0.42 * sqrt(float(i))
		var a := float(i) * 2.4
		b.position = Vector3(cos(a) * r, 0.0, sin(a) * r * 0.7)
		enemy_root.add_child(b)
		enemy_blobs.append(b)


func _battle(delta: float) -> void:
	battle_tick += delta
	# crowds rush each other
	var gap := enemy_root.position.z - center.position.z
	if gap < -3.5:
		center.position.z -= delta * 4.0
		enemy_root.position.z += delta * 4.0
	cam.position = Vector3(6.0, 6.0, center.position.z - 1.5)
	cam.look_at(Vector3(0.0, 0.8, center.position.z - 7.0))
	# shove: both lose blobs, bigger side loses slower
	if battle_tick > 0.5 and fmod(battle_tick, 0.12) < delta:
		var my_rate := 1 if count < enemy_count else (1 if randf() < 0.35 else 0)
		var their_rate := 1 if enemy_count <= count else (1 if randf() < 0.35 else 0)
		_set_count(count - my_rate)
		enemy_count -= their_rate
		if my_rate + their_rate > 0:
			AudioManager.play_sfx(SFX_POP, 0.15)
		var visual := mini(enemy_count, VISUAL_CAP)
		while enemy_blobs.size() > visual:
			var dead: Node3D = enemy_blobs.pop_back()
			Kit.burst(self, dead.global_position + Vector3.UP * 0.4, Kit.RED, 6, 3.0)
			dead.queue_free()
		if count <= 0:
			_finish(false, "their mob out-shoved yours!")
		elif enemy_count <= 0:
			_finish(true, "")


func _finish(won: bool, reason: String) -> void:
	state = State.RESULT
	if won:
		level += 1
		SaveManager.set_value(LEVEL_KEY, level)
		AudioManager.play_sfx(SFX_WIN)
		Haptics.medium()
		for i in 3:
			Kit.burst(self, center.position + Vector3(randf_range(-2, 2), 1.5, randf_range(-2, 2)),
				Kit.CANDY[i], 30, 8.0)
		overlay.title.text = "MELA JEET GAYE!"
		overlay.body.text = "%d blobs survived\nnext mela: tougher rival\n\ntap to continue" % count
	else:
		AudioManager.play_sfx(SFX_LOSE)
		AudioManager.play_sfx(SFX_GAME_OVER)
		Haptics.heavy()
		overlay.title.text = "MOB GONE"
		overlay.body.text = "%s\n\ntap to retry mela %d" % [reason, level]
	Analytics.log_event("game_over", {"won": won, "level": level})
	AdsManager.round_finished()
	overlay.panel.visible = true


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "double" or state != State.READY:
		return
	doubled = true
	_set_count(count * 2)
	Analytics.log_event("double_used")
	Haptics.medium()
	Kit.burst(self, center.position + Vector3.UP, Kit.SUN, 30, 7.0)
	_begin_run()


func _begin_run() -> void:
	start_panel.visible = false
	state = State.RUNNING


func _unhandled_input(event: InputEvent) -> void:
	match state:
		State.READY:
			var t := event as InputEventScreenTouch
			if t != null and t.pressed:
				var dbl: Button = start_panel.get_node_or_null("Double")
				if dbl != null and dbl.visible and dbl.get_global_rect().has_point(t.position):
					return
				AudioManager.play_sfx(SFX_TAP)
				_begin_run()
		State.RUNNING:
			if event is InputEventScreenTouch:
				var touch := event as InputEventScreenTouch
				touching = touch.pressed
				if touch.pressed:
					touch_start = touch.position
					start_x = drag_x
			elif event is InputEventScreenDrag and touching:
				var drag := event as InputEventScreenDrag
				drag_x = clampf(start_x + (drag.position.x - touch_start.x) / 140.0,
					-STEER_LIMIT, STEER_LIMIT)
		State.RESULT:
			var end_touch := event as InputEventScreenTouch
			if end_touch != null and end_touch.pressed and not restarting:
				restarting = true
				if AdsManager.maybe_show_interstitial():
					await AdsManager.interstitial_closed
				get_tree().reload_current_scene()


# --- world ------------------------------------------------------------------

func _build_world() -> void:
	Kit.sky(self, Kit.SKY, Color(1.0, 0.8, 0.55), Color(0.5, 0.75, 0.4))
	cam = Camera3D.new()
	cam.fov = 58.0
	add_child(cam)
	center = Node3D.new()
	add_child(center)
	enemy_root = Node3D.new()
	enemy_root.visible = false
	add_child(enemy_root)


func _build_track() -> void:
	var road := Kit.texbox(Vector3(8.4, 0.4, TRACK_LEN + 60.0), "tex1", Color(0.55, 0.85, 0.5), 8.0)
	road.position = Vector3(0.0, -0.2, -TRACK_LEN / 2.0)
	add_child(road)
	for side: float in [-1.0, 1.0]:
		var edge := Kit.box(Vector3(0.25, 0.45, TRACK_LEN + 60.0), Kit.CREAM)
		edge.position = Vector3(side * 4.2, -0.1, -TRACK_LEN / 2.0)
		add_child(edge)
	# bunting flags along the track — mela vibes
	for i in 40:
		var flag := Kit.cone(0.22, 0.5, Kit.CANDY[i % Kit.CANDY.size()])
		flag.rotation.x = PI
		flag.position = Vector3((-1.0 if i % 2 == 0 else 1.0) * 4.8, 2.2, -8.0 - i * 8.0)
		add_child(flag)
		var pole := Kit.cyl(0.05, 2.6, Kit.CREAM)
		pole.position = Vector3(flag.position.x, 1.3, flag.position.z)
		add_child(pole)
	# gate rows + walls
	var z := -22.0
	while z > -TRACK_LEN + 20.0:
		if randf() < 0.75:
			_gate_row(z)
		else:
			_wall(z)
		z -= randf_range(16.0, 24.0)
	# finish arch
	var arch := Kit.box(Vector3(8.4, 0.6, 0.6), Kit.MAGENTA)
	arch.position = Vector3(0.0, 3.4, -TRACK_LEN)
	add_child(arch)
	for side: float in [-1.0, 1.0]:
		var post := Kit.cyl(0.3, 3.4, Kit.MAGENTA)
		post.position = Vector3(side * 4.0, 1.7, -TRACK_LEN)
		add_child(post)


func _gate_row(z: float) -> void:
	var specs: Array = [["x", 2], ["+", 10], ["+", 25], ["-", 15]]
	specs.shuffle()
	for side in 2:
		var spec: Array = specs[side]
		var x := -1.9 if side == 0 else 1.9
		var good: bool = spec[0] != "-"
		var node := Node3D.new()
		node.position = Vector3(x, 0.0, z)
		var frame := Kit.box(Vector3(3.4, 0.2, 0.2), Kit.MINT if good else Kit.RED)
		frame.position.y = 2.6
		node.add_child(frame)
		for px: float in [-1.6, 1.6]:
			var post := Kit.cyl(0.1, 2.6, Kit.MINT if good else Kit.RED)
			post.position = Vector3(px, 1.3, 0.0)
			node.add_child(post)
		var pane := Kit.box(Vector3(3.2, 2.4, 0.08), Color(
			(Kit.MINT if good else Kit.RED).r, (Kit.MINT if good else Kit.RED).g,
			(Kit.MINT if good else Kit.RED).b, 0.3))
		pane.position.y = 1.3
		node.add_child(pane)
		var text := Label3D.new()
		text.text = "%s%d" % ["×" if spec[0] == "x" else spec[0], spec[1]]
		text.font_size = 220
		text.pixel_size = 0.01
		text.position = Vector3(0.0, 1.4, 0.15)
		text.modulate = Color.WHITE
		text.outline_size = 40
		node.add_child(text)
		add_child(node)
		gates.append({ "z": z, "x": x, "op": spec[0], "value": spec[1], "node": node, "used": false })


func _wall(z: float) -> void:
	var x := randf_range(-2.0, 2.0)
	var w := randf_range(3.0, 4.5)
	var node := Kit.box(Vector3(w, 1.4, 0.5), Kit.RED)
	node.position = Vector3(x, 0.7, z)
	add_child(node)
	var text := Label3D.new()
	text.text = "-30%"
	text.font_size = 160
	text.pixel_size = 0.01
	text.position = Vector3(0.0, 0.2, 0.3)
	text.outline_size = 36
	node.add_child(text)
	walls.append({ "z": z, "x": x, "w": w, "node": node, "used": false })


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	count_label = Kit.label("10", 110, Color.WHITE)
	count_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	count_label.offset_top = 40.0
	count_label.offset_bottom = 170.0
	layer.add_child(count_label)
	level_label = Kit.label("MELA 1", 50, Kit.SUN)
	level_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_top = 170.0
	level_label.offset_bottom = 235.0
	layer.add_child(level_label)
	overlay = Kit.overlay("", Kit.MINT)
	layer.add_child(overlay.panel)
	start_panel = Control.new()
	start_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var hint := Kit.label("drag to steer your mob\ngreen gates grow it, red shrinks it\n\ntap to start", 50)
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 1280.0
	hint.offset_bottom = 1560.0
	start_panel.add_child(hint)
	var dbl := Kit.button("START ×2 CROWD · AD", 46, Kit.PURPLE)
	dbl.name = "Double"
	dbl.position = Vector2(250.0, 1600.0)
	dbl.size = Vector2(580.0, 115.0)
	dbl.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("double"))
	start_panel.add_child(dbl)
	layer.add_child(start_panel)
