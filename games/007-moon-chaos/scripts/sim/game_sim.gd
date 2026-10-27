class_name GameSim
extends RefCounted
## The whole game state and every rule that changes it.
##
## RefCounted, not Node: the sim never touches the scene tree or an autoload,
## which is what lets the economy, offline earnings and dust conservation be
## tested headlessly. The view layer owns all rendering and all autoload calls
## and reacts to the signals below.

signal cash_changed(cash: int)
signal crystals_changed(crystals: int)
signal carry_changed(carried: int, capacity: int)
signal carry_full
signal depot_changed(stored: int, capacity: int)
signal dust_swept(result: DustGrid.SweepResult)
signal clean_pct_changed(pct: float)
signal zone_completed(zone_id: String)
signal zone_unlocked(zone_id: String)
signal shipment_changed
signal shipment_launch_started
signal shipment_launched(payout: int, payload: int)
signal upgrade_purchased(track: String, level: int)
signal tool_upgraded(tier: int)

const SCHEMA_VERSION: int = 1

const REWARD_SHIPMENT_2X: String = "shipment_2x"
const REWARD_INSTANT_ROCKET: String = "instant_rocket"
const REWARD_SPEED_BOOST: String = "speed_boost"

var balance: Balance = null
var profile: PlayerProfile = null
var player: PlayerState = null
var depot: DepotState = null
var shipment: ShipmentState = null
var zones: Array = []                 ## of ZoneState, parallel to balance.zones
var active_zone_index: int = 0
var sim_time: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sweep_credit: float = 0.0
var _last_clean_pct: float = -1.0


static func new_game(b: Balance) -> GameSim:
	var sim := GameSim.new()
	sim.balance = b
	sim.profile = PlayerProfile.new()
	sim.player = PlayerState.new()
	sim.depot = DepotState.new()
	sim.shipment = ShipmentState.new()
	sim.shipment.reset(b.rocket_auto_launch_seconds)
	sim._rng.randomize()
	for i: int in b.zones.size():
		var def: Balance.ZoneDef = b.zones[i]
		sim.zones.append(ZoneState.fresh(def, b, i == 0))
	sim.active_zone_index = 0
	sim._reset_player_to_depot()
	return sim


# --- queries --------------------------------------------------------------

func active_zone() -> ZoneState:
	if active_zone_index < 0 or active_zone_index >= zones.size():
		return null
	return zones[active_zone_index]


func active_zone_def() -> Balance.ZoneDef:
	if active_zone_index < 0 or active_zone_index >= balance.zones.size():
		return null
	return balance.zones[active_zone_index]


func carry_capacity() -> int:
	return profile.carry_capacity(balance)


func depot_capacity() -> int:
	return profile.depot_capacity(balance)


func rocket_capacity() -> int:
	return balance.rocket_base_capacity


func clean_pct() -> float:
	var z: ZoneState = active_zone()
	return 0.0 if z == null or z.grid == null else z.grid.clean_pct()


func current_tool() -> Balance.ToolDef:
	return profile.tool(balance)


func move_speed() -> float:
	var speed: float = profile.move_speed(balance)
	if player.has_speed_boost(sim_time):
		speed *= balance.rewarded_speed_boost_mult
	return speed


## True when the player is standing on (or beside) the depot pad.
func is_at_depot() -> bool:
	var def: Balance.ZoneDef = active_zone_def()
	if def == null:
		return false
	var centre: Vector2i = ZoneState.depot_cell_for(def)
	var half: Vector2i = ZoneState.DEPOT_SIZE / 2
	var c: Vector2i = cell_of(player.pos)
	# One cell of slack so the action button is not a pixel-hunt on a phone.
	return absi(c.x - centre.x) <= half.x + 1 and absi(c.y - centre.y) <= half.y + 1


func cell_of(local_pos: Vector2) -> Vector2i:
	var def: Balance.ZoneDef = active_zone_def()
	if def == null:
		return Vector2i.ZERO
	return Vector2i(int(floor(local_pos.x / def.cell_size)), int(floor(local_pos.y / def.cell_size)))


