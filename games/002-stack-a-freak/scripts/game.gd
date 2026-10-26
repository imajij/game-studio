extends Node2D
## Stack-a-Freak — round controller: swing/drop timing, settle scoring with
## perfect bonuses, camera climb, 3 misses, rewarded "glue", interstitial on
## restart via the shared AdsManager caps.

enum State { PLAYING, GAME_OVER }

const HIGH_SCORE_KEY: String = "high_score"

const PLATFORM_CENTER_X: float = 540.0
const PLATFORM_TOP_Y: float = 1700.0
const PLATFORM_WIDTH: float = 460.0
const PLATFORM_THICKNESS: float = 60.0
## Crane pivot offset from the camera center (near the top of the view).
const CRANE_LOCAL := Vector2(0.0, -820.0)
const BASE_CAMERA_Y: float = 960.0
## Keep the stack top roughly this far above the camera center.
const CAMERA_LEAD: float = 320.0
const CAMERA_LERP: float = 3.0
const DROP_COOLDOWN_SEC: float = 0.55
const SETTLE_SEC: float = 0.35
const PERFECT_WINDOW_PX: float = 22.0
const PERFECT_BONUS: int = 3
const MAX_MISSES: int = 3
## A block this far below the view bottom has fallen off.
const FALL_MARGIN: float = 400.0
const RESTART_LOCKOUT_SEC: float = 0.6
const SHAKE_DECAY_PER_SEC: float = 9.0
const SHAKE_MAX_PX: float = 26.0
const MIN_STACK_FOR_GLUE: int = 4

