extends Node2D
## Gobble Gus — drag the bottomless gremlin mouth to catch snacks and dodge
## hardware. Combos build to FEVER (double points). Rewarded revive once;
## interstitial on restart.

enum State { PLAYING, GAME_OVER }

const HIGH_SCORE_KEY: String = "high_score"

const GUS_Y: float = 1700.0
const GUS_MIN_X: float = 110.0
const GUS_MAX_X: float = 970.0
const GUS_FOLLOW: float = 14.0
const CATCH_RADIUS: float = 125.0
const CATCH_BAND: float = 150.0
const FLOOR_Y: float = 1990.0
const MAX_LIVES: int = 3
const BASE_FALL: float = 520.0
const MAX_EXTRA_FALL: float = 520.0
const FALL_RAMP_PER_SEC: float = 9.0
const SPAWN_GAP_START: float = 0.85
const SPAWN_GAP_MIN: float = 0.42
const SPAWN_RAMP: float = 0.005
const BAD_CHANCE: float = 0.3
const FEVER_COMBO: int = 12
const FEVER_SEC: float = 10.0
const RESTART_LOCKOUT_SEC: float = 0.6
const SHAKE_DECAY_PER_SEC: float = 9.0
const SHAKE_MAX_PX: float = 26.0

const SFX_CHOMP: AudioStream = preload("res://assets/audio/chomp.wav")
const SFX_YUCK: AudioStream = preload("res://assets/audio/yuck.wav")
const SFX_FEVER: AudioStream = preload("res://assets/audio/fever.wav")
const SFX_MISS: AudioStream = preload("res://assets/audio/miss.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var score: int = 0
var high_score: int = 0
var lives: int = MAX_LIVES
var combo: int = 0
var fever_left: float = 0.0
var elapsed: float = 0.0
var spawn_timer: float = 0.6
var target_x: float = 540.0
var revive_used: bool = false
var restarting: bool = false
var game_over_at_sec: float = 0.0
var shake_strength: float = 0.0

## Art pass sets this; null = greybox Gus.
static var gus_texture: Texture2D = null

@onready var camera: Camera2D = $Camera
@onready var items: Node2D = $Items
@onready var gus: Node2D = $Gus
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var lives_label: Label = $UI/LivesLabel
@onready var fever_label: Label = $UI/FeverLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_score_label: Label = $UI/GameOverPanel/FinalScore
@onready var revive_button: Button = $UI/GameOverPanel/ReviveButton

func _ready() -> void:
	randomize()
	camera.make_current()
	gus.position = Vector2(540.0, GUS_Y)
	gus.draw.connect(_draw_gus)
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
	gus.queue_redraw()


func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	elapsed += delta
	if fever_left > 0.0:
		fever_left -= delta
		if fever_left <= 0.0:
			fever_label.visible = false
	gus.position.x = lerpf(gus.position.x, clampf(target_x, GUS_MIN_X, GUS_MAX_X),
		GUS_FOLLOW * delta)

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_item()
		spawn_timer = maxf(SPAWN_GAP_START - elapsed * SPAWN_RAMP, SPAWN_GAP_MIN)

	for node in items.get_children():
		var item := node as FallItem
		if item == null:
			continue
		item.advance(delta)
		if absf(item.position.y - GUS_Y) < CATCH_BAND \
			and item.position.distance_to(gus.position) < CATCH_RADIUS + item.radius * 0.4:
			_catch(item)
			continue
		if item.position.y > FLOOR_Y:
			if Items.IS_GOOD[item.kind] and combo > 0:
				combo = 0
				AudioManager.play_sfx(SFX_MISS, 0.1)
				_refresh_ui()
			item.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.GAME_OVER:
		var touch := event as InputEventScreenTouch
		if touch != null and touch.pressed:
			_try_restart()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			target_x = touch.position.x
	elif event is InputEventScreenDrag:
		target_x = (event as InputEventScreenDrag).position.x


# --- catching ---------------------------------------------------------------

func _catch(item: FallItem) -> void:
	if Items.IS_GOOD[item.kind]:
		var points := 2 if fever_left > 0.0 else 1
		score += points
		combo += 1
		AudioManager.play_sfx(SFX_CHOMP, 0.08, 1.0 + minf(combo * 0.015, 0.3))
		Haptics.light()
		_burst(item.position, Items.COLORS[item.kind], 14)
		if combo == FEVER_COMBO and fever_left <= 0.0:
			fever_left = FEVER_SEC
			fever_label.visible = true
			AudioManager.play_sfx(SFX_FEVER)
			Haptics.heavy()
			_add_shake(8.0)
		if score > high_score:
			high_score = score
			SaveManager.set_value(HIGH_SCORE_KEY, high_score)
	else:
		lives -= 1
		combo = 0
		fever_left = 0.0
		fever_label.visible = false
		AudioManager.play_sfx(SFX_YUCK)
		Haptics.heavy()
		_burst(item.position, Color(0.85, 0.3, 0.3), 22)
		_add_shake(12.0)
	item.queue_free()
	_refresh_ui()
	if lives <= 0:
		_game_over()


func _spawn_item() -> void:
	var kind: int
	if randf() < BAD_CHANCE:
		kind = randi_range(4, Items.COUNT - 1)
	else:
		kind = randi_range(0, 3)
	var item := FallItem.new()
	var fall := BASE_FALL + minf(elapsed * FALL_RAMP_PER_SEC, MAX_EXTRA_FALL)
	item.setup(kind, Vector2(randf_range(120.0, 960.0), -120.0),
		Vector2(randf_range(-70.0, 70.0), fall))
	items.add_child(item)


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
	for node in items.get_children():
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


# --- gus & helpers ----------------------------------------------------------

func _draw_gus() -> void:
	var grow := 1.0 + minf(combo * 0.012, 0.3)
	var r := 115.0 * grow
	if gus_texture != null:
		var side := r * 2.4
		gus.draw_texture_rect(gus_texture,
			Rect2(Vector2(-side / 2.0, -side / 2.0), Vector2(side, side)), false)
		return
	var body := Color(0.55, 0.75, 0.4) if fever_left <= 0.0 else \
		Color(0.9, 0.6, 0.2).lerp(Color(0.6, 0.4, 0.9), 0.5 + 0.5 * sin(elapsed * 10.0))
	gus.draw_circle(Vector2.ZERO, r, body)
	gus.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, body.darkened(0.35), 6.0, true)
	gus.draw_circle(Vector2(0.0, -r * 0.1), r * 0.62, Color(0.2, 0.1, 0.15))
	gus.draw_arc(Vector2(0.0, -r * 0.1), r * 0.62, 0.0, TAU, 32, body.darkened(0.45), 5.0)
	for ex in [-r * 0.45, r * 0.45]:
		gus.draw_circle(Vector2(ex, -r * 0.65), r * 0.2, Color.WHITE)
		gus.draw_circle(Vector2(ex, -r * 0.6), r * 0.1, Color(0.1, 0.1, 0.15))


func _burst(at: Vector2, color: Color, amount: int) -> void:
	var burst := CPUParticles2D.new()
	burst.position = at
	burst.one_shot = true
	burst.emitting = true
	burst.amount = amount
	burst.lifetime = 0.45
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2(0.0, 800.0)
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
