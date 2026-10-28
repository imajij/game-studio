extends Node3D
## Toda Todi — cannon vs candy block forts. Drag to aim (dotted arc), release
## to fire; knock enough blocks off the platform before the cannonballs run
## out. Pure physics demolition joy — it's blocks, nothing lives in the fort.
## Rewarded ad = +3 balls on a fail; interstitial at result screens.

enum State { AIMING, RESULT }

const BALLS_PER_LEVEL: int = 5
const POWER: float = 16.5
const CLEAR_FRACTION: float = 0.75
const FALL_Y: float = -2.0
const LEVEL_KEY: String = "level"

const SFX_FIRE: AudioStream = preload("res://assets/audio/fire.wav")
const SFX_HIT: AudioStream = preload("res://assets/audio/hit.wav")
const SFX_TOPPLE: AudioStream = preload("res://assets/audio/topple.wav")
const SFX_STAR: AudioStream = preload("res://assets/audio/star.wav")
const SFX_WIN: AudioStream = preload("res://assets/audio/win.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.AIMING
var level: int = 1
var balls_left: int = BALLS_PER_LEVEL
var blocks: Array = []        # RigidBody3D
var fallen: int = 0
var total_blocks: int = 0
var aiming: bool = false
var aim_yaw: float = 0.0
var aim_pitch: float = 0.62
var touch_start: Vector2 = Vector2.ZERO
var extra_used: bool = false
var restarting: bool = false
var settle_timer: float = 0.0
var shots_resolving: int = 0

var cannon: Node3D = null
var barrel: Node3D = null
var cam: Camera3D = null
var dots: Array = []
var level_label: Label = null
var progress_label: Label = null
var overlay: Dictionary = {}

func _ready() -> void:
	randomize()
	level = int(SaveManager.get_value(LEVEL_KEY, 1))
	Kit.sky(self, Kit.SKY, Color(1.0, 0.85, 0.6), Color(0.9, 0.75, 0.55))
	cam = Camera3D.new()
	cam.position = Vector3(0.0, 4.2, 13.0)
	cam.fov = 50.0
	add_child(cam)
	cam.look_at(Vector3(0.0, 1.8, 0.0))
	_build_arena()
	_build_fort()
	_build_ui()
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	Analytics.log_event("round_start")
	_refresh()


func _process(delta: float) -> void:
	var newly := 0
	for b: RigidBody3D in blocks.duplicate():
		if b.position.y < FALL_Y:
			blocks.erase(b)
			fallen += 1
			newly += 1
			Kit.burst(self, Vector3(b.position.x, 0.2, b.position.z), b.get_meta("color"), 8, 4.0)
			b.queue_free()
	if newly > 0:
		AudioManager.play_sfx(SFX_TOPPLE, 0.15)
		Haptics.light()
		_refresh()
	if state == State.AIMING and balls_left <= 0 and shots_resolving <= 0:
		settle_timer += delta
		if settle_timer > 2.2:
			_finish()
	else:
		settle_timer = 0.0
	if fallen >= int(total_blocks * CLEAR_FRACTION) and state == State.AIMING:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.RESULT:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			var extra: Button = overlay.panel.get_node_or_null("Extra")
			if extra != null and extra.visible and extra.get_global_rect().has_point(t.position):
				return
			_next()
		return
	if balls_left <= 0:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			aiming = true
			touch_start = touch.position
		elif aiming:
			aiming = false
			_hide_dots()
			_fire()
	elif event is InputEventScreenDrag and aiming:
		var drag := event as InputEventScreenDrag
		var d := drag.position - touch_start
		aim_yaw = clampf(-d.x / 300.0, -0.6, 0.6)
		aim_pitch = clampf(0.62 + d.y / 500.0, 0.3, 1.1)
		_show_dots()


func _aim_velocity() -> Vector3:
	var dir := Vector3(sin(aim_yaw) * cos(aim_pitch), sin(aim_pitch), -cos(aim_yaw) * cos(aim_pitch))
	return dir * POWER


func _show_dots() -> void:
	var vel := _aim_velocity()
	var pos := barrel.global_position
	for i in dots.size():
		var t := 0.12 * (i + 1)
		var p := pos + vel * t + Vector3(0.0, -9.8, 0.0) * 0.5 * t * t
		dots[i].position = p
		dots[i].visible = true
	barrel.rotation = Vector3(aim_pitch - PI / 2.0, aim_yaw, 0.0)


func _hide_dots() -> void:
	for d: Node3D in dots:
		d.visible = false


func _fire() -> void:
	balls_left -= 1
	shots_resolving += 1
	AudioManager.play_sfx(SFX_FIRE)
	Haptics.medium()
	Kit.squash(cannon, 0.3)
	Kit.burst(self, barrel.global_position, Kit.SUN, 14, 5.0)
	var ball := RigidBody3D.new()
	ball.position = barrel.global_position
	ball.mass = 2.4
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.32
	shape.shape = sphere
	ball.add_child(shape)
	ball.add_child(Kit.sphere(0.32, Kit.INK, true))
	add_child(ball)
	ball.linear_velocity = _aim_velocity()
	ball.body_entered.connect(func(_b: Node) -> void:
		AudioManager.play_sfx(SFX_HIT, 0.2, randf_range(0.9, 1.2)))
	ball.contact_monitor = true
	ball.max_contacts_reported = 2
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		shots_resolving -= 1
		if is_instance_valid(ball):
			ball.queue_free())
	_refresh()


