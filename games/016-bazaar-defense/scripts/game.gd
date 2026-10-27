extends Node2D
## Bazaar Tower Defense — meme creatures march the gali toward your shop.
## Build and evolve three desi defense units on fixed spots. Boss every 5th
## wave. Endless; score = waves survived. Rewarded ad = free upgrade voucher;
## interstitial on restart.

enum State { BUILD, WAVE, GAME_OVER }

const BEST_KEY: String = "best_wave"
const PATH: Array[Vector2] = [
	Vector2(-80.0, 360.0), Vector2(880.0, 360.0), Vector2(880.0, 720.0),
	Vector2(200.0, 720.0), Vector2(200.0, 1080.0), Vector2(880.0, 1080.0),
	Vector2(880.0, 1440.0), Vector2(100.0, 1440.0),
]
const SPOTS: Array[Vector2] = [
	Vector2(300.0, 540.0), Vector2(700.0, 540.0), Vector2(540.0, 900.0),
	Vector2(160.0, 900.0), Vector2(420.0, 1260.0), Vector2(760.0, 1260.0),
]
const START_MONEY: int = 220
const START_LIVES: int = 5
const WAVE_BREAK_SEC: float = 5.0
const VOUCHER_COOLDOWN: float = 120.0
const RESTART_LOCKOUT_SEC: float = 0.6

