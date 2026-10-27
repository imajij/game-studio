extends Control
## Greybox HUD, built in code while the layout is still moving. Shows only
## what the core loop needs: money, clean %, carry, rocket, one action button,
## the upgrade tracks, and a joystick.
##
## Reads the sim and calls its actions; the sim never reaches back into the UI.

const MARGIN: float = 28.0
const BIG_FONT: int = 46
const MID_FONT: int = 34
const SMALL_FONT: int = 28

var sim: GameSim = null

var _game: Node3D = null
var _joystick: Joystick = null
var _cash: Label = null
var _crystals: Label = null
var _zone_label: Label = null
var _clean: ProgressBar = null
var _carry: Label = null
var _carry_bar: ProgressBar = null
var _rocket_label: Label = null
var _rocket_bar: ProgressBar = null
var _action: Button = null
var _toast: Label = null
var _toast_timer: Timer = null
var _upgrades: VBoxContainer = null
var _tool_button: Button = null
var _zone_button: Button = null
var _track_buttons: Dictionary = {}   ## track id -> Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func bind(game_sim: GameSim, game: Node3D) -> void:
	sim = game_sim
	_game = game
	_refresh()


func joystick_vector() -> Vector2:
	return Vector2.ZERO if _joystick == null else _joystick.vector


# --- construction ---------------------------------------------------------

func _build() -> void:
	# Joystick sits underneath everything else so buttons win any overlap.
	_joystick = Joystick.new()
	_joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick.anchor_right = 1.0
	_joystick.offset_left = 0.0
	_joystick.offset_right = 0.0
	_joystick.offset_top = -900.0
	_joystick.offset_bottom = 0.0
	add_child(_joystick)

	_cash = _label("$0", BIG_FONT, Color(1.0, 0.92, 0.5))
	_cash.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_cash.position = Vector2(MARGIN, MARGIN)
	add_child(_cash)

	_crystals = _label("0 crystals", SMALL_FONT, Color(0.75, 0.9, 1.0))
	_crystals.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_crystals.position = Vector2(MARGIN, MARGIN + 58.0)
	add_child(_crystals)

	_zone_label = _label("", MID_FONT, Color(0.9, 0.92, 0.96))
	_zone_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_zone_label.offset_top = MARGIN + 110.0
	_zone_label.offset_left = MARGIN
	_zone_label.offset_right = -MARGIN
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_zone_label)

	_clean = ProgressBar.new()
	_clean.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_clean.offset_left = MARGIN
	_clean.offset_right = -MARGIN
	_clean.offset_top = MARGIN + 162.0
	_clean.offset_bottom = MARGIN + 202.0
	_clean.min_value = 0.0
	_clean.max_value = 100.0
	_clean.show_percentage = true
	add_child(_clean)

	# Rocket readout, top right.
	_rocket_label = _label("rocket", SMALL_FONT, Color(0.95, 0.75, 0.7))
	_rocket_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_rocket_label.offset_left = -420.0
	_rocket_label.offset_right = -MARGIN
	_rocket_label.offset_top = MARGIN
	_rocket_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_rocket_label)

	_rocket_bar = ProgressBar.new()
	_rocket_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_rocket_bar.offset_left = -420.0
	_rocket_bar.offset_right = -MARGIN
	_rocket_bar.offset_top = MARGIN + 46.0
	_rocket_bar.offset_bottom = MARGIN + 80.0
	_rocket_bar.min_value = 0.0
	_rocket_bar.max_value = 100.0
	_rocket_bar.show_percentage = false
	add_child(_rocket_bar)

	# Carry meter, just above the action button.
	_carry = _label("carry 0 / 0", MID_FONT, Color(0.92, 0.94, 0.98))
	_carry.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_carry.offset_left = -520.0
	_carry.offset_right = -MARGIN
	_carry.offset_top = -430.0
	_carry.offset_bottom = -380.0
	_carry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_carry)

	_carry_bar = ProgressBar.new()
	_carry_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_carry_bar.offset_left = -520.0
	_carry_bar.offset_right = -MARGIN
	_carry_bar.offset_top = -374.0
	_carry_bar.offset_bottom = -340.0
	_carry_bar.min_value = 0.0
	_carry_bar.max_value = 100.0
	_carry_bar.show_percentage = false
	add_child(_carry_bar)

	# One big contextual action button, reachable by the right thumb.
	_action = Button.new()
	_action.text = "—"
	_action.add_theme_font_size_override("font_size", BIG_FONT)
	_action.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_action.offset_left = -330.0
	_action.offset_right = -MARGIN
	_action.offset_top = -320.0
	_action.offset_bottom = -MARGIN - 60.0
	_action.pressed.connect(_on_action_pressed)
	add_child(_action)

	# Upgrade tracks, down the left side above the joystick visuals.
	_upgrades = VBoxContainer.new()
	_upgrades.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_upgrades.offset_left = MARGIN
	_upgrades.offset_right = MARGIN + 430.0
	_upgrades.offset_top = -260.0
	_upgrades.offset_bottom = 260.0
	_upgrades.add_theme_constant_override("separation", 10)
	add_child(_upgrades)

	_tool_button = _make_upgrade_button("tool")
	_upgrades.add_child(_tool_button)
	for track: String in [PlayerProfile.TRACK_CARRY, PlayerProfile.TRACK_SPEED,
			PlayerProfile.TRACK_DEPOT, PlayerProfile.TRACK_PAYOUT]:
		var button: Button = _make_upgrade_button(track)
		_track_buttons[track] = button
		_upgrades.add_child(button)

	_zone_button = _make_upgrade_button("zone")
	_upgrades.add_child(_zone_button)

	_toast = _label("", MID_FONT, Color(1.0, 1.0, 1.0))
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -480.0
	_toast.offset_right = 480.0
	_toast.offset_top = 560.0
	_toast.offset_bottom = 700.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.visible = false
	add_child(_toast)

	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(func() -> void: _toast.visible = false)
	add_child(_toast_timer)


