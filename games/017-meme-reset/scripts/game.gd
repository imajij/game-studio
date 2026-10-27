extends Node2D
## Meme Reset 2014 — a retro CRT arcade throwback. Smash brick walls with a
## paddle and ball; golden bricks drop collectible "era-cards": original
## tributes to 2010s internet artifacts (Shutter Shades, Planking Pete, Dial-Up
## Demon…). Collection persists across runs — "remember this?" is the hook.
## Rewarded ad = extra ball; interstitial on restart.

enum State { SERVE, PLAYING, GAME_OVER }

const BEST_KEY: String = "best"
const CARDS_KEY: String = "cards"
const CARDS: Array[String] = [
	"Shutter Shades", "Planking Pete", "Duckface Dana", "Swag Fedora",
	"Keyboard Smash", "Loading Bar of Doom", "Dial-Up Demon", "Selfie Stick",
	"Air Horn", "Rage Scribble",
]
const BRICK_COLS: int = 8
const BRICK_W: float = 122.0
const BRICK_H: float = 64.0
const BRICK_TOP: float = 300.0
const BRICK_LEFT: float = 52.0
const PADDLE_Y: float = 1650.0
const PADDLE_W: float = 260.0
const PADDLE_H: float = 34.0
const BALL_R: float = 22.0
const BASE_BALL_SPEED: float = 850.0
const SPEED_PER_LEVEL: float = 55.0
const MAX_LIVES: int = 3
const GOLD_CHANCE: float = 0.12
const RESTART_LOCKOUT_SEC: float = 0.6

