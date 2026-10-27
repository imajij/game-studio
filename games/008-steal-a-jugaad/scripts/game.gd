extends Node2D
## Steal a Jugaad — collect absurd desi creatures off the bazaar conveyor,
## earn idle rupees from your godown, raid AI godowns past a sleepy guard,
## and fight off counter-thieves. Fully offline; raids are vs AI only.
## Rewarded ad = Lucky Crate. Interstitial after raid results.

enum Mode { BASE, RAID, THIEF }

const SLOT_COUNT: int = 12
const SLOT_COLS: int = 4
const CONVEYOR_Y: float = 1565.0
const SPAWN_EVERY_MIN: float = 2.4
const SPAWN_EVERY_MAX: float = 3.6
const WALK_SPEED_MIN: float = 130.0
const WALK_SPEED_MAX: float = 185.0
const TAP_RADIUS: float = 120.0
const FEATURED_PERIOD_SEC: int = 600
const OFFLINE_CAP_SEC: float = 4.0 * 3600.0
const RAID_COOLDOWN_SEC: float = 90.0
const RAID_PATH_TOP: float = 560.0
const RAID_PATH_BOTTOM: float = 1500.0
const SNEAK_SPEED: float = 0.16
const EYE_GRACE_SEC: float = 0.14
const THIEF_TAPS_NEEDED: int = 5
const THIEF_WINDOW_SEC: float = 4.0
const THIEF_CHANCE: float = 0.3
const START_COINS: int = 120

