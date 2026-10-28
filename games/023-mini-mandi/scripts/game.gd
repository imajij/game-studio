extends Node3D
## Mini Mandi — arcade-idle market: joystick-walk your blob, harvest veggies
## into a wobbling head-stack, dump them at the stall, and smiling customers
## pay you. Stand on the glowing pads to buy upgrades and new patches.
## Rewarded ad = 2× coins for 60 s; interstitials only at purchase breaks.

const PICK_EVERY: float = 2.0
const CUSTOMER_EVERY: float = 3.6
const PAD_HOLD: float = 0.9

const SFX_PICK: AudioStream = preload("res://assets/audio/pick.wav")
const SFX_SELL: AudioStream = preload("res://assets/audio/sell.wav")
const SFX_UNLOCK: AudioStream = preload("res://assets/audio/unlock.wav")
const SFX_DROP: AudioStream = preload("res://assets/audio/drop.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

const VEG_COLORS: Array[Color] = [Kit.ORANGE, Kit.LIME, Kit.RED, Kit.PURPLE]

var coins: int = 0
var carry: Array = []          # veggie colors on the stack
var carry_cap: int = 5
var walk_speed: float = 4.2
var stock: int = 0
var boost_until: float = 0.0
var save_tick: float = 0.0

var player: Node3D = null
var stack_root: Node3D = null
var cam: Camera3D = null
var patches: Array = []        # {node, pos, veggies:[nodes], timer, unlocked}
var customers: Array = []      # {node, state, need, timer}
var pads: Array = []           # {node, pos, key, cost, hold, label3d}
var customer_timer: float = 0.0
var stall_pos := Vector3(4.2, 0.0, -3.5)
var stall_stock_root: Node3D = null

var joystick: Joystick = null
var coin_label: Label = null
var carry_label: Label = null
var toast_label: Label = null
var boost_button: Button = null
var _toast_tween: Tween = null

func _ready() -> void:
	randomize()
	coins = int(SaveManager.get_value("coins", 0))
	carry_cap = int(SaveManager.get_value("cap", 5))
	walk_speed = float(SaveManager.get_value("speed", 4.2))
	_build_world()
	_build_ui()
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	Analytics.log_event("round_start")


func _process(delta: float) -> void:
	save_tick += delta
	if save_tick > 12.0:
		save_tick = 0.0
		_save()
	_move_player(delta)
	_tick_patches(delta)
	_tick_customers(delta)
	_tick_pads(delta)
	coin_label.text = "₹%d%s" % [coins, "  ×2!" if _boosted() else ""]
	carry_label.text = "carrying %d / %d   stall %d" % [carry.size(), carry_cap, stock]
	boost_button.visible = AdsManager.is_rewarded_ready() and not _boosted()


func _boosted() -> bool:
	return Time.get_unix_time_from_system() < boost_until


func _move_player(delta: float) -> void:
	var v := joystick.vector
	if v.length() > 0.05:
		var dir := Vector3(v.x, 0.0, v.y)
		player.position += dir * walk_speed * delta
		player.position.x = clampf(player.position.x, -6.0, 6.0)
		player.position.z = clampf(player.position.z, -7.0, 5.0)
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)
		# stack sway
		for i in stack_root.get_child_count():
			var crate := stack_root.get_child(i) as Node3D
			crate.rotation.x = sin(Time.get_ticks_msec() / 90.0 + i) * 0.08 * v.length()
	cam.position = cam.position.lerp(player.position + Vector3(0.0, 11.0, 8.5), 5.0 * delta)
	cam.look_at(player.position + Vector3(0.0, 0.5, -1.0))
	# near stall: unload
	if not carry.is_empty() and player.position.distance_to(stall_pos) < 1.8:
		stock += carry.size()
		AudioManager.play_sfx(SFX_DROP)
		Haptics.light()
		Kit.burst(self, stall_pos + Vector3.UP * 1.2, Kit.MINT, 14, 4.0)
		carry.clear()
		_rebuild_stack()
		_restock_visual()


func _tick_patches(delta: float) -> void:
	for p: Dictionary in patches:
		if not p.unlocked:
			continue
		p.timer -= delta
		if p.timer <= 0.0 and p.veggies.size() < 6:
			p.timer = PICK_EVERY
			var veg := Kit.sphere(0.2, VEG_COLORS[patches.find(p) % VEG_COLORS.size()], true)
			veg.position = p.pos + Vector3(randf_range(-1.0, 1.0), 0.25, randf_range(-1.0, 1.0))
			add_child(veg)
			p.veggies.append(veg)
			Kit.squash(veg, 0.4)
		# auto-pick when close
		if carry.size() < carry_cap:
			for veg: Node3D in p.veggies.duplicate():
				if veg.position.distance_to(player.position) < 1.1:
					p.veggies.erase(veg)
					veg.queue_free()
					carry.append(VEG_COLORS[patches.find(p) % VEG_COLORS.size()])
					AudioManager.play_sfx(SFX_PICK, 0.08, 1.0 + carry.size() * 0.04)
					Haptics.light()
					_rebuild_stack()
					if carry.size() >= carry_cap:
						break