const SFX_DROP: AudioStream = preload("res://assets/audio/drop.wav")
const SFX_LAND: AudioStream = preload("res://assets/audio/land.wav")
const SFX_PERFECT: AudioStream = preload("res://assets/audio/perfect.wav")
const SFX_MISS: AudioStream = preload("res://assets/audio/miss.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var score: int = 0
var high_score: int = 0
var stacked: int = 0
var misses: int = 0
var glue_used: bool = false
var restarting: bool = false
var game_over_at_sec: float = 0.0
var shake_strength: float = 0.0
## Top surface y of the highest counted block (starts at the platform).
var top_y: float = PLATFORM_TOP_Y
var top_x: float = PLATFORM_CENTER_X

@onready var camera: Camera2D = $Camera
@onready var crane: Crane = $Camera/Crane
@onready var deco: Deco = $Deco
@onready var blocks: Node2D = $Blocks
@onready var drop_timer: Timer = $DropTimer
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var lives_label: Label = $UI/LivesLabel
@onready var glue_button: Button = $UI/GlueButton
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_score_label: Label = $UI/GameOverPanel/FinalScore

func _ready() -> void:
	randomize()
	camera.make_current()
	crane.position = CRANE_LOCAL
	deco.painter = _paint_deco
	deco.queue_redraw()
	_build_platform()
	drop_timer.timeout.connect(_arm_crane)
	glue_button.pressed.connect(_on_glue_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(_on_rewarded_closed)
	AdsManager.rewarded_unavailable.connect(_on_rewarded_closed)
	high_score = int(SaveManager.get_value(HIGH_SCORE_KEY, 0))
	Analytics.log_event("round_start")
	_arm_crane()
	_refresh_ui()


func _process(delta: float) -> void:
	if shake_strength > 0.3:
		shake_strength = maxf(shake_strength - shake_strength * SHAKE_DECAY_PER_SEC * delta, 0.0)
		camera.offset = Vector2(randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength))
	else:
		shake_strength = 0.0
		camera.offset = Vector2.ZERO
	var target_y := minf(BASE_CAMERA_Y, top_y + CAMERA_LEAD)
	camera.position.y = lerpf(camera.position.y, target_y, CAMERA_LERP * delta)


func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	var fall_line := camera.position.y + 960.0 + FALL_MARGIN
	for node in blocks.get_children():
		var block := node as FreakBlock
		if block == null:
			continue
		if block.global_position.y > fall_line:
			block.queue_free()
			_on_block_fell()
			continue
		if block.counted or block.freeze:
			continue
		if block.is_still():
			block.still_time += delta
			if block.still_time >= SETTLE_SEC:
				_count_block(block)
		else:
			block.still_time = 0.0
	glue_button.visible = state == State.PLAYING and not glue_used \
		and stacked >= MIN_STACK_FOR_GLUE and AdsManager.is_rewarded_ready()


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	match state:
		State.PLAYING:
			_drop()
		State.GAME_OVER:
			_try_restart()


# --- core loop --------------------------------------------------------------

func _arm_crane() -> void:
	crane.freak = randi_range(0, Freaks.COUNT - 1)
	crane.holding = true


func _drop() -> void:
	if not crane.holding:
		return
	crane.holding = false
	var block := FreakBlock.new()
	block.setup(crane.freak)
	block.global_position = crane.holder_global()
	blocks.add_child(block)
	block.linear_velocity = crane.holder_velocity() * 0.6
	AudioManager.play_sfx(SFX_DROP, 0.08)
	Haptics.light()
	drop_timer.start(DROP_COOLDOWN_SEC)


func _count_block(block: FreakBlock) -> void:
	block.counted = true
	stacked += 1
	score += 1
	var perfect := absf(block.global_position.x - top_x) <= PERFECT_WINDOW_PX
	if block.global_position.y - block.side / 2.0 < top_y:
		top_y = block.global_position.y - block.side / 2.0
		top_x = block.global_position.x
	if perfect:
		score += PERFECT_BONUS
		AudioManager.play_sfx(SFX_PERFECT)
		_burst(block.global_position, Color(1.0, 0.84, 0.35))
	else:
		AudioManager.play_sfx(SFX_LAND, 0.06, 1.0 - minf(block.mass * 0.1, 0.3))
	_add_shake(2.0 + block.mass * 1.5)
	Haptics.light()
	crane.set_difficulty(stacked)
	if score > high_score:
		high_score = score
		SaveManager.set_value(HIGH_SCORE_KEY, high_score)
	_refresh_ui()


func _on_block_fell() -> void:
	misses += 1
	AudioManager.play_sfx(SFX_MISS)
	Haptics.medium()
	_add_shake(8.0)
	_refresh_ui()
	if misses >= MAX_MISSES:
		_game_over()


# --- rewarded glue ----------------------------------------------------------

func _on_glue_pressed() -> void:
	if state != State.PLAYING or glue_used:
		return
	AudioManager.play_sfx(SFX_TAP)
	get_tree().paused = true
	AdsManager.show_rewarded("glue")


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "glue":
		return
	glue_used = true
	for node in blocks.get_children():
		var block := node as FreakBlock
		if block != null and block.counted:
			block.freeze = true
			_burst(block.global_position, Color(1.0, 1.0, 1.0, 0.8))
	Analytics.log_event("glue_used")
	Haptics.heavy()


func _on_rewarded_closed() -> void:
	get_tree().paused = false


# --- round end --------------------------------------------------------------

func _game_over() -> void:
	state = State.GAME_OVER
	game_over_at_sec = _now_sec()
	crane.holding = false
	drop_timer.stop()
	glue_button.visible = false
	SaveManager.set_value(HIGH_SCORE_KEY, high_score)
	Analytics.log_event("game_over", {"score": score})
	AdsManager.round_finished()
	AudioManager.play_sfx(SFX_GAME_OVER)
	Haptics.heavy()
	_add_shake(14.0)
	final_score_label.text = "SCORE %d\nBEST %d" % [score, high_score]
	game_over_panel.visible = true


func _try_restart() -> void:
	if restarting or _now_sec() - game_over_at_sec < RESTART_LOCKOUT_SEC:
		return
	restarting = true
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


# --- helpers ----------------------------------------------------------------

func _build_platform() -> void:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(PLATFORM_WIDTH, PLATFORM_THICKNESS)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = Vector2(PLATFORM_CENTER_X, PLATFORM_TOP_Y + PLATFORM_THICKNESS / 2.0)
	add_child(body)


func _burst(at: Vector2, color: Color) -> void:
	var burst := CPUParticles2D.new()
	burst.position = at
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 16
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2(0.0, 700.0)
	burst.initial_velocity_min = 220.0
	burst.initial_velocity_max = 430.0
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
	lives_label.text = "LIVES %d" % (MAX_MISSES - misses)


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


func _paint_deco(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(PLATFORM_CENTER_X - PLATFORM_WIDTH / 2.0, PLATFORM_TOP_Y,
		PLATFORM_WIDTH, PLATFORM_THICKNESS), Color(0.32, 0.28, 0.42))
	canvas.draw_rect(Rect2(PLATFORM_CENTER_X - PLATFORM_WIDTH / 2.0, PLATFORM_TOP_Y,
		PLATFORM_WIDTH, 10.0), Color(1.0, 1.0, 1.0, 0.35))
