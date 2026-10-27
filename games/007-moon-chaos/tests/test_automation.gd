extends "res://tests/test_case.gd"
## The load-bearing suite: conveyors must never lose dust. Everything else in
## automation is tuning, but a leak here silently eats the player's progress.


func suite_name() -> String:
	return "automation"


func run() -> void:
	var b: Balance = Balance.load_default()
	if not b.is_valid():
		ok(false, "balance.json invalid — " + str(b.errors))
		return
	var def: Balance.ZoneDef = b.zone_def("mining_shelf")
	ok(def != null, "mining_shelf zone exists")
	if def == null:
		return

	_conservation(def, b)
	_backpressure(def, b)
	_throughput(def, b)
	_disconnected(def, b)
	_refund_returns_buffer(def, b)


## Build collector -> conveyor -> conveyor -> depot, laid out relative to the
## depot pad so it keeps working if the zone is resized in balance.json.
func _build_chain(def: Balance.ZoneDef, b: Balance) -> ZoneState:
	var z: ZoneState = ZoneState.fresh(def, b, true)
	var dcell: Vector2i = ZoneState.depot_cell_for(def)
	var col_x: int = dcell.x - 1
	var depot_top: int = dcell.y - 1

	z.add_building("collector", Vector2i(col_x, depot_top - 4), 2)
	z.add_building("conveyor", Vector2i(col_x, depot_top - 2), 2)
	z.add_building("conveyor", Vector2i(col_x, depot_top - 1), 2)
	return z


func _buffers_total(z: ZoneState) -> int:
	var sum: int = 0
	for building: BuildingState in z.buildings:
		sum += building.buffer_total()
	return sum


func _conservation(def: Balance.ZoneDef, b: Balance) -> void:
	var z: ZoneState = _build_chain(def, b)
	var depot := DepotState.new()
	var capacity: int = 1_000_000_000   # effectively unlimited for this test

	# Verify the chain is wired before trusting what it moves.
	var collector: BuildingState = z.buildings[0]
	var last: BuildingState = z.buildings[2]
	var depot_cells: Array[Vector2i] = ZoneState.depot_cells_for(def)
	ok(depot_cells.has(last.output_cell(b.building("conveyor"))),
			"the last conveyor points into the depot pad")
	ok(not depot_cells.has(collector.output_cell(b.building("collector"))),
			"the collector feeds the belt, not the depot directly")

	var initial: int = z.grid.initial_total()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var delivered_reported: int = 0
	var pulled_reported: int = 0

	for _i: int in 4000:
		var delta: float = rng.randf_range(1.0 / 120.0, 1.0 / 30.0)
		var res: AutomationNet.TickResult = AutomationNet.tick(z, def, depot, capacity, b, delta)
		delivered_reported += res.delivered_total()
		pulled_reported += res.pulled_total()

	var removed_from_grid: int = initial - z.grid.remaining()
	var held_in_system: int = depot.total() + _buffers_total(z)

	ok(removed_from_grid > 0, "the collector actually lifted dust off the grid")
	eq(removed_from_grid, held_in_system,
			"every unit off the grid is in the depot or a buffer — nothing lost")
	eq(pulled_reported, removed_from_grid, "reported pulls match what left the grid")
	eq(delivered_reported, depot.total(), "reported deliveries match the depot contents")
	ok(depot.total() > 0, "dust reached the depot across the belt")


func _backpressure(def: Balance.ZoneDef, b: Balance) -> void:
	var z: ZoneState = _build_chain(def, b)
	var depot := DepotState.new()
	var capacity: int = 10   # fills almost immediately

	var initial: int = z.grid.initial_total()
	for _i: int in 3000:
		AutomationNet.tick(z, def, depot, capacity, b, 1.0 / 60.0)

	var removed: int = initial - z.grid.remaining()
	eq(depot.total(), capacity, "the depot fills to exactly its capacity and stops")
	eq(removed, depot.total() + _buffers_total(z),
			"a jammed line holds its dust instead of dropping it")

	# Buffers must respect their own caps too, not grow without bound.
	var within_caps: bool = true
	for building: BuildingState in z.buildings:
		var bdef: Balance.BuildingDef = b.building(building.def_id)
		if building.buffer_total() > bdef.buffer:
			within_caps = false
	ok(within_caps, "no buffer exceeds its configured size")

	# And once everything is jammed, the grid stops being drained.
	var before: int = z.grid.remaining()
	for _i: int in 600:
		AutomationNet.tick(z, def, depot, capacity, b, 1.0 / 60.0)
	eq(z.grid.remaining(), before, "a fully jammed network stops pulling from the grid")


func _throughput(def: Balance.ZoneDef, b: Balance) -> void:
	var z: ZoneState = _build_chain(def, b)
	var collector_rate: float = b.building("collector").rate_per_sec
	var conveyor_rate: float = b.building("conveyor").rate_per_sec

	approx(AutomationNet.throughput(z, def, b), minf(collector_rate, conveyor_rate),
			"throughput is the smaller of supply and delivery")

	var bare := ZoneState.fresh(def, b, true)
	approx(AutomationNet.throughput(bare, def, b), 0.0, "a zone with no buildings has no throughput")

	# A belt with nothing feeding it delivers nothing.
	var beltless := ZoneState.fresh(def, b, true)
	var dcell: Vector2i = ZoneState.depot_cell_for(def)
	beltless.add_building("conveyor", Vector2i(dcell.x - 1, dcell.y - 1), 2)
	approx(AutomationNet.throughput(beltless, def, b), 0.0,
			"a conveyor with no collector behind it supplies nothing")


func _disconnected(def: Balance.ZoneDef, b: Balance) -> void:
	var z: ZoneState = ZoneState.fresh(def, b, true)
	# Far from the depot and pointing at bare ground.
	z.add_building("collector", Vector2i(2, 2), 0)
	var depot := DepotState.new()
	var cdef: Balance.BuildingDef = b.building("collector")

	approx(AutomationNet.throughput(z, def, b), 0.0, "an unconnected collector has no throughput")

	var initial: int = z.grid.initial_total()
	for _i: int in 3000:
		AutomationNet.tick(z, def, depot, 1_000_000, b, 1.0 / 60.0)

	var removed: int = initial - z.grid.remaining()
	eq(depot.total(), 0, "an unconnected collector delivers nothing to the depot")
	eq(removed, _buffers_total(z), "what it lifted is all still in its own buffer")
	eq((z.buildings[0] as BuildingState).buffer_total(), cdef.buffer,
			"it fills its buffer and then stops")


func _refund_returns_buffer(def: Balance.ZoneDef, b: Balance) -> void:
	var z: ZoneState = _build_chain(def, b)
	var depot := DepotState.new()
	for _i: int in 200:
		AutomationNet.tick(z, def, depot, 1_000_000, b, 1.0 / 60.0)

	var before_total: int = depot.total() + _buffers_total(z)
	var target: BuildingState = z.buildings[1]
	var held: int = target.buffer_total()
	var returned: Dictionary = z.remove_building(target.uid)

	eq(Economy.total_of(returned), held, "refunding a building hands back what it held")
	eq(depot.total() + _buffers_total(z) + Economy.total_of(returned), before_total,
			"removing a building conserves dust")
	eq(z.buildings.size(), 2, "the building is gone from the zone")
	eq(Economy.total_of(z.remove_building(99999)), 0, "removing a missing uid is a no-op")
