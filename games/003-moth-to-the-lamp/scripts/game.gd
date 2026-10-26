extends Node2D
## Moth to the Lamp — endless vertical climb. The world scrolls down past
## Mothias; hold a screen half to flutter that way, dodge hazards, grab
## sparkles. Rewarded revive once per round; interstitial on restart.

enum State { PLAYING, GAME_OVER }

const HIGH_SCORE_KEY: String = "high_score"

const MOTH_Y: float = 1300.0
const MOTH_RADIUS: float = 42.0
const MOTH_MIN_X: float = 70.0
const MOTH_MAX_X: float = 1010.0
const MOTH_SPEED: float = 560.0
const MOTH_ACCEL: float = 2600.0

const BASE_SCROLL: float = 270.0
const MAX_EXTRA_SCROLL: float = 360.0
const SCROLL_RAMP_PER_SEC: float = 7.0
const BASE_SPAWN_GAP: float = 1.1
const MIN_SPAWN_GAP: float = 0.55
const SPAWN_Y: float = -260.0
const DESPAWN_Y: float = 2200.0
const SPARKLE_POINTS: int = 5
const PX_PER_METER: float = 100.0
const REVIVE_INVINCIBLE_SEC: float = 1.6
const REVIVE_CLEAR_RADIUS: float = 650.0
const RESTART_LOCKOUT_SEC: float = 0.6
const SHAKE_DECAY_PER_SEC: float = 9.0
const SHAKE_MAX_PX: float = 26.0

