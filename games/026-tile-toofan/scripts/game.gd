extends Node3D
## Tile Toofan — shortcut-run ad genre: hoover up rainbow tiles, they stack on
## your back, and every stretch of water silently eats one tile per plank to
## bridge your steps. Run dry mid-water and it's a splash. Survivors ride the
## multiplier runway: leftover tiles become distance, distance becomes coins.
## Rewarded ad = +15 golden tiles at the start; interstitial at results.

enum State { READY, RUNNING, SLIDE, RESULT }

const RUN_SPEED: float = 8.5
const STEER_LIMIT: float = 3.0
const TILE_CAP: int = 40
const PLANK_EVERY: float = 0.55
const LEVEL_KEY: String = "level"
const COINS_KEY: String = "coins"

const SFX_TILE: AudioStream = preload("res://assets/audio/tile.wav")
const SFX_BRIDGE: AudioStream = preload("res://assets/audio/bridge.wav")
const SFX_SPLASH: AudioStream = preload("res://assets/audio/splash.wav")
const SFX_FINISH: AudioStream = preload("res://assets/audio/finish.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.READY
var level: int = 1
var coins: int = 0
var tiles: int = 0
var course_len: float = 0.0
var water_spans: Array = []   # [z_start, z_end] (negative z, start > end)
var pickups: Array = []       # {node, z, x, got}
var next_plank_z: float = 0.0
var slide_left: float = 0.0
var zone_mult: int = 1
var golden: bool = false
var restarting: bool = false
var drag_x: float = 0.0
var touching: bool = false
var touch_start: Vector2 = Vector2.ZERO
var start_x: float = 0.0

var player: Node3D = null
var stack_root: Node3D = null
var cam: Camera3D = null
var tiles_label: Label = null
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
	tiles_label.text = "tiles %d / %d" % [tiles, TILE_CAP]
	level_label.text = "TOOFAN %d   ₹%d" % [level, coins]
	if state == State.RUNNING:
		_run(delta)
	elif state == State.SLIDE:
		_slide(delta)


func _run(delta: float) -> void:
	player.position.z -= RUN_SPEED * delta
	player.position.x = lerpf(player.position.x, drag_x, 10.0 * delta)
	cam.position = Vector3(player.position.x * 0.4, 7.0, player.position.z + 9.0)
	cam.look_at(Vector3(player.position.x * 0.4, 0.4, player.position.z - 5.0))
	var pz := player.position.z
	# pickups
	for p: Dictionary in pickups:
		if p.got or absf(p.z - pz) > 0.6 or absf(p.x - player.position.x) > 0.8:
			continue
		if tiles >= TILE_CAP:
			continue
		p.got = true
		p.node.queue_free()
		tiles += 1
		AudioManager.play_sfx(SFX_TILE, 0.08, 1.0 + tiles * 0.015)
		Haptics.light()
		_rebuild_stack()
	# water
	if _over_water(pz):
		if pz <= next_plank_z:
			next_plank_z = pz - PLANK_EVERY
			if tiles <= 0:
				_splash()
				return
			tiles -= 1
			_rebuild_stack()
			AudioManager.play_sfx(SFX_BRIDGE, 0.1)
			var plank := Kit.box(Vector3(1.1, 0.12, 0.5), Kit.CANDY[tiles % Kit.CANDY.size()])
			plank.position = Vector3(player.position.x, 0.05, pz)
			add_child(plank)
	else:
		next_plank_z = pz
	if pz <= -course_len:
		_start_slide()


func _over_water(z: float) -> bool:
	for span: Array in water_spans:
		if z <= span[0] and z >= span[1]:
			return true
	return false


func _splash() -> void:
	state = State.RESULT
	AudioManager.play_sfx(SFX_SPLASH)
	AudioManager.play_sfx(SFX_GAME_OVER)
	Haptics.heavy()
	Kit.burst(self, player.position, Kit.SKY, 30, 6.0)
	var tween := create_tween()
	tween.tween_property(player, "position:y", -1.6, 0.4)
	Analytics.log_event("game_over", {"won": false, "level": level})
	AdsManager.round_finished()
	overlay.title.text = "SPLASH!"
	overlay.body.text = "ran out of tiles over water\n\ntap to retry toofan %d" % level
	overlay.panel.visible = true


func _start_slide() -> void:
	state = State.SLIDE
	slide_left = tiles * 0.85
	AudioManager.play_sfx(SFX_FINISH)
	Haptics.medium()


func _slide(delta: float) -> void:
	var step := minf(RUN_SPEED * 1.4 * delta, slide_left)
	player.position.z -= step
	slide_left -= step
	cam.position = Vector3(player.position.x * 0.4, 7.0, player.position.z + 9.0)
	cam.look_at(Vector3(0.0, 0.4, player.position.z - 5.0))
	var past := -(player.position.z + course_len)
	zone_mult = clampi(1 + int(past / 7.0), 1, 5)
	if slide_left <= 0.01:
		var pay := maxi(tiles, 1) * zone_mult * 2
		coins += pay
		level += 1
		SaveManager.set_value(LEVEL_KEY, level)
		SaveManager.set_value(COINS_KEY, coins)
		state = State.RESULT
		for i in 3:
			Kit.burst(self, player.position + Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)),
				Kit.CANDY[i], 30, 8.0)
		AudioManager.play_sfx(SFX_FINISH)
		Analytics.log_event("game_over", {"won": true, "level": level - 1})
		AdsManager.round_finished()
		overlay.title.text = "×%d LANDING!" % zone_mult
		overlay.body.text = "%d tiles × %d = ₹%d\nbank ₹%d\n\ntap for toofan %d" \
			% [tiles, zone_mult, pay, coins, level]
		overlay.panel.visible = true


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "golden" or state != State.READY:
		return
	golden = true
	tiles = 15
	_rebuild_stack()
	Analytics.log_event("golden_used")
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
				var gold: Button = start_panel.get_node_or_null("Gold")
				if gold != null and gold.visible and gold.get_global_rect().has_point(t.position):
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


