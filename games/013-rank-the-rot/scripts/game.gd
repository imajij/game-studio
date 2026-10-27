extends Node2D
## Rank the Rot — a creature card appears; swipe it into a tier: ↑ S, → A,
## ↓ B, ← F. After 8 cards the daily Mohalla Panel verdict (a deterministic
## in-game jury that changes every calendar day — NOT real online votes) is
## revealed and you're scored on how close your taste was. Arguing with the
## panel is the retention. Rewarded ad = peek hints; interstitial on restart.

enum State { RANKING, REVEAL }

const TIERS: Array[String] = ["S", "A", "B", "F"]
const TIER_COLORS: Array[Color] = [
	Color(1.0, 0.78, 0.25), Color(0.4, 0.85, 0.55),
	Color(0.4, 0.65, 0.95), Color(0.95, 0.4, 0.45),
]
const CREATURES: Array = [
	# name, body color, accessory variant
	["Gyaan Pigeon", Color(0.6, 0.65, 0.75), 0],
	["WiFi Chacha", Color(0.85, 0.7, 0.5), 1],
	["Tubelight Tiger", Color(0.95, 0.8, 0.3), 2],
	["Scooter Shark", Color(0.4, 0.6, 0.85), 3],
	["Golgappa Ghost", Color(0.92, 0.9, 0.85), 4],
	["Filter Coffee Falcon", Color(0.6, 0.42, 0.3), 5],
	["Thermocol Titan", Color(0.9, 0.93, 0.95), 6],
	["Dramatic Lizard", Color(0.5, 0.8, 0.45), 7],
	["Inverter Owl", Color(0.55, 0.5, 0.7), 8],
	["Mango Mummy", Color(0.95, 0.65, 0.2), 9],
]
const CARDS_PER_ROUND: int = 8
const SWIPE_PX: float = 110.0
const BEST_KEY: String = "best"
const STREAK_KEY: String = "streak_day"
const RESTART_LOCKOUT_SEC: float = 0.6
const CARD_CENTER: Vector2 = Vector2(540.0, 760.0)

