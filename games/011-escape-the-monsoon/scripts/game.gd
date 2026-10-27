extends Node2D
## Escape the Monsoon — 3-lane runner. The flood wave is always behind you;
## swipe between lanes, jump the low stuff, dodge the solid stuff. Every hit
## lets the wave catch up. Themes rotate mid-run: flood → aunty stampede →
## wedding baraat. Rewarded revive, interstitial on restart.

enum State { PLAYING, GAME_OVER }

const BEST_KEY: String = "best"
const THEME_NAMES: Array[String] = ["FLOOD!", "AUNTY STAMPEDE!", "BARAAT INCOMING!"]
const THEME_EVERY_M: int = 400

const LANES: Array[float] = [270.0, 540.0, 810.0]
const PLAYER_Y: float = 1480.0
const BASE_SPEED: float = 520.0
const SPEED_PER_M: float = 0.45
const MAX_SPEED: float = 1150.0
const SPAWN_EVERY_M: float = 95.0
const JUMP_SEC: float = 0.52
const HIT_WAVE_PENALTY: float = 32.0
const WAVE_START: float = 100.0
const WAVE_MAX: float = 130.0
const WAVE_REGEN_PER_SEC: float = 3.2
const HIT_RADIUS: float = 95.0
const SWIPE_PX: float = 70.0
const INVULN_SEC: float = 1.1
const UMBRELLA_POINTS: int = 25
const RESTART_LOCKOUT_SEC: float = 0.6

