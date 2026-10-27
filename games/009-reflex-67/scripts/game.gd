extends Node2D
## 67 Reflex — beats count 1-2-3-4-5 by themselves, then YOU must tap dead on
## "six" and "seven". Every pair completed speeds the beat up. Three lives,
## 10-second rounds, daily + all-time best. Rewarded revive, interstitial on
## restart.

enum State { IDLE, COUNTING, GAME_OVER }

const BEST_KEY: String = "best"
const DAILY_KEY_PREFIX: String = "daily_best_"

const START_INTERVAL: float = 0.52
const INTERVAL_FACTOR: float = 0.965
const MIN_INTERVAL: float = 0.24
const PERFECT_SEC: float = 0.09
const GOOD_SEC: float = 0.17
const MAX_LIVES: int = 3
const RESTART_LOCKOUT_SEC: float = 0.6
const CENTER: Vector2 = Vector2(540.0, 880.0)

const SFX_BEAT: AudioStream = preload("res://assets/audio/beat.wav")
const SFX_SIX: AudioStream = preload("res://assets/audio/six.wav")
const SFX_SEVEN: AudioStream = preload("res://assets/audio/seven.wav")
const SFX_PERFECT: AudioStream = preload("res://assets/audio/perfect.wav")
const SFX_FAIL: AudioStream = preload("res://assets/audio/fail.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.IDLE
var score: int = 0
var best: int = 0
var daily_best: int = 0
var lives: int = MAX_LIVES
var streak_perfect: int = 0
var interval: float = START_INTERVAL
var clock: float = 0.0
var next_beat: int = 1  # 1..7, beat N lands at t = N * interval
var waiting_tap: bool = false  # true while beat 6/7 needs the player
var revive_used: bool = false
var restarting: bool = false
var game_over_at_sec: float = 0.0
var pulse: float = 0.0
var flash_color: Color = Color.TRANSPARENT

@onready var deco: Deco = $Deco
@onready var number_label: Label = $UI/NumberLabel
@onready var judge_label: Label = $UI/JudgeLabel
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var lives_label: Label = $UI/LivesLabel
@onready var start_label: Label = $UI/StartLabel
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
	daily_best = int(SaveManager.get_value(_daily_key(), 0))
	Analytics.log_event("round_start")
	_refresh_ui()


func _process(delta: float) -> void:
	pulse = maxf(pulse - delta * 4.0, 0.0)
	if flash_color.a > 0.0:
		flash_color.a = maxf(flash_color.a - delta * 3.0, 0.0)
	deco.queue_redraw()
	if state != State.COUNTING:
		return
	clock += delta
	var beat_time := next_beat * interval
	if next_beat <= 5:
		if clock >= beat_time:
			AudioManager.play_sfx(SFX_BEAT, 0.0, 1.0 + (next_beat - 1) * 0.06)
			number_label.text = str(next_beat)
			pulse = 1.0
			next_beat += 1
			waiting_tap = next_beat >= 6
	else:
		# beat 6 or 7: player must tap inside the window around beat_time
		if clock > beat_time + GOOD_SEC:
			_miss("TOO SLOW")


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	match state:
		State.IDLE:
			_start_round()
		State.COUNTING:
			_judge_tap()
		State.GAME_OVER:
			if not _point_in(revive_button, touch.position):
				_try_restart()


func _start_round() -> void:
	state = State.COUNTING
	clock = 0.0
	next_beat = 1
	waiting_tap = false
	start_label.visible = false
	judge_label.text = ""
	AudioManager.play_sfx(SFX_TAP)


func _judge_tap() -> void:
	if next_beat <= 5:
		# spamming before "six" costs you
		if clock > interval * 1.2:
			_miss("TOO EARLY")
		return
	var beat_time := next_beat * interval
	var dt := absf(clock - beat_time)
	if dt > GOOD_SEC:
		_miss("TOO EARLY" if clock < beat_time else "TOO SLOW")
		return
	var perfect := dt <= PERFECT_SEC
	AudioManager.play_sfx(SFX_SIX if next_beat == 6 else SFX_SEVEN)
	number_label.text = str(next_beat)
	pulse = 1.0
	if perfect:
		streak_perfect += 1
		score += 2
		judge_label.text = "PERFECT x%d" % streak_perfect if streak_perfect > 1 else "PERFECT"
		judge_label.modulate = Color(0.4, 1.0, 0.85)
		flash_color = Color(0.3, 1.0, 0.8, 0.22)
		AudioManager.play_sfx(SFX_PERFECT, 0.03)
		Haptics.medium()
	else:
		streak_perfect = 0
		score += 1
		judge_label.text = "GOOD"
		judge_label.modulate = Color(1.0, 0.9, 0.4)
		Haptics.light()
	if next_beat == 7:
		_pair_done()
	else:
		next_beat = 7
	_refresh_ui()


func _pair_done() -> void:
	interval = maxf(interval * INTERVAL_FACTOR, MIN_INTERVAL)
	clock = 0.0
	next_beat = 1
	waiting_tap = false
	if score > best:
		best = score
		SaveManager.set_value(BEST_KEY, best)
	if score > daily_best:
		daily_best = score
		SaveManager.set_value(_daily_key(), daily_best)


func _miss(verdict: String) -> void:
	lives -= 1
	streak_perfect = 0
	judge_label.text = verdict
	judge_label.modulate = Color(1.0, 0.4, 0.45)
	flash_color = Color(1.0, 0.25, 0.3, 0.3)
	AudioManager.play_sfx(SFX_FAIL)
	Haptics.heavy()
	_refresh_ui()
	if lives <= 0:
		_game_over()
	else:
		clock = 0.0
		next_beat = 1
		waiting_tap = false
		number_label.text = "·"


func _game_over() -> void:
	state = State.GAME_OVER
	game_over_at_sec = _now_sec()
	Analytics.log_event("game_over", {"score": score})
	AdsManager.round_finished()
	AudioManager.play_sfx(SFX_GAME_OVER)
	final_score_label.text = "SCORE %d\nTODAY %d   BEST %d" % [score, daily_best, best]
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
	state = State.COUNTING
	clock = 0.0
	next_beat = 1
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


func _refresh_ui() -> void:
	score_label.text = str(score)
	best_label.text = "BEST %d" % best
	lives_label.text = "♥".repeat(maxi(lives, 0))


func _daily_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%s%04d%02d%02d" % [DAILY_KEY_PREFIX, date.year, date.month, date.day]


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


func _point_in(control: Control, point: Vector2) -> bool:
	return control.visible and control.get_global_rect().has_point(point)


func _paint(canvas: CanvasItem) -> void:
	# beat ring: fills toward the next beat
	var frac := 0.0
	if state == State.COUNTING:
		frac = clampf(fmod(clock, interval) / interval, 0.0, 1.0)
	var ring := Color(0.35, 0.9, 0.95) if next_beat < 6 else Color(1.0, 0.45, 0.75)
	canvas.draw_arc(CENTER, 330.0, 0.0, TAU, 64, Color(ring.r, ring.g, ring.b, 0.18), 20.0, true)
	if frac > 0.0:
		canvas.draw_arc(CENTER, 330.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 64, ring, 20.0, true)
	canvas.draw_circle(CENTER, 250.0 + pulse * 36.0, Color(0.14, 0.12, 0.24))
	canvas.draw_arc(CENTER, 250.0 + pulse * 36.0, 0.0, TAU, 64, ring, 10.0, true)
	# tap-zone hint when 6/7 due
	if state == State.COUNTING and next_beat >= 6:
		canvas.draw_circle(CENTER, 120.0 + pulse * 20.0, Color(ring.r, ring.g, ring.b, 0.12))
	if flash_color.a > 0.0:
		canvas.draw_rect(Rect2(0.0, 0.0, 1080.0, 1920.0), flash_color)