const SFX_SWIPE: AudioStream = preload("res://assets/audio/swipe.wav")
const SFX_PLACE: AudioStream = preload("res://assets/audio/place.wav")
const SFX_REVEAL: AudioStream = preload("res://assets/audio/reveal.wav")
const SFX_MATCH: AudioStream = preload("res://assets/audio/match.wav")
const SFX_MISMATCH: AudioStream = preload("res://assets/audio/mismatch.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.RANKING
var deck: Array = []
var card_index: int = 0
var placements: Dictionary = {}  # creature id -> tier index
var best: int = 0
var hints_left: int = 0
var touch_start: Vector2 = Vector2.ZERO
var touching: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var restarting: bool = false
var reveal_at_sec: float = 0.0

@onready var deco: Deco = $Deco
@onready var progress_label: Label = $UI/ProgressLabel
@onready var name_label: Label = $UI/NameLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var tier_labels: Array = [$UI/TierS, $UI/TierA, $UI/TierB, $UI/TierF]
@onready var peek_button: Button = $UI/PeekButton
@onready var reveal_panel: Control = $UI/RevealPanel
@onready var reveal_body: Label = $UI/RevealPanel/Body

func _ready() -> void:
	randomize()
	deco.painter = _paint
	peek_button.pressed.connect(_on_peek_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	best = int(SaveManager.get_value(BEST_KEY, 0))
	var ids := range(CREATURES.size())
	ids.shuffle()
	deck = ids.slice(0, CARDS_PER_ROUND)
	Analytics.log_event("round_start")
	_refresh_ui()


func _process(_delta: float) -> void:
	deco.queue_redraw()


## Deterministic "panel" tier for a creature today. Everyone sees the same
## verdict on the same date; it reshuffles daily.
func panel_tier(id: int) -> int:
	var date := Time.get_date_dict_from_system()
	var seed_text := "%s-%04d%02d%02d" % [CREATURES[id][0], date.year, date.month, date.day]
	return int(hash(seed_text)) % TIERS.size()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.REVEAL:
		var end_touch := event as InputEventScreenTouch
		if end_touch != null and end_touch.pressed:
			_try_restart()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			touching = true
			touch_start = touch.position
			drag_offset = Vector2.ZERO
		else:
			if touching and drag_offset.length() >= SWIPE_PX:
				_place_card(_dir_to_tier(drag_offset))
			touching = false
			drag_offset = Vector2.ZERO
	elif event is InputEventScreenDrag and touching:
		var drag := event as InputEventScreenDrag
		drag_offset = drag.position - touch_start


func _dir_to_tier(offset: Vector2) -> int:
	if absf(offset.y) > absf(offset.x):
		return 0 if offset.y < 0.0 else 2  # up S, down B
	return 1 if offset.x > 0.0 else 3      # right A, left F


func _place_card(tier: int) -> void:
	var id: int = deck[card_index]
	placements[id] = tier
	AudioManager.play_sfx(SFX_SWIPE, 0.1)
	AudioManager.play_sfx(SFX_PLACE, 0.05, 1.0 + tier * 0.1)
	Haptics.light()
	card_index += 1
	if hints_left > 0:
		hints_left -= 1
	if card_index >= deck.size():
		_reveal()
	_refresh_ui()


func _reveal() -> void:
	state = State.REVEAL
	reveal_at_sec = _now_sec()
	AudioManager.play_sfx(SFX_REVEAL)
	var score := 0
	var lines: Array[String] = []
	for id: int in deck:
		var yours: int = placements[id]
		var panel := panel_tier(id)
		var points := 3 if yours == panel else (1 if absi(yours - panel) == 1 else 0)
		score += points
		lines.append("%s %s — you %s · panel %s" % ["✓" if yours == panel else "✗",
			CREATURES[id][0], TIERS[yours], TIERS[panel]])
	var max_score := deck.size() * 3
	if score > best:
		best = score
		SaveManager.set_value(BEST_KEY, best)
	var verdict := "CERTIFIED TASTE"
	if score < max_score / 3:
		verdict = "THE PANEL IS DISAPPOINTED"
	elif score < 2 * max_score / 3:
		verdict = "MID. RESPECTFULLY."
	reveal_body.text = "%s\n\n%s\n\nSCORE %d / %d   BEST %d\nnew panel verdict tomorrow!" \
		% [verdict, "\n".join(lines), score, max_score, best]
	AudioManager.play_sfx(SFX_MATCH if score >= 2 * max_score / 3 else SFX_MISMATCH)
	Analytics.log_event("game_over", {"score": score})
	AdsManager.round_finished()
	reveal_panel.visible = true


func _on_peek_pressed() -> void:
	AudioManager.play_sfx(SFX_TAP)
	AdsManager.show_rewarded("peek")


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "peek":
		return
	hints_left = 3
	Analytics.log_event("peek_used")
	Haptics.medium()
	_refresh_ui()


func _try_restart() -> void:
	if restarting or _now_sec() - reveal_at_sec < RESTART_LOCKOUT_SEC:
		return
	restarting = true
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


func _refresh_ui() -> void:
	progress_label.text = "CARD %d / %d" % [mini(card_index + 1, deck.size()), deck.size()]
	if state == State.RANKING and card_index < deck.size():
		var id: int = deck[card_index]
		name_label.text = CREATURES[id][0]
		if hints_left > 0:
			hint_label.text = "panel says: %s" % TIERS[panel_tier(id)]
		else:
			hint_label.text = ""
	for t in 4:
		var names: Array[String] = []
		for id: int in placements:
			if placements[id] == t:
				names.append(String(CREATURES[id][0]).split(" ")[0])
		tier_labels[t].text = "%s  %s" % [TIERS[t], ", ".join(names)]
	peek_button.visible = state == State.RANKING and hints_left == 0 \
		and AdsManager.is_rewarded_ready()


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


func _paint(canvas: CanvasItem) -> void:
	# tier board backdrop
	for t in 4:
		var y := 1310.0 + t * 130.0
		canvas.draw_rect(Rect2(50.0, y, 980.0, 112.0), Color(0.14, 0.13, 0.19))
		canvas.draw_rect(Rect2(50.0, y, 112.0, 112.0), TIER_COLORS[t])
	if state != State.RANKING or card_index >= deck.size():
		return
	# swipe direction arrows
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(505.0, 320.0), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, TIER_COLORS[0])
	canvas.draw_string(font, Vector2(960.0, 790.0), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, TIER_COLORS[1])
	canvas.draw_string(font, Vector2(505.0, 1270.0), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, TIER_COLORS[2])
	canvas.draw_string(font, Vector2(70.0, 790.0), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, TIER_COLORS[3])
	# the card follows the drag a little
	var center := CARD_CENTER + drag_offset.limit_length(220.0)
	var tilt := clampf(drag_offset.x / 600.0, -0.25, 0.25)
	canvas.draw_set_transform(center, tilt, Vector2.ONE)
	canvas.draw_rect(Rect2(-310.0, -400.0, 620.0, 800.0), Color(0.96, 0.94, 0.88))
	canvas.draw_rect(Rect2(-310.0, -400.0, 620.0, 800.0), Color(0.2, 0.17, 0.22), false, 10.0)
	var id: int = deck[card_index]
	var body: Color = CREATURES[id][1]
	var outline := body.darkened(0.45)
	# creature blob
	canvas.draw_circle(Vector2(0.0, -40.0), 190.0, outline)
	canvas.draw_circle(Vector2(0.0, -40.0), 180.0, body)
	canvas.draw_circle(Vector2(0.0, 30.0), 100.0, body.lightened(0.15))
	var variant: int = CREATURES[id][2]
	_paint_accessory(canvas, variant, outline)
	for side in [-1.0, 1.0]:
		canvas.draw_circle(Vector2(side * 62.0, -70.0), 30.0, Color.WHITE)
		canvas.draw_circle(Vector2(side * 62.0 + 8.0, -64.0), 14.0, Color(0.1, 0.1, 0.15))
	canvas.draw_arc(Vector2(0.0, 20.0), 34.0, 0.15, PI - 0.15, 12, outline, 9.0)
	# highlight toward current drag direction
	if drag_offset.length() > 40.0:
		var t := _dir_to_tier(drag_offset)
		canvas.draw_rect(Rect2(-310.0, -400.0, 620.0, 800.0),
			Color(TIER_COLORS[t].r, TIER_COLORS[t].g, TIER_COLORS[t].b, 0.18))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_accessory(canvas: CanvasItem, variant: int, outline: Color) -> void:
	match variant:
		0:  # pigeon wing + lecture finger
			canvas.draw_arc(Vector2(-130.0, -20.0), 70.0, PI * 0.5, PI * 1.5, 16, outline, 16.0)
			canvas.draw_line(Vector2(150.0, -60.0), Vector2(230.0, -130.0), outline, 18.0)
		1:  # chacha moustache + router antenna
			canvas.draw_arc(Vector2(-40.0, -4.0), 40.0, PI, TAU, 12, Color(0.3, 0.25, 0.25), 20.0)
			canvas.draw_arc(Vector2(40.0, -4.0), 40.0, PI, TAU, 12, Color(0.3, 0.25, 0.25), 20.0)
			canvas.draw_line(Vector2(0.0, -220.0), Vector2(0.0, -300.0), outline, 10.0)
			canvas.draw_circle(Vector2(0.0, -306.0), 14.0, Color(0.4, 0.9, 0.5))
		2:  # tiger stripes + flicker bolt
			for i in 3:
				canvas.draw_line(Vector2(-150.0 + i * 60.0, -180.0),
					Vector2(-180.0 + i * 60.0, -90.0), outline, 16.0)
			canvas.draw_line(Vector2(140.0, -230.0), Vector2(180.0, -170.0), Color(1, 0.95, 0.5), 12.0)
		3:  # shark fin + handlebar
			var fin := PackedVector2Array([Vector2(-40, -210), Vector2(60, -210), Vector2(10, -300)])
			canvas.draw_colored_polygon(fin, outline)
			canvas.draw_line(Vector2(-110.0, 60.0), Vector2(110.0, 60.0), Color(0.3, 0.3, 0.35), 14.0)
		4:  # ghost wavy bottom + golgappa
			for i in 5:
				canvas.draw_circle(Vector2(-120.0 + i * 60.0, 130.0), 34.0, CREATURES[4][1])
			canvas.draw_circle(Vector2(130.0, -180.0), 36.0, Color(0.9, 0.75, 0.4))
		5:  # falcon beak + tumbler
			var beak := PackedVector2Array([Vector2(20, -60), Vector2(120, -30), Vector2(20, 0)])
			canvas.draw_colored_polygon(beak, Color(0.95, 0.7, 0.2))
			canvas.draw_rect(Rect2(-180.0, -10.0, 60.0, 80.0), Color(0.8, 0.82, 0.86))
		6:  # blocky thermocol corners
			for corner: Vector2 in [Vector2(-150, -190), Vector2(150, -190)]:
				canvas.draw_rect(Rect2(corner.x - 40.0, corner.y - 40.0, 80.0, 80.0),
					Color(0.97, 0.98, 1.0))
		7:  # drama — back of hand on forehead
			canvas.draw_line(Vector2(80.0, -160.0), Vector2(-30.0, -210.0), outline, 20.0)
			canvas.draw_circle(Vector2(-40.0, -214.0), 26.0, outline)
		8:  # owl brows + battery
			for side in [-1.0, 1.0]:
				canvas.draw_line(Vector2(side * 100.0, -130.0), Vector2(side * 20.0, -110.0),
					outline, 16.0)
			canvas.draw_rect(Rect2(-40.0, -250.0, 80.0, 44.0), Color(0.4, 0.75, 0.45))
		9:  # mummy wraps + mango leaf
			for i in 3:
				canvas.draw_line(Vector2(-170.0, -120.0 + i * 70.0), Vector2(170.0, -90.0 + i * 70.0),
					Color(0.98, 0.95, 0.88, 0.9), 22.0)
			canvas.draw_arc(Vector2(20.0, -230.0), 40.0, PI * 1.1, PI * 1.9, 10, Color(0.4, 0.7, 0.3), 14.0)
