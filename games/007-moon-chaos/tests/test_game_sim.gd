extends "res://tests/test_case.gd"
## End-to-end core loop through GameSim: sweep -> carry -> dump -> rocket ->
## cash -> upgrade -> next zone, plus a save/load round trip.
##
## The unit suites prove each rule in isolation; this one proves they are
## actually wired to each other.


func suite_name() -> String:
	return "game_sim"


func run() -> void:
	var b: Balance = Balance.load_default()
	if not b.is_valid():
		ok(false, "balance.json invalid — " + str(b.errors))
		return

	_new_game(b)
	_sweep_and_carry(b)
	_dump_and_launch(b)
	_rewarded_double(b)
	_upgrades(b)
	_zone_unlock(b)
	_round_trip(b)
	_offline_without_automation(b)


## Park the player on a cell that definitely has dust.
func _place_on_dust(sim: GameSim) -> bool:
	var def: Balance.ZoneDef = sim.active_zone_def()
	var grid: DustGrid = sim.active_zone().grid
	for y: int in grid.h:
		for x: int in grid.w:
			if grid.dust_at(Vector2i(x, y)) > 0:
				sim.player.pos = Vector2(float(x) + 0.5, float(y) + 0.5) * def.cell_size
				return true
	return false


func _new_game(b: Balance) -> void:
	var sim: GameSim = GameSim.new_game(b)
	eq(sim.profile.cash, 0, "a new game starts broke")
	eq(sim.profile.crystals, 0, "a new game starts with no crystals")
	eq(sim.profile.tool_tier, 0, "a new game starts on the first tool")
	eq(sim.active_zone_index, 0, "a new game starts in the first zone")
	ok((sim.zones[0] as ZoneState).unlocked, "the first zone is unlocked")
	ok(not (sim.zones[1] as ZoneState).unlocked, "the second zone is locked")
	eq(sim.zones.size(), b.zones.size(), "every zone in balance has a state")
	ok(sim.is_at_depot(), "the player starts standing on the depot")
	approx(sim.clean_pct(), 0.0, "the first zone starts filthy")
	eq(sim.carry_capacity(), b.base_carry_capacity, "carry capacity comes from balance")


func _sweep_and_carry(b: Balance) -> void:
	var sim: GameSim = GameSim.new_game(b)
	ok(_place_on_dust(sim), "the first zone has dust to stand on")

	var swept_signals: Array = []
	sim.dust_swept.connect(func(r: DustGrid.SweepResult) -> void: swept_signals.append(r))
	var full_fired: Array = []
	sim.carry_full.connect(func() -> void: full_fired.append(true))

	var before: int = sim.active_zone().grid.remaining()
	for _i: int in 240:
		sim.step(Vector2.ZERO, 1.0 / 60.0)

	ok(sim.player.carry_total() > 0, "sweeping puts dust in the pack")
	ok(swept_signals.size() > 0, "sweeping emits dust_swept for the renderer")
	ok(sim.active_zone().grid.remaining() < before, "sweeping removes dust from the zone")
	ok(sim.clean_pct() > 0.0, "sweeping raises clean%")

	# Conservation across the sim boundary: dust leaving the grid is on the
	# player, nowhere else (nothing has been dumped yet).
	var removed: int = before - sim.active_zone().grid.remaining()
	eq(removed, sim.player.carry_total(), "dust off the grid is exactly what the player carries")

	var capacity: int = sim.carry_capacity()
	for _i: int in 600:
		sim.step(Vector2.ZERO, 1.0 / 60.0)
	eq(sim.player.carry_total(), capacity, "the pack fills to capacity and stops")
	ok(full_fired.size() > 0, "filling the pack emits carry_full")

	# A full pack must stop taking dust off the grid, not keep deleting it.
	var grid_at_full: int = sim.active_zone().grid.remaining()
	for _i: int in 120:
		sim.step(Vector2.ZERO, 1.0 / 60.0)
	eq(sim.active_zone().grid.remaining(), grid_at_full,
			"a full pack stops removing dust instead of destroying it")

	var dirty: DustGrid.SweepResult = swept_signals[0]
	ok(dirty.had_change, "the first sweep reports a dirty rect")
	ok(dirty.dirty_rect().size.x > 0, "the dirty rect has real area")