# --- world ------------------------------------------------------------------

func _build_world() -> void:
	Kit.sky(self, Kit.SKY, Color(1.0, 0.88, 0.62), Color(0.3, 0.6, 0.8))
	cam = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	player = Node3D.new()
	player.add_child(Kit.chara(Kit.MAGENTA, 1.0, 0))
	stack_root = Node3D.new()
	stack_root.position = Vector3(0.0, 0.35, 0.55)
	player.add_child(stack_root)
	add_child(player)


func _build_course() -> void:
	course_len = 90.0 + level * 18.0
	var z := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 1337
	# big water world below
	var sea := Kit.texbox(Vector3(60.0, 0.3, course_len + 120.0), "tex1", Color(0.25, 0.6, 0.85), 1.0)
	sea.position = Vector3(0.0, -0.4, -course_len / 2.0)
	add_child(sea)
	while z > -course_len:
		var land_len := rng.randf_range(14.0, 22.0)
		var strip := Kit.box(Vector3(8.0, 0.5, land_len), Kit.LIME, true)
		strip.position = Vector3(0.0, -0.25, z - land_len / 2.0)
		add_child(strip)
		# tiles on this strip
		var n := int(land_len / 1.6)
		for i in n:
			for lane in 3:
				if rng.randf() < 0.45:
					var tz := z - 2.0 - i * 1.6
					var tx: float = [-2.0, 0.0, 2.0][lane] + rng.randf_range(-0.4, 0.4)
					var tile := Kit.box(Vector3(0.9, 0.1, 0.9), Kit.CANDY[rng.randi() % Kit.CANDY.size()])
					tile.position = Vector3(tx, 0.08, tz)
					add_child(tile)
					pickups.append({ "node": tile, "z": tz, "x": tx, "got": false })
		z -= land_len
		# water gap
		var gap := rng.randf_range(4.0, 7.0 + level * 0.6)
		water_spans.append([z, z - gap])
		z -= gap
	# finish runway with multiplier zones
	var runway_z := -course_len
	for m in 5:
		var zone := Kit.box(Vector3(8.0, 0.5, 7.0), Kit.CANDY[m * 2 % Kit.CANDY.size()], true)
		zone.position = Vector3(0.0, -0.25, runway_z - 3.5 - m * 7.0)
		add_child(zone)
		var text := Label3D.new()
		text.text = "×%d" % int([1, 2, 3, 4, 5][m])
		text.font_size = 240
		text.pixel_size = 0.012
		text.rotation.x = -PI / 2.0
		text.position = Vector3(0.0, 0.1, runway_z - 3.5 - m * 7.0)
		text.outline_size = 48
		add_child(text)


func _rebuild_stack() -> void:
	for child in stack_root.get_children():
		child.queue_free()
	for i in tiles:
		var t := Kit.box(Vector3(0.5, 0.08, 0.5),
			Kit.SUN if golden and i < 15 else Kit.CANDY[i % Kit.CANDY.size()])
		t.position.y = 0.55 + i * 0.09
		stack_root.add_child(t)


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	tiles_label = Kit.label("tiles 0", 72, Color.WHITE)
	tiles_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tiles_label.offset_top = 44.0
	tiles_label.offset_bottom = 136.0
	layer.add_child(tiles_label)
	level_label = Kit.label("TOOFAN 1", 48, Kit.SUN)
	level_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_top = 140.0
	level_label.offset_bottom = 205.0
	layer.add_child(level_label)
	overlay = Kit.overlay("", Kit.MINT)
	layer.add_child(overlay.panel)
	start_panel = Control.new()
	start_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint := Kit.label("grab tiles — water takes one per step\nleftovers = multiplier cash\n\ntap to run", 48)
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 1280.0
	hint.offset_bottom = 1560.0
	start_panel.add_child(hint)
	var gold := Kit.button("+15 GOLD TILES · AD", 46, Kit.PURPLE)
	gold.name = "Gold"
	gold.position = Vector2(250.0, 1600.0)
	gold.size = Vector2(580.0, 115.0)
	gold.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("golden"))
	start_panel.add_child(gold)
	layer.add_child(start_panel)
