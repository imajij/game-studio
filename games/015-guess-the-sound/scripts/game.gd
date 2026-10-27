extends Node2D
## Guess the Sound or Get Yeeted — a mystery sound plays (all sounds are
## original synth creations, nothing licensed), four names appear, you get a
## few seconds. Wrong or too slow = YEETED. Streak is the score. Rewarded ad
## = one second chance per run; interstitial on restart.

enum State { PLAYING, YEETED }

const QUIZ: Array = [
	["Wet Slap", preload("res://assets/audio/q_wet_slap.wav")],
	["Angry Kettle", preload("res://assets/audio/q_angry_kettle.wav")],
	["Sad Horn", preload("res://assets/audio/q_sad_horn.wav")],
	["Bubble Pop", preload("res://assets/audio/q_bubble.wav")],
	["Robot Burp", preload("res://assets/audio/q_robot_burp.wav")],
	["Tiny Violin", preload("res://assets/audio/q_tiny_violin.wav")],
	["Haunted Door", preload("res://assets/audio/q_door_creak.wav")],
	["Spring Boing", preload("res://assets/audio/q_spring.wav")],
	["Alien Sneeze", preload("res://assets/audio/q_alien_sneeze.wav")],
	["Disco Drip", preload("res://assets/audio/q_disco_drip.wav")],
]
const BEST_KEY: String = "best"
const BASE_TIME: float = 6.0
const TIME_FACTOR: float = 0.96
const MIN_TIME: float = 2.8
const RESTART_LOCKOUT_SEC: float = 0.6

