extends Node2D
## Aura Farming Idle — tap your guy to do pointless cool things and farm aura.
## Buy increasingly ridiculous aura generators, then cash it all in to rank up
## RESPECT (prestige multiplier). Offline aura pulls players back. Rewarded ad
## = 2× aura boost; interstitial only on prestige (natural break).

const GENERATORS: Array = [
	# name, base cost, aura per second
	["Sunglasses Rack", 25, 1],
	["Portable Fan (hair)", 180, 6],
	["Lo-fi Speaker", 1200, 28],
	["Slow-Mo Camera Crew", 7500, 120],
	["Pigeon Audience", 42000, 540],
	["Monsoon Photoshoot", 230000, 2400],
]
const COST_GROWTH: float = 1.16
const TAP_FLAVOR: Array[String] = [
	"adjusted collar", "stared into the distance", "slow blink", "wind check",
	"leaned on nothing", "cracked knuckles", "walked away from explosion (imaginary)",
	"nodded at a stranger", "flipped an old coin", "said 'hm.' quietly",
]
const PRESTIGE_BASE: float = 100000.0
const PRESTIGE_GROWTH: float = 6.0
const RESPECT_RANKS: Array[String] = ["Nobody", "Local Legend", "Mohalla Icon",
	"City Famous", "National Treasure", "Aura Singularity"]
const BOOST_SEC: float = 120.0
const OFFLINE_CAP_SEC: float = 4.0 * 3600.0

