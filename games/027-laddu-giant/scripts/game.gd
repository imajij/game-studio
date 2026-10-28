extends Node3D
## Laddu Giant — size-change runner: every laddu makes you BIGGER, every rock
## and squeeze-gate cuts you down, and the wall at the end crumbles exactly as
## deep as you are big. Giant-Rush ad genre, pure growth fantasy.
## Rewarded ad = start double size; interstitial at results.

enum State { READY, RUNNING, SMASH, RESULT }

const RUN_SPEED: float = 9.0
const STEER_LIMIT: float = 2.8
const MIN_SIZE: float = 0.5
const MAX_SIZE: float = 3.2
const LEVEL_KEY: String = "level"
const COINS_KEY: String = "coins"

const SFX_EAT: AudioStream = preload("res://assets/audio/eat.wav")
const SFX_SHRINK: AudioStream = preload("res://assets/audio/shrink.wav")
const SFX_SMASH: AudioStream = preload("res://assets/audio/smash.wav")
const SFX_FINISH: AudioStream = preload("res://assets/audio/finish.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.READY
var level: int = 1
var coins: int = 0
var size: float = 1.0
var course_len: float = 0.0
var doubled: bool = false
var restarting: bool = false
var smash_depth: float = 0.0
var drag_x: float = 0.0
var touching: bool = false
var touch_start: Vector2 = Vector2.ZERO
var start_x: float = 0.0

var player: Node3D = null
var player_body: Node3D = null
var cam: Camera3D = null
var items: Array = []     # {node, z, x, kind:"laddu"|"rock"|"gate", used, gate_size}
var wall_bricks: Array = []
var size_label: Label = null
var level_label: Label = null
var overlay: Dictionary = {}
var start_panel: Control = null

func _ready() -> void:
	randomize()
	level = int(SaveManager.get_value(LEVEL_KEY, 1))
	coins = int(SaveManager.get_value(COINS_KEY, 0))
	_build_world()
	_build_course()
	_build_ui()
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	Analytics.log_event("round_start")


func _process(delta: float) -> void:
	size_label.text = "size ×%.1f" % size
	level_label.text = "GALI %d   ₹%d" % [level, coins]
	if state == State.RUNNING:
		_run(delta)
	elif state == State.SMASH:
		_smash(delta)


func _run(delta: float) -> void:
	player.position.z -= RUN_SPEED * delta
	player.position.x = lerpf(player.position.x, drag_x, 10.0 * delta)
	player_body.scale = player_body.scale.lerp(Vector3.ONE * size, 6.0 * delta)
	cam.position = Vector3(player.position.x * 0.4, 5.0 + size * 2.2, player.position.z + 8.0 + size * 2.0)
	cam.look_at(Vector3(player.position.x * 0.4, size * 0.8, player.position.z - 5.0))
	var pz := player.position.z
	var reach := 0.8 + size * 0.45
	for it: Dictionary in items:
		if it.used or absf(it.z - pz) > 0.8:
			continue
		match String(it.kind):
			"laddu":
				if absf(it.x - player.position.x) < reach:
					it.used = true
					it.node.queue_free()
					size = minf(size + 0.1, MAX_SIZE)
					AudioManager.play_sfx(SFX_EAT, 0.08, 1.0 + size * 0.1)
					Haptics.light()
					Kit.burst(self, Vector3(it.x, size, pz), Kit.ORANGE, 10, 3.5)
					Kit.squash(player_body, 0.18)
			"rock":
				if absf(it.x - player.position.x) < reach * 0.8:
					it.used = true
					it.node.queue_free()
					size = maxf(size - 0.25, MIN_SIZE)
					AudioManager.play_sfx(SFX_SHRINK)
					Haptics.heavy()
					Kit.burst(self, Vector3(it.x, 0.6, pz), Color(0.55, 0.55, 0.6), 16, 4.0)
			"gate":
				it.used = true
				if size > float(it.gate_size):
					var lost: float = size - float(it.gate_size)
					size = float(it.gate_size)
					AudioManager.play_sfx(SFX_SHRINK)
					Haptics.heavy()
					Kit.burst(self, Vector3(player.position.x, size, pz), Kit.PINK, int(lost * 20.0), 5.0)
				else:
					AudioManager.play_sfx(SFX_EAT, 0.0, 1.4)
	if pz <= -course_len:
		state = State.SMASH
		AudioManager.play_sfx(SFX_SMASH)
		Haptics.heavy()
		smash_depth = size * 6.0


func _smash(delta: float) -> void:
	player.position.z -= RUN_SPEED * 1.3 * delta
	cam.position = Vector3(player.position.x * 0.4, 5.0 + size * 2.2, player.position.z + 9.0 + size * 2.0)
	cam.look_at(Vector3(0.0, size * 0.8, player.position.z - 5.0))
	smash_depth -= RUN_SPEED * 1.3 * delta
	var pz := player.position.z
	for brick: Node3D in wall_bricks.duplicate():
		if absf(brick.position.z - pz) < 1.0:
			wall_bricks.erase(brick)
			AudioManager.play_sfx(SFX_SMASH, 0.2, randf_range(0.9, 1.3))
			Kit.burst(self, brick.position, brick.get_meta("color"), 10, 6.0)
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(brick, "position",
				brick.position + Vector3(randf_range(-4, 4), randf_range(2, 5), -randf_range(2, 5)), 0.6)
			tween.tween_property(brick, "rotation",
				Vector3(randf() * 6, randf() * 6, randf() * 6), 0.6)
			tween.chain().tween_callback(brick.queue_free)
	if smash_depth <= 0.0:
		var pay := int(size * 10.0) * 3
		coins += pay
		level += 1
		SaveManager.set_value(LEVEL_KEY, level)
		SaveManager.set_value(COINS_KEY, coins)
		state = State.RESULT
		AudioManager.play_sfx(SFX_FINISH)
		for i in 3:
			Kit.burst(self, player.position + Vector3(0, 2, -2), Kit.CANDY[i], 30, 9.0)
		Analytics.log_event("game_over", {"level": level - 1, "size": size})
		AdsManager.round_finished()
		overlay.title.text = "WALL TODA!"
		overlay.body.text = "final size ×%.1f = ₹%d\nbank ₹%d\n\ntap for gali %d" \
			% [size, pay, coins, level]
		overlay.panel.visible = true


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "double" or state != State.READY:
		return
	doubled = true
	size = 2.0
	Analytics.log_event("double_used")
	Haptics.medium()
	Kit.burst(self, player.position + Vector3.UP, Kit.SUN, 26, 6.0)
	_begin()


func _begin() -> void:
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
				_begin()
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
		_:
			pass


# --- world ------------------------------------------------------------------

func _build_world() -> void:
	Kit.sky(self, Color(1.0, 0.62, 0.3), Color(1.0, 0.88, 0.55), Color(0.8, 0.5, 0.35))
	cam = Camera3D.new()
	cam.fov = 58.0
	add_child(cam)
	player = Node3D.new()
	player_body = Kit.blobby(Kit.ORANGE, 0.34)
	player.add_child(player_body)
	add_child(player)


func _build_course() -> void:
	course_len = 80.0 + level * 12.0
	var road := Kit.texbox(Vector3(7.6, 0.4, course_len + 60.0), "tex1", Color(0.85, 0.62, 0.35), 6.0)
	road.position = Vector3(0.0, -0.2, -course_len / 2.0)
	add_child(road)
	for side: float in [-1.0, 1.0]:
		var kerb := Kit.box(Vector3(0.3, 0.5, course_len + 60.0), Kit.PINK)
		kerb.position = Vector3(side * 3.9, 0.0, -course_len / 2.0)
		add_child(kerb)
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 4242
	var z := -8.0
	while z > -course_len + 10.0:
		var roll := rng.randf()
		if roll < 0.5:
			for i in rng.randi_range(2, 4):
				var x := rng.randf_range(-2.8, 2.8)
				var laddu := Kit.sphere(0.32, Kit.ORANGE, true)
				var dot := Kit.sphere(0.1, Kit.SUN)
				dot.position.y = 0.28
				laddu.add_child(dot)
				laddu.position = Vector3(x, 0.4, z - i * 1.3)
				add_child(laddu)
				items.append({ "node": laddu, "z": z - i * 1.3, "x": x, "kind": "laddu", "used": false, "gate_size": 0.0 })
		elif roll < 0.82:
			var x := rng.randf_range(-2.8, 2.8)
			var rock := Kit.box(Vector3(1.0, 0.9, 0.9), Color(0.55, 0.55, 0.6), true)
			rock.rotation.y = rng.randf()
			rock.position = Vector3(x, 0.45, z)
			add_child(rock)
			items.append({ "node": rock, "z": z, "x": x, "kind": "rock", "used": false, "gate_size": 0.0 })
		else:
			var gate_size := rng.randf_range(0.8, 1.8)
			var frame := Node3D.new()
			frame.position = Vector3(0.0, 0.0, z)
			var top := Kit.box(Vector3(7.6, 0.4, 0.4), Kit.MAGENTA)
			top.position.y = gate_size * 1.35
			frame.add_child(top)
			for side: float in [-1.0, 1.0]:
				var post := Kit.cyl(0.18, gate_size * 1.35, Kit.MAGENTA)
				post.position = Vector3(side * 3.7, gate_size * 0.675, 0.0)
				frame.add_child(post)
			var text := Label3D.new()
			text.text = "fit ×%.1f" % gate_size
			text.font_size = 140
			text.pixel_size = 0.012
			text.position = Vector3(0.0, gate_size * 1.35 + 0.6, 0.0)
			text.outline_size = 32
			frame.add_child(text)
			add_child(frame)
			items.append({ "node": frame, "z": z, "x": 0.0, "kind": "gate", "used": false, "gate_size": gate_size })
		z -= rng.randf_range(6.0, 10.0)
	# the wall: colorful brick stack spanning the road, deep
	for layer_i in 14:
		for col in 5:
			for row in 4:
				var brick := Kit.box(Vector3(1.45, 0.75, 1.0), Kit.CANDY[(col + row + layer_i) % Kit.CANDY.size()], true)
				brick.position = Vector3(-2.9 + col * 1.5, 0.4 + row * 0.78, -course_len - 1.0 - layer_i * 1.05)
				brick.set_meta("color", Kit.CANDY[(col + row + layer_i) % Kit.CANDY.size()])
				add_child(brick)
				wall_bricks.append(brick)


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	size_label = Kit.label("size ×1.0", 80, Color.WHITE)
	size_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	size_label.offset_top = 44.0
	size_label.offset_bottom = 146.0
	layer.add_child(size_label)
	level_label = Kit.label("GALI 1", 48, Kit.SUN)
	level_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_top = 150.0
	level_label.offset_bottom = 215.0
	layer.add_child(level_label)
	overlay = Kit.overlay("", Kit.ORANGE)
	layer.add_child(overlay.panel)
	start_panel = Control.new()
	start_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var hint := Kit.label("laddus = BIG · rocks = small\nsqueeze the gates, SMASH the wall\n\ntap to run", 48)
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 1280.0
	hint.offset_bottom = 1560.0
	start_panel.add_child(hint)
	var dbl := Kit.button("START ×2 SIZE · AD", 46, Kit.PURPLE)
	dbl.name = "Double"
	dbl.position = Vector2(250.0, 1600.0)
	dbl.size = Vector2(580.0, 115.0)
	dbl.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("double"))
	start_panel.add_child(dbl)
	layer.add_child(start_panel)