func _dump_and_launch(b: Balance) -> void:
	var sim: GameSim = GameSim.new_game(b)
	_place_on_dust(sim)
	for _i: int in 600:
		sim.step(Vector2.ZERO, 1.0 / 60.0)
	var carried: int = sim.player.carry_total()
	ok(carried > 0, "the player has a load to dump")

	eq(sim.dump(), 0, "dumping away from the depot does nothing")
	ok(sim.player.carry_total() == carried, "a failed dump keeps the load")

	sim.player.pos = sim.depot_local_pos()
	ok(sim.is_at_depot(), "walking onto the pad counts as being at the depot")
	var accepted: int = sim.dump()
	eq(accepted, carried, "the depot accepts the whole load")
	eq(sim.player.carry_total(), 0, "the player is empty after dumping")

	var launched: Array = []
	sim.shipment_launched.connect(func(payout: int, payload: int) -> void:
		launched.append({"payout": payout, "payload": payload})
	)

	# One step moves the depot's dust into the rocket.
	sim.step(Vector2.ZERO, 1.0 / 60.0)
	eq(sim.shipment.payload_total(), accepted, "the rocket loads from the depot")
	eq(sim.depot.total(), 0, "the depot hands its dust to the waiting rocket")

	ok(sim.request_launch(), "a loaded rocket can be launched by hand")
	eq(sim.shipment.status, ShipmentState.Status.LAUNCHING, "the rocket enters its launch")
	ok(not sim.request_launch(), "a rocket already launching cannot be launched again")

	for _i: int in 240:
		sim.step(Vector2.ZERO, 1.0 / 60.0)

	eq(launched.size(), 1, "the launch pays out exactly once")
	ok(sim.profile.cash > 0, "the launch pays cash")
	eq(int((launched[0] as Dictionary)["payload"]), accepted, "the payout reports the real payload")
	eq(sim.shipment.payload_total(), 0, "the rocket is empty again")
	eq(sim.shipment.status, ShipmentState.Status.FILLING, "the rocket is back on the pad")
	approx(sim.shipment.pending_multiplier, 1.0, "the launch consumed any multiplier")


func _rewarded_double(b: Balance) -> void:
	var sim: GameSim = GameSim.new_game(b)
	var regular: int = b.dust_type_index("regular")
	sim.depot.stored = {regular: 100}

	ok(sim.grant_reward(GameSim.REWARD_SHIPMENT_2X), "the 2x reward is granted")
	approx(sim.shipment.pending_multiplier, b.rewarded_shipment_multiplier,
			"the reward sets the payout multiplier")

	sim.step(Vector2.ZERO, 1.0 / 60.0)
	sim.request_launch()
	for _i: int in 240:
		sim.step(Vector2.ZERO, 1.0 / 60.0)
	var doubled: int = sim.profile.cash

	var plain: GameSim = GameSim.new_game(b)
	plain.depot.stored = {regular: 100}
	plain.step(Vector2.ZERO, 1.0 / 60.0)
	plain.request_launch()
	for _i: int in 240:
		plain.step(Vector2.ZERO, 1.0 / 60.0)

	eq(doubled, plain.profile.cash * 2, "the rewarded ad really doubles the payout")

	ok(sim.grant_reward(GameSim.REWARD_SPEED_BOOST), "the speed boost is granted")
	ok(sim.player.has_speed_boost(sim.sim_time), "the speed boost is active")
	ok(sim.move_speed() > sim.profile.move_speed(b), "the boost raises move speed")
	ok(not sim.grant_reward("nonsense_reward"), "an unknown reward type is refused")


func _upgrades(b: Balance) -> void:
	var sim: GameSim = GameSim.new_game(b)
	ok(not sim.buy_upgrade(PlayerProfile.TRACK_CARRY), "cannot buy an upgrade while broke")

	sim.profile.cash = 1_000_000
	var before_capacity: int = sim.carry_capacity()
	ok(sim.buy_upgrade(PlayerProfile.TRACK_CARRY), "an affordable upgrade is bought")
	ok(sim.carry_capacity() > before_capacity, "the upgrade raises carry capacity")
	eq(sim.profile.level_of(PlayerProfile.TRACK_CARRY), 1, "the level went up by one")
	ok(sim.profile.cash < 1_000_000, "the upgrade was paid for")

	var before_speed: float = sim.move_speed()
	ok(sim.buy_upgrade(PlayerProfile.TRACK_SPEED), "the speed track is buyable")
	ok(sim.move_speed() > before_speed, "the upgrade raises move speed")

	var before_radius: int = sim.current_tool().radius_cells
	ok(sim.buy_tool(), "the next tool tier is buyable")
	eq(sim.profile.tool_tier, 1, "the tool tier advanced")
	ok(sim.current_tool().radius_cells > before_radius, "a better tool sweeps wider")

	# Buy to the top of the tool tree and confirm it closes cleanly.
	while sim.buy_tool():
		pass
	eq(sim.profile.tool_tier, b.max_tool_tier(), "tools top out at the last tier")
	eq(sim.tool_upgrade_cost(), -1, "a maxed tool tree reports no cost")

	ok(not sim.buy_upgrade("no_such_track"), "an unknown track cannot be bought")