const SFX_CLICK: AudioStream = preload("res://assets/audio/click.wav")
const SFX_BUY: AudioStream = preload("res://assets/audio/buy.wav")
const SFX_PRESTIGE: AudioStream = preload("res://assets/audio/prestige.wav")
const SFX_BOOST: AudioStream = preload("res://assets/audio/boost.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var aura: float = 0.0
var owned: Array = [0, 0, 0, 0, 0, 0]
var respect: int = 0
var boost_until: float = 0.0
var save_tick: float = 0.0
var pose: int = 0
var pose_time: float = 0.0
var shop_buttons: Array = []

@onready var deco: Deco = $Deco
@onready var aura_label: Label = $UI/AuraLabel
@onready var rate_label: Label = $UI/RateLabel
@onready var respect_label: Label = $UI/RespectLabel
@onready var flavor_label: Label = $UI/FlavorLabel
@onready var shop_box: VBoxContainer = $UI/ShopScroll/ShopBox
@onready var prestige_button: Button = $UI/PrestigeButton
@onready var boost_button: Button = $UI/BoostButton
@onready var toast_label: Label = $UI/ToastLabel

func _ready() -> void:
	randomize()
	deco.painter = _paint
	prestige_button.pressed.connect(_on_prestige_pressed)
	boost_button.pressed.connect(_on_boost_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	_load_save()
	_build_shop()
	_claim_offline()
	Analytics.log_event("round_start")
	_refresh_ui()


func _process(delta: float) -> void:
	aura += rate_per_sec() * delta
	pose_time += delta
	save_tick += delta
	if save_tick >= 12.0:
		save_tick = 0.0
		_write_save()
	_refresh_ui()
	deco.queue_redraw()


func rate_per_sec() -> float:
	var rate: float = 0.0
	for i in GENERATORS.size():
		rate += float(GENERATORS[i][2]) * owned[i]
	rate *= multiplier()
	if _now() < boost_until:
		rate *= 2.0
	return rate


func multiplier() -> float:
	return 1.0 + 0.25 * respect


func tap_value() -> float:
	var value := 1.0 + rate_per_sec() * 0.06
	return value * (2.0 if _now() < boost_until else 1.0)


func prestige_cost() -> float:
	return PRESTIGE_BASE * pow(PRESTIGE_GROWTH, respect)


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	if touch.position.y < 420.0 or touch.position.y > 1150.0:
		return
	aura += tap_value()
	pose = randi() % 4
	pose_time = 0.0
	AudioManager.play_sfx(SFX_CLICK, 0.12)
	Haptics.light()
	flavor_label.text = "+%s  ·  %s" % [_fmt(tap_value()), TAP_FLAVOR[randi() % TAP_FLAVOR.size()]]
	flavor_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(flavor_label, "modulate:a", 0.0, 0.9)


# --- shop --------------------------------------------------------------------

func _build_shop() -> void:
	for i in GENERATORS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 108.0)
		button.add_theme_font_size_override("font_size", 40)
		button.pressed.connect(_on_buy.bind(i))
		shop_box.add_child(button)
		shop_buttons.append(button)


func _cost(i: int) -> float:
	return float(GENERATORS[i][1]) * pow(COST_GROWTH, owned[i])


func _on_buy(i: int) -> void:
	if aura < _cost(i):
		return
	aura -= _cost(i)
	owned[i] += 1
	AudioManager.play_sfx(SFX_BUY, 0.05)
	Haptics.light()
	Analytics.log_event("buy", {"gen": i})
	_write_save()
	_refresh_ui()


# --- prestige / boost ---------------------------------------------------------

func _on_prestige_pressed() -> void:
	if aura < prestige_cost():
		return
	AudioManager.play_sfx(SFX_PRESTIGE)
	Haptics.heavy()
	respect += 1
	aura = 0.0
	for i in owned.size():
		owned[i] = 0
	Analytics.log_event("prestige", {"respect": respect})
	_toast("RESPECT UP: %s (×%.2f aura)" % [_rank_name(), multiplier()])
	_write_save()
	_refresh_ui()
	AdsManager.round_finished()
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed


func _on_boost_pressed() -> void:
	AudioManager.play_sfx(SFX_TAP)
	AdsManager.show_rewarded("boost")


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "boost":
		return
	boost_until = _now() + BOOST_SEC
	AudioManager.play_sfx(SFX_BOOST)
	Haptics.medium()
	Analytics.log_event("boost_used")
	_toast("2× AURA for 2 minutes!")
	_write_save()


# --- save / offline -----------------------------------------------------------

func _load_save() -> void:
	aura = float(SaveManager.get_value("aura", 0.0))
	respect = int(SaveManager.get_value("respect", 0))
	boost_until = float(SaveManager.get_value("boost_until", 0.0))
	var saved: Variant = SaveManager.get_value("owned", [])
	if saved is Array and saved.size() == GENERATORS.size():
		for i in saved.size():
			owned[i] = int(saved[i])


func _write_save() -> void:
	SaveManager.set_value("aura", aura)
	SaveManager.set_value("owned", owned)
	SaveManager.set_value("respect", respect)
	SaveManager.set_value("boost_until", boost_until)
	SaveManager.set_value("last_seen", int(_now()))


func _claim_offline() -> void:
	var last := int(SaveManager.get_value("last_seen", 0))
	if last <= 0:
		return
	var away := clampf(_now() - last, 0.0, OFFLINE_CAP_SEC)
	var earned := away * rate_per_sec()
	if earned < 5.0:
		return
	aura += earned
	_toast("Your aura farmed itself: +%s" % _fmt(earned))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write_save()


# --- ui ------------------------------------------------------------------------

func _refresh_ui() -> void:
	aura_label.text = "%s AURA" % _fmt(aura)
	rate_label.text = "+%s/s%s" % [_fmt(rate_per_sec()),
		"  (2× BOOST)" if _now() < boost_until else ""]
	respect_label.text = "RESPECT: %s  ×%.2f" % [_rank_name(), multiplier()]
	for i in shop_buttons.size():
		var button: Button = shop_buttons[i]
		button.text = "%s  ·  %d owned\ncost %s  (+%s/s)" % [GENERATORS[i][0], owned[i],
			_fmt(_cost(i)), _fmt(float(GENERATORS[i][2]) * multiplier())]
		button.disabled = aura < _cost(i)
	prestige_button.visible = aura >= prestige_cost() * 0.5
	prestige_button.text = "GAIN RESPECT  (needs %s)" % _fmt(prestige_cost())
	prestige_button.disabled = aura < prestige_cost()
	boost_button.visible = AdsManager.is_rewarded_ready() and _now() >= boost_until


func _rank_name() -> String:
	return RESPECT_RANKS[mini(respect, RESPECT_RANKS.size() - 1)]


var _toast_tween: Tween = null

func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func _fmt(value: float) -> String:
	if value >= 1e9:
		return "%.2fB" % (value / 1e9)
	if value >= 1e6:
		return "%.2fM" % (value / 1e6)
	if value >= 1e3:
		return "%.1fk" % (value / 1e3)
	return str(int(value))


func _now() -> float:
	return Time.get_unix_time_from_system()


# --- painting -------------------------------------------------------------------

func _paint(canvas: CanvasItem) -> void:
	var center := Vector2(540.0, 800.0)
	# aura glow scales with rate
	var glow := clampf(0.15 + rate_per_sec() * 0.0004, 0.15, 0.6)
	var boosted := _now() < boost_until
	var glow_color := Color(1.0, 0.7, 0.2, glow) if boosted else Color(0.55, 0.4, 0.95, glow)
	canvas.draw_circle(center, 330.0 + sin(pose_time * 2.0) * 14.0, glow_color)
	canvas.draw_circle(center, 240.0, Color(0.16, 0.13, 0.26))
	# the guy
	var bob := sin(pose_time * 3.0) * 6.0
	var body := center + Vector2(0.0, 40.0 + bob)
	canvas.draw_circle(body + Vector2(0, 90), 95.0, Color(0.22, 0.2, 0.34))  # hoodie
	canvas.draw_circle(body - Vector2(0, 40), 62.0, Color(0.9, 0.72, 0.56))  # head
	# swag hair
	canvas.draw_arc(body - Vector2(0, 62), 54.0, PI + 0.3, TAU - 0.3, 14, Color(0.15, 0.12, 0.14), 24.0)
	# sunglasses — the aura source
	canvas.draw_rect(Rect2(body.x - 52.0, body.y - 58.0, 44.0, 26.0), Color(0.08, 0.08, 0.1))
	canvas.draw_rect(Rect2(body.x + 8.0, body.y - 58.0, 44.0, 26.0), Color(0.08, 0.08, 0.1))
	canvas.draw_line(body + Vector2(-8, -46), body + Vector2(8, -46), Color(0.08, 0.08, 0.1), 6.0)
	# pose arms
	match pose:
		0:
			canvas.draw_line(body + Vector2(-80, 60), body + Vector2(-130, 130), Color(0.22, 0.2, 0.34), 26.0)
			canvas.draw_line(body + Vector2(80, 60), body + Vector2(130, 130), Color(0.22, 0.2, 0.34), 26.0)
		1:  # collar adjust
			canvas.draw_line(body + Vector2(-80, 60), body + Vector2(-40, 0), Color(0.22, 0.2, 0.34), 26.0)
			canvas.draw_line(body + Vector2(80, 60), body + Vector2(130, 130), Color(0.22, 0.2, 0.34), 26.0)
		2:  # double point
			canvas.draw_line(body + Vector2(-80, 60), body + Vector2(-160, 20), Color(0.22, 0.2, 0.34), 26.0)
			canvas.draw_line(body + Vector2(80, 60), body + Vector2(160, 20), Color(0.22, 0.2, 0.34), 26.0)
		3:  # arms crossed
			canvas.draw_line(body + Vector2(-80, 70), body + Vector2(60, 110), Color(0.22, 0.2, 0.34), 26.0)
			canvas.draw_line(body + Vector2(80, 70), body + Vector2(-60, 110), Color(0.22, 0.2, 0.34), 26.0)
	# orbiting aura sparks
	for i in 6:
		var a := pose_time * 1.2 + i * TAU / 6.0
		var p := center + Vector2(cos(a) * 290.0, sin(a) * 120.0)
		canvas.draw_circle(p, 8.0, Color(1.0, 0.9, 0.5, 0.8) if boosted else Color(0.75, 0.6, 1.0, 0.8))
