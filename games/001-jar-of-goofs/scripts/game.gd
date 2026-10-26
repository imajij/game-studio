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
const SHAKE_DECAY_PER_SEC: float = 9.0
const SHAKE_MAX_PX: float = 30.0

const SFX_DROP: AudioStream = preload("res://assets/audio/drop.wav")
const SFX_POP: AudioStream = preload("res://assets/audio/pop.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")
const SFX_DANGER: AudioStream = preload("res://assets/audio/danger.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
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
var revive_used: bool = false
var restarting: bool = false
var shake_strength: float = 0.0

@onready var jar: Jar = $Jar
@onready var danger_line: DangerLine = $DangerLine
@onready var creatures: Node2D = $Creatures
@onready var drop_timer: Timer = $DropTimer
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var next_preview: NextPreview = $UI/NextPreview
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_score_label: Label = $UI/GameOverPanel/FinalScore
@onready var revive_button: Button = $UI/GameOverPanel/ReviveButton
@onready var shake_button: Button = $UI/ShakeButton
@onready var goofdex_button: Button = $UI/GoofdexButton
@onready var camera: Camera2D = $Camera
@onready var goofdex: Goofdex = $Goofdex
@onready var discovery_card: DiscoveryCard = $DiscoveryCard

func _ready() -> void:
	randomize()
	camera.make_current()
	goofdex_button.pressed.connect(goofdex.open)
	jar.build(JAR_LEFT, JAR_RIGHT, JAR_WALL_TOP, JAR_FLOOR_Y)
	danger_line.position = Vector2(0.0, DANGER_Y)
	danger_line.build(JAR_LEFT, JAR_RIGHT)
	drop_timer.timeout.connect(_on_drop_timer_timeout)
	revive_button.pressed.connect(_on_revive_pressed)
	shake_button.pressed.connect(_on_shake_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(_on_rewarded_closed)
	AdsManager.rewarded_unavailable.connect(_on_rewarded_closed)
	high_score = int(SaveManager.get_value(HIGH_SCORE_KEY, 0))
	Analytics.log_event("round_start")
	next_tier = _roll_drop_tier()
	_spawn_pending()


func _process(delta: float) -> void:
	if shake_strength > 0.3:
		shake_strength = maxf(shake_strength - shake_strength * SHAKE_DECAY_PER_SEC * delta, 0.0)
		camera.offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength))
	else:
		shake_strength = 0.0
		camera.offset = Vector2.ZERO


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
	if any_in_danger and not danger_line.armed:
		AudioManager.play_sfx(SFX_DANGER)
	danger_line.armed = any_in_danger
	# Opt-in rewarded shake: only offered while playing and an ad is loaded.
	shake_button.visible = AdsManager.is_rewarded_ready()


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
	if restarting or _now_sec() - game_over_at_sec < RESTART_LOCKOUT_SEC:
		return
	restarting = true
	# Natural break: the player declined the revive and is leaving the round.
	# AdsManager enforces the frequency caps (round count + time between).
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


func _move_pending(x: float) -> void:
	var clamped := clampf(x, JAR_LEFT + pending.radius, JAR_RIGHT - pending.radius)
	pending.position = Vector2(clamped, DROP_Y)


func _drop() -> void:
	var dropped := pending
	pending = null
	dropped.freeze = false
	Haptics.light()
	AudioManager.play_sfx(SFX_DROP, 0.08)
	_mark_discovered(dropped.tier)
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
	AudioManager.play_sfx(SFX_POP, 0.04, 1.35 - 0.055 * new_tier)
	_add_shake(1.5 + 1.1 * new_tier)
	_spawn_merge_burst(mid, new_tier)
	_mark_discovered(new_tier)
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
	AudioManager.play_sfx(SFX_GAME_OVER)
	_add_shake(14.0)
	shake_button.visible = false
	final_score_label.text = "SCORE %d\nBEST %d" % [score, high_score]
	revive_button.visible = not revive_used and AdsManager.is_rewarded_ready()
	game_over_panel.visible = true


# --- rewarded ads -----------------------------------------------------------

func _on_revive_pressed() -> void:
	if state != State.GAME_OVER or revive_used:
		return
	AudioManager.play_sfx(SFX_TAP)
	AdsManager.show_rewarded("revive")


func _on_shake_pressed() -> void:
	if state != State.PLAYING:
		return
	AudioManager.play_sfx(SFX_TAP)
	get_tree().paused = true
	AdsManager.show_rewarded("shake")


func _on_rewarded_earned(reward_type: String) -> void:
	match reward_type:
		"revive":
			_do_revive()
		"shake":
			_apply_shake()


func _on_rewarded_closed() -> void:
	get_tree().paused = false


## Revive reward: clear the top third of the jar and resume the round.
func _do_revive() -> void:
	if state != State.GAME_OVER:
		return
	revive_used = true
	var cutoff := JAR_WALL_TOP + (JAR_FLOOR_Y - JAR_WALL_TOP) / 3.0
	for node in creatures.get_children():
		var creature := node as Creature
		if creature == null:
			continue
		creature.danger_time = 0.0
		if creature.global_position.y - creature.radius < cutoff:
			creature.queue_free()
	state = State.PLAYING
	game_over_panel.visible = false
	Analytics.log_event("revive_used")
	Haptics.medium()
	_spawn_pending()


## Shake reward: kick every settled creature so tall stacks resettle.
func _apply_shake() -> void:
	for node in creatures.get_children():
		var creature := node as Creature
		if creature == null or creature.freeze:
			continue
		creature.apply_central_impulse(
			Vector2(randf_range(-120.0, 120.0), -randf_range(220.0, 420.0)) * creature.mass)
	Analytics.log_event("shake_used")
	Haptics.heavy()


# --- juice & goofdex --------------------------------------------------------

func _add_shake(amount: float) -> void:
	shake_strength = minf(shake_strength + amount, SHAKE_MAX_PX)


func _spawn_merge_burst(at: Vector2, tier: int) -> void:
	var burst := CPUParticles2D.new()
	burst.position = at
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 12 + tier * 2
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2(0.0, 700.0)
	burst.initial_velocity_min = 240.0
	burst.initial_velocity_max = 420.0 + tier * 25.0
	burst.scale_amount_min = 4.0
	burst.scale_amount_max = 8.0 + tier
	burst.color = Tiers.COLORS[tier]
	add_child(burst)
	burst.finished.connect(burst.queue_free)


func _mark_discovered(tier: int) -> void:
	# duplicate() matters: SaveManager skips the write if handed the same
	# array reference it already stores.
	var found: Array = (SaveManager.get_value(Goofdex.DISCOVERED_KEY, []) as Array).duplicate()
	for value in found:
		if int(value) == tier:
			return
	found.append(tier)
	SaveManager.set_value(Goofdex.DISCOVERED_KEY, found)
	Analytics.log_event("goof_discovered", {"tier": tier})
	discovery_card.enqueue(tier)


# --- ui --------------------------------------------------------------------

func _refresh_ui() -> void:
	score_label.text = str(score)
	best_label.text = "BEST %d" % high_score
	next_preview.set_tier(next_tier)


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0