const SFX_CORRECT: AudioStream = preload("res://assets/audio/correct.wav")
const SFX_WRONG: AudioStream = preload("res://assets/audio/wrong.wav")
const SFX_YEET: AudioStream = preload("res://assets/audio/yeet.wav")
const SFX_TICK: AudioStream = preload("res://assets/audio/tick.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var streak: int = 0
var best: int = 0
var answer: int = 0
var options: Array = []
var time_left: float = BASE_TIME
var time_total: float = BASE_TIME
var second_chance_used: bool = false
var locked: bool = false
var yeet_offset: float = 0.0
var last_tick_at: int = 99
var restarting: bool = false
var game_over_at_sec: float = 0.0
var answer_buttons: Array = []

@onready var deco: Deco = $Deco
@onready var streak_label: Label = $UI/StreakLabel
@onready var best_label: Label = $UI/BestLabel
@onready var prompt_label: Label = $UI/PromptLabel
@onready var replay_button: Button = $UI/ReplayButton
@onready var answers_grid: GridContainer = $UI/AnswersGrid
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_label: Label = $UI/GameOverPanel/FinalScore
@onready var chance_button: Button = $UI/GameOverPanel/ChanceButton

func _ready() -> void:
	randomize()
	deco.painter = _paint
	replay_button.pressed.connect(_on_replay_pressed)
	chance_button.pressed.connect(_on_chance_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	best = int(SaveManager.get_value(BEST_KEY, 0))
	for i in 4:
		var button := Button.new()
		button.custom_minimum_size = Vector2(470.0, 150.0)
		button.add_theme_font_size_override("font_size", 44)
		button.pressed.connect(_on_answer.bind(i))
		answers_grid.add_child(button)
		answer_buttons.append(button)
	Analytics.log_event("round_start")
	_next_question()
	_refresh_ui()


func _process(delta: float) -> void:
	deco.queue_redraw()
	if state == State.YEETED:
		yeet_offset += delta * 2600.0
		return
	if locked:
		return
	time_left -= delta
	var whole := int(ceil(time_left))
	if whole != last_tick_at and whole <= 3 and whole > 0:
		last_tick_at = whole
		AudioManager.play_sfx(SFX_TICK)
	if time_left <= 0.0:
		_yeet("TOO SLOW!")


func _next_question() -> void:
	locked = false
	answer = randi() % QUIZ.size()
	var pool := range(QUIZ.size())
	pool.erase(answer)
	pool.shuffle()
	options = [answer, pool[0], pool[1], pool[2]]
	options.shuffle()
	time_total = maxf(BASE_TIME * pow(TIME_FACTOR, streak), MIN_TIME)
	time_left = time_total
	last_tick_at = 99
	for i in 4:
		answer_buttons[i].text = QUIZ[options[i]][0]
		answer_buttons[i].disabled = false
	_play_quiz_sound()


func _play_quiz_sound() -> void:
	AudioManager.play_sfx(QUIZ[answer][1])


func _on_replay_pressed() -> void:
	if state != State.PLAYING or locked:
		return
	_play_quiz_sound()


func _on_answer(i: int) -> void:
	if state != State.PLAYING or locked:
		return
	if options[i] == answer:
		streak += 1
		AudioManager.play_sfx(SFX_CORRECT, 0.03, 1.0 + minf(streak * 0.02, 0.4))
		Haptics.light()
		if streak > best:
			best = streak
			SaveManager.set_value(BEST_KEY, best)
		_next_question()
		_refresh_ui()
	else:
		_yeet("WRONG! It was %s" % QUIZ[answer][0])


func _yeet(reason: String) -> void:
	locked = true
	state = State.YEETED
	yeet_offset = 0.0
	game_over_at_sec = _now_sec()
	AudioManager.play_sfx(SFX_WRONG)
	AudioManager.play_sfx(SFX_YEET)
	Haptics.heavy()
	Analytics.log_event("game_over", {"score": streak})
	AdsManager.round_finished()
	final_label.text = "%s\n\nSTREAK %d   BEST %d" % [reason, streak, best]
	chance_button.visible = not second_chance_used and AdsManager.is_rewarded_ready()
	game_over_panel.visible = true
	for button: Button in answer_buttons:
		button.disabled = true


func _on_chance_pressed() -> void:
	if second_chance_used:
		return
	AudioManager.play_sfx(SFX_TAP)
	AdsManager.show_rewarded("chance")


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "chance" or state != State.YEETED:
		return
	second_chance_used = true
	state = State.PLAYING
	game_over_panel.visible = false
	Analytics.log_event("second_chance")
	Haptics.medium()
	_next_question()
	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if state != State.YEETED:
		return
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed \
			and not chance_button.get_global_rect().has_point(touch.position):
		_try_restart()


func _try_restart() -> void:
	if restarting or _now_sec() - game_over_at_sec < RESTART_LOCKOUT_SEC:
		return
	restarting = true
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


func _refresh_ui() -> void:
	streak_label.text = str(streak)
	best_label.text = "BEST %d" % best


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


func _paint(canvas: CanvasItem) -> void:
	# listener blob — gets yeeted on loss
	var at := Vector2(540.0, 700.0)
	var spin := 0.0
	if state == State.YEETED:
		at += Vector2(yeet_offset * 0.7, -yeet_offset * 0.4 + yeet_offset * yeet_offset * 0.0004)
		spin = yeet_offset * 0.01
	canvas.draw_set_transform(at, spin, Vector2.ONE)
	canvas.draw_circle(Vector2.ZERO, 150.0, Color(0.2, 0.17, 0.28))
	canvas.draw_circle(Vector2.ZERO, 138.0, Color(0.95, 0.72, 0.4))
	# giant ear (it's a listening game)
	canvas.draw_arc(Vector2(110.0, -30.0), 54.0, -PI * 0.6, PI * 0.6, 16, Color(0.85, 0.6, 0.35), 20.0)
	for side in [-1.0, 1.0]:
		canvas.draw_circle(Vector2(side * 48.0, -30.0), 26.0, Color.WHITE)
		canvas.draw_circle(Vector2(side * 48.0 + 8.0, -26.0), 12.0, Color(0.1, 0.1, 0.15))
	if state == State.YEETED:
		canvas.draw_arc(Vector2(0.0, 44.0), 30.0, PI + 0.3, TAU - 0.3, 12, Color(0.4, 0.25, 0.2), 9.0)
	else:
		canvas.draw_arc(Vector2(0.0, 36.0), 30.0, 0.15, PI - 0.15, 12, Color(0.4, 0.25, 0.2), 9.0)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state != State.PLAYING:
		return
	# sound waves while question is live
	var wob := fmod(Time.get_ticks_msec() / 200.0, TAU)
	for i in 3:
		canvas.draw_arc(Vector2(540.0, 700.0), 200.0 + i * 50.0 + sin(wob + i) * 8.0,
			-0.6, 0.6, 16, Color(0.6, 0.85, 1.0, 0.5 - i * 0.13), 8.0)
		canvas.draw_arc(Vector2(540.0, 700.0), 200.0 + i * 50.0 + sin(wob + i) * 8.0,
			PI - 0.6, PI + 0.6, 16, Color(0.6, 0.85, 1.0, 0.5 - i * 0.13), 8.0)
	# timer bar
	var frac := clampf(time_left / time_total, 0.0, 1.0)
	var bar_color := Color(0.4, 0.85, 0.55) if frac > 0.35 else Color(0.95, 0.4, 0.35)
	canvas.draw_rect(Rect2(140.0, 1010.0, 800.0, 34.0), Color(0.18, 0.16, 0.26))
	canvas.draw_rect(Rect2(140.0, 1010.0, 800.0 * frac, 34.0), bar_color)