func _tick_customers(delta: float) -> void:
	customer_timer -= delta
	if customer_timer <= 0.0 and customers.size() < 5:
		customer_timer = CUSTOMER_EVERY
		var c := Kit.blobby(Kit.CANDY[randi() % Kit.CANDY.size()], 0.26)
		c.position = Vector3(randf_range(-2.0, 2.0), 0.0, 7.5)
		add_child(c)
		customers.append({ "node": c, "state": "walk", "need": randi_range(1, 3), "timer": 0.0 })
	for c: Dictionary in customers.duplicate():
		var node: Node3D = c.node
		match String(c.state):
			"walk":
				var target := stall_pos + Vector3(-1.6 - customers.find(c) * 0.8, 0.0, 1.4)
				var to_t := target - node.position
				if to_t.length() < 0.2:
					c.state = "wait"
				else:
					node.position += to_t.normalized() * 2.6 * delta
					node.rotation.y = lerp_angle(node.rotation.y, atan2(-to_t.x, -to_t.z), 8.0 * delta)
			"wait":
				if stock >= int(c.need):
					stock -= int(c.need)
					var pay := int(c.need) * 6 * (2 if _boosted() else 1)
					coins += pay
					AudioManager.play_sfx(SFX_SELL, 0.05)
					Haptics.light()
					Kit.burst(self, node.position + Vector3.UP, Kit.SUN, 10, 4.0)
					_restock_visual()
					c.state = "leave"
			"leave":
				node.position += Vector3(0.0, 0.0, 1.0) * 3.0 * delta
				if node.position.z > 7.5:
					node.queue_free()
					customers.erase(c)


func _tick_pads(delta: float) -> void:
	for pad: Dictionary in pads.duplicate():
		var near: bool = player.position.distance_to(pad.pos) < 1.2
		if near and coins >= int(pad.cost):
			pad.hold += delta
			if pad.hold >= PAD_HOLD:
				_buy(pad)
		else:
			pad.hold = 0.0


func _buy(pad: Dictionary) -> void:
	coins -= int(pad.cost)
	AudioManager.play_sfx(SFX_UNLOCK)
	Haptics.medium()
	Kit.burst(self, pad.pos + Vector3.UP, Kit.SUN, 26, 6.0)
	match String(pad.key):
		"patch2":
			patches[1].unlocked = true
			patches[1].node.visible = true
			_toast("New patch unlocked!")
		"patch3":
			patches[2].unlocked = true
			patches[2].node.visible = true
			_toast("Third patch unlocked!")
		"cap":
			carry_cap += 2
			_toast("Bigger basket: carry %d" % carry_cap)
			_spawn_pad("cap", int(pad.cost * 1.7), pad.pos)
		"speed":
			walk_speed += 0.7
			_toast("Faster chappals!")
			_spawn_pad("speed", int(pad.cost * 1.7), pad.pos)
	pad.node.queue_free()
	pads.erase(pad)
	Analytics.log_event("buy", {"what": pad.key})
	_save()
	AdsManager.round_finished()
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "boost":
		return
	boost_until = Time.get_unix_time_from_system() + 60.0
	Analytics.log_event("boost_used")
	Haptics.medium()
	_toast("DOUBLE PAY for 60 seconds!")


