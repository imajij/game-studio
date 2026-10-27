extends Node2D
## Brainrot Fusion Lab — mash two essences into a fusion creature with an
## auto-generated name, then battle the Lab's AI fusions. Fully offline: every
## opponent is generated locally. Names come from fixed syllable pools (no free
## text — Families-safe). Rewarded ad unlocks the two rare essences.

enum State { PICK, BATTLE, RESULT }

const PARTS: Array = [
	# name, name prefix, name suffix, color, power, speed, chaos, rare
	["Jalebi", "Jale", "bi", Color(0.95, 0.6, 0.15), 2, 1, 5, false],
	["Tubelight", "Tube", "light", Color(0.9, 0.95, 0.7), 1, 4, 3, false],
	["Pressure Cooker", "Cook", "ker", Color(0.75, 0.78, 0.82), 5, 1, 2, false],
	["Pigeon", "Pige", "on", Color(0.6, 0.65, 0.75), 1, 5, 2, false],
	["Rickshaw", "Riksh", "aw", Color(0.3, 0.7, 0.65), 3, 4, 1, false],
	["Cactus", "Cact", "us", Color(0.45, 0.75, 0.35), 4, 1, 3, false],
	["Dhol", "Dhol", "ak", Color(0.85, 0.35, 0.35), 5, 3, 4, true],
	["Monsoon Cloud", "Mons", "oon", Color(0.5, 0.6, 0.85), 3, 4, 5, true],
]
const STAT_NAMES: Array[String] = ["POWER", "SPEED", "CHAOS"]
const MAX_HP: int = 3
const EXCHANGE_SEC: float = 1.1
const TROPHY_KEY: String = "trophies"
const STREAK_KEY: String = "best_streak"
const UNLOCK_KEY: String = "rare_unlocked"
const RESTART_LOCKOUT_SEC: float = 0.6