func _finish() -> void:
	if state == State.RESULT:
		return
	state = State.RESULT
	var cleared := fallen >= int(total_blocks * CLEAR_FRACTION)
	var stars := 1 + mini(balls_left, 2) if cleared else 0
	if cleared:
		level += 1
		SaveManager.set_value(LEVEL_KEY, level)
		AudioManager.play_sfx(SFX_WIN)
		for i in stars:
			get_tree().create_timer(0.3 * i).timeout.connect(func() -> void:
				AudioManager.play_sfx(SFX_STAR, 0.0, 1.0 + i * 0.2))
		Haptics.medium()
		for i in 3:
			Kit.burst(self, Vector3(randf_range(-2, 2), 2.0, 0.0), Kit.CANDY[i], 28, 8.0)
		overlay.title.text = "FORT TODA! " + "★".repeat(stars)
		overlay.body.text = "%d / %d blocks down\n\ntap for fort %d" % [fallen, total_blocks, level]
	else:
		AudioManager.play_sfx(SFX_TAP)
		Haptics.heavy()
		overlay.title.text = "FORT STANDS"
		overlay.body.text = "%d / %d down — needed %d\n\ntap to retry" \
			% [fallen, total_blocks, int(total_blocks * CLEAR_FRACTION)]
	Analytics.log_event("game_over", {"won": cleared, "level": level})
	AdsManager.round_finished()
	overlay.panel.visible = true
	var extra: Button = overlay.panel.get_node_or_null("Extra")
	if extra != null:
		extra.visible = not cleared and not extra_used and AdsManager.is_rewarded_ready()


func _next() -> void:
	if restarting:
		return
	restarting = true
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "balls" or state != State.RESULT:
		return
	extra_used = true
	balls_left += 3
	state = State.AIMING
	overlay.panel.visible = false
	Analytics.log_event("extra_balls")
	Haptics.medium()
	_refresh()


# --- arena + fort -----------------------------------------------------------

func _build_arena() -> void:
	var sand := Kit.texbox(Vector3(30.0, 0.5, 26.0), "tex1", Color(0.93, 0.8, 0.55), 1.0)
	sand.position = Vector3(0.0, -3.0, -2.0)
	add_child(sand)
	# platform the fort stands on
	var plat_body := StaticBody3D.new()
	plat_body.position = Vector3(0.0, 0.0, -1.5)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(7.0, 0.6, 5.0)
	shape.shape = box
	plat_body.add_child(shape)
	plat_body.add_child(Kit.box(Vector3(7.0, 0.6, 5.0), Kit.TEAL, true))
	add_child(plat_body)
	for px: float in [-3.2, 3.2]:
		var leg := Kit.cyl(0.4, 2.6, Kit.TEAL.darkened(0.25))
		leg.position = Vector3(px, -1.6, -1.5)
		add_child(leg)
	# cannon
	cannon = Node3D.new()
	cannon.position = Vector3(0.0, 1.2, 9.0)
	var base := Kit.sphere(0.65, Kit.PURPLE, true)
	base.scale = Vector3(1.0, 0.7, 1.0)
	cannon.add_child(base)
	barrel = Kit.cyl(0.3, 1.5, Kit.MAGENTA, true)
	barrel.position = Vector3(0.0, 0.5, -0.4)
	barrel.rotation.x = -0.9
	cannon.add_child(barrel)
	add_child(cannon)
	for i in 10:
		var dot := Kit.sphere(0.09, Color(1, 1, 1, 0.8))
		dot.visible = false
		add_child(dot)
		dots.append(dot)


func _build_fort() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 20011
	var layers := mini(3 + level / 2, 6)
	for layer_i in layers:
		var w := rng.randi_range(2, 4)
		var cols := []
		for c in w:
			cols.append((c - (w - 1) / 2.0) * 1.3 + rng.randf_range(-0.15, 0.15))
		for x: float in cols:
			_block(Vector3(x, 0.75 + layer_i * 1.1, -1.5 + rng.randf_range(-1.0, 1.0)),
				Vector3(0.9, 1.0, 0.9), rng)
		# lintels
		if w >= 2 and rng.randf() < 0.7:
			_block(Vector3(0.0, 1.35 + layer_i * 1.1, -1.5),
				Vector3(w * 1.3, 0.35, 0.9), rng)
	total_blocks = blocks.size()


func _block(pos: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	var body := RigidBody3D.new()
	body.position = pos
	body.mass = size.x * size.y * size.z * 0.9
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var color := Kit.CANDY[rng.randi() % Kit.CANDY.size()]
	body.add_child(Kit.box(size, color, true))
	body.set_meta("color", color)
	add_child(body)
	blocks.append(body)


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	level_label = Kit.label("FORT 1", 82, Kit.MAGENTA)
	level_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_top = 44.0
	level_label.offset_bottom = 148.0
	layer.add_child(level_label)
	progress_label = Kit.label("", 50, Color.WHITE)
	progress_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	progress_label.offset_top = 150.0
	progress_label.offset_bottom = 218.0
	layer.add_child(progress_label)
	var hint := Kit.label("drag to aim · release to FIRE", 40, Color(1, 1, 1, 0.8))
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 1760.0
	hint.offset_bottom = 1820.0
	layer.add_child(hint)
	overlay = Kit.overlay("", Kit.SUN)
	var extra := Kit.button("+3 BALLS · AD", 46, Kit.PURPLE)
	extra.name = "Extra"
	extra.position = Vector2(290.0, 1190.0)
	extra.size = Vector2(500.0, 110.0)
	extra.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("balls"))
	overlay.panel.add_child(extra)
	layer.add_child(overlay.panel)


func _refresh() -> void:
	level_label.text = "FORT %d" % level
	progress_label.text = "down %d / %d   balls %d" % [fallen, total_blocks, balls_left]