func depot_local_pos() -> Vector2:
	var def: Balance.ZoneDef = active_zone_def()
	if def == null:
		return Vector2.ZERO
	var c: Vector2i = ZoneState.depot_cell_for(def)
	return Vector2(float(c.x) + 0.5, float(c.y) + 0.5) * def.cell_size


func next_zone_index() -> int:
	for i: int in zones.size():
		if not (zones[i] as ZoneState).unlocked:
			return i
	return -1


func next_zone_cost() -> int:
	var i: int = next_zone_index()
	if i < 0:
		return -1
	return (balance.zones[i] as Balance.ZoneDef).unlock_cost


# --- per-frame ------------------------------------------------------------

## One simulation step. `move_dir` is a normalised-ish input vector in grid
## space; sweeping happens automatically wherever the player passes over dust.
func step(move_dir: Vector2, delta: float) -> void:
	if delta <= 0.0:
		return
	sim_time += delta
	_move(move_dir, delta)
	_sweep(delta)
	_tick_automation(delta)
	_tick_shipment(delta)


func _move(move_dir: Vector2, delta: float) -> void:
	var def: Balance.ZoneDef = active_zone_def()
	if def == null:
		return
	if move_dir.length_squared() > 1.0:
		move_dir = move_dir.normalized()
	if move_dir.is_zero_approx():
		return
	var extent: Vector2 = def.extent()
	player.pos += move_dir * move_speed() * delta
	player.pos.x = clampf(player.pos.x, 0.0, extent.x)
	player.pos.y = clampf(player.pos.y, 0.0, extent.y)


func _sweep(delta: float) -> void:
	var z: ZoneState = active_zone()
	if z == null or z.grid == null:
		return
	var tool: Balance.ToolDef = current_tool()
	var capacity: int = carry_capacity()

	_sweep_credit += tool.sweep_rate * delta
	# A full pack must not bank credit it will dump the instant it empties.
	_sweep_credit = minf(_sweep_credit, tool.sweep_rate)

	var space: int = player.carry_space(capacity)
	if space <= 0:
		return
	var budget: int = mini(int(floor(_sweep_credit)), space)
	if budget <= 0:
		return

	var res: DustGrid.SweepResult = z.grid.sweep(cell_of(player.pos), tool.radius_cells,
			budget, _rng, balance.crystal_find_chance_per_cell)
	if res.collected <= 0:
		return

	_sweep_credit -= float(res.collected)
	Economy.deposit(player.carrying, res.by_type)
	if res.crystals_found > 0:
		profile.crystals += res.crystals_found
		crystals_changed.emit(profile.crystals)

	dust_swept.emit(res)
	carry_changed.emit(player.carry_total(), capacity)
	if player.is_full(capacity):
		carry_full.emit()
	_emit_clean_pct_if_changed()
	_check_zone_complete()


func _tick_automation(delta: float) -> void:
	var z: ZoneState = active_zone()
	if z == null or z.buildings.is_empty():
		return
	var res: AutomationNet.TickResult = AutomationNet.tick(z, active_zone_def(), depot,
			depot_capacity(), balance, delta)
	if res.delivered_total() > 0:
		depot_changed.emit(depot.total(), depot_capacity())
	if res.pulled_total() > 0:
		_emit_clean_pct_if_changed()
		_check_zone_complete()


func _tick_shipment(delta: float) -> void:
	var capacity: int = rocket_capacity()

	if shipment.status == ShipmentState.Status.LAUNCHING:
		shipment.launch_seconds_left -= delta
		if shipment.launch_seconds_left <= 0.0:
			_complete_launch()
		return

	# The depot and the rocket are the same pile conceptually, so loading is
	# immediate; the depot only backs up once the rocket is full.
	var room: int = capacity - shipment.payload_total()
	if room > 0 and depot.total() > 0:
		var moved: Dictionary = depot.withdraw(room)
		if not moved.is_empty():
			Economy.deposit(shipment.payload, moved)
			depot_changed.emit(depot.total(), depot_capacity())
			shipment_changed.emit()

	shipment.seconds_until_launch -= delta
	var timed_out: bool = shipment.seconds_until_launch <= 0.0 and shipment.payload_total() > 0
	if shipment.is_full(capacity) or timed_out:
		_begin_launch()


