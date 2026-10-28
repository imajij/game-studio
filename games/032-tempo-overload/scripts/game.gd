extends Node3D
## Tempo Overload — drive an overloaded tempo down the valley road. The cargo
## stack sways with every swerve and pothole; boxes that sway too far tumble
## off. Deliver what survives — taller stacks pay more, if they survive.
## Rewarded ad = cargo straps (double sway tolerance); interstitial at results.

enum State { READY, DRIVING, RESULT }

const DRIVE_SPEED: float = 9.5
const STEER_LIMIT: float = 2.6
const SWAY_LIMIT: float = 0.85
const LEVEL_KEY: String = "level"
const COINS_KEY: String = "coins"

const SFX_PUTT: AudioStream = preload("res://assets/audio/putt.wav")
const SFX_BUMP: AudioStream = preload("res://assets/audio/bump.wav")
const SFX_DROP: AudioStream = preload("res://assets/audio/drop.wav")
const SFX_DELIVER: AudioStream = preload("res://assets/audio/deliver.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.READY
var level: int = 1
var coins: int = 0
var course_len: float = 0.0
var cargo: Array = []       # {node, sway, vel, lost}
var potholes: Array = []    # {x, z, hit}
var strapped: bool = false
var restarting: bool = false
var putt_cd: float = 0.0
var last_x: float = 0.0
var drag_x: float = 0.0
var touching: bool = false
var touch_start: Vector2 = Vector2.ZERO
var start_x: float = 0.0

var tempo: Node3D = null
var bed: Node3D = null
var cam: Camera3D = null
var cargo_label: Label = null
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


func _alive() -> int:
	return cargo.filter(func(c: Dictionary) -> bool: return not c.lost).size()


func _process(delta: float) -> void:
	cargo_label.text = "cargo %d / %d" % [_alive(), cargo.size()]
	level_label.text = "TRIP %d   ₹%d" % [level, coins]
	if state != State.DRIVING:
		return
	putt_cd -= delta
	if putt_cd <= 0.0:
		putt_cd = 0.6
		AudioManager.play_sfx(SFX_PUTT, 0.2)
	tempo.position.z -= DRIVE_SPEED * delta
	tempo.position.x = lerpf(tempo.position.x, drag_x, 8.0 * delta)
	var steer_impulse := (tempo.position.x - last_x) * 2.4
	last_x = tempo.position.x
	tempo.rotation.z = lerpf(tempo.rotation.z, -steer_impulse * 0.5, 8.0 * delta)
	cam.position = Vector3(tempo.position.x * 0.4, 5.6, tempo.position.z + 9.5)
	cam.look_at(Vector3(tempo.position.x * 0.4, 1.0, tempo.position.z - 5.0))
	# potholes
	var pz := tempo.position.z
	var bump := 0.0
	for p: Dictionary in potholes:
		if p.hit or absf(p.z - pz) > 0.7 or absf(p.x - tempo.position.x) > 1.0:
			continue
		p.hit = true
		bump = randf_range(0.35, 0.6) * (1.0 if randf() < 0.5 else -1.0)
		AudioManager.play_sfx(SFX_BUMP)
		Haptics.medium()
		Kit.squash(tempo, 0.12)
	# cargo sway: each box follows the one below with growing looseness
	var limit := SWAY_LIMIT * (2.0 if strapped else 1.0)
	for i in cargo.size():
		var c: Dictionary = cargo[i]
		if c.lost:
			continue
		var looseness := 1.0 + i * 0.4
		c.vel += (-c.sway * 6.0 - steer_impulse * looseness * 2.0 + bump * looseness) * delta * 6.0
		c.vel *= pow(0.4, delta * 4.0)
		c.sway += c.vel * delta
		var node: Node3D = c.node
		node.position.x = c.sway
		node.rotation.z = -c.sway * 0.5
		if absf(c.sway) > limit:
			c.lost = true
			AudioManager.play_sfx(SFX_DROP)
			Haptics.heavy()
			Kit.burst(self, node.global_position, Kit.CORAL, 12, 4.0)
			var g := node.global_position
			node.get_parent().remove_child(node)
			add_child(node)
			node.global_position = g
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(node, "position",
				g + Vector3(signf(c.sway) * 3.0, -0.2, 3.0), 0.7)
			tween.tween_property(node, "rotation", Vector3(randf() * 4, randf() * 4, randf() * 4), 0.7)
	if _alive() == 0:
		_finish(false)
		return
	if pz <= -course_len:
		_finish(true)


func _finish(delivered: bool) -> void:
	state = State.RESULT
	var n := _alive()
	if delivered:
		var pay := n * 12 * (1 + level / 3)
		coins += pay
		level += 1
		SaveManager.set_value(LEVEL_KEY, level)
		SaveManager.set_value(COINS_KEY, coins)
		AudioManager.play_sfx(SFX_DELIVER)
		Haptics.medium()
		for i in 3:
			Kit.burst(self, tempo.position + Vector3(0, 2, -2), Kit.CANDY[i], 28, 8.0)
		overlay.title.text = "DELIVERED!"
		overlay.body.text = "%d / %d boxes made it = ₹%d\nbank ₹%d\n\ntap for trip %d" \
			% [n, cargo.size(), pay, coins, level]
	else:
		AudioManager.play_sfx(SFX_GAME_OVER)
		Haptics.heavy()
		overlay.title.text = "SAB GIR GAYA"
		overlay.body.text = "the whole stack tumbled!\n\ntap to retry trip %d" % level
	Analytics.log_event("game_over", {"won": delivered, "level": level})
	AdsManager.round_finished()
	overlay.panel.visible = true


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "straps" or state != State.READY:
		return
	strapped = true
	Analytics.log_event("straps_used")
	Haptics.medium()
	Kit.burst(self, tempo.position + Vector3.UP * 2.0, Kit.SUN, 24, 6.0)
	_begin()


func _begin() -> void:
	start_panel.visible = false
	state = State.DRIVING
	last_x = tempo.position.x


func _unhandled_input(event: InputEvent) -> void:
	match state:
		State.READY:
			var t := event as InputEventScreenTouch
			if t != null and t.pressed:
				var straps: Button = start_panel.get_node_or_null("Straps")
				if straps != null and straps.visible and straps.get_global_rect().has_point(t.position):
					return
				AudioManager.play_sfx(SFX_TAP)
				_begin()
		State.DRIVING:
			if event is InputEventScreenTouch:
				var touch := event as InputEventScreenTouch
				touching = touch.pressed
				if touch.pressed:
					touch_start = touch.position
					start_x = drag_x
			elif event is InputEventScreenDrag and touching:
				var drag := event as InputEventScreenDrag
				drag_x = clampf(start_x + (drag.position.x - touch_start.x) / 160.0,
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
	Kit.sky(self, Kit.SKY, Color(1.0, 0.9, 0.7), Color(0.45, 0.7, 0.4))
	cam = Camera3D.new()
	cam.fov = 56.0
	add_child(cam)
	# the tempo
	tempo = Node3D.new()
	var cab := Kit.box(Vector3(1.4, 1.1, 0.9), Kit.TEAL, true)
	cab.position = Vector3(0.0, 0.85, -1.2)
	tempo.add_child(cab)
	var windshield := Kit.box(Vector3(1.2, 0.5, 0.08), Color(0.75, 0.92, 1.0), true)
	windshield.position = Vector3(0.0, 1.1, -1.66)
	tempo.add_child(windshield)
	bed = Node3D.new()
	bed.position = Vector3(0.0, 0.62, 0.5)
	var bed_mesh := Kit.box(Vector3(1.5, 0.18, 2.2), Kit.ORANGE, true)
	bed.add_child(bed_mesh)
	tempo.add_child(bed)
	for wx: float in [-0.7, 0.7]:
		for wz: float in [-1.2, 1.1]:
			var wheel := Kit.cyl(0.3, 0.2, Kit.INK)
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(wx, 0.3, wz)
			tempo.add_child(wheel)
	add_child(tempo)
	# cargo stack
	var n := 4 + level
	for i in n:
		var box := Kit.box(Vector3(1.2, 0.5, 1.6), Kit.CANDY[i % Kit.CANDY.size()], true)
		box.position = Vector3(0.0, 0.4 + i * 0.52, 0.0)
		bed.add_child(box)
		cargo.append({ "node": box, "sway": 0.0, "vel": 0.0, "lost": false })


func _build_course() -> void:
	course_len = 70.0 + level * 15.0
	var road := Kit.box(Vector3(7.0, 0.4, course_len + 50.0), Color(0.45, 0.42, 0.45))
	road.position = Vector3(0.0, -0.2, -course_len / 2.0)
	add_child(road)
	for side: float in [-1.0, 1.0]:
		var hills := Kit.texbox(Vector3(14.0, 0.5, course_len + 50.0), "tex1", Color(0.5, 0.75, 0.4), 6.0)
		hills.position = Vector3(side * 10.4, -0.3, -course_len / 2.0)
		add_child(hills)
		for i in 14:
			var tree := Kit.cone(0.6, 1.4, Kit.LIME.darkened(0.1))
			tree.position = Vector3(side * randf_range(4.6, 9.0), 0.7, -i * (course_len / 14.0))
			add_child(tree)
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 31337
	var z := -10.0
	while z > -course_len + 6.0:
		var x := rng.randf_range(-2.4, 2.4)
		var hole := Kit.cyl(0.55, 0.05, Color(0.2, 0.18, 0.2))
		hole.position = Vector3(x, 0.03, z)
		hole.scale.z = 0.7
		add_child(hole)
		potholes.append({ "x": x, "z": z, "hit": false })
		z -= rng.randf_range(4.5, 8.0 - minf(level * 0.3, 3.0))
	# delivery gate
	var arch := Kit.box(Vector3(7.0, 0.5, 0.5), Kit.MAGENTA)
	arch.position = Vector3(0.0, 3.2, -course_len)
	add_child(arch)
	for side: float in [-1.0, 1.0]:
		var post := Kit.cyl(0.25, 3.2, Kit.MAGENTA)
		post.position = Vector3(side * 3.3, 1.6, -course_len)
		add_child(post)


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	cargo_label = Kit.label("cargo 0", 76, Color.WHITE)
	cargo_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cargo_label.offset_top = 44.0
	cargo_label.offset_bottom = 140.0
	layer.add_child(cargo_label)
	level_label = Kit.label("TRIP 1", 48, Kit.SUN)
	level_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_top = 144.0
	level_label.offset_bottom = 208.0
	layer.add_child(level_label)
	overlay = Kit.overlay("", Kit.ORANGE)
	layer.add_child(overlay.panel)
	start_panel = Control.new()
	start_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var hint := Kit.label("steer gently — the stack remembers\npotholes are personal\n\ntap to drive", 48)
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 1280.0
	hint.offset_bottom = 1560.0
	start_panel.add_child(hint)
	var straps := Kit.button("CARGO STRAPS · AD", 46, Kit.PURPLE)
	straps.name = "Straps"
	straps.position = Vector2(250.0, 1600.0)
	straps.size = Vector2(580.0, 115.0)
	straps.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("straps"))
	start_panel.add_child(straps)
	layer.add_child(start_panel)