func _zone_unlock(b: Balance) -> void:
	var sim: GameSim = GameSim.new_game(b)
	eq(sim.next_zone_index(), 1, "the next zone to unlock is the second")
	eq(sim.next_zone_cost(), (b.zones[1] as Balance.ZoneDef).unlock_cost,
			"the unlock cost comes from balance")
	ok(not sim.unlock_next_zone(), "cannot unlock a zone while broke")

	sim.profile.cash = 10_000_000
	var unlocked: Array = []
	sim.zone_unlocked.connect(func(id: String) -> void: unlocked.append(id))
	ok(sim.unlock_next_zone(), "an affordable zone unlocks")
	eq(unlocked.size(), 1, "unlocking emits once")
	ok((sim.zones[1] as ZoneState).unlocked, "the second zone is now unlocked")

	ok(sim.set_active_zone(1), "the player can travel to the unlocked zone")
	eq(sim.active_zone_index, 1, "the active zone changed")
	ok(sim.is_at_depot(), "travelling puts the player on the new zone's depot")
	approx(sim.clean_pct(), 0.0, "the new zone starts filthy")
	ok(not sim.set_active_zone(99), "cannot travel to a zone that does not exist")

	# Zone 2 should be a different size, which is what the renderer rebuilds on.
	ok(sim.active_zone().grid.w != (sim.zones[0] as ZoneState).grid.w,
			"zone 2 is a different size from zone 1")

	while sim.unlock_next_zone():
		pass
	eq(sim.next_zone_index(), -1, "with everything unlocked there is no next zone")
	eq(sim.next_zone_cost(), -1, "and no next cost")


func _round_trip(b: Balance) -> void:
	var sim: GameSim = GameSim.new_game(b)
	_place_on_dust(sim)
	for _i: int in 300:
		sim.step(Vector2.ZERO, 1.0 / 60.0)
	sim.player.pos = sim.depot_local_pos()
	sim.dump()
	sim.profile.cash = 4321
	sim.profile.crystals = 7
	sim.profile.set_level(PlayerProfile.TRACK_DEPOT, 3)
	sim.profile.tool_tier = 2

	var saved: Dictionary = sim.to_dict()
	# Mutating the live sim afterwards must not reach into the saved snapshot.
	sim.profile.cash = 999999
	eq(int((saved["profile"] as Dictionary)["cash"]), 4321, "to_dict snapshots rather than aliases")

	var restored: GameSim = GameSim.from_dict(saved, b)
	eq(restored.profile.cash, 4321, "cash survives a round trip")
	eq(restored.profile.crystals, 7, "crystals survive a round trip")
	eq(restored.profile.tool_tier, 2, "tool tier survives a round trip")
	eq(restored.profile.level_of(PlayerProfile.TRACK_DEPOT), 3, "upgrade levels survive")
	eq(restored.depot.total(), sim.depot.total(), "depot contents survive")
	approx(restored.clean_pct(), sim.clean_pct(), "the swept ground survives")
	eq(restored.zones.size(), sim.zones.size(), "every zone survives")
	eq(restored.active_zone_index, sim.active_zone_index, "the active zone survives")

	# A save from a future/unknown schema must not be half-applied.
	var bad: Dictionary = saved.duplicate(true)
	bad["schema_version"] = 999
	var fresh: GameSim = GameSim.from_dict(bad, b)
	eq(fresh.profile.cash, 0, "an unknown schema version starts a fresh game")


func _offline_without_automation(b: Balance) -> void:
	var sim: GameSim = GameSim.new_game(b)
	var res: Offline.Result = sim.apply_offline(6.0 * 3600.0)
	ok(res.is_empty(), "with no buildings, time away earns nothing")
	eq(sim.profile.cash, 0, "and no cash is credited")