const SFX_SWIPE: AudioStream = preload("res://assets/audio/swipe.wav")
const SFX_SPLASH: AudioStream = preload("res://assets/audio/splash.wav")
const SFX_CRASH: AudioStream = preload("res://assets/audio/crash.wav")
const SFX_PICKUP: AudioStream = preload("res://assets/audio/pickup.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var distance: float = 0.0
var score: int = 0
var best: int = 0
var lane: int = 1
var player_x: float = LANES[1]
var jump_left: float = 0.0
var invuln_left: float = 0.0
var wave: float = WAVE_START  # 0 = caught
var next_spawn_at: float = SPAWN_EVERY_M
var theme_id: int = 0
var theme_flash: float = 0.0
var revive_used: bool = false
var restarting: bool = false
var game_over_at_sec: float = 0.0
var touch_start: Vector2 = Vector2.ZERO
var touching: bool = false
var rain_seed: float = 0.0

@onready var deco: Deco = $Deco
@onready var obstacles: Node2D = $Obstacles
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var theme_label: Label = $UI/ThemeLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_score_label: Label = $UI/GameOverPanel/FinalScore
@onready var revive_button: Button = $UI/GameOverPanel/ReviveButton

func _ready() -> void:
	randomize()
	deco.painter = _paint
	revive_button.pressed.connect(_on_revive_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	best = int(SaveManager.get_value(BEST_KEY, 0))
	Analytics.log_event("round_start")
	_refresh_ui()


func _process(delta: float) -> void:
	rain_seed += delta
	deco.queue_redraw()
	if state != State.PLAYING:
		return
	var speed := minf(BASE_SPEED + distance * SPEED_PER_M, MAX_SPEED)
	distance += speed * delta / 10.0  # ~meters
	wave = minf(wave + WAVE_REGEN_PER_SEC * delta, WAVE_MAX)
	jump_left = maxf(jump_left - delta, 0.0)
	invuln_left = maxf(invuln_left - delta, 0.0)
	theme_flash = maxf(theme_flash - delta, 0.0)
	player_x = lerpf(player_x, LANES[lane], 14.0 * delta)
	var new_theme := int(distance / THEME_EVERY_M) % THEME_NAMES.size()
	if new_theme != theme_id:
		theme_id = new_theme
		theme_flash = 1.4
		theme_label.text = THEME_NAMES[theme_id]
		AudioManager.play_sfx(SFX_SWIPE)
	if distance >= next_spawn_at:
		next_spawn_at += SPAWN_EVERY_M
		_spawn_row()
	_scroll_and_collide(speed * delta)
	_refresh_ui()


func _spawn_row() -> void:
	var open_lane := randi() % 3
	for l in 3:
		if l == open_lane:
			if randf() < 0.22:
				_spawn_one(l, 2)
			continue
		var roll := randf()
		if roll < 0.42:
			_spawn_one(l, 0)
		elif roll < 0.72:
			_spawn_one(l, 1)


func _spawn_one(in_lane: int, kind: int) -> void:
	var ob := MonsoonObstacle.new()
	ob.position = Vector2(LANES[in_lane], -140.0)
	obstacles.add_child(ob)
	ob.setup(theme_id, kind)


func _scroll_and_collide(dy: float) -> void:
	for child in obstacles.get_children():
		var ob := child as MonsoonObstacle
		if ob == null:
			continue
		ob.position.y += dy
		if ob.position.y > 2050.0:
			ob.queue_free()
			continue
		if ob.done or absf(ob.position.y - PLAYER_Y) > HIT_RADIUS \
				or absf(ob.position.x - player_x) > HIT_RADIUS:
			continue
		match ob.kind:
			2:
				ob.done = true
				ob.queue_free()
				score += UMBRELLA_POINTS
				AudioManager.play_sfx(SFX_PICKUP, 0.05)
				Haptics.light()
			1:
				if jump_left > 0.0:
					continue
				ob.done = true
				_hit()
			0:
				ob.done = true
				_hit()


func _hit() -> void:
	if invuln_left > 0.0:
		return
	invuln_left = INVULN_SEC
	wave -= HIT_WAVE_PENALTY
	AudioManager.play_sfx(SFX_SPLASH if theme_id == 0 else SFX_CRASH)
	Haptics.heavy()
	if wave <= 0.0:
		_game_over()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.GAME_OVER:
		var end_touch := event as InputEventScreenTouch
		if end_touch != null and end_touch.pressed \
				and not revive_button.get_global_rect().has_point(end_touch.position):
			_try_restart()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			touching = true
			touch_start = touch.position
		else:
			touching = false
	elif event is InputEventScreenDrag and touching:
		var drag := event as InputEventScreenDrag
		var d := drag.position - touch_start
		if absf(d.x) >= SWIPE_PX and absf(d.x) > absf(d.y):
			touching = false
			lane = clampi(lane + (1 if d.x > 0.0 else -1), 0, 2)
			AudioManager.play_sfx(SFX_SWIPE, 0.1)
			Haptics.light()
		elif d.y <= -SWIPE_PX:
			touching = false
			if jump_left <= 0.0:
				jump_left = JUMP_SEC
				AudioManager.play_sfx(SFX_SWIPE, 0.1, 1.3)
				Haptics.light()


func _game_over() -> void:
	state = State.GAME_OVER
	game_over_at_sec = _now_sec()
	score += int(distance)
	if score > best:
		best = score
		SaveManager.set_value(BEST_KEY, best)
	Analytics.log_event("game_over", {"score": score})
	AdsManager.round_finished()
	AudioManager.play_sfx(SFX_GAME_OVER)
	Haptics.heavy()
	final_score_label.text = "%dm + %d bonus\nSCORE %d   BEST %d" \
		% [int(distance), score - int(distance), score, best]
	revive_button.visible = not revive_used and AdsManager.is_rewarded_ready()
	game_over_panel.visible = true


func _on_revive_pressed() -> void:
	if state != State.GAME_OVER or revive_used:
		return
	AudioManager.play_sfx(SFX_TAP)
	AdsManager.show_rewarded("revive")


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "revive" or state != State.GAME_OVER:
		return
	revive_used = true
	score -= int(distance)  # distance keeps counting; avoid double-add
	wave = WAVE_START
	invuln_left = 2.0
	state = State.PLAYING
	game_over_panel.visible = false
	for child in obstacles.get_children():
		child.queue_free()
	Analytics.log_event("revive_used")
	Haptics.medium()


func _try_restart() -> void:
	if restarting or _now_sec() - game_over_at_sec < RESTART_LOCKOUT_SEC:
		return
	restarting = true
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


func _refresh_ui() -> void:
	score_label.text = "%dm" % int(distance)
	best_label.text = "BEST %d" % best
	theme_label.visible = theme_flash > 0.0 or distance < 30.0
	if distance < 30.0:
		theme_label.text = THEME_NAMES[0]


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


func _paint(canvas: CanvasItem) -> void:
	# road + lanes
	canvas.draw_rect(Rect2(120.0, 0.0, 840.0, 1920.0), Color(0.16, 0.18, 0.22))
	for x in [405.0, 675.0]:
		var scroll := fmod(distance * 10.0, 160.0)
		for i in 14:
			var y := i * 160.0 - scroll
			canvas.draw_line(Vector2(x, y), Vector2(x, y + 80.0), Color(0.35, 0.38, 0.45), 8.0)
	# rain
	for i in 40:
		var rx := fmod(i * 173.3 + rain_seed * 90.0, 1080.0)
		var ry := fmod(i * 311.7 + rain_seed * (1400.0 + (i % 5) * 120.0), 1920.0)
		canvas.draw_line(Vector2(rx, ry), Vector2(rx - 10.0, ry + 34.0),
			Color(0.6, 0.7, 0.9, 0.25), 3.0)
	# player
	var py := PLAYER_Y - (sin(PI * (1.0 - jump_left / JUMP_SEC)) * 90.0 if jump_left > 0.0 else 0.0)
	var jump_scale := 1.0 + (0.25 if jump_left > 0.0 else 0.0)
	var blink := invuln_left > 0.0 and fmod(invuln_left, 0.2) < 0.1
	if not blink:
		canvas.draw_set_transform(Vector2(player_x, PLAYER_Y + 60.0), 0.0, Vector2(1.0, 0.3))
		canvas.draw_circle(Vector2.ZERO, 70.0, Color(0.0, 0.0, 0.0, 0.3))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		canvas.draw_circle(Vector2(player_x, py), 62.0 * jump_scale, Color(0.25, 0.2, 0.3))
		canvas.draw_circle(Vector2(player_x, py), 54.0 * jump_scale, Color(0.95, 0.75, 0.3))
		canvas.draw_circle(Vector2(player_x, py - 20.0 * jump_scale), 30.0 * jump_scale,
			Color(0.9, 0.7, 0.55))
		for side in [-1.0, 1.0]:
			canvas.draw_circle(Vector2(player_x + side * 10.0, py - 24.0), 5.0, Color(0.1, 0.1, 0.15))
	# flood wave at the bottom — closer = taller
	var danger := 1.0 - clampf(wave / WAVE_MAX, 0.0, 1.0)
	var wave_h := 90.0 + danger * 330.0
	var wave_top := 1920.0 - wave_h
	canvas.draw_rect(Rect2(0.0, wave_top, 1080.0, wave_h), Color(0.22, 0.42, 0.65, 0.92))
	for i in 11:
		var wx := i * 108.0 + fmod(rain_seed * 220.0, 108.0)
		canvas.draw_circle(Vector2(wx, wave_top), 36.0, Color(0.32, 0.55, 0.78, 0.92))
	canvas.draw_rect(Rect2(0.0, wave_top + 20.0, 1080.0, 14.0), Color(0.75, 0.88, 0.98, 0.5))