const SFX_BOUNCE: AudioStream = preload("res://assets/audio/bounce.wav")
const SFX_BRICK: AudioStream = preload("res://assets/audio/brick.wav")
const SFX_CARD: AudioStream = preload("res://assets/audio/card.wav")
const SFX_LOSE_BALL: AudioStream = preload("res://assets/audio/lose_ball.wav")
const SFX_LEVEL: AudioStream = preload("res://assets/audio/level.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.SERVE
var score: int = 0
var best: int = 0
var level: int = 1
var lives: int = MAX_LIVES
var paddle_x: float = 540.0
var ball_pos: Vector2 = Vector2.ZERO
var ball_vel: Vector2 = Vector2.ZERO
var bricks: Array = []  # {rect: Rect2, hp: int, gold: bool}
var cards: Array = []
var extra_ball_used: bool = false
var restarting: bool = false
var game_over_at_sec: float = 0.0

@onready var deco: Deco = $Deco
@onready var score_label: Label = $UI/ScoreLabel
@onready var info_label: Label = $UI/InfoLabel
@onready var toast_label: Label = $UI/ToastLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_label: Label = $UI/GameOverPanel/FinalScore
@onready var ball_button: Button = $UI/GameOverPanel/BallButton

func _ready() -> void:
	randomize()
	deco.painter = _paint
	ball_button.pressed.connect(_on_ball_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	best = int(SaveManager.get_value(BEST_KEY, 0))
	var saved: Variant = SaveManager.get_value(CARDS_KEY, [])
	if saved is Array:
		for v in saved:
			cards.append(int(v))
	_build_level()
	Analytics.log_event("round_start")
	_refresh_ui()


func _build_level() -> void:
	bricks.clear()
	var rows := mini(3 + level, 7)
	for row in rows:
		for col in BRICK_COLS:
			if randf() < 0.08:
				continue
			bricks.append({
				"rect": Rect2(BRICK_LEFT + col * BRICK_W + 4.0, BRICK_TOP + row * BRICK_H + 4.0,
					BRICK_W - 8.0, BRICK_H - 8.0),
				"hp": 2 if level > 2 and row < 2 else 1,
				"gold": randf() < GOLD_CHANCE,
			})
	state = State.SERVE
	ball_pos = Vector2(paddle_x, PADDLE_Y - 60.0)


func ball_speed() -> float:
	return BASE_BALL_SPEED + (level - 1) * SPEED_PER_LEVEL


func _process(delta: float) -> void:
	deco.queue_redraw()
	if state != State.PLAYING:
		if state == State.SERVE:
			ball_pos = Vector2(paddle_x, PADDLE_Y - 60.0)
		return
	ball_pos += ball_vel * delta
	# walls
	if ball_pos.x < BALL_R:
		ball_pos.x = BALL_R
		ball_vel.x = absf(ball_vel.x)
		AudioManager.play_sfx(SFX_BOUNCE, 0.1)
	elif ball_pos.x > 1080.0 - BALL_R:
		ball_pos.x = 1080.0 - BALL_R
		ball_vel.x = -absf(ball_vel.x)
		AudioManager.play_sfx(SFX_BOUNCE, 0.1)
	if ball_pos.y < 180.0 + BALL_R:
		ball_pos.y = 180.0 + BALL_R
		ball_vel.y = absf(ball_vel.y)
		AudioManager.play_sfx(SFX_BOUNCE, 0.1)
	# paddle
	var paddle := Rect2(paddle_x - PADDLE_W / 2.0, PADDLE_Y - PADDLE_H / 2.0, PADDLE_W, PADDLE_H)
	if ball_vel.y > 0.0 and paddle.grow(BALL_R).has_point(ball_pos):
		var offset := clampf((ball_pos.x - paddle_x) / (PADDLE_W / 2.0), -1.0, 1.0)
		var angle := -PI / 2.0 + offset * 1.05
		ball_vel = Vector2(cos(angle), sin(angle)) * ball_speed()
		ball_pos.y = paddle.position.y - BALL_R
		AudioManager.play_sfx(SFX_BOUNCE, 0.1, 1.15)
		Haptics.light()
	# bricks
	for i in range(bricks.size() - 1, -1, -1):
		var brick: Dictionary = bricks[i]
		var rect: Rect2 = brick.rect
		if not rect.grow(BALL_R).has_point(ball_pos):
			continue
		# bounce off nearest axis
		var cx := clampf(ball_pos.x, rect.position.x, rect.end.x)
		var cy := clampf(ball_pos.y, rect.position.y, rect.end.y)
		if absf(ball_pos.x - cx) > absf(ball_pos.y - cy):
			ball_vel.x = -ball_vel.x
		else:
			ball_vel.y = -ball_vel.y
		brick.hp -= 1
		if brick.hp <= 0:
			score += 20 if brick.gold else 10
			if brick.gold:
				_drop_card()
			bricks.remove_at(i)
			AudioManager.play_sfx(SFX_BRICK, 0.1)
		else:
			AudioManager.play_sfx(SFX_BOUNCE, 0.1, 0.8)
		Haptics.light()
		break
	# lost ball
	if ball_pos.y > 1920.0 + BALL_R:
		lives -= 1
		AudioManager.play_sfx(SFX_LOSE_BALL)
		Haptics.heavy()
		if lives <= 0:
			_game_over()
		else:
			state = State.SERVE
		_refresh_ui()
	# level clear
	if bricks.is_empty() and state == State.PLAYING:
		level += 1
		score += 100
		AudioManager.play_sfx(SFX_LEVEL)
		Haptics.medium()
		_toast("LEVEL %d — rewind deeper!" % level)
		_build_level()
	if score > best:
		best = score
		SaveManager.set_value(BEST_KEY, best)
	_refresh_ui()


func _drop_card() -> void:
	var missing: Array = []
	for i in CARDS.size():
		if not cards.has(i):
			missing.append(i)
	if missing.is_empty():
		score += 50
		_toast("full collection bonus +50")
		return
	var id: int = missing[randi() % missing.size()]
	cards.append(id)
	SaveManager.set_value(CARDS_KEY, cards)
	AudioManager.play_sfx(SFX_CARD)
	_toast("ERA-CARD: %s  (%d/%d)" % [CARDS[id], cards.size(), CARDS.size()])


func _unhandled_input(event: InputEvent) -> void:
	if state == State.GAME_OVER:
		var end_touch := event as InputEventScreenTouch
		if end_touch != null and end_touch.pressed \
				and not ball_button.get_global_rect().has_point(end_touch.position):
			_try_restart()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		paddle_x = clampf(touch.position.x, PADDLE_W / 2.0, 1080.0 - PADDLE_W / 2.0)
		if touch.pressed and state == State.SERVE:
			state = State.PLAYING
			var angle := -PI / 2.0 + randf_range(-0.5, 0.5)
			ball_vel = Vector2(cos(angle), sin(angle)) * ball_speed()
			AudioManager.play_sfx(SFX_TAP)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		paddle_x = clampf(drag.position.x, PADDLE_W / 2.0, 1080.0 - PADDLE_W / 2.0)


func _game_over() -> void:
	state = State.GAME_OVER
	game_over_at_sec = _now_sec()
	Analytics.log_event("game_over", {"score": score})
	AdsManager.round_finished()
	AudioManager.play_sfx(SFX_GAME_OVER)
	final_label.text = "SCORE %d   BEST %d\nLEVEL %d\nCARDS %d / %d" \
		% [score, best, level, cards.size(), CARDS.size()]
	ball_button.visible = not extra_ball_used and AdsManager.is_rewarded_ready()
	game_over_panel.visible = true


func _on_ball_pressed() -> void:
	if extra_ball_used:
		return
	AudioManager.play_sfx(SFX_TAP)
	AdsManager.show_rewarded("ball")


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "ball" or state != State.GAME_OVER:
		return
	extra_ball_used = true
	lives = 1
	state = State.SERVE
	game_over_panel.visible = false
	Analytics.log_event("extra_ball")
	Haptics.medium()
	_refresh_ui()


func _try_restart() -> void:
	if restarting or _now_sec() - game_over_at_sec < RESTART_LOCKOUT_SEC:
		return
	restarting = true
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


var _toast_tween: Tween = null

func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func _refresh_ui() -> void:
	score_label.text = str(score)
	info_label.text = "LV %d   ●%s   BEST %d" % [level, "●".repeat(maxi(lives - 1, 0)), best]
	if state == State.SERVE:
		info_label.text += "   tap to launch"


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


func _paint(canvas: CanvasItem) -> void:
	# CRT frame + scanlines
	canvas.draw_rect(Rect2(0.0, 160.0, 1080.0, 20.0), Color(0.9, 0.3, 0.8, 0.5))
	for i in 44:
		canvas.draw_line(Vector2(0.0, 180.0 + i * 40.0), Vector2(1080.0, 180.0 + i * 40.0),
			Color(1.0, 1.0, 1.0, 0.025), 2.0)
	# bricks
	for brick: Dictionary in bricks:
		var rect: Rect2 = brick.rect
		var color: Color
		if brick.gold:
			color = Color(1.0, 0.82, 0.25)
		elif brick.hp >= 2:
			color = Color(0.3, 0.85, 0.9)
		else:
			color = Color(0.9, 0.35, 0.75)
		canvas.draw_rect(rect, color)
		canvas.draw_rect(rect, color.darkened(0.45), false, 5.0)
		if brick.gold:
			canvas.draw_rect(Rect2(rect.get_center() - Vector2(14.0, 20.0), Vector2(28.0, 40.0)),
				color.darkened(0.35), false, 4.0)
	# paddle (swag fedora shape, obviously)
	canvas.draw_rect(Rect2(paddle_x - PADDLE_W / 2.0, PADDLE_Y - PADDLE_H / 2.0,
		PADDLE_W, PADDLE_H), Color(0.45, 0.35, 0.3))
	canvas.draw_rect(Rect2(paddle_x - PADDLE_W / 5.0, PADDLE_Y - PADDLE_H / 2.0 - 26.0,
		PADDLE_W * 0.4, 26.0), Color(0.45, 0.35, 0.3))
	canvas.draw_rect(Rect2(paddle_x - PADDLE_W / 2.0, PADDLE_Y - 6.0, PADDLE_W, 10.0),
		Color(0.2, 0.15, 0.14))
	# ball
	canvas.draw_circle(ball_pos, BALL_R + 4.0, Color(0.3, 0.9, 0.9, 0.35))
	canvas.draw_circle(ball_pos, BALL_R, Color(0.85, 1.0, 1.0))
