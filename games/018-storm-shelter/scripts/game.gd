extends Node3D
## Storm Shelter — dig your bunker deeper, every floor produces supplies,
## and a MEGA-STORM hits on a timer: if your hatch level matches the storm,
## you ride it out for a fat bonus; if not, the wind takes a cut of your
## stockpile. Upgrade-the-shelter ad-genre loop, fully offline.
## Rewarded ad = instant supply crate. Interstitial after each storm result.

const FLOOR_H: float = 1.7
const ROOM_W: float = 5.0
const STORM_PERIOD: float = 45.0
const STORM_SECONDS: float = 4.0
const OFFLINE_CAP_SEC: float = 4.0 * 3600.0
const ROOM_NAMES: Array[String] = ["Supply Farm", "Water Still", "Workshop", "Greenhouse", "Battery Den"]
const ROOM_COLORS: Array[Color] = [Kit.LIME, Kit.TEAL, Kit.ORANGE, Kit.MINT, Kit.SUN]

const SFX_BUILD: AudioStream = preload("res://assets/audio/build.wav")
const SFX_COIN: AudioStream = preload("res://assets/audio/coin.wav")
const SFX_STORM: AudioStream = preload("res://assets/audio/storm.wav")
const SFX_SAFE: AudioStream = preload("res://assets/audio/safe.wav")
const SFX_CRASH: AudioStream = preload("res://assets/audio/crash.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var supplies: float = 60.0
var floors: int = 0
var hatch_level: int = 1
var storm_number: int = 1
var storm_timer: float = STORM_PERIOD
var storming: float = 0.0
var save_tick: float = 0.0
var shake: float = 0.0

var cam: Camera3D = null
var cam_y: float = 1.0
var sky_mat: ProceduralSkyMaterial = null
var hatch_node: Node3D = null
var floors_root: Node3D = null
var rain: CPUParticles3D = null
var workers: Array = []

var supplies_label: Label = null
var storm_label: Label = null
var hatch_label: Label = null
var dig_button: Button = null
var hatch_button: Button = null
var crate_button: Button = null
var toast_label: Label = null
var _toast_tween: Tween = null

func _ready() -> void:
	randomize()
	_load_save()
	_build_world()
	_build_ui()
	_claim_offline()
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	Analytics.log_event("round_start")
	_refresh_ui()


func _process(delta: float) -> void:
	supplies += rate_per_sec() * delta
	storm_timer -= delta
	save_tick += delta
	if save_tick > 12.0:
		save_tick = 0.0
		_write_save()
	if storm_timer <= 0.0 and storming <= 0.0:
		_storm_hits()
	if storming > 0.0:
		storming -= delta
		shake = 0.25
		if storming <= 0.0:
			_storm_ends()
	shake = maxf(shake - delta * 0.6, 0.0)
	# camera follows the bunker depth with a storm wobble
	var target_y := 1.2 - floors * FLOOR_H * 0.42
	cam_y = lerpf(cam_y, target_y, 3.0 * delta)
	cam.position = Vector3(randf_range(-shake, shake), cam_y + randf_range(-shake, shake), 11.5)
	# idle workers bob
	for w: Node3D in workers:
		w.position.x = wrapf(w.position.x + delta * w.get_meta("speed"), -ROOM_W * 0.4, ROOM_W * 0.4)
	_refresh_ui()


func rate_per_sec() -> float:
	var rate: float = 2.0
	for i in floors:
		rate += 3.0 * pow(1.18, i)
	return rate


func dig_cost() -> int:
	return int(80.0 * pow(1.38, floors))


func hatch_cost() -> int:
	return int(120.0 * pow(1.5, hatch_level - 1))


# --- storms -----------------------------------------------------------------

func _storm_hits() -> void:
	storming = STORM_SECONDS
	AudioManager.play_sfx(SFX_STORM)
	Haptics.heavy()
	rain.emitting = true
	_set_sky(Color(0.25, 0.23, 0.4), Color(0.45, 0.4, 0.6))


func _storm_ends() -> void:
	rain.emitting = false
	_set_sky(Kit.SKY, Color(1.0, 0.85, 0.7))
	var survived := hatch_level >= storm_number
	if survived:
		var bonus := int(rate_per_sec() * 25.0)
		supplies += bonus
		AudioManager.play_sfx(SFX_SAFE)
		Haptics.medium()
		Kit.burst(self, hatch_node.position + Vector3.UP, Kit.SUN, 36, 7.0)
		_toast("STORM LVL %d SURVIVED! +%d supplies" % [storm_number, bonus])
	else:
		var lost := int(supplies * 0.35)
		supplies -= lost
		AudioManager.play_sfx(SFX_CRASH)
		Haptics.heavy()
		_toast("Hatch too weak! The storm took %d supplies" % lost)
	storm_number += 1
	storm_timer = STORM_PERIOD
	Analytics.log_event("storm", {"n": storm_number, "ok": survived})
	_write_save()
	AdsManager.round_finished()
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed


# --- actions ----------------------------------------------------------------

func _on_dig() -> void:
	if supplies < dig_cost():
		return
	supplies -= dig_cost()
	floors += 1
	AudioManager.play_sfx(SFX_BUILD)
	Haptics.medium()
	var room := _make_room(floors - 1)
	floors_root.add_child(room)
	Kit.squash(room, 0.35)
	Kit.burst(self, room.position, ROOM_COLORS[(floors - 1) % ROOM_COLORS.size()], 20, 4.0)
	Analytics.log_event("dig", {"floor": floors})
	_write_save()


func _on_hatch() -> void:
	if supplies < hatch_cost():
		return
	supplies -= hatch_cost()
	hatch_level += 1
	AudioManager.play_sfx(SFX_BUILD)
	Haptics.medium()
	Kit.squash(hatch_node, 0.4)
	Kit.burst(self, hatch_node.position + Vector3.UP * 0.5, Kit.TEAL, 24, 5.0)
	_write_save()


func _on_crate() -> void:
	AudioManager.play_sfx(SFX_TAP)
	AdsManager.show_rewarded("crate")


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "crate":
		return
	var gain := maxi(int(rate_per_sec() * 60.0), 80)
	supplies += gain
	AudioManager.play_sfx(SFX_COIN)
	Haptics.medium()
	Kit.burst(self, Vector3(0.0, cam_y, 2.0), Kit.SUN, 40, 8.0)
	_toast("Supply crate: +%d!" % gain)
	Analytics.log_event("crate_opened")
	_write_save()


# --- save / offline ---------------------------------------------------------

func _load_save() -> void:
	supplies = float(SaveManager.get_value("supplies", 140.0))
	floors = int(SaveManager.get_value("floors", 1))
	hatch_level = int(SaveManager.get_value("hatch", 1))
	storm_number = int(SaveManager.get_value("storm", 1))


func _write_save() -> void:
	SaveManager.set_value("supplies", int(supplies))
	SaveManager.set_value("floors", floors)
	SaveManager.set_value("hatch", hatch_level)
	SaveManager.set_value("storm", storm_number)
	SaveManager.set_value("last_seen", int(Time.get_unix_time_from_system()))


func _claim_offline() -> void:
	var last := int(SaveManager.get_value("last_seen", 0))
	if last <= 0:
		return
	var away := clampf(Time.get_unix_time_from_system() - last, 0.0, OFFLINE_CAP_SEC)
	var earned := int(away * rate_per_sec() * 0.5)
	if earned < 20:
		return
	supplies += earned
	_toast("Your bunker kept working: +%d supplies" % earned)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write_save()


# --- world ------------------------------------------------------------------

func _build_world() -> void:
	sky_mat = Kit.sky(self, Kit.SKY, Color(1.0, 0.85, 0.7), Color(0.55, 0.4, 0.3))
	cam = Camera3D.new()
	cam.position = Vector3(0.0, 1.0, 11.5)
	cam.fov = 45.0
	add_child(cam)
	# earth cross-section
	var earth := Kit.box(Vector3(60.0, 80.0, 6.0), Color(0.52, 0.34, 0.24))
	earth.position = Vector3(0.0, -40.0, -3.2)
	add_child(earth)
	# grass lip + surface
	var grass := Kit.box(Vector3(60.0, 0.5, 8.0), Kit.LIME)
	grass.position = Vector3(0.0, 0.25, -2.0)
	add_child(grass)
	for i in 4:
		var hill := Kit.sphere(randf_range(1.2, 2.4), Kit.LIME.lightened(0.12))
		hill.position = Vector3([-13.0, -7.5, 6.5, 12.0][i], 0.4, -6.5)
		add_child(hill)
	for i in 4:
		var cloud := Kit.sphere(randf_range(0.7, 1.2), Color(1, 1, 1, 0.95))
		cloud.position = Vector3(-8.0 + i * 5.5, 6.5 + (i % 2), -8.0)
		add_child(cloud)
	var sun := Kit.sphere(1.3, Kit.SUN)
	sun.position = Vector3(8.5, 8.5, -12.0)
	add_child(sun)
	# the hatch on the surface
	hatch_node = Node3D.new()
	hatch_node.position = Vector3(0.0, 0.5, 0.0)
	var dome := Kit.sphere(1.1, Kit.TEAL, true)
	dome.scale = Vector3(1.0, 0.65, 1.0)
	hatch_node.add_child(dome)
	var door := Kit.box(Vector3(0.8, 0.9, 0.2), Kit.INK)
	door.position = Vector3(0.0, 0.25, -1.0)
	hatch_node.add_child(door)
	add_child(hatch_node)
	floors_root = Node3D.new()
	add_child(floors_root)
	for i in floors:
		floors_root.add_child(_make_room(i))
	# rain (storm only)
	rain = CPUParticles3D.new()
	rain.position = Vector3(0.0, 9.0, -2.0)
	rain.amount = 160
	rain.lifetime = 1.0
	rain.emitting = false
	rain.direction = Vector3.DOWN
	rain.spread = 6.0
	rain.initial_velocity_min = 14.0
	rain.initial_velocity_max = 18.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(12.0, 0.2, 3.0)
	var drop := BoxMesh.new()
	drop.size = Vector3(0.05, 0.4, 0.05)
	rain.mesh = drop
	rain.color = Color(0.6, 0.8, 1.0, 0.8)
	add_child(rain)


func _make_room(index: int) -> Node3D:
	var root := Node3D.new()
	var color := ROOM_COLORS[index % ROOM_COLORS.size()]
	root.position = Vector3(0.0, -1.2 - index * FLOOR_H, 0.0)
	var shell := Kit.box(Vector3(ROOM_W, FLOOR_H - 0.25, 2.4), Kit.CREAM)
	root.add_child(shell)
	var band := Kit.box(Vector3(ROOM_W, 0.22, 2.45), color)
	band.position.y = -(FLOOR_H - 0.25) / 2.0 + 0.1
	root.add_child(band)
	var machine := Kit.box(Vector3(1.0, 0.8, 1.0), color)
	machine.position = Vector3(-ROOM_W * 0.32, -0.2, 0.2)
	root.add_child(machine)
	var lamp := Kit.sphere(0.14, Kit.SUN)
	lamp.position = Vector3(0.0, FLOOR_H * 0.28, 0.6)
	root.add_child(lamp)
	var worker := Kit.blobby(Kit.CANDY[index % Kit.CANDY.size()], 0.2)
	worker.position = Vector3(randf_range(-1.0, 1.0), -(FLOOR_H - 0.25) / 2.0 + 0.2, 0.6)
	worker.set_meta("speed", randf_range(0.4, 0.9) * (1.0 if randf() < 0.5 else -1.0))
	root.add_child(worker)
	workers.append(worker)
	return root


func _set_sky(top: Color, horizon: Color) -> void:
	if sky_mat == null:
		return
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	supplies_label = Kit.label("0", 84, Kit.SUN)
	supplies_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	supplies_label.offset_top = 44.0
	supplies_label.offset_bottom = 150.0
	layer.add_child(supplies_label)
	storm_label = Kit.label("", 46, Kit.CORAL)
	storm_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	storm_label.offset_top = 152.0
	storm_label.offset_bottom = 215.0
	layer.add_child(storm_label)
	hatch_label = Kit.label("", 40, Kit.TEAL)
	hatch_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hatch_label.offset_top = 218.0
	hatch_label.offset_bottom = 272.0
	layer.add_child(hatch_label)
	toast_label = Kit.label("", 46)
	toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_label.offset_top = 1350.0
	toast_label.offset_bottom = 1420.0
	toast_label.modulate.a = 0.0
	layer.add_child(toast_label)
	dig_button = Kit.button("DIG", 46, Kit.ORANGE)
	dig_button.position = Vector2(40.0, 1740.0)
	dig_button.size = Vector2(320.0, 120.0)
	dig_button.pressed.connect(_on_dig)
	layer.add_child(dig_button)
	hatch_button = Kit.button("HATCH", 46, Kit.TEAL)
	hatch_button.position = Vector2(385.0, 1740.0)
	hatch_button.size = Vector2(320.0, 120.0)
	hatch_button.pressed.connect(_on_hatch)
	layer.add_child(hatch_button)
	crate_button = Kit.button("CRATE · AD", 42, Kit.PURPLE)
	crate_button.position = Vector2(730.0, 1740.0)
	crate_button.size = Vector2(310.0, 120.0)
	crate_button.pressed.connect(_on_crate)
	layer.add_child(crate_button)


func _refresh_ui() -> void:
	supplies_label.text = "%d  ⚡ +%d/s" % [int(supplies), int(rate_per_sec())]
	if storming > 0.0:
		storm_label.text = "⛈ STORM LVL %d IS HERE!" % storm_number
	else:
		storm_label.text = "⛈ STORM LVL %d in %ds" % [storm_number, int(ceil(storm_timer))]
	hatch_label.text = "hatch LVL %d %s" % [hatch_level,
		"— HOLDS" if hatch_level >= storm_number else "— TOO WEAK, UPGRADE!"]
	dig_button.text = "DIG  (%d)" % dig_cost()
	dig_button.disabled = supplies < dig_cost()
	hatch_button.text = "HATCH  (%d)" % hatch_cost()
	hatch_button.disabled = supplies < hatch_cost()
	crate_button.visible = AdsManager.is_rewarded_ready()


func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
