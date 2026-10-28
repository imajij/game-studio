extends Node3D
## Nom Hole — you are a hungry hole in a toy town. Joystick around, swallow
## cones, crates, trees, carts, whole buses as you grow; two AI holes are
## eating the same town. Most points when the timer dies wins the buffet.
## Everything is empty toy props — nobody is inside anything.
## Rewarded ad = +30 seconds once; interstitial on restart.

enum State { PLAYING, DONE }

const WORLD: float = 19.0
const ROUND_SECONDS: float = 90.0
const BEST_KEY: String = "best"

const SFX_GULP: AudioStream = preload("res://assets/audio/gulp.wav")
const SFX_GROW: AudioStream = preload("res://assets/audio/grow.wav")
const SFX_BIG: AudioStream = preload("res://assets/audio/big.wav")
const SFX_TICK: AudioStream = preload("res://assets/audio/tick.wav")
const SFX_WIN: AudioStream = preload("res://assets/audio/win.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var time_left: float = ROUND_SECONDS
var best: int = 0
var extra_used: bool = false
var restarting: bool = false
var last_tick: int = 99

var holes: Array = []   # {node, rim, speed, pts, r, ai, target}
var props: Array = []   # {node, size, pts, eaten}
var cam: Camera3D = null
var joystick: Joystick = null
var score_label: Label = null
var time_label: Label = null
var rival_label: Label = null
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


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	time_left -= delta
	var whole := int(ceil(time_left))
	if whole != last_tick and whole <= 5 and whole > 0:
		last_tick = whole
		AudioManager.play_sfx(SFX_TICK)
	if time_left <= 0.0:
		_finish()
		return
	for h: Dictionary in holes:
		_move_hole(h, delta)
		_eat(h)
	var me: Dictionary = holes[0]
	cam.position = cam.position.lerp(me.node.position + Vector3(0.0, 13.0 + me.r * 2.5, 7.0 + me.r), 5.0 * delta)
	cam.look_at(me.node.position)
	score_label.text = "%d" % int(me.pts)
	time_label.text = "%ds" % int(ceil(time_left))
	rival_label.text = "rivals %d · %d" % [int(holes[1].pts), int(holes[2].pts)]


func _move_hole(h: Dictionary, delta: float) -> void:
	var node: Node3D = h.node
	var dir := Vector3.ZERO
	if h.ai:
		var target: Dictionary = h.target
		if target.is_empty() or target.eaten or target.size > h.r * 0.92:
			h.target = _nearest_edible(h)
			target = h.target
		if not target.is_empty():
			dir = (target.node.position - node.position)
			dir.y = 0.0
			dir = dir.normalized()
	else:
		var v := joystick.vector
		if v.length() > 0.05:
			dir = Vector3(v.x, 0.0, v.y)
	node.position += dir * h.speed * delta
	node.position.x = clampf(node.position.x, -WORLD, WORLD)
	node.position.z = clampf(node.position.z, -WORLD, WORLD)


func _nearest_edible(h: Dictionary) -> Dictionary:
	var node: Node3D = h.node
	var pick: Dictionary = {}
	var best_d := 999.0
	for p: Dictionary in props:
		if p.eaten or p.size > h.r * 0.92:
			continue
		var d: float = node.position.distance_to(p.node.position)
		if d < best_d:
			best_d = d
			pick = p
	return pick


func _eat(h: Dictionary) -> void:
	var node: Node3D = h.node
	for p: Dictionary in props:
		if p.eaten or p.size > h.r * 0.92:
			continue
		if node.position.distance_to(p.node.position) < h.r * 0.85:
			p.eaten = true
			h.pts += p.pts
			h.r = minf(float(h.r) + 0.015 * float(p.pts), 3.4)
			node.scale = Vector3(h.r, 1.0, h.r)
			var prop: Node3D = p.node
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(prop, "position:y", -2.2, 0.35)
			tween.tween_property(prop, "scale", Vector3.ONE * 0.1, 0.35)
			tween.chain().tween_callback(prop.queue_free)
			if not h.ai:
				AudioManager.play_sfx(SFX_BIG if p.pts >= 5 else SFX_GULP, 0.1, 1.0 - h.r * 0.08)
				Haptics.light()
				Kit.burst(self, prop.position + Vector3.UP * 0.3, Kit.SUN, 8 + p.pts, 3.5)
				if p.pts >= 5:
					AudioManager.play_sfx(SFX_GROW)
					Kit.squash(node, 0.2)


func _finish() -> void:
	state = State.DONE
	var me: Dictionary = holes[0]
	var won: bool = me.pts >= holes[1].pts and me.pts >= holes[2].pts
	if int(me.pts) > best:
		best = int(me.pts)
		SaveManager.set_value(BEST_KEY, best)
	AudioManager.play_sfx(SFX_WIN if won else SFX_GAME_OVER)
	Haptics.heavy()
	if won:
		for i in 3:
			Kit.burst(self, me.node.position + Vector3(randf_range(-2, 2), 1.0, randf_range(-2, 2)),
				Kit.CANDY[i], 30, 8.0)
	Analytics.log_event("game_over", {"pts": int(me.pts), "won": won})
	AdsManager.round_finished()
	overlay.title.text = "TOWN DEVOURED!" if won else "OUT-NOMMED"
	overlay.body.text = "you %d   rivals %d · %d\nBEST %d\n\ntap to re-nom" \
		% [int(me.pts), int(holes[1].pts), int(holes[2].pts), best]
	overlay.panel.visible = true
	var extra: Button = overlay.panel.get_node_or_null("Extra")
	if extra != null:
		extra.visible = not extra_used and AdsManager.is_rewarded_ready()


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "extra" or state != State.DONE:
		return
	extra_used = true
	time_left = 30.0
	last_tick = 99
	state = State.PLAYING
	overlay.panel.visible = false
	Analytics.log_event("extra_time")
	Haptics.medium()


func _unhandled_input(event: InputEvent) -> void:
	if state != State.DONE:
		return
	var t := event as InputEventScreenTouch
	if t == null or not t.pressed:
		return
	var extra: Button = overlay.panel.get_node_or_null("Extra")
	if extra != null and extra.visible and extra.get_global_rect().has_point(t.position):
		return
	if restarting:
		return
	restarting = true
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


# --- world ------------------------------------------------------------------

func _build_world() -> void:
	Kit.sky(self, Kit.SKY, Color(1.0, 0.86, 0.62), Color(0.6, 0.75, 0.5))
	cam = Camera3D.new()
	cam.position = Vector3(0.0, 14.0, 8.0)
	cam.fov = 55.0
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var ground := Kit.texbox(Vector3(WORLD * 2.0 + 4.0, 0.4, WORLD * 2.0 + 4.0), "tex1",
		Color(0.62, 0.68, 0.62), 1.0)
	ground.position.y = -0.21
	add_child(ground)
	# props: cones, crates, trees, carts, buses
	for i in 34:
		_prop(Kit.cone(0.22, 0.5, Kit.ORANGE), 0.4, 1, 0.25)
	for i in 22:
		_prop(Kit.box(Vector3(0.55, 0.55, 0.55), Kit.CANDY[randi() % Kit.CANDY.size()], true), 0.6, 2, 0.28)
	for i in 16:
		var tree := Node3D.new()
		var trunk := Kit.cyl(0.12, 0.7, Color(0.5, 0.33, 0.22))
		trunk.position.y = 0.35
		tree.add_child(trunk)
		var crown := Kit.sphere(0.55, Kit.LIME, true)
		crown.position.y = 1.0
		tree.add_child(crown)
		_prop(tree, 0.95, 3, 0.0)
	for i in 10:
		var cart := Node3D.new()
		var body := Kit.box(Vector3(1.3, 0.6, 0.8), Kit.TEAL, true)
		body.position.y = 0.45
		cart.add_child(body)
		var canopy := Kit.box(Vector3(1.4, 0.1, 0.9), Kit.PINK, true)
		canopy.position.y = 1.1
		cart.add_child(canopy)
		_prop(cart, 1.5, 5, 0.0)
	for i in 6:
		var bus := Node3D.new()
		var body := Kit.box(Vector3(2.6, 1.0, 1.0), Kit.SUN, true)
		body.position.y = 0.6
		bus.add_child(body)
		for wx: float in [-0.9, 0.9]:
			for wz: float in [-0.5, 0.5]:
				var wheel := Kit.cyl(0.18, 0.12, Kit.INK)
				wheel.rotation.x = PI / 2.0
				wheel.position = Vector3(wx, 0.18, wz)
				bus.add_child(wheel)
		_prop(bus, 2.4, 8, 0.0)
	# the three holes
	holes.append(_make_hole(Kit.TEAL, false, Vector3(0.0, 0.0, 6.0)))
	holes.append(_make_hole(Kit.RED, true, Vector3(-8.0, 0.0, -6.0)))
	holes.append(_make_hole(Kit.PURPLE, true, Vector3(8.0, 0.0, -6.0)))


func _prop(node: Node3D, size: float, pts: int, lift: float) -> void:
	node.position = Vector3(randf_range(-WORLD, WORLD), lift, randf_range(-WORLD, WORLD))
	if node.position.length() < 3.0:
		node.position *= 3.0 / node.position.length()
	node.rotation.y = randf() * TAU
	add_child(node)
	props.append({ "node": node, "size": size, "pts": pts, "eaten": false })


func _make_hole(color: Color, ai: bool, pos: Vector3) -> Dictionary:
	var node := Node3D.new()
	node.position = pos
	var disc := Kit.cyl(0.95, 0.05, Kit.INK)
	disc.position.y = 0.03
	node.add_child(disc)
	var rim := Kit.cyl(1.0, 0.1, color)
	rim.position.y = 0.01
	node.add_child(rim)
	add_child(node)
	return { "node": node, "rim": rim, "speed": 4.6 if not ai else 3.4,
		"pts": 0.0, "r": 1.0, "ai": ai, "target": {} }


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	score_label = Kit.label("0", 104, Color.WHITE)
	score_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	score_label.offset_top = 40.0
	score_label.offset_bottom = 165.0
	layer.add_child(score_label)
	time_label = Kit.label("90s", 60, Kit.SUN)
	time_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	time_label.offset_top = 168.0
	time_label.offset_bottom = 245.0
	layer.add_child(time_label)
	rival_label = Kit.label("", 42, Kit.CORAL)
	rival_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rival_label.offset_top = 248.0
	rival_label.offset_bottom = 305.0
	layer.add_child(rival_label)
	joystick = Joystick.new()
	joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	joystick.offset_top = 760.0
	layer.add_child(joystick)
	overlay = Kit.overlay("", Kit.SUN)
	var extra := Kit.button("+30 SECONDS · AD", 46, Kit.LIME)
	extra.name = "Extra"
	extra.position = Vector2(270.0, 1190.0)
	extra.size = Vector2(540.0, 110.0)
	extra.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("extra"))
	overlay.panel.add_child(extra)
	layer.add_child(overlay.panel)
