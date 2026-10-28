extends Node3D
## Glow Hunt — neon top-down arena tag. Robo-blobs hide in the dark; only your
## torch cone reveals them. Zap every bot before their cones catch YOU three
## times. It's tag with light pulses — no weapons, nobody gets hurt, tagged
## bots just sit down. Rewarded ad = one life refill; interstitial on restart.

enum State { PLAYING, WON, GAME_OVER }

const ARENA: float = 8.0
const PLAYER_SPEED: float = 4.6
const CONE_ANGLE_DEG: float = 38.0
const CONE_RANGE: float = 5.6
const BOT_CONE_ANGLE: float = 30.0
const BOT_CONE_RANGE: float = 4.2
const TAG_SECONDS: float = 0.6
const INVULN_SECONDS: float = 2.0
const MAX_LIVES: int = 3
const BEST_KEY: String = "best_round"

const SFX_ZAP: AudioStream = preload("res://assets/audio/zap.wav")
const SFX_TAGGED: AudioStream = preload("res://assets/audio/tagged.wav")
const SFX_WIN: AudioStream = preload("res://assets/audio/win.wav")
const SFX_TICK: AudioStream = preload("res://assets/audio/tick.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var round_number: int = 1
var best_round: int = 0
var lives: int = MAX_LIVES
var invuln: float = 0.0
var danger: float = 0.0
var revive_used: bool = false
var restarting: bool = false

var player: Node3D = null
var player_cone: Node3D = null
var bots: Array = []  # {node, cone, dir, target, speed, tagged}
var cam: Camera3D = null

var joystick: Joystick = null
var zap_button: Button = null
var round_label: Label = null
var lives_label: Label = null
var danger_label: Label = null
var overlay: Dictionary = {}

func _ready() -> void:
	randomize()
	best_round = int(SaveManager.get_value(BEST_KEY, 0))
	_build_world()
	_build_ui()
	_spawn_round()
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	Analytics.log_event("round_start")


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	invuln = maxf(invuln - delta, 0.0)
	_move_player(delta)
	_move_bots(delta)
	_update_visibility()
	_update_danger(delta)
	_refresh_ui()


func _move_player(delta: float) -> void:
	var v := joystick.vector
	if v.length() > 0.05:
		var dir := Vector3(v.x, 0.0, v.y)
		player.position += dir * PLAYER_SPEED * delta
		player.position.x = clampf(player.position.x, -ARENA, ARENA)
		player.position.z = clampf(player.position.z, -ARENA, ARENA)
		var target_angle := atan2(-dir.x, -dir.z)
		player.rotation.y = lerp_angle(player.rotation.y, target_angle, 12.0 * delta)
	cam.position = cam.position.lerp(
		Vector3(player.position.x * 0.35, 15.5, player.position.z * 0.35 + 5.5), 4.0 * delta)
	cam.look_at(Vector3(player.position.x * 0.4, 0.0, player.position.z * 0.4))


func _move_bots(delta: float) -> void:
	for b: Dictionary in bots:
		if b.tagged:
			continue
		var node: Node3D = b.node
		var to_target: Vector3 = b.target - node.position
		if to_target.length() < 0.4:
			b.target = _random_point()
			continue
		var dir := to_target.normalized()
		node.position += dir * b.speed * delta
		node.rotation.y = lerp_angle(node.rotation.y, atan2(-dir.x, -dir.z), 6.0 * delta)


func _forward(node: Node3D) -> Vector3:
	return -node.global_transform.basis.z


func _in_cone(looker: Node3D, point: Vector3, angle_deg: float, range_len: float) -> bool:
	var to_point := point - looker.position
	to_point.y = 0.0
	if to_point.length() > range_len:
		return false
	return rad_to_deg(_forward(looker).angle_to(to_point.normalized())) < angle_deg


func _update_visibility() -> void:
	for b: Dictionary in bots:
		if b.tagged:
			continue
		var node: Node3D = b.node
		var near := node.position.distance_to(player.position) < 1.8
		node.visible = near or _in_cone(player, node.position, CONE_ANGLE_DEG, CONE_RANGE)


func _update_danger(delta: float) -> void:
	var seen := false
	if invuln <= 0.0:
		for b: Dictionary in bots:
			if not b.tagged and _in_cone(b.node, player.position, BOT_CONE_ANGLE, BOT_CONE_RANGE):
				seen = true
				break
	if seen:
		if danger == 0.0:
			AudioManager.play_sfx(SFX_TICK)
		danger += delta
		if danger >= TAG_SECONDS:
			_player_tagged()
	else:
		danger = maxf(danger - delta * 2.0, 0.0)


func _player_tagged() -> void:
	danger = 0.0
	lives -= 1
	invuln = INVULN_SECONDS
	AudioManager.play_sfx(SFX_TAGGED)
	Haptics.heavy()
	Kit.burst(self, player.position + Vector3.UP * 0.5, Kit.RED, 26, 5.0)
	if lives <= 0:
		_game_over()


func _on_zap() -> void:
	if state != State.PLAYING:
		return
	var target: Dictionary = {}
	var best_d := CONE_RANGE
	for b: Dictionary in bots:
		if b.tagged or not b.node.visible:
			continue
		var d: float = b.node.position.distance_to(player.position)
		if d < best_d and _in_cone(player, b.node.position, CONE_ANGLE_DEG, CONE_RANGE):
			best_d = d
			target = b
	if target.is_empty():
		AudioManager.play_sfx(SFX_TAP)
		return
	target.tagged = true
	var node: Node3D = target.node
	node.visible = true
	target.cone.visible = false
	AudioManager.play_sfx(SFX_ZAP)
	Haptics.medium()
	Kit.burst(self, node.position + Vector3.UP * 0.5, Kit.SUN, 30, 6.0)
	Kit.squash(node, 0.5)
	node.rotation.x = 0.4  # sits back, out of the game
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = Kit.mat(Color(0.5, 0.52, 0.6))
	if bots.all(func(b: Dictionary) -> bool: return b.tagged):
		_round_won()


func _round_won() -> void:
	state = State.WON
	round_number += 1
	if round_number - 1 > best_round:
		best_round = round_number - 1
		SaveManager.set_value(BEST_KEY, best_round)
	AudioManager.play_sfx(SFX_WIN)
	Haptics.medium()
	Kit.burst(self, player.position + Vector3.UP, Kit.TEAL, 40, 8.0)
	Analytics.log_event("round_won", {"round": round_number - 1})
	overlay.title.text = "ALL BOTS ZAPPED!"
	overlay.body.text = "round %d cleared\nnext: %d bots, faster\n\ntap to keep hunting" \
		% [round_number - 1, 3 + round_number]
	overlay.panel.visible = true


func _game_over() -> void:
	state = State.GAME_OVER
	AudioManager.play_sfx(SFX_GAME_OVER)
	Analytics.log_event("game_over", {"round": round_number})
	AdsManager.round_finished()
	overlay.title.text = "CAUGHT IN THE LIGHT"
	overlay.body.text = "reached round %d   best %d\n\ntap to restart" % [round_number, best_round]
	overlay.panel.visible = true
	zap_button.visible = false
	_update_revive()


func _update_revive() -> void:
	var revive: Button = overlay.panel.get_node_or_null("Revive")
	if revive != null:
		revive.visible = state == State.GAME_OVER and not revive_used and AdsManager.is_rewarded_ready()


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "revive" or state != State.GAME_OVER:
		return
	revive_used = true
	lives = MAX_LIVES
	invuln = INVULN_SECONDS
	state = State.PLAYING
	overlay.panel.visible = false
	zap_button.visible = true
	Analytics.log_event("revive_used")
	Haptics.medium()


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	match state:
		State.WON:
			overlay.panel.visible = false
			state = State.PLAYING
			_spawn_round()
		State.GAME_OVER:
			if restarting:
				return
			restarting = true
			if AdsManager.maybe_show_interstitial():
				await AdsManager.interstitial_closed
			get_tree().reload_current_scene()


# --- world ------------------------------------------------------------------

func _build_world() -> void:
	Kit.sky(self, Color(0.1, 0.07, 0.25), Color(0.4, 0.15, 0.5), Color(0.08, 0.06, 0.18))
	cam = Camera3D.new()
	cam.position = Vector3(0.0, 15.5, 5.5)
	cam.fov = 50.0
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var floor_mesh := Kit.box(Vector3(ARENA * 2.0 + 2.0, 0.3, ARENA * 2.0 + 2.0), Color(0.13, 0.1, 0.3))
	floor_mesh.position.y = -0.15
	add_child(floor_mesh)
	# neon grid lines + wall ring
	for i in 9:
		var x := -ARENA + i * (ARENA / 4.0)
		var line := Kit.box(Vector3(0.06, 0.02, ARENA * 2.0), Color(0.35, 0.2, 0.7))
		line.position = Vector3(x, 0.02, 0.0)
		add_child(line)
		var line2 := Kit.box(Vector3(ARENA * 2.0, 0.02, 0.06), Color(0.35, 0.2, 0.7))
		line2.position = Vector3(0.0, 0.02, x)
		add_child(line2)
	for side in 4:
		var wall := Kit.box(Vector3(ARENA * 2.0 + 2.0, 0.8, 0.4), Kit.CANDY[side])
		wall.position = Vector3(0.0, 0.4, 0.0)
		match side:
			0: wall.position.z = -ARENA - 1.0
			1: wall.position.z = ARENA + 1.0
			2:
				wall.rotation.y = PI / 2.0
				wall.position.x = -ARENA - 1.0
			3:
				wall.rotation.y = PI / 2.0
				wall.position.x = ARENA + 1.0
		add_child(wall)
	player = Kit.blobby(Kit.TEAL, 0.32)
	player_cone = _make_cone(Color(0.2, 0.95, 0.9, 0.22), CONE_RANGE, CONE_ANGLE_DEG)
	player.add_child(player_cone)
	add_child(player)


func _make_cone(color: Color, length: float, angle_deg: float) -> Node3D:
	var wedge := Kit.cone(tan(deg_to_rad(angle_deg)) * length, length, color)
	wedge.rotation.x = -PI / 2.0
	wedge.position = Vector3(0.0, 0.05, -length / 2.0)
	var holder := Node3D.new()
	holder.add_child(wedge)
	return holder


func _random_point() -> Vector3:
	return Vector3(randf_range(-ARENA + 1.0, ARENA - 1.0), 0.0, randf_range(-ARENA + 1.0, ARENA - 1.0))


func _spawn_round() -> void:
	for b: Dictionary in bots:
		b.node.queue_free()
	bots.clear()
	player.position = Vector3(0.0, 0.0, ARENA - 1.5)
	danger = 0.0
	invuln = 1.0
	var count := 3 + round_number
	var speed := 1.6 + round_number * 0.22
	for i in count:
		var node := Kit.blobby(Kit.CANDY[i % Kit.CANDY.size()], 0.3)
		node.position = _random_point()
		var cone := _make_cone(Color(1.0, 0.5, 0.2, 0.16), BOT_CONE_RANGE, BOT_CONE_ANGLE)
		node.add_child(cone)
		add_child(node)
		bots.append({ "node": node, "cone": cone, "target": _random_point(),
			"speed": speed * randf_range(0.8, 1.2), "tagged": false })


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	round_label = Kit.label("ROUND 1", 72, Kit.MINT)
	round_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	round_label.offset_top = 48.0
	round_label.offset_bottom = 140.0
	layer.add_child(round_label)
	lives_label = Kit.label("♥♥♥", 54, Kit.PINK)
	lives_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lives_label.offset_top = 142.0
	lives_label.offset_bottom = 210.0
	layer.add_child(lives_label)
	danger_label = Kit.label("", 46, Kit.CORAL)
	danger_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	danger_label.offset_top = 215.0
	danger_label.offset_bottom = 275.0
	layer.add_child(danger_label)
	joystick = Joystick.new()
	joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	joystick.offset_top = 900.0
	layer.add_child(joystick)
	zap_button = Kit.button("ZAP!", 56, Kit.MAGENTA)
	zap_button.position = Vector2(770.0, 1700.0)
	zap_button.size = Vector2(270.0, 160.0)
	zap_button.pressed.connect(_on_zap)
	layer.add_child(zap_button)
	overlay = Kit.overlay("", Kit.MINT)
	var revive := Kit.button("REFILL ♥♥♥ · AD", 46, Kit.LIME)
	revive.name = "Revive"
	revive.position = Vector2(290.0, 1190.0)
	revive.size = Vector2(500.0, 110.0)
	revive.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("revive"))
	overlay.panel.add_child(revive)
	layer.add_child(overlay.panel)


func _refresh_ui() -> void:
	round_label.text = "ROUND %d" % round_number
	lives_label.text = "♥".repeat(maxi(lives, 0)) + ("  ✦" if invuln > 0.0 else "")
	var remaining := bots.filter(func(b: Dictionary) -> bool: return not b.tagged).size()
	if danger > 0.0:
		danger_label.text = "!! A BOT SEES YOU — RUN !!"
	else:
		danger_label.text = "%d bots hiding" % remaining
	_update_revive()