const SFX_FLAP: AudioStream = preload("res://assets/audio/flap.wav")
const SFX_SPARKLE: AudioStream = preload("res://assets/audio/sparkle.wav")
const SFX_HIT: AudioStream = preload("res://assets/audio/hit.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var height_px: float = 0.0
var sparkle_score: int = 0
var high_score: int = 0
var elapsed: float = 0.0
var held_dir: int = 0
var moth_vx: float = 0.0
var spawn_timer: float = 0.0
var revive_used: bool = false
var invincible_left: float = 0.0
var restarting: bool = false
var game_over_at_sec: float = 0.0
var shake_strength: float = 0.0

@onready var camera: Camera2D = $Camera
@onready var moth: Moth = $Moth
@onready var obstacles: Node2D = $Obstacles
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_score_label: Label = $UI/GameOverPanel/FinalScore
@onready var revive_button: Button = $UI/GameOverPanel/ReviveButton

func _ready() -> void:
	randomize()
	camera.make_current()
	moth.position = Vector2(540.0, MOTH_Y)
	revive_button.pressed.connect(_on_revive_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(_on_rewarded_closed)
	AdsManager.rewarded_unavailable.connect(_on_rewarded_closed)
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


func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	elapsed += delta
	if invincible_left > 0.0:
		invincible_left -= delta
		moth.invincible = invincible_left > 0.0
	var scroll := scroll_speed() * delta
	height_px += scroll

	var target_vx := held_dir * MOTH_SPEED
	moth_vx = move_toward(moth_vx, target_vx, MOTH_ACCEL * delta)
	moth.position.x = clampf(moth.position.x + moth_vx * delta, MOTH_MIN_X, MOTH_MAX_X)

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_wave()
		spawn_timer = maxf(BASE_SPAWN_GAP - elapsed * 0.01, MIN_SPAWN_GAP)

	for node in obstacles.get_children():
		var ob := node as MothObstacle
		if ob == null:
			continue
		ob.advance(delta, scroll)
		if ob.position.y > DESPAWN_Y:
			ob.queue_free()
			continue
		if ob.hits(moth.position, MOTH_RADIUS):
			if ob.kind == MothObstacle.Kind.SPARKLE:
				sparkle_score += SPARKLE_POINTS
				AudioManager.play_sfx(SFX_SPARKLE, 0.05)
				Haptics.light()
				_burst(ob.position, Color(1.0, 0.9, 0.45))
				ob.queue_free()
			elif invincible_left <= 0.0:
				_crash(ob.position)
				return
	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.GAME_OVER:
		var touch := event as InputEventScreenTouch
		if touch != null and touch.pressed:
			_try_restart()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_set_held(-1 if touch.position.x < 540.0 else 1)
		else:
			held_dir = 0
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_set_held(-1 if drag.position.x < 540.0 else 1)


func _set_held(dir: int) -> void:
	if dir != held_dir:
		AudioManager.play_sfx(SFX_FLAP, 0.15)
	held_dir = dir


func scroll_speed() -> float:
	return BASE_SCROLL + minf(elapsed * SCROLL_RAMP_PER_SEC, MAX_EXTRA_SCROLL)


func score() -> int:
	return int(height_px / PX_PER_METER) + sparkle_score


# --- spawning ---------------------------------------------------------------

func _spawn_wave() -> void:
	var roll := randf()
	var ob := MothObstacle.new()
	if roll < 0.34:
		ob.setup(MothObstacle.Kind.FAN, randf_range(240.0, 840.0), SPAWN_Y)
	elif roll < 0.58:
		ob.setup(MothObstacle.Kind.PAW, 0.0, SPAWN_Y)
		ob.side = -1 if randf() < 0.5 else 1
	else:
		ob.setup(MothObstacle.Kind.ORB, randf_range(140.0, 940.0), SPAWN_Y)
	obstacles.add_child(ob)
	if randf() < 0.55:
		var sparkle := MothObstacle.new()
		sparkle.setup(MothObstacle.Kind.SPARKLE, randf_range(100.0, 980.0),
			SPAWN_Y - randf_range(120.0, 320.0))
		obstacles.add_child(sparkle)


# --- crash / revive ---------------------------------------------------------

func _crash(at: Vector2) -> void:
	state = State.GAME_OVER
	game_over_at_sec = _now_sec()
	held_dir = 0
	AudioManager.play_sfx(SFX_HIT)
	Haptics.heavy()
	_add_shake(16.0)
	_burst(at, Color(0.9, 0.4, 0.4))
	var final := score()
	if final > high_score:
		high_score = final
	SaveManager.set_value(HIGH_SCORE_KEY, high_score)
	Analytics.log_event("game_over", {"score": final})
	AdsManager.round_finished()
	AudioManager.play_sfx(SFX_GAME_OVER)
	final_score_label.text = "%d m\nBEST %d" % [final, high_score]
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
	for node in obstacles.get_children():
		var ob := node as MothObstacle
		if ob != null and ob.kind != MothObstacle.Kind.SPARKLE \
			and ob.position.distance_to(moth.position) < REVIVE_CLEAR_RADIUS:
			ob.queue_free()
	invincible_left = REVIVE_INVINCIBLE_SEC
	moth.invincible = true
	state = State.PLAYING
	game_over_panel.visible = false
	Analytics.log_event("revive_used")
	Haptics.medium()


func _on_rewarded_closed() -> void:
	get_tree().paused = false


func _try_restart() -> void:
	if restarting or _now_sec() - game_over_at_sec < RESTART_LOCKOUT_SEC:
		return
	restarting = true
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


# --- helpers ----------------------------------------------------------------

func _burst(at: Vector2, color: Color) -> void:
	var burst := CPUParticles2D.new()
	burst.position = at
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 16
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2(0.0, 500.0)
	burst.initial_velocity_min = 200.0
	burst.initial_velocity_max = 420.0
	burst.scale_amount_min = 4.0
	burst.scale_amount_max = 9.0
	burst.color = color
	add_child(burst)
	burst.finished.connect(burst.queue_free)


func _add_shake(amount: float) -> void:
	shake_strength = minf(shake_strength + amount, SHAKE_MAX_PX)


func _refresh_ui() -> void:
	score_label.text = "%d m" % score()
	best_label.text = "BEST %d" % high_score


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0
