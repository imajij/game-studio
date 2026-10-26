extends Node2D
## Jar of Goofs — round controller: drop input, merge resolution, scoring,
## danger-line game over, instant restart. Layout numbers live here and are
## pushed into Jar/DangerLine so there is one source of truth.

enum State { PLAYING, GAME_OVER }

const HIGH_SCORE_KEY: String = "high_score"

# Layout at the 1080x1920 base resolution (see GAME.md).
const JAR_LEFT: float = 80.0
const JAR_RIGHT: float = 1000.0
const JAR_WALL_TOP: float = 520.0
const JAR_FLOOR_Y: float = 1800.0
## Drop height sits above the jar so aiming never clips the walls.
const DROP_Y: float = 380.0
const DANGER_Y: float = 560.0

const DROP_COOLDOWN_SEC: float = 0.45
const DANGER_SECONDS: float = 2.0
## Ignore taps right after game over so the losing tap can't instantly restart.
const RESTART_LOCKOUT_SEC: float = 0.6
## Upward kick (per kg) for a freshly merged creature — the "pop".
const MERGE_POP_IMPULSE: float = 220.0

var state: State = State.PLAYING
var score: int = 0
var high_score: int = 0
var next_tier: int = 1
var pending: Creature = null
var game_over_at_sec: float = 0.0

@onready var jar: Jar = $Jar
@onready var danger_line: DangerLine = $DangerLine
@onready var creatures: Node2D = $Creatures
@onready var drop_timer: Timer = $DropTimer
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var next_preview: NextPreview = $UI/NextPreview
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_score_label: Label = $UI/GameOverPanel/FinalScore

func _ready() -> void:
	randomize()
	jar.build(JAR_LEFT, JAR_RIGHT, JAR_WALL_TOP, JAR_FLOOR_Y)
	danger_line.position = Vector2(0.0, DANGER_Y)
	danger_line.build(JAR_LEFT, JAR_RIGHT)
	drop_timer.timeout.connect(_on_drop_timer_timeout)
	high_score = int(SaveManager.get_value(HIGH_SCORE_KEY, 0))
	Analytics.log_event("round_start")
	next_tier = _roll_drop_tier()
	_spawn_pending()


func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	var any_in_danger := false
	for node in creatures.get_children():
		var creature := node as Creature
		if creature == null or creature.freeze or not creature.activated:
			continue
		if creature.global_position.y - creature.radius < DANGER_Y:
			any_in_danger = true
			creature.danger_time += delta
			if creature.danger_time >= DANGER_SECONDS:
				_game_over()
				return
		else:
			creature.danger_time = 0.0
	danger_line.armed = any_in_danger


func _unhandled_input(event: InputEvent) -> void:
	match state:
		State.PLAYING:
			_handle_play_input(event)
		State.GAME_OVER:
			_handle_game_over_input(event)


# --- input -----------------------------------------------------------------

func _handle_play_input(event: InputEvent) -> void:
	if pending == null:
		return
	if event is InputEventScreenDrag:
		_move_pending((event as InputEventScreenDrag).position.x)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_move_pending(touch.position.x)
		else:
			_drop()


func _handle_game_over_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	if _now_sec() - game_over_at_sec < RESTART_LOCKOUT_SEC:
		return
	get_tree().reload_current_scene()


func _move_pending(x: float) -> void:
	var clamped := clampf(x, JAR_LEFT + pending.radius, JAR_RIGHT - pending.radius)
	pending.position = Vector2(clamped, DROP_Y)


func _drop() -> void:
	var dropped := pending
	pending = null
	dropped.freeze = false
	Haptics.light()
	drop_timer.start(DROP_COOLDOWN_SEC)


# --- spawning --------------------------------------------------------------

func _on_drop_timer_timeout() -> void:
	if state == State.PLAYING:
		_spawn_pending()


func _spawn_pending() -> void:
	pending = _make_creature(next_tier)
	pending.freeze = true
	pending.position = Vector2((JAR_LEFT + JAR_RIGHT) / 2.0, DROP_Y)
	next_tier = _roll_drop_tier()
	_refresh_ui()


func _roll_drop_tier() -> int:
	return randi_range(1, Tiers.MAX_DROP_TIER)


func _make_creature(tier: int) -> Creature:
	var creature := Creature.new()
	creature.setup(tier)
	creature.same_tier_contact.connect(_on_same_tier_contact)
	creatures.add_child(creature)
	return creature


# --- merging ---------------------------------------------------------------

func _on_same_tier_contact(a: Creature, b: Creature) -> void:
	if a.merging or b.merging:
		return
	a.merging = true
	b.merging = true
	# Contact signals fire during the physics step — mutate the world after it.
	_merge.call_deferred(a, b)


func _merge(a: Creature, b: Creature) -> void:
	if state != State.PLAYING:
		return
	var new_tier := a.tier + 1
	var mid := (a.position + b.position) / 2.0
	var velocity := (a.linear_velocity + b.linear_velocity) / 2.0
	a.queue_free()
	b.queue_free()
	var merged := _make_creature(new_tier)
	merged.position = mid
	merged.linear_velocity = velocity
	merged.activated = true
	merged.apply_central_impulse(Vector2.UP * MERGE_POP_IMPULSE * merged.mass)
	merged.pop_in()
	Haptics.medium()
	score += Tiers.POINTS[new_tier]
	if score > high_score:
		high_score = score
		SaveManager.set_value(HIGH_SCORE_KEY, high_score)
	_refresh_ui()


# --- round end -------------------------------------------------------------

func _game_over() -> void:
	state = State.GAME_OVER
	game_over_at_sec = _now_sec()
	danger_line.armed = false
	drop_timer.stop()
	if pending != null:
		pending.queue_free()
		pending = null
	SaveManager.set_value(HIGH_SCORE_KEY, high_score)
	Analytics.log_event("game_over", {"score": score})
	AdsManager.round_finished()
	Haptics.heavy()
	final_score_label.text = "SCORE %d\nBEST %d" % [score, high_score]
	game_over_panel.visible = true


# --- ui --------------------------------------------------------------------

func _refresh_ui() -> void:
	score_label.text = str(score)
	best_label.text = "BEST %d" % high_score
	next_preview.set_tier(next_tier)


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0