# --- actions --------------------------------------------------------------

## Hand the carried load to the depot. Returns how much it accepted; anything
## that did not fit stays on the player rather than vanishing.
func dump() -> int:
	var capacity: int = depot_capacity()
	var before: int = player.carry_total()
	if before <= 0:
		return 0
	var leftover: Dictionary = depot.accept(player.carrying, capacity)
	player.carrying = leftover
	var accepted: int = before - player.carry_total()
	if accepted > 0:
		depot_changed.emit(depot.total(), capacity)
		carry_changed.emit(player.carry_total(), carry_capacity())
	return accepted


## Player-tapped launch. Returns false when there is nothing to send.
func request_launch() -> bool:
	if not shipment.can_launch_now():
		return false
	_begin_launch()
	return true


func grant_reward(reward_type: String) -> bool:
	match reward_type:
		REWARD_SHIPMENT_2X:
			shipment.pending_multiplier = balance.rewarded_shipment_multiplier
			shipment_changed.emit()
			return true
		REWARD_INSTANT_ROCKET:
			return request_launch()
		REWARD_SPEED_BOOST:
			player.speed_boost_until = sim_time + balance.rewarded_speed_boost_seconds
			return true
	return false


func upgrade_cost(track: String) -> int:
	return Economy.upgrade_cost(balance.upgrade(track), profile.level_of(track))


func can_buy_upgrade(track: String) -> bool:
	var cost: int = upgrade_cost(track)
	return cost >= 0 and profile.cash >= cost


func buy_upgrade(track: String) -> bool:
	var cost: int = upgrade_cost(track)
	if cost < 0 or profile.cash < cost:
		return false
	profile.cash -= cost
	var level: int = profile.level_of(track) + 1
	profile.set_level(track, level)
	cash_changed.emit(profile.cash)
	upgrade_purchased.emit(track, level)
	# Capacity changes alter the meters immediately.
	carry_changed.emit(player.carry_total(), carry_capacity())
	depot_changed.emit(depot.total(), depot_capacity())
	return true


func tool_upgrade_cost() -> int:
	if profile.tool_tier >= balance.max_tool_tier():
		return -1
	return (balance.tools[profile.tool_tier + 1] as Balance.ToolDef).cost


func buy_tool() -> bool:
	var cost: int = tool_upgrade_cost()
	if cost < 0 or profile.cash < cost:
		return false
	profile.cash -= cost
	profile.tool_tier += 1
	cash_changed.emit(profile.cash)
	tool_upgraded.emit(profile.tool_tier)
	return true


func unlock_next_zone() -> bool:
	var i: int = next_zone_index()
	if i < 0:
		return false
	var def: Balance.ZoneDef = balance.zones[i]
	if profile.cash < def.unlock_cost:
		return false
	profile.cash -= def.unlock_cost
	(zones[i] as ZoneState).unlocked = true
	cash_changed.emit(profile.cash)
	zone_unlocked.emit(def.id)
	return true


func set_active_zone(index: int) -> bool:
	if index < 0 or index >= zones.size():
		return false
	if not (zones[index] as ZoneState).unlocked:
		return false
	active_zone_index = index
	_reset_player_to_depot()
	_last_clean_pct = -1.0
	_emit_clean_pct_if_changed()
	return true


## Credit time that passed while the app was closed. Offline runs only on
## automation, so a player with no buildings earns nothing and is told why.
func apply_offline(elapsed_sec: float) -> Offline.Result:
	var z: ZoneState = active_zone()
	var rate: float = 0.0 if z == null else AutomationNet.throughput(z, active_zone_def(), balance)
	var def: Balance.ZoneDef = active_zone_def()
	var zone_mult: float = 1.0 if def == null else def.payout_mult
	var cash_per_dust: float = balance.rocket_cash_per_dust * zone_mult * profile.payout_mult(balance)
	var res: Offline.Result = Offline.compute(elapsed_sec, rate, cash_per_dust,
			balance.offline_rate_multiplier, balance.offline_cap_hours)
	if res.cash > 0:
		profile.cash += res.cash
		cash_changed.emit(profile.cash)
	return res