const SFX_PLACE: AudioStream = preload("res://assets/audio/place.wav")
const SFX_SHOOT: AudioStream = preload("res://assets/audio/shoot.wav")
const SFX_HIT: AudioStream = preload("res://assets/audio/hit.wav")
const SFX_EVOLVE: AudioStream = preload("res://assets/audio/evolve.wav")
const SFX_WAVE: AudioStream = preload("res://assets/audio/wave.wav")
const SFX_LOSE_LIFE: AudioStream = preload("res://assets/audio/lose_life.wav")
const SFX_WIN: AudioStream = preload("res://assets/audio/win.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.BUILD
var money: int = START_MONEY
var lives: int = START_LIVES
var wave: int = 0
var best: int = 0
var towers: Dictionary = {}  # spot index -> BazaarTower
var selected_spot: int = -1
var to_spawn: Array = []  # queued [kind, hp, speed, reward]
var spawn_timer: float = 0.0
var break_timer: float = 0.0
var shots: Array = []  # {pos, target(creep), speed, dmg, type}
var voucher_ready_at: float = 0.0
var path_lengths: Array[float] = []
var total_path: float = 0.0
var restarting: bool = false
var game_over_at_sec: float = 0.0

@onready var deco: Deco = $Deco
@onready var creeps: Node2D = $Creeps
@onready var tower_holder: Node2D = $Towers
@onready var money_label: Label = $UI/MoneyLabel
@onready var lives_label: Label = $UI/LivesLabel
@onready var wave_label: Label = $UI/WaveLabel
@onready var info_label: Label = $UI/InfoLabel
@onready var build_panel: Control = $UI/BuildPanel
@onready var build_buttons: Array = [$UI/BuildPanel/Build0, $UI/BuildPanel/Build1,
	$UI/BuildPanel/Build2]
@onready var upgrade_button: Button = $UI/BuildPanel/UpgradeButton
@onready var wave_button: Button = $UI/WaveButton
@onready var voucher_button: Button = $UI/VoucherButton
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_label: Label = $UI/GameOverPanel/FinalScore

func _ready() -> void:
	randomize()
	deco.painter = _paint
	for i in 3:
		build_buttons[i].pressed.connect(_on_build.bind(i))
		build_buttons[i].text = "%s\n₹%d" % [BazaarTower.NAMES[i], BazaarTower.COSTS[i]]
	upgrade_button.pressed.connect(_on_upgrade)
	wave_button.pressed.connect(_start_wave)
	voucher_button.pressed.connect(_on_voucher_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	best = int(SaveManager.get_value(BEST_KEY, 0))
	total_path = 0.0
	for i in PATH.size() - 1:
		var seg := PATH[i].distance_to(PATH[i + 1])
		path_lengths.append(seg)
		total_path += seg
	Analytics.log_event("round_start")
	_refresh_ui()


func path_pos(progress: float) -> Vector2:
	var left := clampf(progress, 0.0, total_path)
	for i in path_lengths.size():
		if left <= path_lengths[i]:
			return PATH[i].lerp(PATH[i + 1], left / path_lengths[i])
		left -= path_lengths[i]
	return PATH[PATH.size() - 1]


func _process(delta: float) -> void:
	deco.queue_redraw()
	if state == State.GAME_OVER:
		return
	if state == State.BUILD and wave > 0:
		break_timer -= delta
		wave_button.text = "WAVE %d IN %d · GO" % [wave + 1, int(ceil(maxf(break_timer, 0.0)))]
		if break_timer <= 0.0:
			_start_wave()
	if state == State.WAVE:
		_tick_spawning(delta)
		_tick_creeps(delta)
		_tick_towers(delta)
		_tick_shots(delta)
		if to_spawn.is_empty() and creeps.get_child_count() == 0:
			_wave_cleared()
	voucher_button.visible = AdsManager.is_rewarded_ready() \
		and _now_sec() >= voucher_ready_at and not towers.is_empty()


# --- waves ---------------------------------------------------------------------

func _start_wave() -> void:
	if state != State.BUILD:
		return
	wave += 1
	state = State.WAVE
	_close_panel()
	AudioManager.play_sfx(SFX_WAVE)
	var hp_scale := pow(1.14, wave - 1)
	to_spawn.clear()
	if wave % 5 == 0:
		to_spawn.append([3, 220.0 * hp_scale, 70.0, 120])
		for i in wave / 2:
			to_spawn.append([2, 7.0 * hp_scale, 190.0, 4])
	else:
		for i in 4 + wave:
			var roll := randf()
			if roll < 0.5:
				to_spawn.append([0, 16.0 * hp_scale, 150.0, 8])
			elif roll < 0.8:
				to_spawn.append([1, 42.0 * hp_scale, 85.0, 14])
			else:
				to_spawn.append([2, 7.0 * hp_scale, 190.0, 4])
	spawn_timer = 0.3
	_refresh_ui()


func _tick_spawning(delta: float) -> void:
	if to_spawn.is_empty():
		return
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	spawn_timer = 0.75
	var spec: Array = to_spawn.pop_front()
	var creep := BazaarCreep.new()
	creeps.add_child(creep)
	creep.setup(spec[0], spec[1], spec[2], spec[3])
	creep.position = PATH[0]


func _tick_creeps(delta: float) -> void:
	for child in creeps.get_children():
		var creep := child as BazaarCreep
		if creep == null or creep.dead:
			continue
		var slow := 0.45 if Time.get_ticks_msec() < creep.slow_until_msec else 1.0
		creep.progress += creep.speed * slow * delta
		creep.position = path_pos(creep.progress)
		if creep.progress >= total_path:
			creep.dead = true
			creep.queue_free()
			lives -= 1
			AudioManager.play_sfx(SFX_LOSE_LIFE)
			Haptics.heavy()
			_refresh_ui()
			if lives <= 0:
				_game_over()
				return


func _tick_towers(delta: float) -> void:
	for spot: int in towers:
		var tower: BazaarTower = towers[spot]
		tower.cooldown_left -= delta
		if tower.cooldown_left > 0.0:
			continue
		var target := _nearest_creep(tower.position, tower.attack_range())
		if target == null:
			continue
		tower.cooldown_left = tower.cooldown()
		shots.append({"pos": tower.position, "target": target, "dmg": tower.damage(),
			"type": tower.type})
		AudioManager.play_sfx(SFX_SHOOT, 0.12, 1.0 + tower.type * 0.15)


func _nearest_creep(from: Vector2, within: float) -> BazaarCreep:
	var nearest: BazaarCreep = null
	var nearest_d := within
	for child in creeps.get_children():
		var creep := child as BazaarCreep
		if creep == null or creep.dead:
			continue
		var d := from.distance_to(creep.position)
		if d <= nearest_d:
			nearest_d = d
			nearest = creep
	return nearest


func _tick_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot: Dictionary = shots[i]
		var target: BazaarCreep = shot.target
		if target == null or not is_instance_valid(target) or target.dead:
			shots.remove_at(i)
			continue
		var pos: Vector2 = shot.pos
		var step := 950.0 * delta
		if pos.distance_to(target.position) <= step:
			_land_shot(shot)
			shots.remove_at(i)
		else:
			shot.pos = pos + (target.position - pos).normalized() * step


func _land_shot(shot: Dictionary) -> void:
	var target: BazaarCreep = shot.target
	AudioManager.play_sfx(SFX_HIT, 0.15)
	match int(shot.type):
		1:  # splash
			for child in creeps.get_children():
				var creep := child as BazaarCreep
				if creep != null and not creep.dead \
						and creep.position.distance_to(target.position) <= BazaarTower.SPLASH_RADIUS:
					_damage(creep, shot.dmg)
		2:  # slow
			target.slow_until_msec = Time.get_ticks_msec() + BazaarTower.SLOW_MSEC
			_damage(target, shot.dmg)
		_:
			_damage(target, shot.dmg)


func _damage(creep: BazaarCreep, amount: float) -> void:
	if creep.dead:
		return
	creep.hp -= amount
	if creep.hp <= 0.0:
		creep.dead = true
		money += creep.reward
		creep.queue_free()
		Haptics.light()
		_refresh_ui()


func _wave_cleared() -> void:
	state = State.BUILD
	money += 40 + wave * 8
	if wave > best:
		best = wave
		SaveManager.set_value(BEST_KEY, best)
	AudioManager.play_sfx(SFX_WIN)
	break_timer = WAVE_BREAK_SEC
	info_label.text = "wave %d cleared! +₹%d" % [wave, 40 + wave * 8]
	_refresh_ui()


func _game_over() -> void:
	state = State.GAME_OVER
	game_over_at_sec = _now_sec()
	Analytics.log_event("game_over", {"wave": wave})
	AdsManager.round_finished()
	AudioManager.play_sfx(SFX_GAME_OVER)
	final_label.text = "SURVIVED %d WAVES\nBEST %d" % [wave - 1 if lives <= 0 else wave, best]
	game_over_panel.visible = true


# --- building ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	if state == State.GAME_OVER:
		_try_restart()
		return
	for i in SPOTS.size():
		if touch.position.distance_to(SPOTS[i]) < 90.0:
			_select_spot(i)
			return
	_close_panel()


func _select_spot(i: int) -> void:
	AudioManager.play_sfx(SFX_TAP)
	_set_selected_ring(-1)
	selected_spot = i
	_set_selected_ring(i)
	build_panel.visible = true
	var has_tower := towers.has(i)
	for b: Button in build_buttons:
		b.visible = not has_tower
	upgrade_button.visible = has_tower
	if has_tower:
		var tower: BazaarTower = towers[i]
		if tower.level >= BazaarTower.MAX_LEVEL:
			upgrade_button.text = "%s — FULLY EVOLVED" % BazaarTower.NAMES[tower.type]
			upgrade_button.disabled = true
		else:
			upgrade_button.text = "EVOLVE %s · ₹%d" % [BazaarTower.NAMES[tower.type],
				tower.upgrade_cost()]
			upgrade_button.disabled = money < tower.upgrade_cost()


func _set_selected_ring(i: int) -> void:
	if i >= 0 and towers.has(i):
		towers[i].selected = true
		towers[i].queue_redraw()
	elif i < 0:
		for spot: int in towers:
			towers[spot].selected = false
			towers[spot].queue_redraw()


func _close_panel() -> void:
	selected_spot = -1
	_set_selected_ring(-1)
	build_panel.visible = false


func _on_build(type: int) -> void:
	if selected_spot < 0 or towers.has(selected_spot) or money < BazaarTower.COSTS[type]:
		return
	money -= BazaarTower.COSTS[type]
	var tower := BazaarTower.new()
	tower.position = SPOTS[selected_spot]
	tower_holder.add_child(tower)
	tower.setup(type)
	towers[selected_spot] = tower
	AudioManager.play_sfx(SFX_PLACE)
	Haptics.light()
	Analytics.log_event("build", {"type": type})
	_close_panel()
	_refresh_ui()


func _on_upgrade() -> void:
	if selected_spot < 0 or not towers.has(selected_spot):
		return
	var tower: BazaarTower = towers[selected_spot]
	if tower.level >= BazaarTower.MAX_LEVEL or money < tower.upgrade_cost():
		return
	money -= tower.upgrade_cost()
	tower.level += 1
	tower.queue_redraw()
	AudioManager.play_sfx(SFX_EVOLVE)
	Haptics.medium()
	_close_panel()
	_refresh_ui()


# --- rewarded voucher ----------------------------------------------------------------

func _on_voucher_pressed() -> void:
	AudioManager.play_sfx(SFX_TAP)
	AdsManager.show_rewarded("voucher")


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "voucher":
		return
	voucher_ready_at = _now_sec() + VOUCHER_COOLDOWN
	# upgrade the lowest-level tower for free
	var lowest: BazaarTower = null
	for spot: int in towers:
		var tower: BazaarTower = towers[spot]
		if tower.level < BazaarTower.MAX_LEVEL \
				and (lowest == null or tower.level < lowest.level):
			lowest = tower
	if lowest != null:
		lowest.level += 1
		lowest.queue_redraw()
		AudioManager.play_sfx(SFX_EVOLVE)
		info_label.text = "free evolve: %s → L%d" % [BazaarTower.NAMES[lowest.type], lowest.level]
	Analytics.log_event("voucher_used")
	Haptics.medium()


func _try_restart() -> void:
	if restarting or _now_sec() - game_over_at_sec < RESTART_LOCKOUT_SEC:
		return
	restarting = true
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


func _refresh_ui() -> void:
	money_label.text = "₹%d" % money
	lives_label.text = "SHOP %s" % "♥".repeat(maxi(lives, 0))
	wave_label.text = "WAVE %d   BEST %d" % [wave, best]
	wave_button.visible = state == State.BUILD
	if wave == 0:
		wave_button.text = "START WAVE 1"


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


func _paint(canvas: CanvasItem) -> void:
	# gali path
	for i in PATH.size() - 1:
		canvas.draw_line(PATH[i], PATH[i + 1], Color(0.3, 0.26, 0.22), 110.0)
	for i in PATH.size() - 1:
		canvas.draw_line(PATH[i], PATH[i + 1], Color(0.38, 0.33, 0.27), 90.0)
	# shop at the end
	var shop := PATH[PATH.size() - 1] + Vector2(0.0, 0.0)
	canvas.draw_rect(Rect2(shop.x - 70.0, shop.y - 70.0, 140.0, 140.0), Color(0.85, 0.65, 0.3))
	canvas.draw_rect(Rect2(shop.x - 70.0, shop.y - 70.0, 140.0, 40.0), Color(0.8, 0.3, 0.3))
	canvas.draw_rect(Rect2(shop.x - 30.0, shop.y - 10.0, 60.0, 80.0), Color(0.4, 0.25, 0.18))
	# build spots
	for i in SPOTS.size():
		if towers.has(i):
			continue
		canvas.draw_circle(SPOTS[i], 66.0, Color(0.2, 0.24, 0.2))
		canvas.draw_arc(SPOTS[i], 66.0, 0.0, TAU, 32, Color(0.5, 0.65, 0.5, 0.7), 5.0)
		canvas.draw_line(SPOTS[i] - Vector2(22.0, 0.0), SPOTS[i] + Vector2(22.0, 0.0),
			Color(0.5, 0.65, 0.5, 0.7), 7.0)
		canvas.draw_line(SPOTS[i] - Vector2(0.0, 22.0), SPOTS[i] + Vector2(0.0, 22.0),
			Color(0.5, 0.65, 0.5, 0.7), 7.0)
	# shots
	for shot: Dictionary in shots:
		var colors: Array[Color] = [Color(0.9, 0.7, 0.4), Color(1.0, 0.8, 0.2), Color(0.6, 0.9, 1.0)]
		canvas.draw_circle(shot.pos, 14.0, colors[int(shot.type)])
