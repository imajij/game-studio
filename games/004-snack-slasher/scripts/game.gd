extends Node2D
## Snack Slasher — swipe-to-slice arcade. Snacks get lobbed up in waves;
## drag across them to slice (combo per stroke). Don't slice Sir Soap.
## Dropped snacks cost lives. Rewarded revive once; interstitial on restart.

enum State { PLAYING, GAME_OVER }

const HIGH_SCORE_KEY: String = "high_score"

const MAX_LIVES: int = 3
const WAVE_GAP_START: float = 1.5
const WAVE_GAP_MIN: float = 0.75
const WAVE_RAMP: float = 0.008
const SOAP_CHANCE: float = 0.18
const FLOOR_Y: float = 2050.0
const COMBO_MIN: int = 3
const TRAIL_LIFE: float = 0.14
const RESTART_LOCKOUT_SEC: float = 0.6
const SHAKE_DECAY_PER_SEC: float = 9.0
const SHAKE_MAX_PX: float = 26.0

const SFX_SLICE: AudioStream = preload("res://assets/audio/slice.wav")
const SFX_SPLAT: AudioStream = preload("res://assets/audio/splat.wav")
const SFX_COMBO: AudioStream = preload("res://assets/audio/combo.wav")
const SFX_SOAP: AudioStream = preload("res://assets/audio/soap.wav")
const SFX_MISS: AudioStream = preload("res://assets/audio/miss.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var score: int = 0
var high_score: int = 0
var lives: int = MAX_LIVES
var elapsed: float = 0.0
var wave_timer: float = 1.0
var stroke_combo: int = 0
var swiping: bool = false
var last_touch: Vector2 = Vector2.ZERO
var trail: Array[Dictionary] = []
var revive_used: bool = false
var restarting: bool = false
var game_over_at_sec: float = 0.0
var shake_strength: float = 0.0

@onready var camera: Camera2D = $Camera
@onready var snacks: Node2D = $Snacks
@onready var deco: Deco = $Deco
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var lives_label: Label = $UI/LivesLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/GameOverLabel
@onready var final_score_label: Label = $UI/GameOverPanel/FinalScore
@onready var revive_button: Button = $UI/GameOverPanel/ReviveButton

func _ready() -> void:
	randomize()
	camera.make_current()
	deco.painter = _paint_trail
	revive_button.pressed.connect(_on_revive_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	high_score = int(SaveManager.get_value(HIGH_SCORE_KEY, 0))
	Analytics.log_event("round_start")
	_refresh_ui()


func _process(delta: float) -> void:
	if shake_strength > 0.3:
		shake_strength = maxf(shake_strength - shake_strength * SHAKE_DECAY_PER_SEC * delta, 0.0)
		camera.offset = Vector2(randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength))
	else:
		shake_strength = 0.0
		camera.offset = Vector2.ZERO
	var now := _now_sec()
	while not trail.is_empty() and now - float(trail[0].t) > TRAIL_LIFE:
		trail.pop_front()
	deco.queue_redraw()


func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	elapsed += delta
	wave_timer -= delta
	if wave_timer <= 0.0:
		_spawn_wave()
		wave_timer = maxf(WAVE_GAP_START - elapsed * WAVE_RAMP, WAVE_GAP_MIN)
	for node in snacks.get_children():
		var snack := node as Snack
		if snack == null:
			continue
		if snack.advance(delta):
			snack.queue_free()
			continue
		if not snack.sliced and snack.position.y > FLOOR_Y and snack.velocity.y > 0.0:
			snack.queue_free()
			if snack.kind != Snacks.SOAP:
				_drop_snack()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.GAME_OVER:
		var touch := event as InputEventScreenTouch
		if touch != null and touch.pressed:
			_try_restart()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			swiping = true
			stroke_combo = 0
			last_touch = touch.position
		else:
			swiping = false
			if stroke_combo >= COMBO_MIN:
				score += stroke_combo
				AudioManager.play_sfx(SFX_COMBO)
				Haptics.medium()
			_refresh_ui()
	elif event is InputEventScreenDrag and swiping:
		var drag := event as InputEventScreenDrag
		trail.append({"p": drag.position, "t": _now_sec()})
		_slice_segment(last_touch, drag.position)
		last_touch = drag.position


# --- slicing ----------------------------------------------------------------

func _slice_segment(from: Vector2, to: Vector2) -> void:
	if from.distance_to(to) < 4.0:
		return
	for node in snacks.get_children():
		var snack := node as Snack
		if snack == null or snack.sliced:
			continue
		if _segment_hits_circle(from, to, snack.position, snack.radius):
			_slice(snack)
			if state != State.PLAYING:
				return


func _slice(snack: Snack) -> void:
	snack.sliced = true
	if snack.kind == Snacks.SOAP:
		AudioManager.play_sfx(SFX_SOAP)
		_burst(snack.position, Color(0.7, 0.9, 1.0), 30)
		_add_shake(18.0)
		_game_over("YOU SLICED SIR SOAP")
		return
	score += 1
	stroke_combo += 1
	AudioManager.play_sfx(SFX_SLICE, 0.1)
	AudioManager.play_sfx(SFX_SPLAT, 0.08, 1.1 - snack.radius * 0.002)
	Haptics.light()
	_burst(snack.position, Snacks.COLORS[snack.kind], 18)
	_add_shake(3.0)
	if score > high_score:
		high_score = score
		SaveManager.set_value(HIGH_SCORE_KEY, high_score)
	_refresh_ui()


static func _segment_hits_circle(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	var ab := b - a
	var t := clampf((center - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return center.distance_to(a + ab * t) <= radius


# --- spawning ---------------------------------------------------------------

func _spawn_wave() -> void:
	var count := randi_range(1, 2 + int(elapsed / 25.0))
	for i in mini(count, 4):
		var kind := randi_range(0, Snacks.SOAP - 1)
		if randf() < SOAP_CHANCE:
			kind = Snacks.SOAP
		var x := randf_range(180.0, 900.0)
		var vel := Vector2(randf_range(-160.0, 160.0) + (540.0 - x) * 0.3,
			randf_range(-2350.0, -1950.0))
		var snack := Snack.new()
		snack.setup(kind, Vector2(x, 2000.0), vel)
		snacks.add_child(snack)


func _drop_snack() -> void:
	lives -= 1
	AudioManager.play_sfx(SFX_MISS)
	Haptics.medium()
	_add_shake(6.0)
	_refresh_ui()
	if lives <= 0:
		_game_over("OUT OF SNACKS")


# --- round end / revive -----------------------------------------------------

func _game_over(reason: String) -> void:
	state = State.GAME_OVER
	game_over_at_sec = _now_sec()
	swiping = false
	SaveManager.set_value(HIGH_SCORE_KEY, high_score)
	Analytics.log_event("game_over", {"score": score})
	AdsManager.round_finished()
	AudioManager.play_sfx(SFX_GAME_OVER)
	Haptics.heavy()
	game_over_label.text = reason
	final_score_label.text = "SCORE %d\nBEST %d" % [score, high_score]
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
	lives = MAX_LIVES
	for node in snacks.get_children():
		node.queue_free()
	state = State.PLAYING
	game_over_panel.visible = false
	Analytics.log_event("revive_used")
	Haptics.medium()
	_refresh_ui()


func _try_restart() -> void:
	if restarting or _now_sec() - game_over_at_sec < RESTART_LOCKOUT_SEC:
		return
	restarting = true
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


# --- helpers ----------------------------------------------------------------

func _burst(at: Vector2, color: Color, amount: int) -> void:
	var burst := CPUParticles2D.new()
	burst.position = at
	burst.one_shot = true
	burst.emitting = true
	burst.amount = amount
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2(0.0, 900.0)
	burst.initial_velocity_min = 260.0
	burst.initial_velocity_max = 520.0
	burst.scale_amount_min = 4.0
	burst.scale_amount_max = 10.0
	burst.color = color
	add_child(burst)
	burst.finished.connect(burst.queue_free)


func _add_shake(amount: float) -> void:
	shake_strength = minf(shake_strength + amount, SHAKE_MAX_PX)


func _refresh_ui() -> void:
	score_label.text = str(score)
	best_label.text = "BEST %d" % high_score
	lives_label.text = "LIVES %d" % maxi(lives, 0)


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


func _paint_trail(canvas: CanvasItem) -> void:
	if trail.size() < 2:
		return
	for i in range(1, trail.size()):
		var alpha := float(i) / trail.size()
		canvas.draw_line(trail[i - 1].p, trail[i].p, Color(1.0, 1.0, 1.0, alpha * 0.8),
			10.0 * alpha + 2.0)
