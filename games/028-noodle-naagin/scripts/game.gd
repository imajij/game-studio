extends Node3D
## Noodle Naagin — snake.io night arena: your glowing noodle eats diyas and
## grows; four AI noodles want the same diyas. Any head that touches a wall or
## another noodle's body POPS into a shower of diyas for everyone else.
## Rewarded ad = revive with a 10 s shield; interstitial on restart.

enum State { PLAYING, DEAD }

const ARENA: float = 10.0
const SPEED: float = 4.2
const TURN_RATE: float = 4.6
const SEG_SPACING: float = 0.34
const SEG_R: float = 0.26
const START_SEGS: int = 6
const DIYA_COUNT: int = 26
const BEST_KEY: String = "best"

const SFX_EAT: AudioStream = preload("res://assets/audio/eat.wav")
const SFX_POP: AudioStream = preload("res://assets/audio/pop.wav")
const SFX_SHIELD: AudioStream = preload("res://assets/audio/shield.wav")
const SFX_WIN: AudioStream = preload("res://assets/audio/win.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var best: int = 0
var revive_used: bool = false
var restarting: bool = false
var shield_until: float = 0.0

var snakes: Array = []  # {head, heading, color, segs:[Node3D], trail:[Vector3], ai, respawn, dead}
var diyas: Array = []   # {node, pos}
var cam: Camera3D = null
var joystick: Joystick = null
var score_label: Label = null
var shield_label: Label = null
var overlay: Dictionary = {}

func _ready() -> void:
	randomize()
	best = int(SaveManager.get_value(BEST_KEY, 0))
	_build_world()
	_build_ui()
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	Analytics.log_event("round_start")


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	for s: Dictionary in snakes:
		if s.dead:
			s.respawn -= delta
			if s.ai and s.respawn <= 0.0:
				_spawn_snake(s)
			continue
		s.grace = maxf(float(s.grace) - delta, 0.0)
		_steer(s, delta)
		_advance(s, delta)
	_check_collisions()
	var me: Dictionary = snakes[0]
	cam.position = cam.position.lerp(me.head.position + Vector3(0.0, 11.0, 6.5), 5.0 * delta)
	cam.look_at(me.head.position)
	score_label.text = "length %d" % me.segs.size()
	shield_label.text = "✦ SHIELD" if _now() < shield_until else ""


func _steer(s: Dictionary, delta: float) -> void:
	var desired: float = s.heading
	if s.ai:
		var target := _nearest_diya(s.head.position)
		var to_t: Vector3 = target - s.head.position
		desired = atan2(-to_t.x, -to_t.z)
		# wall avoidance overrides
		var next_pos: Vector3 = s.head.position + _dir(s.heading) * 1.6
		if absf(next_pos.x) > ARENA - 1.0 or absf(next_pos.z) > ARENA - 1.0:
			desired = atan2(next_pos.x, next_pos.z)  # turn roughly back toward centre
	else:
		var v := joystick.vector
		if v.length() > 0.1:
			desired = atan2(-v.x, -v.y)
	s.heading = lerp_angle(s.heading, desired, TURN_RATE * delta)


func _dir(heading: float) -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


func _advance(s: Dictionary, delta: float) -> void:
	var head: Node3D = s.head
	head.position += _dir(s.heading) * SPEED * delta
	head.rotation.y = s.heading
	var trail: Array = s.trail
	if trail.is_empty() or head.position.distance_to(trail[0]) >= SEG_SPACING:
		trail.push_front(head.position)
		var cap: int = (s.segs.size() + 4) * 3
		while trail.size() > cap:
			trail.pop_back()
	for i in s.segs.size():
		var idx := mini((i + 1) * 1, trail.size() - 1)
		if idx >= 0 and trail.size() > 0:
			var seg: Node3D = s.segs[i]
			seg.position = trail[idx]


func _nearest_diya(from: Vector3) -> Vector3:
	var pick := Vector3.ZERO
	var best_d := 999.0
	for d: Dictionary in diyas:
		var dist: float = from.distance_to(d.pos)
		if dist < best_d:
			best_d = dist
			pick = d.pos
	return pick


func _check_collisions() -> void:
	for s: Dictionary in snakes:
		if s.dead:
			continue
		var head: Node3D = s.head
		var shielded: bool = float(s.grace) > 0.0 or ((not s.ai) and _now() < shield_until)
		# diyas
		for d: Dictionary in diyas.duplicate():
			if head.position.distance_to(d.pos) < 0.55:
				diyas.erase(d)
				d.node.queue_free()
				_grow(s)
				if not s.ai:
					AudioManager.play_sfx(SFX_EAT, 0.08, 1.0 + s.segs.size() * 0.008)
					Haptics.light()
				_drop_diya(_random_pos())
		# walls
		if absf(head.position.x) > ARENA or absf(head.position.z) > ARENA:
			if not shielded:
				_kill(s)
				continue
		# bodies
		for o: Dictionary in snakes:
			if o.dead:
				continue
			var start_i := 6 if o == s else 0
			var hit := false
			for i in range(start_i, o.segs.size(), 2):
				var seg: Node3D = o.segs[i]
				if head.position.distance_to(seg.position) < SEG_R * 2.0:
					hit = true
					break
			if hit and not shielded:
				_kill(s)
				break


func _grow(s: Dictionary) -> void:
	var seg := Kit.sphere(SEG_R, s.color, true)
	var tail_pos: Vector3 = s.segs.back().position if not s.segs.is_empty() else s.head.position
	seg.position = tail_pos
	add_child(seg)
	s.segs.append(seg)


func _kill(s: Dictionary) -> void:
	s.dead = true
	s.respawn = 2.5
	AudioManager.play_sfx(SFX_POP)
	Kit.burst(self, s.head.position + Vector3.UP * 0.3, s.color, 24, 6.0)
	# body becomes diyas
	for i in range(0, s.segs.size(), 2):
		_drop_diya(s.segs[i].position)
	for seg: Node3D in s.segs:
		seg.queue_free()
	s.segs.clear()
	s.trail.clear()
	s.head.visible = false
	if not s.ai:
		_game_over()


func _game_over() -> void:
	state = State.DEAD
	Haptics.heavy()
	var length: int = snakes[0].segs.size()
	AudioManager.play_sfx(SFX_GAME_OVER)
	Analytics.log_event("game_over", {"len": length})
	AdsManager.round_finished()
	overlay.title.text = "POPPED!"
	overlay.body.text = "length %d   best %d\n\ntap to slither again" % [length, best]
	overlay.panel.visible = true
	var revive: Button = overlay.panel.get_node_or_null("Revive")
	if revive != null:
		revive.visible = not revive_used and AdsManager.is_rewarded_ready()


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "revive" or state != State.DEAD:
		return
	revive_used = true
	var me: Dictionary = snakes[0]
	me.dead = false
	me.head.visible = true
	me.head.position = Vector3(0.0, 0.3, 0.0)
	me.trail = []
	for i in START_SEGS:
		_grow(me)
	shield_until = _now() + 10.0
	AudioManager.play_sfx(SFX_SHIELD)
	Haptics.medium()
	state = State.PLAYING
	overlay.panel.visible = false
	Analytics.log_event("revive_used")


func _unhandled_input(event: InputEvent) -> void:
	if state != State.DEAD:
		return
	var t := event as InputEventScreenTouch
	if t == null or not t.pressed:
		return
	var revive: Button = overlay.panel.get_node_or_null("Revive")
	if revive != null and revive.visible and revive.get_global_rect().has_point(t.position):
		return
	if restarting:
		return
	restarting = true
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		var me: Dictionary = snakes[0] if not snakes.is_empty() else {}
		if not me.is_empty() and me.segs.size() > best:
			best = me.segs.size()
			SaveManager.set_value(BEST_KEY, best)


# --- world ------------------------------------------------------------------

func _build_world() -> void:
	Kit.sky(self, Color(0.09, 0.06, 0.2), Color(0.5, 0.2, 0.45), Color(0.07, 0.05, 0.15))
	cam = Camera3D.new()
	cam.position = Vector3(0.0, 11.0, 6.5)
	cam.fov = 55.0
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var floor_mesh := Kit.texbox(Vector3(ARENA * 2.0 + 2.0, 0.3, ARENA * 2.0 + 2.0), "tex1",
		Color(0.12, 0.09, 0.22), 1.0)
	floor_mesh.position.y = -0.15
	add_child(floor_mesh)
	for side in 4:
		var wall := Kit.box(Vector3(ARENA * 2.0 + 2.0, 0.7, 0.35), Kit.CANDY[side * 2])
		match side:
			0: wall.position = Vector3(0.0, 0.35, -ARENA - 0.5)
			1: wall.position = Vector3(0.0, 0.35, ARENA + 0.5)
			2:
				wall.rotation.y = PI / 2.0
				wall.position = Vector3(-ARENA - 0.5, 0.35, 0.0)
			3:
				wall.rotation.y = PI / 2.0
				wall.position = Vector3(ARENA + 0.5, 0.35, 0.0)
		add_child(wall)
	for i in DIYA_COUNT:
		_drop_diya(_random_pos())
	# snakes: player + 4 AI
	var colors: Array[Color] = [Kit.MINT, Kit.PINK, Kit.SUN, Kit.PURPLE, Kit.CORAL]
	for i in 5:
		var s := { "head": null, "heading": randf() * TAU, "color": colors[i],
			"segs": [], "trail": [], "ai": i > 0, "respawn": 0.0, "dead": false, "grace": 1.5 }
		var head := Node3D.new()
		var ball := Kit.sphere(SEG_R * 1.25, colors[i], true)
		ball.position.y = 0.0
		head.add_child(ball)
		for side: float in [-1.0, 1.0]:
			var eye := Kit.sphere(0.08, Color.WHITE)
			eye.position = Vector3(side * 0.14, 0.14, -0.2)
			head.add_child(eye)
		head.position = Vector3([0.0, -6.0, 6.0, -6.0, 6.0][i], 0.3, [0.0, -6.0, -6.0, 6.0, 6.0][i])
		add_child(head)
		s.head = head
		snakes.append(s)
		for k in START_SEGS:
			_grow(s)


func _spawn_snake(s: Dictionary) -> void:
	s.dead = false
	s.head.visible = true
	s.head.position = _random_pos() * 0.8 + Vector3(0.0, 0.3, 0.0)
	s.trail = []
	for i in START_SEGS:
		_grow(s)


func _random_pos() -> Vector3:
	return Vector3(randf_range(-ARENA + 1.2, ARENA - 1.2), 0.3, randf_range(-ARENA + 1.2, ARENA - 1.2))


func _drop_diya(pos: Vector3) -> void:
	var node := Node3D.new()
	node.position = pos
	var cup := Kit.cyl(0.18, 0.12, Kit.ORANGE, true)
	node.add_child(cup)
	var flame := Kit.sphere(0.1, Kit.SUN)
	flame.position.y = 0.16
	node.add_child(flame)
	add_child(node)
	diyas.append({ "node": node, "pos": pos })


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	score_label = Kit.label("length 6", 76, Color.WHITE)
	score_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	score_label.offset_top = 44.0
	score_label.offset_bottom = 140.0
	layer.add_child(score_label)
	shield_label = Kit.label("", 48, Kit.MINT)
	shield_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shield_label.offset_top = 144.0
	shield_label.offset_bottom = 208.0
	layer.add_child(shield_label)
	joystick = Joystick.new()
	joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	joystick.offset_top = 760.0
	layer.add_child(joystick)
	overlay = Kit.overlay("", Kit.PINK)
	var revive := Kit.button("SHIELD REVIVE · AD", 46, Kit.LIME)
	revive.name = "Revive"
	revive.position = Vector2(260.0, 1190.0)
	revive.size = Vector2(560.0, 110.0)
	revive.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("revive"))
	overlay.panel.add_child(revive)
	layer.add_child(overlay.panel)
