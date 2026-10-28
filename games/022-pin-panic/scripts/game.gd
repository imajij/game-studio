extends Node3D
## Pin Panic — pull-the-pin puzzles. Gold balls wait above the pins, purple
## gunk lurks beside them; yank pins in the right order so the gold pours into
## the pot and the gunk pours anywhere else. Real physics, instant retries.
## Rewarded ad = skip a level; interstitial at result screens.

enum State { PLAYING, RESULT }

const BALL_R: float = 0.32
const POT_Y: float = -5.2
const LEVEL_KEY: String = "level"

const SFX_PIN: AudioStream = preload("res://assets/audio/pin.wav")
const SFX_GOLD: AudioStream = preload("res://assets/audio/gold.wav")
const SFX_GUNK: AudioStream = preload("res://assets/audio/gunk.wav")
const SFX_WIN: AudioStream = preload("res://assets/audio/win.wav")
const SFX_LOSE: AudioStream = preload("res://assets/audio/lose.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var level: int = 1
var pins: Array = []       # {node, body, pulled}
var balls: Array = []      # {body, gold, done}
var golds_needed: int = 0
var golds_in: int = 0
var settled_timer: float = 0.0
var pot_x: float = 0.0
var restarting: bool = false
var won_level: bool = false

var cam: Camera3D = null
var level_label: Label = null
var goal_label: Label = null
var overlay: Dictionary = {}

func _ready() -> void:
	randomize()
	level = int(SaveManager.get_value(LEVEL_KEY, 1))
	Kit.sky(self, Kit.PURPLE.lightened(0.25), Color(1.0, 0.75, 0.6), Color(0.85, 0.6, 0.75))
	cam = Camera3D.new()
	cam.position = Vector3(0.0, -1.2, 11.0)
	cam.fov = 48.0
	add_child(cam)
	_build_ui()
	_build_level()
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	Analytics.log_event("round_start")


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	var moving := false
	for b: Dictionary in balls:
		if b.done:
			continue
		var body: RigidBody3D = b.body
		if body.linear_velocity.length() > 0.4:
			moving = true
		# fell past the pot line?
		if body.position.y < POT_Y:
			b.done = true
			var in_pot: bool = absf(body.position.x - pot_x) < 1.5
			if in_pot and b.gold:
				golds_in += 1
				AudioManager.play_sfx(SFX_GOLD, 0.06)
				Haptics.light()
				Kit.burst(self, body.position, Kit.SUN, 12, 4.0)
				body.queue_free()
				if golds_in >= golds_needed:
					_finish(true)
					return
			elif in_pot and not b.gold:
				AudioManager.play_sfx(SFX_GUNK)
				Haptics.heavy()
				Kit.burst(self, body.position, Kit.PURPLE, 18, 4.0)
				_finish(false)
				return
			else:
				body.queue_free()
	# all pins pulled and everything settled but not enough gold = lose
	if pins.all(func(p: Dictionary) -> bool: return p.pulled):
		if not moving:
			settled_timer += delta
			if settled_timer > 1.4:
				_finish(golds_in >= golds_needed)
		else:
			settled_timer = 0.0
	goal_label.text = "gold %d / %d" % [golds_in, golds_needed]


func _unhandled_input(event: InputEvent) -> void:
	if state == State.RESULT:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			var skip: Button = overlay.panel.get_node_or_null("Skip")
			if skip != null and skip.visible and skip.get_global_rect().has_point(t.position):
				return
			_next(won_level)
		return
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	# nearest pin to the tap, in screen space
	var best: Dictionary = {}
	var best_d := 120.0
	for p: Dictionary in pins:
		if p.pulled:
			continue
		var screen := cam.unproject_position(p.node.global_position)
		var d := screen.distance_to(touch.position / _ui_scale())
		if d < best_d:
			best_d = d
			best = p
	if best.is_empty():
		return
	best.pulled = true
	AudioManager.play_sfx(SFX_PIN)
	Haptics.medium()
	var node: Node3D = best.node
	var tween := create_tween()
	var dir := 1.0 if node.position.x >= 0.0 else -1.0
	tween.tween_property(node, "position:x", node.position.x + dir * 4.5, 0.25)
	tween.tween_callback(node.queue_free)
	var body: StaticBody3D = best.body
	body.queue_free()


func _ui_scale() -> float:
	# touches arrive in window pixels; unproject gives viewport (1080x1920) pixels
	return float(get_viewport().get_visible_rect().size.x) / 1080.0 \
		if get_viewport().get_visible_rect().size.x != 1080.0 else 1.0


func _finish(won: bool) -> void:
	if state == State.RESULT:
		return
	state = State.RESULT
	won_level = won
	if won:
		AudioManager.play_sfx(SFX_WIN)
		Haptics.medium()
		for i in 3:
			Kit.burst(self, Vector3(randf_range(-2, 2), randf_range(-4, 0), 0.0), Kit.CANDY[i], 26, 7.0)
		overlay.title.text = "POT OF GOLD!"
		overlay.body.text = "vat %d cleared\n\ntap for vat %d" % [level, level + 1]
	else:
		AudioManager.play_sfx(SFX_LOSE)
		Haptics.heavy()
		overlay.title.text = "GUNKED!"
		overlay.body.text = "the gunk got in\n\ntap to retry vat %d" % level
	Analytics.log_event("game_over", {"won": won, "level": level})
	AdsManager.round_finished()
	overlay.panel.visible = true
	var skip: Button = overlay.panel.get_node_or_null("Skip")
	if skip != null:
		skip.visible = not won and AdsManager.is_rewarded_ready()


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
	if reward_type != "skip" or state != State.RESULT:
		return
	Analytics.log_event("skip_used")
	_next(true)


# --- level building ---------------------------------------------------------

func _build_level() -> void:
	var shaft_x: float = [-1.6, 0.0, 1.6][level % 3]
	pot_x = shaft_x
	# board back + side walls (physics kept in a z-slot by front/back panes)
	var back := Kit.texbox(Vector3(10.0, 12.0, 0.3), "tex1", Kit.CREAM, 1.0)
	back.position = Vector3(0.0, -1.0, -0.6)
	add_child(back)
	_wall(Vector3(0.3, 12.0, 1.2), Vector3(-4.2, -1.0, 0.0))
	_wall(Vector3(0.3, 12.0, 1.2), Vector3(4.2, -1.0, 0.0))
	_invisible_wall(Vector3(10.0, 12.0, 0.2), Vector3(0.0, -1.0, -0.45))
	_invisible_wall(Vector3(10.0, 12.0, 0.2), Vector3(0.0, -1.0, 0.45))
	# pot
	_wall(Vector3(3.2, 0.3, 1.2), Vector3(pot_x, POT_Y - 0.4, 0.0), Kit.ORANGE)
	_wall(Vector3(0.3, 1.4, 1.2), Vector3(pot_x - 1.55, POT_Y + 0.15, 0.0), Kit.ORANGE)
	_wall(Vector3(0.3, 1.4, 1.2), Vector3(pot_x + 1.55, POT_Y + 0.15, 0.0), Kit.ORANGE)
	# generated layout: 3 stacked chambers with pins, gold high, gunk flanking
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 7919
	var gold_count := 3 + mini(level / 2, 4)
	golds_needed = maxi(2, gold_count - 1)
	for i in gold_count:
		_ball(Vector3(shaft_x + rng.randf_range(-0.8, 0.8), 3.2 + (i % 3) * 0.8, 0.0), true)
	var gunk_count := 2 + mini(level / 3, 3)
	for i in gunk_count:
		var gx: float = shaft_x + (1.8 + rng.randf_range(0.0, 0.8)) * (1.0 if i % 2 == 0 else -1.0)
		_ball(Vector3(clampf(gx, -3.6, 3.6), 2.2 + (i % 2) * 1.4, 0.0), false)
	# pins: one under the gold, one under each gunk cluster, one mid trap
	_pin(Vector3(shaft_x, 2.2, 0.0), 3.0, rng.randf_range(-0.12, 0.12))
	_pin(Vector3(shaft_x - 2.2, 1.0, 0.0), 2.6, -0.25)
	_pin(Vector3(shaft_x + 2.2, 1.0, 0.0), 2.6, 0.25)
	_pin(Vector3(shaft_x + rng.randf_range(-1.0, 1.0), -1.4, 0.0), 3.4, rng.randf_range(-0.2, 0.2))
	level_label.text = "VAT %d" % level


func _wall(size: Vector3, pos: Vector3, color: Color = Kit.TEAL) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(Kit.box(size, color, true))
	add_child(body)


func _invisible_wall(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _pin(pos: Vector3, length: float, tilt: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.z = tilt
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, 0.22, 1.0)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	var visual := Kit.box(Vector3(length, 0.22, 0.5), Kit.SKY, true)
	visual.position = pos
	visual.rotation.z = tilt
	var knob := Kit.sphere(0.2, Kit.BLUE)
	knob.position.x = length / 2.0
	visual.add_child(knob)
	add_child(visual)
	pins.append({ "node": visual, "body": body, "pulled": false })


func _ball(pos: Vector3, gold: bool) -> void:
	var body := RigidBody3D.new()
	body.position = pos
	body.mass = 0.6
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = BALL_R
	shape.shape = sphere
	body.add_child(shape)
	body.add_child(Kit.sphere(BALL_R, Kit.SUN if gold else Kit.PURPLE, true))
	add_child(body)
	balls.append({ "body": body, "gold": gold, "done": false })


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	level_label = Kit.label("VAT 1", 84, Kit.ORANGE)
	level_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_top = 46.0
	level_label.offset_bottom = 150.0
	layer.add_child(level_label)
	goal_label = Kit.label("gold 0 / 0", 50, Kit.SUN)
	goal_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	goal_label.offset_top = 152.0
	goal_label.offset_bottom = 220.0
	layer.add_child(goal_label)
	var hint := Kit.label("tap the blue pins — gold in the pot, gunk OUT", 38, Color(1, 1, 1, 0.8))
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 1760.0
	hint.offset_bottom = 1820.0
	layer.add_child(hint)
	overlay = Kit.overlay("", Kit.SUN)
	var skip := Kit.button("SKIP VAT · AD", 46, Kit.PURPLE)
	skip.name = "Skip"
	skip.position = Vector2(300.0, 1190.0)
	skip.size = Vector2(480.0, 110.0)
	skip.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("skip"))
	overlay.panel.add_child(skip)
	layer.add_child(overlay.panel)
