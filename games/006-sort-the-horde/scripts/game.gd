extends Node2D
## Sort the Horde — one creature at a time falls down the middle; swipe LEFT
## to dungeon the ghouls, RIGHT to daycare the babies. Disguises show up once
## you get cocky. Rewarded revive once; interstitial on restart.

enum State { PLAYING, GAME_OVER }

const HIGH_SCORE_KEY: String = "high_score"

const SPAWN_Y: float = 260.0
const FAIL_Y: float = 1560.0
const BASE_FALL: float = 170.0
const FALL_PER_SCORE: float = 7.0
const MAX_FALL: float = 560.0
const SWIPE_PX: float = 90.0
const RESOLVE_FLY_SEC: float = 0.22
const MAX_LIVES: int = 3
const DISGUISE_SCORE: int = 15
const DISGUISE_CHANCE: float = 0.28
const STREAK_BONUS_EVERY: int = 10
const STREAK_BONUS: int = 5
const RESTART_LOCKOUT_SEC: float = 0.6
const SHAKE_DECAY_PER_SEC: float = 9.0
const SHAKE_MAX_PX: float = 26.0

const SFX_CORRECT: AudioStream = preload("res://assets/audio/correct.wav")
const SFX_WRONG: AudioStream = preload("res://assets/audio/wrong.wav")
const SFX_SWIPE: AudioStream = preload("res://assets/audio/swipe.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var score: int = 0
var high_score: int = 0
var lives: int = MAX_LIVES
var streak: int = 0
var current: Hordeling = null
var touch_start: Vector2 = Vector2.ZERO
var touching: bool = false
var revive_used: bool = false
var restarting: bool = false
var game_over_at_sec: float = 0.0
var shake_strength: float = 0.0

@onready var camera: Camera2D = $Camera
@onready var creatures: Node2D = $Creatures
@onready var deco: Deco = $Deco
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var lives_label: Label = $UI/LivesLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_score_label: Label = $UI/GameOverPanel/FinalScore
@onready var revive_button: Button = $UI/GameOverPanel/ReviveButton

func _ready() -> void:
	randomize()
	camera.make_current()
	deco.painter = _paint_doors
	deco.queue_redraw()
	revive_button.pressed.connect(_on_revive_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	high_score = int(SaveManager.get_value(HIGH_SCORE_KEY, 0))
	Analytics.log_event("round_start")
	_spawn()
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
	if state != State.PLAYING or current == null or current.resolved:
		return
	current.position.y += fall_speed() * delta
	if current.position.y > FAIL_Y:
		_resolve(0)


func _unhandled_input(event: InputEvent) -> void:
	if state == State.GAME_OVER:
		var touch := event as InputEventScreenTouch
		if touch != null and touch.pressed:
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
		var dx := drag.position.x - touch_start.x
		if absf(dx) >= SWIPE_PX:
			touching = false
			_resolve(-1 if dx < 0.0 else 1)


func fall_speed() -> float:
	return minf(BASE_FALL + score * FALL_PER_SCORE, MAX_FALL)


# --- sorting ----------------------------------------------------------------

## direction: -1 swiped left (dungeon), 1 swiped right (daycare), 0 timed out.
func _resolve(direction: int) -> void:
	if current == null or current.resolved:
		return
	current.resolved = true
	var correct := (direction == -1 and current.is_ghoul) \
		or (direction == 1 and not current.is_ghoul)
	if direction != 0:
		AudioManager.play_sfx(SFX_SWIPE, 0.1)
		var fly := current
		var tween := create_tween()
		tween.tween_property(fly, "position",
			fly.position + Vector2(direction * 900.0, -100.0), RESOLVE_FLY_SEC)
		tween.tween_callback(fly.queue_free)
	else:
		current.queue_free()
	if correct:
		score += 1
		streak += 1
		AudioManager.play_sfx(SFX_CORRECT, 0.05, 1.0 + minf(streak * 0.02, 0.4))
		Haptics.light()
		if streak % STREAK_BONUS_EVERY == 0:
			score += STREAK_BONUS
			_burst(Vector2(540.0, 700.0), Color(1.0, 0.84, 0.35), 24)
			Haptics.medium()
		if score > high_score:
			high_score = score
			SaveManager.set_value(HIGH_SCORE_KEY, high_score)
	else:
		lives -= 1
		streak = 0
		AudioManager.play_sfx(SFX_WRONG)
		Haptics.heavy()
		_add_shake(12.0)
		_burst(Vector2(540.0, 900.0), Color(0.85, 0.3, 0.3), 20)
	current = null
	_refresh_ui()
	if lives <= 0:
		_game_over()
	else:
		_spawn()


func _spawn() -> void:
	current = Hordeling.new()
	var disguise := score >= DISGUISE_SCORE and randf() < DISGUISE_CHANCE
	current.setup(randf() < 0.5, randi_range(0, 2), disguise)
	current.position = Vector2(540.0, SPAWN_Y)
	creatures.add_child(current)


# --- round end / revive -----------------------------------------------------

func _game_over() -> void:
	state = State.GAME_OVER
	game_over_at_sec = _now_sec()
	SaveManager.set_value(HIGH_SCORE_KEY, high_score)
	Analytics.log_event("game_over", {"score": score})
	AdsManager.round_finished()
	AudioManager.play_sfx(SFX_GAME_OVER)
	Haptics.heavy()
	_add_shake(14.0)
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
	state = State.PLAYING
	game_over_panel.visible = false
	Analytics.log_event("revive_used")
	Haptics.medium()
	if current == null:
		_spawn()
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
	burst.gravity = Vector2(0.0, 600.0)
	burst.initial_velocity_min = 220.0
	burst.initial_velocity_max = 460.0
	burst.scale_amount_min = 4.0
	burst.scale_amount_max = 9.0
	burst.color = color
	add_child(burst)
	burst.finished.connect(burst.queue_free)


func _add_shake(amount: float) -> void:
	shake_strength = minf(shake_strength + amount, SHAKE_MAX_PX)


func _refresh_ui() -> void:
	score_label.text = str(score)
	best_label.text = "BEST %d" % high_score
	lives_label.text = "LIVES %d" % lives


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


func _paint_doors(canvas: CanvasItem) -> void:
	# Dungeon door (left) and daycare door (right) flank the fail line.
	canvas.draw_rect(Rect2(0.0, 600.0, 90.0, 560.0), Color(0.4, 0.3, 0.55))
	canvas.draw_circle(Vector2(45.0, 640.0), 45.0, Color(0.4, 0.3, 0.55))
	canvas.draw_rect(Rect2(14.0, 660.0, 62.0, 460.0), Color(0.22, 0.16, 0.32))
	canvas.draw_rect(Rect2(990.0, 600.0, 90.0, 560.0), Color(0.95, 0.8, 0.4))
	canvas.draw_circle(Vector2(1035.0, 640.0), 45.0, Color(0.95, 0.8, 0.4))
	canvas.draw_rect(Rect2(1004.0, 660.0, 62.0, 460.0), Color(1.0, 0.93, 0.7))
	canvas.draw_dashed_line(Vector2(80.0, FAIL_Y), Vector2(1000.0, FAIL_Y),
		Color(0.5, 0.4, 0.6, 0.4), 5.0, 22.0)