# --- internals ------------------------------------------------------------

func _begin_launch() -> void:
	shipment.begin_launch(balance.rocket_launch_seconds)
	shipment_launch_started.emit()


func _complete_launch() -> void:
	var payload: int = shipment.payload_total()
	var payout: int = Economy.shipment_payout(shipment.payload, rocket_capacity(),
			_zone_payout_mult(), profile.payout_mult(balance),
			shipment.pending_multiplier, balance)
	profile.cash += payout
	shipment.reset(balance.rocket_auto_launch_seconds)
	cash_changed.emit(profile.cash)
	shipment_launched.emit(payout, payload)
	shipment_changed.emit()


func _zone_payout_mult() -> float:
	var def: Balance.ZoneDef = active_zone_def()
	return 1.0 if def == null else def.payout_mult


func _reset_player_to_depot() -> void:
	player.pos = depot_local_pos()


func _emit_clean_pct_if_changed() -> void:
	var pct: float = clean_pct()
	if is_equal_approx(pct, _last_clean_pct):
		return
	_last_clean_pct = pct
	clean_pct_changed.emit(pct)


func _check_zone_complete() -> void:
	var z: ZoneState = active_zone()
	var def: Balance.ZoneDef = active_zone_def()
	if z == null or def == null or z.completed or z.grid == null:
		return
	if z.grid.is_complete(def.target_clean_pct):
		z.completed = true
		zone_completed.emit(def.id)


# --- serialisation --------------------------------------------------------

func to_dict() -> Dictionary:
	# Always a FRESH dictionary: SaveManager.set_value() skips the write when
	# the value equals what it already holds, so handing it the same instance
	# back would silently no-op the save.
	var zone_dicts: Array = []
	for z: ZoneState in zones:
		zone_dicts.append(z.to_dict())
	return {
		"schema_version": SCHEMA_VERSION,
		"profile": profile.to_dict(),
		"player": player.to_dict(),
		"depot": depot.to_dict(),
		"shipment": shipment.to_dict(),
		"zones": zone_dicts,
		"active_zone_index": active_zone_index,
	}


static func from_dict(d: Dictionary, b: Balance) -> GameSim:
	var version: int = int(d.get("schema_version", 0))
	if version != SCHEMA_VERSION:
		push_warning("GameSim: save schema %d != %d, starting fresh" % [version, SCHEMA_VERSION])
		return GameSim.new_game(b)

	var sim := GameSim.new()
	sim.balance = b
	sim._rng.randomize()
	sim.profile = PlayerProfile.from_dict(d.get("profile", {}) as Dictionary)
	sim.player = PlayerState.from_dict(d.get("player", {}) as Dictionary)
	sim.depot = DepotState.from_dict(d.get("depot", {}) as Dictionary)
	sim.shipment = ShipmentState.from_dict(d.get("shipment", {}) as Dictionary,
			b.rocket_auto_launch_seconds)

	# Rebuild zone-by-zone against the CURRENT balance, so adding a zone to
	# balance.json shows up in old saves instead of needing a migration.
	var saved: Array = d.get("zones", []) as Array
	var by_id: Dictionary = {}
	for raw: Variant in saved:
		if raw is Dictionary:
			by_id[String((raw as Dictionary).get("def_id", ""))] = raw
	for i: int in b.zones.size():
		var def: Balance.ZoneDef = b.zones[i]
		if by_id.has(def.id):
			sim.zones.append(ZoneState.from_dict(by_id[def.id] as Dictionary, def, b))
		else:
			sim.zones.append(ZoneState.fresh(def, b, i == 0))

	sim.active_zone_index = clampi(int(d.get("active_zone_index", 0)), 0, maxi(sim.zones.size() - 1, 0))
	if sim.player.pos.is_zero_approx():
		sim._reset_player_to_depot()
	return sim