func _save() -> void:
	SaveManager.set_value("coins", coins)
	SaveManager.set_value("cap", carry_cap)
	SaveManager.set_value("speed", walk_speed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


func _rebuild_stack() -> void:
	for child in stack_root.get_children():
		child.queue_free()
	for i in carry.size():
		var crate := Kit.box(Vector3(0.42, 0.22, 0.42), carry[i], true)
		crate.position.y = 1.15 + i * 0.24
		stack_root.add_child(crate)


func _restock_visual() -> void:
	for child in stall_stock_root.get_children():
		child.queue_free()
	for i in mini(stock, 12):
		var veg := Kit.sphere(0.14, VEG_COLORS[i % VEG_COLORS.size()], true)
		veg.position = Vector3(-0.5 + (i % 4) * 0.33, 1.05 + (i / 4) * 0.3, 0.0)
		stall_stock_root.add_child(veg)


# --- world ------------------------------------------------------------------

func _build_world() -> void:
	Kit.sky(self, Kit.SKY, Color(1.0, 0.88, 0.6), Color(0.55, 0.8, 0.45))
	cam = Camera3D.new()
	cam.position = Vector3(0.0, 11.0, 8.5)
	cam.fov = 52.0
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var ground := Kit.texbox(Vector3(16.0, 0.4, 16.0), "tex1", Color(0.55, 0.85, 0.5), 1.0)
	ground.position.y = -0.2
	add_child(ground)
	var path := Kit.box(Vector3(2.4, 0.42, 16.0), Kit.CREAM)
	path.position = Vector3(2.0, -0.19, 0.0)
	add_child(path)
	player = Node3D.new()
	player.add_child(Kit.blobby(Kit.TEAL, 0.3))
	stack_root = Node3D.new()
	player.add_child(stack_root)
	add_child(player)
	player.position = Vector3(0.0, 0.0, 2.0)
	# stall
	var stall := Node3D.new()
	stall.position = stall_pos
	var counter := Kit.box(Vector3(2.4, 1.0, 1.0), Kit.ORANGE, true)
	counter.position.y = 0.5
	stall.add_child(counter)
	var roof := Kit.box(Vector3(2.8, 0.15, 1.6), Kit.PINK, true)
	roof.position.y = 2.2
	stall.add_child(roof)
	for px: float in [-1.2, 1.2]:
		var pole := Kit.cyl(0.07, 2.2, Kit.CREAM)
		pole.position = Vector3(px, 1.1, 0.4)
		stall.add_child(pole)
	stall_stock_root = Node3D.new()
	stall.add_child(stall_stock_root)
	add_child(stall)
	# patches
	for i in 3:
		var patch := Node3D.new()
		var pos := Vector3(-4.0 + (i % 2) * 1.0, 0.0, -4.5 + i * 3.4)
		patch.position = pos
		var soil := Kit.box(Vector3(2.8, 0.15, 2.8), Color(0.5, 0.33, 0.22))
		soil.position.y = 0.05
		patch.add_child(soil)
		for r in 3:
			var row := Kit.box(Vector3(2.5, 0.08, 0.3), Color(0.42, 0.27, 0.18))
			row.position = Vector3(0.0, 0.14, -0.8 + r * 0.8)
			patch.add_child(row)
		patch.visible = i == 0
		add_child(patch)
		patches.append({ "node": patch, "pos": pos, "veggies": [], "timer": 1.0, "unlocked": i == 0 })
	_spawn_pad("patch2", 120, Vector3(-3.5, 0.0, -1.2))
	_spawn_pad("patch3", 420, Vector3(-3.0, 0.0, 2.2))
	_spawn_pad("cap", 80, Vector3(1.0, 0.0, 4.0))
	_spawn_pad("speed", 60, Vector3(3.5, 0.0, 4.0))


func _spawn_pad(key: String, cost: int, pos: Vector3) -> void:
	var node := Node3D.new()
	node.position = pos
	var disc := Kit.cyl(0.9, 0.08, Color(Kit.SUN.r, Kit.SUN.g, Kit.SUN.b, 0.85))
	disc.position.y = 0.04
	node.add_child(disc)
	var text := Label3D.new()
	text.text = "%s\n₹%d" % [{ "patch2": "PATCH", "patch3": "PATCH", "cap": "BASKET+", "speed": "SPEED+" }[key], cost]
	text.font_size = 120
	text.pixel_size = 0.012
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.position.y = 1.1
	text.outline_size = 28
	node.add_child(text)
	add_child(node)
	pads.append({ "node": node, "pos": pos, "key": key, "cost": cost, "hold": 0.0 })


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	coin_label = Kit.label("₹0", 88, Kit.SUN)
	coin_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	coin_label.offset_top = 44.0
	coin_label.offset_bottom = 152.0
	layer.add_child(coin_label)
	carry_label = Kit.label("", 44, Color.WHITE)
	carry_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	carry_label.offset_top = 154.0
	carry_label.offset_bottom = 215.0
	layer.add_child(carry_label)
	toast_label = Kit.label("", 48, Kit.MINT)
	toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_label.offset_top = 1300.0
	toast_label.offset_bottom = 1370.0
	toast_label.modulate.a = 0.0
	layer.add_child(toast_label)
	joystick = Joystick.new()
	joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	joystick.offset_top = 860.0
	layer.add_child(joystick)
	boost_button = Kit.button("×2 PAY · AD", 42, Kit.PURPLE)
	boost_button.position = Vector2(740.0, 250.0)
	boost_button.size = Vector2(300.0, 100.0)
	boost_button.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("boost"))
	layer.add_child(boost_button)


func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