func _label(text: String, size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _make_upgrade_button(key: String) -> Button:
	var button := Button.new()
	button.add_theme_font_size_override("font_size", SMALL_FONT)
	button.custom_minimum_size = Vector2(0.0, 64.0)
	button.pressed.connect(_on_upgrade_pressed.bind(key))
	return button


# --- interaction ----------------------------------------------------------

func _on_action_pressed() -> void:
	if sim == null:
		return
	if sim.player.carry_total() > 0 and sim.is_at_depot():
		if sim.dump() > 0:
			Haptics.light()
	elif sim.shipment.can_launch_now():
		sim.request_launch()


func _on_upgrade_pressed(key: String) -> void:
	if sim == null:
		return
	var bought: bool = false
	match key:
		"tool":
			bought = sim.buy_tool()
		"zone":
			bought = sim.unlock_next_zone()
		_:
			bought = sim.buy_upgrade(key)
	if bought:
		Haptics.light()
		_refresh()


# --- notifications --------------------------------------------------------

func show_payout(payout: int, payload: int) -> void:
	_show_toast("shipment away:  +$%d  (%d dust)" % [payout, payload], 2.2)


func show_offline(result: Offline.Result) -> void:
	var hours: float = result.elapsed_used / 3600.0
	var suffix: String = "  (capped)" if result.capped else ""
	_show_toast("while you were away: +$%d over %.1f h%s" % [result.cash, hours, suffix], 4.0)


func show_zone_complete(zone_id: String) -> void:
	var def: Balance.ZoneDef = sim.balance.zone_def(zone_id) if sim != null else null
	var zone_name: String = zone_id if def == null else def.name
	_show_toast("%s is spotless!" % zone_name, 3.0)


func _show_toast(text: String, seconds: float) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_timer.start(seconds)


# --- refresh --------------------------------------------------------------

func _process(_delta: float) -> void:
	if sim != null:
		_refresh()


func _refresh() -> void:
	if sim == null:
		return

	_cash.text = "$%d" % sim.profile.cash
	_crystals.text = "%d crystals" % sim.profile.crystals

	var def: Balance.ZoneDef = sim.active_zone_def()
	_zone_label.text = "" if def == null else def.name
	_clean.value = sim.clean_pct()

	var capacity: int = sim.carry_capacity()
	var carried: int = sim.player.carry_total()
	_carry.text = "carry %d / %d" % [carried, capacity]
	_carry_bar.value = 0.0 if capacity <= 0 else float(carried) / float(capacity) * 100.0

	var rocket_capacity: int = sim.rocket_capacity()
	var payload: int = sim.shipment.payload_total()
	_rocket_bar.value = sim.shipment.fill_pct(rocket_capacity)
	if sim.shipment.status == ShipmentState.Status.LAUNCHING:
		_rocket_label.text = "launching!"
	else:
		var multiplier: String = ""
		if sim.shipment.pending_multiplier > 1.0:
			multiplier = "  x%.0f" % sim.shipment.pending_multiplier
		_rocket_label.text = "rocket %d/%d  %ds%s" % [payload, rocket_capacity,
				int(ceil(maxf(sim.shipment.seconds_until_launch, 0.0))), multiplier]

	_refresh_action(carried)
	_refresh_upgrades()


func _refresh_action(carried: int) -> void:
	if carried > 0 and sim.is_at_depot():
		_action.text = "DUMP"
		_action.disabled = false
	elif sim.shipment.can_launch_now():
		_action.text = "LAUNCH"
		_action.disabled = false
	elif carried > 0:
		_action.text = "to depot"
		_action.disabled = true
	else:
		_action.text = "sweep"
		_action.disabled = true


func _refresh_upgrades() -> void:
	var tool_cost: int = sim.tool_upgrade_cost()
	if tool_cost < 0:
		_tool_button.text = "tool: %s (max)" % sim.current_tool().name
		_tool_button.disabled = true
	else:
		var next_tool: Balance.ToolDef = sim.balance.tools[sim.profile.tool_tier + 1]
		_tool_button.text = "%s — $%d" % [next_tool.name, tool_cost]
		_tool_button.disabled = sim.profile.cash < tool_cost

	for track: String in _track_buttons.keys():
		var button: Button = _track_buttons[track]
		var def: Balance.UpgradeDef = sim.balance.upgrade(track)
		var cost: int = sim.upgrade_cost(track)
		var level: int = sim.profile.level_of(track)
		if cost < 0:
			button.text = "%s Lv%d (max)" % [def.name, level]
			button.disabled = true
		else:
			button.text = "%s Lv%d — $%d" % [def.name, level, cost]
			button.disabled = sim.profile.cash < cost

	var zone_index: int = sim.next_zone_index()
	if zone_index < 0:
		_zone_button.text = "all zones unlocked"
		_zone_button.disabled = true
	else:
		var zone_def: Balance.ZoneDef = sim.balance.zones[zone_index]
		_zone_button.text = "unlock %s — $%d" % [zone_def.name, zone_def.unlock_cost]
		_zone_button.disabled = sim.profile.cash < zone_def.unlock_cost
