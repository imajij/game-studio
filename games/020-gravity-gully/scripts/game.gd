extends Node3D
## Gravity Gully — endless runner down a candy canyon where swiping UP flips
## gravity: run the floor, flip to the ceiling, thread the blocks on both.
## Swipe left/right to change lanes. Coins + distance; speed only climbs.
## Rewarded ad = one revive; interstitial on restart.

enum State { RUNNING, DEAD }

const LANES: Array[float] = [-2.1, 0.0, 2.1]
const CANYON_H: float = 5.6
const BASE_SPEED: float = 9.0
const SPEED_PER_M: float = 0.035
const MAX_SPEED: float = 22.0
const SPAWN_EVERY: float = 7.0
const HIT_Z: float = 0.7
const SWIPE_PX: float = 70.0
const FLIP_SECONDS: float = 0.28
const BEST_KEY: String = "best"
const COINS_KEY: String = "coins"

const SFX_FLIP: AudioStream = preload("res://assets/audio/flip.wav")
const SFX_COIN: AudioStream = preload("res://assets/audio/coin.wav")
const SFX_CRASH: AudioStream = preload("res://assets/audio/crash.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.RUNNING
var distance: float = 0.0
var coins: int = 0
var bank: int = 0
var best: int = 0
var lane: int = 1
var on_ceiling: bool = false
var flipping: float = 0.0
var next_spawn_z: float = -30.0
var revive_used: bool = false
var restarting: bool = false
var touch_start: Vector2 = Vector2.ZERO
var touching: bool = false

var player: Node3D = null
var player_body: Node3D = null
var cam: Camera3D = null
var trail: CPUParticles3D = null
var obstacles: Array = []  # {node, lane, ceiling, z, coin, dead}
var wall_chunks: Array = []

var score_label: Label = null
var coin_label: Label = null
var overlay: Dictionary = {}

func _ready() -> void:
	randomize()
	best = int(SaveManager.get_value(BEST_KEY, 0))
	bank = int(SaveManager.get_value(COINS_KEY, 0))
	_build_world()
	_build_ui()
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	Analytics.log_event("round_start")


func speed() -> float:
	return minf(BASE_SPEED + distance * SPEED_PER_M, MAX_SPEED)


func _process(delta: float) -> void:
	if state != State.RUNNING:
		return
	distance += speed() * delta
	player.position.z -= speed() * delta
	# lane + surface easing
	var target_y := CANYON_H - 0.0 if on_ceiling else 0.0
	player.position.x = lerpf(player.position.x, LANES[lane], 14.0 * delta)
	player.position.y = lerpf(player.position.y, target_y, 10.0 * delta)
	flipping = maxf(flipping - delta, 0.0)
	player_body.rotation.z = lerp_angle(player_body.rotation.z, PI if on_ceiling else 0.0, 12.0 * delta)
	# run bob
	player_body.position.y = (0.12 if not on_ceiling else -0.12) * absf(sin(distance * 2.2))
	# camera chase at canyon middle
	cam.position = Vector3(player.position.x * 0.5, CANYON_H * 0.5, player.position.z + 7.5)
	cam.look_at(Vector3(player.position.x * 0.5, CANYON_H * 0.45, player.position.z - 6.0))
	# spawn + recycle
	while next_spawn_z > player.position.z - 70.0:
		_spawn_row(next_spawn_z)
		next_spawn_z -= SPAWN_EVERY
	_collide()
	_recycle_walls()
	score_label.text = "%dm" % int(distance)
	coin_label.text = "● %d" % coins


func _spawn_row(z: float) -> void:
	# block 1-2 lanes per surface, never all three on one surface
	for surface in 2:
		var ceiling := surface == 1
		var blocked := []
		var count := randi_range(0, 2)
		var lanes := [0, 1, 2]
		lanes.shuffle()
		for i in count:
			blocked.append(lanes[i])
			var block := Kit.box(Vector3(1.6, 1.5, 1.2), Kit.CANDY[randi() % Kit.CANDY.size()], true)
			block.position = Vector3(LANES[lanes[i]], (CANYON_H - 0.75) if ceiling else 0.75, z)
			add_child(block)
			obstacles.append({ "node": block, "lane": lanes[i], "ceiling": ceiling,
				"z": z, "coin": false, "dead": false })
		# a coin on one open lane
		if randf() < 0.7:
			var open: Array = [0, 1, 2].filter(func(l: int) -> bool: return not blocked.has(l))
			if not open.is_empty():
				var pick: int = open[randi() % open.size()]
				var coin := Kit.cyl(0.34, 0.1, Kit.SUN)
				coin.rotation.x = PI / 2.0
				coin.position = Vector3(LANES[pick], (CANYON_H - 0.9) if ceiling else 0.9, z)
				add_child(coin)
				obstacles.append({ "node": coin, "lane": pick, "ceiling": ceiling,
					"z": z, "coin": true, "dead": false })


func _collide() -> void:
	var pz := player.position.z
	for o: Dictionary in obstacles:
		if o.dead:
			continue
		var node: Node3D = o.node
		if node.position.z > pz + 12.0:
			o.dead = true
			node.queue_free()
			continue
		if absf(node.position.z - pz) > HIT_Z or o.ceiling != on_ceiling or o.lane != lane:
			continue
		if flipping > 0.0 and not o.coin:
			continue  # brief grace mid-flip
		o.dead = true
		if o.coin:
			coins += 1
			AudioManager.play_sfx(SFX_COIN, 0.06)
			Haptics.light()
			Kit.burst(self, node.position, Kit.SUN, 10, 3.0)
			node.queue_free()
		else:
			node.queue_free()
			_crash()
			return


func _crash() -> void:
	state = State.DEAD
	AudioManager.play_sfx(SFX_CRASH)
	AudioManager.play_sfx(SFX_GAME_OVER)
	Haptics.heavy()
	Kit.burst(self, player.position + Vector3.UP * 0.4, Kit.RED, 36, 7.0)
	trail.emitting = false
	bank += coins
	var total := int(distance)
	if total > best:
		best = total
		SaveManager.set_value(BEST_KEY, best)
	SaveManager.set_value(COINS_KEY, bank)
	Analytics.log_event("game_over", {"m": total})
	AdsManager.round_finished()
	overlay.title.text = "WIPEOUT!"
	overlay.body.text = "%dm  ● %d\nBEST %dm   BANK ● %d\n\ntap to run again" % [total, coins, best, bank]
	overlay.panel.visible = true
	_update_revive()


func _update_revive() -> void:
	var revive: Button = overlay.panel.get_node_or_null("Revive")
	if revive != null:
		revive.visible = state == State.DEAD and not revive_used and AdsManager.is_rewarded_ready()


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "revive" or state != State.DEAD:
		return
	revive_used = true
	# clear nearby obstacles and keep running
	for o: Dictionary in obstacles:
		if not o.dead and absf(o.node.position.z - player.position.z) < 14.0 and not o.coin:
			o.dead = true
			o.node.queue_free()
	state = State.RUNNING
	trail.emitting = true
	overlay.panel.visible = false
	Analytics.log_event("revive_used")
	Haptics.medium()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.DEAD:
		var end_touch := event as InputEventScreenTouch
		if end_touch != null and end_touch.pressed:
			var revive: Button = overlay.panel.get_node_or_null("Revive")
			if revive != null and revive.visible and revive.get_global_rect().has_point(end_touch.position):
				return
			if restarting:
				return
			restarting = true
			if AdsManager.maybe_show_interstitial():
				await AdsManager.interstitial_closed
			get_tree().reload_current_scene()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		touching = touch.pressed
		if touch.pressed:
			touch_start = touch.position
	elif event is InputEventScreenDrag and touching:
		var drag := event as InputEventScreenDrag
		var d := drag.position - touch_start
		if absf(d.x) >= SWIPE_PX and absf(d.x) > absf(d.y):
			touching = false
			lane = clampi(lane + (1 if d.x > 0.0 else -1), 0, 2)
			Haptics.light()
		elif absf(d.y) >= SWIPE_PX:
			touching = false
			on_ceiling = not on_ceiling
			flipping = FLIP_SECONDS
			AudioManager.play_sfx(SFX_FLIP)
			Haptics.medium()
			Kit.burst(self, player.position, Kit.TEAL, 14, 4.0)


# --- world ------------------------------------------------------------------

func _build_world() -> void:
	Kit.sky(self, Color(1.0, 0.55, 0.45), Color(1.0, 0.85, 0.45), Color(0.9, 0.4, 0.5))
	cam = Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	player = Node3D.new()
	player_body = Kit.blobby(Kit.TEAL, 0.3)
	player.add_child(player_body)
	add_child(player)
	player.position = Vector3(0.0, 0.0, 0.0)
	trail = CPUParticles3D.new()
	trail.amount = 24
	trail.lifetime = 0.45
	trail.direction = Vector3(0, 0, 1)
	trail.initial_velocity_min = 2.0
	trail.initial_velocity_max = 3.0
	trail.scale_amount_min = 0.3
	trail.scale_amount_max = 0.6
	var pm := SphereMesh.new()
	pm.radius = 0.1
	pm.height = 0.2
	trail.mesh = pm
	trail.color = Kit.MINT
	player.add_child(trail)
	for i in 14:
		_make_wall_chunk(-i * 10.0)


func _make_wall_chunk(z: float) -> void:
	var chunk := Node3D.new()
	chunk.position.z = z
	var floor_mesh := Kit.texbox(Vector3(7.4, 0.5, 10.0), "tex2", Kit.TEAL.darkened(0.15), 1.0)
	floor_mesh.position.y = -0.25
	chunk.add_child(floor_mesh)
	var ceil_mesh := Kit.box(Vector3(7.4, 0.5, 10.0), Kit.SUN, true)
	ceil_mesh.position.y = CANYON_H + 0.25
	chunk.add_child(ceil_mesh)
	for side: float in [-1.0, 1.0]:
		var wall := Kit.texbox(Vector3(0.6, CANYON_H + 1.0, 10.0), "tex1",
			(Kit.PINK if side < 0.0 else Kit.ORANGE).lightened(0.05 * (int(absf(z)) % 3)), 1.0)
		wall.position = Vector3(side * 4.0, CANYON_H * 0.5, 0.0)
		chunk.add_child(wall)
	add_child(chunk)
	wall_chunks.append(chunk)


func _recycle_walls() -> void:
	for chunk: Node3D in wall_chunks:
		if chunk.position.z > player.position.z + 18.0:
			chunk.position.z -= 140.0


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	score_label = Kit.label("0m", 92, Color.WHITE)
	score_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	score_label.offset_top = 46.0
	score_label.offset_bottom = 160.0
	layer.add_child(score_label)
	coin_label = Kit.label("● 0", 52, Kit.SUN)
	coin_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	coin_label.offset_top = 162.0
	coin_label.offset_bottom = 230.0
	layer.add_child(coin_label)
	var hint := Kit.label("swipe ←→ lanes · swipe ↑ FLIP GRAVITY", 40, Color(1, 1, 1, 0.75))
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 1700.0
	hint.offset_bottom = 1760.0
	layer.add_child(hint)
	overlay = Kit.overlay("WIPEOUT!", Kit.CORAL)
	var revive := Kit.button("REVIVE · AD", 48, Kit.LIME)
	revive.name = "Revive"
	revive.position = Vector2(320.0, 1190.0)
	revive.size = Vector2(440.0, 110.0)
	revive.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("revive"))
	overlay.panel.add_child(revive)
	layer.add_child(overlay.panel)