const SFX_FUSE: AudioStream = preload("res://assets/audio/fuse.wav")
const SFX_SPAWN: AudioStream = preload("res://assets/audio/spawn.wav")
const SFX_HIT: AudioStream = preload("res://assets/audio/hit.wav")
const SFX_WIN: AudioStream = preload("res://assets/audio/win.wav")
const SFX_LOSE: AudioStream = preload("res://assets/audio/lose.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PICK
var pick_a: int = -1
var pick_b: int = -1
var enemy_a: int = 0
var enemy_b: int = 0
var my_hp: int = MAX_HP
var enemy_hp: int = MAX_HP
var exchange_timer: float = 0.0
var battle_over: bool = false
var trophies: int = 0
var streak: int = 0
var best_streak: int = 0
var rare_unlocked: bool = false
var part_buttons: Array = []
var result_at_sec: float = 0.0
var zap_time: float = 0.0

@onready var deco: Deco = $Deco
@onready var title_label: Label = $UI/TitleLabel
@onready var trophy_label: Label = $UI/TrophyLabel
@onready var my_name_label: Label = $UI/MyNameLabel
@onready var enemy_name_label: Label = $UI/EnemyNameLabel
@onready var log_label: Label = $UI/LogLabel
@onready var parts_grid: GridContainer = $UI/PartsGrid
@onready var fuse_button: Button = $UI/FuseButton
@onready var unlock_button: Button = $UI/UnlockButton
@onready var result_panel: Control = $UI/ResultPanel
@onready var result_title: Label = $UI/ResultPanel/Title
@onready var result_body: Label = $UI/ResultPanel/Body

func _ready() -> void:
	randomize()
	deco.painter = _paint
	fuse_button.pressed.connect(_on_fuse_pressed)
	unlock_button.pressed.connect(_on_unlock_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	trophies = int(SaveManager.get_value(TROPHY_KEY, 0))
	best_streak = int(SaveManager.get_value(STREAK_KEY, 0))
	rare_unlocked = bool(SaveManager.get_value(UNLOCK_KEY, false))
	_build_grid()
	Analytics.log_event("round_start")
	_refresh_ui()


func _process(delta: float) -> void:
	zap_time = maxf(zap_time - delta, 0.0)
	deco.queue_redraw()
	if state != State.BATTLE or battle_over:
		return
	exchange_timer -= delta
	if exchange_timer <= 0.0:
		exchange_timer = EXCHANGE_SEC
		_exchange()


func fusion_name(a: int, b: int) -> String:
	return String(PARTS[a][1]) + String(PARTS[b][2])


func fusion_stat(a: int, b: int, stat: int) -> int:
	return int(PARTS[a][3 + stat + 1]) + int(PARTS[b][3 + stat + 1])


# --- picking / fusing ----------------------------------------------------------

func _build_grid() -> void:
	for i in PARTS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(230.0, 100.0)
		button.add_theme_font_size_override("font_size", 34)
		button.pressed.connect(_on_part_pressed.bind(i))
		parts_grid.add_child(button)
		part_buttons.append(button)


func _on_part_pressed(i: int) -> void:
	if state != State.PICK:
		return
	if bool(PARTS[i][7]) and not rare_unlocked:
		AudioManager.play_sfx(SFX_TAP)
		log_label.text = "That essence is still sealed — watch an ad to unlock both rares."
		return
	AudioManager.play_sfx(SFX_TAP, 0.1)
	Haptics.light()
	if pick_a == i or pick_b == i:
		if pick_a == i:
			pick_a = pick_b
		pick_b = -1
	elif pick_a < 0:
		pick_a = i
	elif pick_b < 0:
		pick_b = i
	else:
		pick_a = pick_b
		pick_b = i
	_refresh_ui()


func _on_fuse_pressed() -> void:
	if state != State.PICK or pick_a < 0 or pick_b < 0:
		return
	AudioManager.play_sfx(SFX_FUSE)
	Haptics.medium()
	zap_time = 0.6
	Analytics.log_event("fuse", {"a": pick_a, "b": pick_b})
	# AI opponent scales a bit with streak: more rerolls for higher totals
	enemy_a = randi() % PARTS.size()
	enemy_b = randi() % PARTS.size()
	while enemy_b == enemy_a:
		enemy_b = randi() % PARTS.size()
	my_hp = MAX_HP
	enemy_hp = MAX_HP
	battle_over = false
	exchange_timer = EXCHANGE_SEC * 1.4
	state = State.BATTLE
	AudioManager.play_sfx(SFX_SPAWN)
	log_label.text = "%s  VS  %s" % [fusion_name(pick_a, pick_b), fusion_name(enemy_a, enemy_b)]
	_refresh_ui()


# --- battle ---------------------------------------------------------------------

func _exchange() -> void:
	var my_stat := randi() % 3
	var enemy_stat := randi() % 3
	var mine := fusion_stat(pick_a, pick_b, my_stat) + randi() % 3
	var theirs := fusion_stat(enemy_a, enemy_b, enemy_stat) + randi() % 3
	var my_fusion_name := fusion_name(pick_a, pick_b)
	var enemy_fusion_name := fusion_name(enemy_a, enemy_b)
	AudioManager.play_sfx(SFX_HIT, 0.1)
	Haptics.light()
	if mine >= theirs:
		enemy_hp -= 1
		log_label.text = "%s hits with %s %d  (vs %d)!" \
			% [my_fusion_name, STAT_NAMES[my_stat], mine, theirs]
	else:
		my_hp -= 1
		log_label.text = "%s counters with %s %d  (vs %d)!" \
			% [enemy_fusion_name, STAT_NAMES[enemy_stat], theirs, mine]
	_refresh_ui()
	if my_hp <= 0 or enemy_hp <= 0:
		battle_over = true
		await get_tree().create_timer(0.8).timeout
		_finish_battle(enemy_hp <= 0)


func _finish_battle(won: bool) -> void:
	state = State.RESULT
	result_at_sec = _now_sec()
	if won:
		trophies += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
		SaveManager.set_value(TROPHY_KEY, trophies)
		SaveManager.set_value(STREAK_KEY, best_streak)
		AudioManager.play_sfx(SFX_WIN)
		Haptics.medium()
		result_title.text = "FUSION VICTORIOUS"
	else:
		streak = 0
		AudioManager.play_sfx(SFX_LOSE)
		Haptics.heavy()
		result_title.text = "DISASSEMBLED"
	result_body.text = "%s\n\nTROPHIES %d   STREAK %d   BEST %d\n\ntap to fuse again" \
		% [fusion_name(pick_a, pick_b), trophies, streak, best_streak]
	Analytics.log_event("game_over", {"won": won})
	AdsManager.round_finished()
	result_panel.visible = true


# --- rewarded unlock -------------------------------------------------------------

func _on_unlock_pressed() -> void:
	AudioManager.play_sfx(SFX_TAP)
	AdsManager.show_rewarded("unlock")


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "unlock":
		return
	rare_unlocked = true
	SaveManager.set_value(UNLOCK_KEY, true)
	Analytics.log_event("rare_unlocked")
	AudioManager.play_sfx(SFX_WIN)
	Haptics.medium()
	log_label.text = "Dhol + Monsoon Cloud unlocked forever!"
	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if state != State.RESULT:
		return
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	if _now_sec() - result_at_sec < RESTART_LOCKOUT_SEC:
		return
	result_panel.visible = false
	state = State.PICK
	pick_a = -1
	pick_b = -1
	log_label.text = "pick two essences"
	_refresh_ui()
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed


# --- ui ----------------------------------------------------------------------------

func _refresh_ui() -> void:
	trophy_label.text = "🏆 %d   STREAK %d" % [trophies, streak]
	for i in part_buttons.size():
		var button: Button = part_buttons[i]
		var tag := ""
		if i == pick_a or i == pick_b:
			tag = " ✦"
		if bool(PARTS[i][7]) and not rare_unlocked:
			button.text = "🔒 %s" % PARTS[i][0]
		else:
			button.text = "%s%s" % [PARTS[i][0], tag]
	fuse_button.visible = state == State.PICK
	fuse_button.disabled = pick_a < 0 or pick_b < 0
	if pick_a >= 0 and pick_b >= 0:
		fuse_button.text = "FUSE: %s" % fusion_name(pick_a, pick_b)
		my_name_label.text = "%s  (P%d S%d C%d)" % [fusion_name(pick_a, pick_b),
			fusion_stat(pick_a, pick_b, 0), fusion_stat(pick_a, pick_b, 1),
			fusion_stat(pick_a, pick_b, 2)]
	elif state == State.PICK:
		fuse_button.text = "FUSE"
		my_name_label.text = "pick two essences"
	if state == State.BATTLE:
		my_name_label.text = "%s  %s" % [fusion_name(pick_a, pick_b), "♥".repeat(maxi(my_hp, 0))]
		enemy_name_label.text = "%s  %s" % [fusion_name(enemy_a, enemy_b), "♥".repeat(maxi(enemy_hp, 0))]
	enemy_name_label.visible = state == State.BATTLE
	parts_grid.visible = state == State.PICK
	unlock_button.visible = state == State.PICK and not rare_unlocked \
		and AdsManager.is_rewarded_ready()


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- painting -----------------------------------------------------------------------

func _draw_fusion(canvas: CanvasItem, a: int, b: int, at: Vector2, flip: bool) -> void:
	var color_a: Color = PARTS[a][3]
	var color_b: Color = PARTS[b][3]
	var blend := color_a.lerp(color_b, 0.5)
	var outline := blend.darkened(0.45)
	canvas.draw_circle(at, 130.0, outline)
	canvas.draw_circle(at, 120.0, blend)
	# half-tint from each parent
	canvas.draw_arc(at, 100.0, PI * 0.5, PI * 1.5, 24, color_a, 20.0)
	canvas.draw_arc(at, 100.0, -PI * 0.5, PI * 0.5, 24, color_b, 20.0)
	var dir := -1.0 if flip else 1.0
	for side in [-1.0, 1.0]:
		canvas.draw_circle(at + Vector2(side * 44.0, -30.0), 22.0, Color.WHITE)
		canvas.draw_circle(at + Vector2(side * 44.0 + dir * 7.0, -26.0), 10.0, Color(0.1, 0.1, 0.15))
	canvas.draw_arc(at + Vector2(0.0, 30.0), 26.0, 0.15, PI - 0.15, 10, outline, 7.0)
	# tiny antenna per parent
	canvas.draw_line(at + Vector2(-50.0, -110.0), at + Vector2(-80.0, -170.0), color_a.darkened(0.2), 12.0)
	canvas.draw_circle(at + Vector2(-82.0, -176.0), 16.0, color_a)
	canvas.draw_line(at + Vector2(50.0, -110.0), at + Vector2(80.0, -170.0), color_b.darkened(0.2), 12.0)
	canvas.draw_circle(at + Vector2(82.0, -176.0), 16.0, color_b)


func _paint(canvas: CanvasItem) -> void:
	# lab bench
	canvas.draw_rect(Rect2(60.0, 330.0, 960.0, 620.0), Color(0.13, 0.15, 0.2))
	canvas.draw_rect(Rect2(60.0, 330.0, 960.0, 620.0), Color(0.3, 0.45, 0.5), false, 8.0)
	match state:
		State.PICK:
			if pick_a >= 0:
				_draw_part(canvas, pick_a, Vector2(330.0, 620.0))
			if pick_b >= 0:
				_draw_part(canvas, pick_b, Vector2(750.0, 620.0))
			if pick_a >= 0 and pick_b >= 0:
				canvas.draw_line(Vector2(440.0, 620.0), Vector2(640.0, 620.0),
					Color(0.5, 0.9, 0.9, 0.6), 10.0)
		State.BATTLE, State.RESULT:
			_draw_fusion(canvas, pick_a, pick_b, Vector2(300.0, 640.0), false)
			_draw_fusion(canvas, enemy_a, enemy_b, Vector2(780.0, 640.0), true)
			canvas.draw_string(ThemeDB.fallback_font, Vector2(505.0, 660.0), "VS",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(1, 1, 1, 0.7))
	if zap_time > 0.0:
		for i in 6:
			var a := randf() * TAU
			canvas.draw_line(Vector2(540.0, 620.0),
				Vector2(540.0, 620.0) + Vector2(cos(a), sin(a)) * randf_range(120.0, 320.0),
				Color(0.7, 1.0, 1.0, zap_time), 6.0)


func _draw_part(canvas: CanvasItem, i: int, at: Vector2) -> void:
	var color: Color = PARTS[i][3]
	canvas.draw_circle(at, 96.0, color.darkened(0.45))
	canvas.draw_circle(at, 88.0, color)
	for side in [-1.0, 1.0]:
		canvas.draw_circle(at + Vector2(side * 30.0, -16.0), 15.0, Color.WHITE)
		canvas.draw_circle(at + Vector2(side * 30.0 + 5.0, -13.0), 7.0, Color(0.1, 0.1, 0.15))
	canvas.draw_string(ThemeDB.fallback_font, at + Vector2(-80.0, 150.0), PARTS[i][0],
		HORIZONTAL_ALIGNMENT_LEFT, 160.0, 30, Color(1, 1, 1, 0.8))