const SFX_BUY: AudioStream = preload("res://assets/audio/buy.wav")
const SFX_COIN: AudioStream = preload("res://assets/audio/coin.wav")
const SFX_CRATE: AudioStream = preload("res://assets/audio/crate.wav")
const SFX_CAUGHT: AudioStream = preload("res://assets/audio/caught.wav")
const SFX_STEAL: AudioStream = preload("res://assets/audio/steal.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var mode: Mode = Mode.BASE
var coins: float = START_COINS
var owned: Array = []  # creature ids, slot order
var walkers: Array = []  # [JugaadCreature, speed]
var spawn_in: float = 1.2
var featured_id: int = 0
var raid_ready_at: float = 0.0
var save_tick: float = 0.0
# raid state
var raid_target: int = 0
var raid_progress: float = 0.0
var raid_holding: bool = false
var eye_open: bool = false
var eye_timer: float = 2.0
var eye_open_for: float = 0.0
var raid_creature: JugaadCreature = null
# thief state
var thief_taps: int = 0
var thief_timer: float = 0.0
var thief_pos: Vector2 = Vector2.ZERO

@onready var deco: Deco = $Deco
@onready var conveyor: Node2D = $Conveyor
@onready var slots: Node2D = $Slots
@onready var coins_label: Label = $UI/CoinsLabel
@onready var income_label: Label = $UI/IncomeLabel
@onready var featured_label: Label = $UI/FeaturedLabel
@onready var raid_button: Button = $UI/RaidButton
@onready var crate_button: Button = $UI/CrateButton
@onready var hint_label: Label = $UI/HintLabel
@onready var toast_label: Label = $UI/ToastLabel
@onready var result_panel: Control = $UI/ResultPanel
@onready var result_title: Label = $UI/ResultPanel/Title
@onready var result_detail: Label = $UI/ResultPanel/Detail

func _ready() -> void:
	randomize()
	deco.painter = _paint
	raid_button.pressed.connect(_on_raid_pressed)
	crate_button.pressed.connect(_on_crate_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	_load_save()
	_claim_offline()
	Analytics.log_event("round_start")
	_rebuild_slots()
	_refresh_ui()


func _process(delta: float) -> void:
	var fid := int(Time.get_unix_time_from_system() / FEATURED_PERIOD_SEC) % JugaadDB.CREATURES.size()
	if fid != featured_id:
		featured_id = fid
	coins += _income_per_sec() * delta
	save_tick += delta
	if save_tick >= 12.0:
		save_tick = 0.0
		_write_save()
	match mode:
		Mode.BASE:
			_tick_conveyor(delta)
		Mode.RAID:
			_tick_raid(delta)
		Mode.THIEF:
			thief_timer -= delta
			if thief_timer <= 0.0:
				_thief_escaped()
	_refresh_ui()
	deco.queue_redraw()


# --- conveyor / buying -------------------------------------------------------

func _tick_conveyor(delta: float) -> void:
	spawn_in -= delta
	if spawn_in <= 0.0 and walkers.size() < 4:
		spawn_in = randf_range(SPAWN_EVERY_MIN, SPAWN_EVERY_MAX)
		var creature := JugaadCreature.new()
		creature.setup(JugaadDB.roll(featured_id), true)
		creature.position = Vector2(-120.0, CONVEYOR_Y)
		conveyor.add_child(creature)
		walkers.append([creature, randf_range(WALK_SPEED_MIN, WALK_SPEED_MAX)])
	for i in range(walkers.size() - 1, -1, -1):
		var creature: JugaadCreature = walkers[i][0]
		creature.position.x += walkers[i][1] * delta
		if creature.position.x > 1220.0:
			creature.queue_free()
			walkers.remove_at(i)


func _try_buy(at: Vector2) -> void:
	for i in range(walkers.size() - 1, -1, -1):
		var creature: JugaadCreature = walkers[i][0]
		if creature.position.distance_to(at) > TAP_RADIUS:
			continue
		var id := creature.id
		if owned.size() >= SLOT_COUNT:
			_toast("Godown full!")
			return
		if coins < JugaadDB.price(id):
			_toast("Not enough rupees!")
			return
		coins -= JugaadDB.price(id)
		owned.append(id)
		creature.queue_free()
		walkers.remove_at(i)
		AudioManager.play_sfx(SFX_BUY, 0.05)
		Haptics.light()
		Analytics.log_event("buy", {"id": id})
		_rebuild_slots()
		_write_save()
		return


# --- raid --------------------------------------------------------------------

func _on_raid_pressed() -> void:
	if mode != Mode.BASE or _now() < raid_ready_at:
		return
	AudioManager.play_sfx(SFX_TAP)
	mode = Mode.RAID
	raid_target = JugaadDB.roll_lucky()
	raid_progress = 0.0
	raid_holding = false
	eye_open = false
	eye_timer = randf_range(1.4, 2.4)
	conveyor.visible = false
	slots.visible = false
	raid_creature = JugaadCreature.new()
	raid_creature.setup(raid_target)
	raid_creature.asleep = true
	raid_creature.position = Vector2(540.0, RAID_PATH_TOP - 110.0)
	add_child(raid_creature)
	hint_label.text = "HOLD to sneak — FREEZE when the eye is open!"


func _tick_raid(delta: float) -> void:
	eye_timer -= delta
	if eye_timer <= 0.0:
		eye_open = not eye_open
		eye_open_for = 0.0
		eye_timer = randf_range(0.7, 1.4) if eye_open else randf_range(1.2, 2.4)
		if eye_open:
			Haptics.light()
	if eye_open:
		eye_open_for += delta
	if raid_holding:
		if eye_open and eye_open_for > EYE_GRACE_SEC:
			_raid_end(false)
			return
		raid_progress += SNEAK_SPEED * delta / 1.0
		if raid_progress >= 1.0:
			_raid_end(true)


func _raid_end(success: bool) -> void:
	mode = Mode.BASE
	if raid_creature != null:
		raid_creature.queue_free()
		raid_creature = null
	raid_ready_at = _now() + RAID_COOLDOWN_SEC
	hint_label.text = ""
	if success:
		AudioManager.play_sfx(SFX_STEAL, 0.05)
		Haptics.medium()
		Analytics.log_event("raid_win")
		var detail: String
		if owned.size() < SLOT_COUNT:
			owned.append(raid_target)
			detail = "You stole %s!" % JugaadDB.creature_name(raid_target)
		else:
			var fence := JugaadDB.price(raid_target) / 2
			coins += fence
			detail = "Godown full — fenced %s for ₹%d" \
				% [JugaadDB.creature_name(raid_target), fence]
		_show_result("RAID SUCCESS", detail)
	else:
		AudioManager.play_sfx(SFX_CAUGHT)
		Haptics.heavy()
		Analytics.log_event("raid_fail")
		var penalty := int(coins * 0.1)
		coins -= penalty
		_show_result("CAUGHT!", "The guard woke up.\nYou dropped ₹%d running away." % penalty)
	_rebuild_slots()
	_write_save()


# --- counter-thief -----------------------------------------------------------

func _maybe_spawn_thief() -> void:
	if owned.is_empty() or randf() > THIEF_CHANCE:
		return
	mode = Mode.THIEF
	thief_taps = 0
	thief_timer = THIEF_WINDOW_SEC
	thief_pos = Vector2(randf_range(240.0, 840.0), randf_range(640.0, 1100.0))
	hint_label.text = "A THIEF! Tap him %d times!" % THIEF_TAPS_NEEDED


func _thief_tapped() -> void:
	thief_taps += 1
	AudioManager.play_sfx(SFX_TAP, 0.1)
	Haptics.light()
	thief_pos = Vector2(randf_range(240.0, 840.0), randf_range(640.0, 1100.0))
	if thief_taps >= THIEF_TAPS_NEEDED:
		mode = Mode.BASE
		hint_label.text = ""
		_toast("Thief chased off!")
		AudioManager.play_sfx(SFX_STEAL, 0.05)


func _thief_escaped() -> void:
	mode = Mode.BASE
	hint_label.text = ""
	if not owned.is_empty():
		var lost: int = owned.pop_back()
		_toast("He grabbed your %s!" % JugaadDB.creature_name(lost))
		AudioManager.play_sfx(SFX_CAUGHT)
		Haptics.heavy()
		_rebuild_slots()
		_write_save()


# --- rewarded crate ----------------------------------------------------------

func _on_crate_pressed() -> void:
	if mode != Mode.BASE:
		return
	AudioManager.play_sfx(SFX_TAP)
	AdsManager.show_rewarded("crate")


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "crate":
		return
	var id := JugaadDB.roll_lucky()
	AudioManager.play_sfx(SFX_CRATE)
	Haptics.medium()
	Analytics.log_event("crate_opened")
	if owned.size() < SLOT_COUNT:
		owned.append(id)
		_toast("Crate: %s (%s)!" % [JugaadDB.creature_name(id),
			JugaadDB.RARITY_NAMES[JugaadDB.rarity(id)]])
	else:
		var fence := JugaadDB.price(id) / 2
		coins += fence
		_toast("Crate fenced for ₹%d (godown full)" % fence)
	_rebuild_slots()
	_write_save()


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	if result_panel.visible:
		if touch.pressed:
			_dismiss_result()
		return
	match mode:
		Mode.BASE:
			if touch.pressed:
				_try_buy(touch.position)
		Mode.RAID:
			raid_holding = touch.pressed
		Mode.THIEF:
			if touch.pressed and touch.position.distance_to(thief_pos) < 150.0:
				_thief_tapped()


func _show_result(title: String, detail: String) -> void:
	result_title.text = title
	result_detail.text = detail
	result_panel.visible = true
	conveyor.visible = false
	slots.visible = false


func _dismiss_result() -> void:
	result_panel.visible = false
	conveyor.visible = true
	slots.visible = true
	AdsManager.round_finished()
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	_maybe_spawn_thief()


# --- save / offline ----------------------------------------------------------

func _load_save() -> void:
	coins = float(SaveManager.get_value("coins", START_COINS))
	var saved: Variant = SaveManager.get_value("owned", [])
	owned = []
	if saved is Array:
		for v in saved:
			owned.append(int(v))


func _write_save() -> void:
	SaveManager.set_value("coins", int(coins))
	SaveManager.set_value("owned", owned)
	SaveManager.set_value("last_seen", int(_now()))


func _claim_offline() -> void:
	var last := int(SaveManager.get_value("last_seen", 0))
	if last <= 0:
		return
	var away := clampf(_now() - last, 0.0, OFFLINE_CAP_SEC)
	var earned := int(away * _income_per_sec())
	if earned < 10:
		return
	coins += earned
	AudioManager.play_sfx(SFX_COIN)
	_toast("Welcome back! Your creatures earned ₹%d" % earned)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write_save()


# --- layout / ui -------------------------------------------------------------

func _income_per_sec() -> float:
	var total: float = 0.0
	for id in owned:
		total += JugaadDB.income(id)
	return total


func _slot_pos(index: int) -> Vector2:
	var col := index % SLOT_COLS
	var row := index / SLOT_COLS
	return Vector2(190.0 + col * 235.0, 600.0 + row * 290.0)


func _rebuild_slots() -> void:
	for child in slots.get_children():
		child.queue_free()
	for i in owned.size():
		var creature := JugaadCreature.new()
		creature.setup(owned[i])
		creature.position = _slot_pos(i)
		creature.scale = Vector2(0.62, 0.62)
		slots.add_child(creature)


func _refresh_ui() -> void:
	coins_label.text = "₹%d" % int(coins)
	income_label.text = "+₹%d/s" % int(_income_per_sec())
	featured_label.text = "HOT DROP: %s  (%ds)" % [JugaadDB.creature_name(featured_id),
		FEATURED_PERIOD_SEC - int(Time.get_unix_time_from_system()) % FEATURED_PERIOD_SEC]
	var cd := raid_ready_at - _now()
	raid_button.text = "RAID" if cd <= 0.0 else "RAID %ds" % int(ceil(cd))
	raid_button.disabled = cd > 0.0 or mode != Mode.BASE
	crate_button.visible = mode == Mode.BASE and AdsManager.is_rewarded_ready()


var _toast_tween: Tween = null

func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func _now() -> float:
	return Time.get_unix_time_from_system()


# --- painting ----------------------------------------------------------------

func _paint(canvas: CanvasItem) -> void:
	match mode:
		Mode.RAID:
			_paint_raid(canvas)
		_:
			_paint_base(canvas)


func _paint_base(canvas: CanvasItem) -> void:
	# godown floor
	canvas.draw_rect(Rect2(60.0, 460.0, 960.0, 880.0), Color(0.16, 0.14, 0.20))
	canvas.draw_rect(Rect2(60.0, 460.0, 960.0, 880.0), Color(0.30, 0.26, 0.38), false, 8.0)
	for i in SLOT_COUNT:
		var p := _slot_pos(i)
		canvas.draw_set_transform(p + Vector2(0.0, 66.0), 0.0, Vector2(1.0, 0.35))
		canvas.draw_circle(Vector2.ZERO, 96.0, Color(0.10, 0.09, 0.14))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# conveyor belt
	canvas.draw_rect(Rect2(0.0, CONVEYOR_Y + 60.0, 1080.0, 140.0), Color(0.24, 0.20, 0.17))
	var scroll := fmod(Time.get_ticks_msec() / 14.0, 80.0)
	for i in 16:
		var x := i * 80.0 - scroll
		canvas.draw_line(Vector2(x, CONVEYOR_Y + 60.0), Vector2(x - 24.0, CONVEYOR_Y + 200.0),
			Color(0.33, 0.28, 0.24), 8.0)
	if mode == Mode.THIEF:
		canvas.draw_circle(thief_pos, 96.0, Color(0.16, 0.14, 0.2))
		canvas.draw_circle(thief_pos, 84.0, Color(0.32, 0.30, 0.38))
		canvas.draw_rect(Rect2(thief_pos.x - 60.0, thief_pos.y - 34.0, 120.0, 26.0),
			Color(0.1, 0.09, 0.13))
		for side in [-1.0, 1.0]:
			canvas.draw_circle(thief_pos + Vector2(side * 26.0, -20.0), 10.0, Color(1, 1, 1))


func _paint_raid(canvas: CanvasItem) -> void:
	# AI godown backdrop
	canvas.draw_rect(Rect2(0.0, 0.0, 1080.0, 1920.0), Color(0.07, 0.08, 0.13))
	canvas.draw_rect(Rect2(140.0, RAID_PATH_TOP - 260.0, 800.0, 330.0), Color(0.14, 0.12, 0.18))
	# pedestal
	canvas.draw_set_transform(Vector2(540.0, RAID_PATH_TOP - 30.0), 0.0, Vector2(1.0, 0.35))
	canvas.draw_circle(Vector2.ZERO, 130.0, Color(0.22, 0.19, 0.28))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# guard head + eye
	var guard := Vector2(850.0, RAID_PATH_TOP - 140.0)
	canvas.draw_circle(guard, 92.0, Color(0.55, 0.42, 0.34))
	canvas.draw_rect(Rect2(guard.x - 96.0, guard.y - 130.0, 192.0, 48.0), Color(0.75, 0.2, 0.2))
	if eye_open:
		canvas.draw_circle(guard + Vector2(0.0, -8.0), 34.0, Color(1, 1, 1))
		canvas.draw_circle(guard + Vector2(0.0, -8.0), 15.0, Color(0.85, 0.15, 0.15))
		canvas.draw_circle(Vector2(540.0, 960.0), 520.0, Color(0.9, 0.2, 0.2, 0.06))
	else:
		canvas.draw_line(guard + Vector2(-32.0, -8.0), guard + Vector2(32.0, -8.0),
			Color(0.2, 0.15, 0.12), 10.0)
	# sneak path + thief
	canvas.draw_line(Vector2(540.0, RAID_PATH_BOTTOM), Vector2(540.0, RAID_PATH_TOP),
		Color(0.25, 0.28, 0.40), 14.0)
	var y := lerpf(RAID_PATH_BOTTOM, RAID_PATH_TOP, raid_progress)
	canvas.draw_circle(Vector2(540.0, y), 54.0, Color(0.30, 0.32, 0.44))
	canvas.draw_circle(Vector2(540.0, y - 14.0), 34.0, Color(0.42, 0.44, 0.58))
	for side in [-1.0, 1.0]:
		canvas.draw_circle(Vector2(540.0 + side * 12.0, y - 20.0), 7.0, Color(1, 1, 1))
	# progress bar
	canvas.draw_rect(Rect2(140.0, 1700.0, 800.0, 30.0), Color(0.18, 0.18, 0.26))
	canvas.draw_rect(Rect2(140.0, 1700.0, 800.0 * raid_progress, 30.0), Color(0.45, 0.85, 0.55))
