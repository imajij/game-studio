class_name AutomationNet
extends RefCounted
## Collectors, conveyors and mergers feeding the depot.
##
## Dust must never be lost. Two rules make that structural rather than
## something to remember:
##
##  1. Every transfer is a paired drain/deposit of the SAME by-type bag, so a
##     unit cannot exist in two places or neither.
##  2. A transfer is capped by the destination's free room, so a full line
##     applies backpressure instead of dropping what it cannot take. There is
##     no "discarded because downstream was full" branch to get wrong.
##
## Buildings are processed nearest-to-depot first, so the belt closest to the
## depot empties before the one behind it pushes — dust can cross several hops
## in a single tick instead of crawling one belt per frame.

class TickResult extends RefCounted:
	var pulled_from_grid: Dictionary = {}   ## dust type index -> amount
	var delivered: Dictionary = {}          ## reached the depot this tick

	func pulled_total() -> int:
		return Economy.total_of(pulled_from_grid)

	func delivered_total() -> int:
		return Economy.total_of(delivered)


static func tick(zone: ZoneState, def: Balance.ZoneDef, depot: DepotState,
		depot_capacity: int, balance: Balance, delta: float) -> TickResult:
	var res := TickResult.new()
	if zone == null or zone.grid == null or zone.buildings.is_empty() or delta <= 0.0:
		return res

	var occupancy: Dictionary = _occupancy(zone, balance)
	var depot_cells: Dictionary = _depot_cell_set(def)
	var plan: Dictionary = _plan(zone, balance, occupancy, depot_cells)
	var order: Array = plan["order"]

	for b: BuildingState in order:
		var bdef: Balance.BuildingDef = balance.building(b.def_id)
		if bdef == null:
			continue

		# Fractional credit: at 60 fps a 30/sec conveyor earns 0.5 dust per
		# frame, which would floor to zero forever without an accumulator.
		b.credit += bdef.rate_per_sec * delta
		var budget: int = int(floor(b.credit))
		var spent: int = 0

		if budget > 0:
			spent += _push(b, bdef, budget - spent, occupancy, depot_cells,
					depot, depot_capacity, balance, res)

		# Collectors are the only source: they move dust off the grid.
		if bdef.radius_cells > 0 and budget - spent > 0:
			spent += _pull_from_grid(b, bdef, budget - spent, zone.grid, res)

		b.credit -= float(spent)
		# Blocked buildings must not bank unlimited credit, or unblocking would
		# dump a huge burst in one frame.
		b.credit = minf(b.credit, bdef.rate_per_sec)

	return res


## Steady-state dust/sec for offline earnings: limited either by how much the
## connected collectors can lift, or by how much the lines can actually hand
## to the depot, whichever is smaller.
static func throughput(zone: ZoneState, def: Balance.ZoneDef, balance: Balance) -> float:
	if zone == null or zone.buildings.is_empty():
		return 0.0
	var occupancy: Dictionary = _occupancy(zone, balance)
	var depot_cells: Dictionary = _depot_cell_set(def)
	var plan: Dictionary = _plan(zone, balance, occupancy, depot_cells)
	var connected: Dictionary = plan["connected"]

	var supply: float = 0.0
	var delivery: float = 0.0
	for b: BuildingState in zone.buildings:
		var bdef: Balance.BuildingDef = balance.building(b.def_id)
		if bdef == null or not connected.has(b.uid):
			continue
		if bdef.radius_cells > 0:
			supply += bdef.rate_per_sec
		if depot_cells.has(b.output_cell(bdef)):
			delivery += bdef.rate_per_sec
	return minf(supply, delivery)


# --- internals ------------------------------------------------------------

static func _occupancy(zone: ZoneState, balance: Balance) -> Dictionary:
	var map: Dictionary = {}
	for b: BuildingState in zone.buildings:
		var bdef: Balance.BuildingDef = balance.building(b.def_id)
		for c: Vector2i in b.occupied_cells(bdef):
			map[c] = b
	return map


static func _depot_cell_set(def: Balance.ZoneDef) -> Dictionary:
	var set: Dictionary = {}
	if def == null:
		return set
	for c: Vector2i in ZoneState.depot_cells_for(def):
		set[c] = true
	return set


## Breadth-first from the depot, following feeds upstream. Returns the
## processing order (nearest first, unconnected buildings last) and the set of
## uids that actually reach the depot.
static func _plan(zone: ZoneState, balance: Balance, occupancy: Dictionary,
		depot_cells: Dictionary) -> Dictionary:
	# Who pushes into whom: a building's feeders are whoever points at it.
	var feeders: Dictionary = {}       ## uid -> Array[BuildingState]
	var depot_feeders: Array = []
	for f: BuildingState in zone.buildings:
		var fdef: Balance.BuildingDef = balance.building(f.def_id)
		var out_cell: Vector2i = f.output_cell(fdef)
		if depot_cells.has(out_cell):
			depot_feeders.append(f)
			continue
		var target: Variant = occupancy.get(out_cell)
		if target == null:
			continue
		var t: BuildingState = target
		if t.uid == f.uid:
			continue
		var tdef: Balance.BuildingDef = balance.building(t.def_id)
		# A collector accepts nothing; it is a source only.
		if tdef == null or tdef.inputs <= 0:
			continue
		if not feeders.has(t.uid):
			feeders[t.uid] = []
		(feeders[t.uid] as Array).append(f)

	var order: Array = []
	var connected: Dictionary = {}
	var queue: Array = depot_feeders.duplicate()
	for b: BuildingState in queue:
		connected[b.uid] = true

	var head: int = 0
	while head < queue.size():
		var b: BuildingState = queue[head]
		head += 1
		order.append(b)
		for f: BuildingState in feeders.get(b.uid, []) as Array:
			if connected.has(f.uid):
				continue
			connected[f.uid] = true
			queue.append(f)

	# Orphans still run, so an unconnected collector fills its own buffer and
	# then stops rather than silently doing nothing.
	for b: BuildingState in zone.buildings:
		if not connected.has(b.uid):
			order.append(b)
	return {"order": order, "connected": connected}


static func _push(b: BuildingState, bdef: Balance.BuildingDef, budget: int,
		occupancy: Dictionary, depot_cells: Dictionary, depot: DepotState,
		depot_capacity: int, balance: Balance, res: TickResult) -> int:
	var held: int = b.buffer_total()
	if budget <= 0 or held <= 0:
		return 0
	var out_cell: Vector2i = b.output_cell(bdef)

	if depot_cells.has(out_cell):
		var room: int = depot.space(depot_capacity)
		var amount: int = mini(mini(budget, held), room)
		if amount <= 0:
			return 0
		var moved: Dictionary = Economy.drain(b.buffer, amount)
		Economy.deposit(depot.stored, moved)
		Economy.deposit(res.delivered, moved)
		return Economy.total_of(moved)

	var target: Variant = occupancy.get(out_cell)
	if target == null:
		return 0
	var t: BuildingState = target
	if t.uid == b.uid:
		return 0
	var tdef: Balance.BuildingDef = balance.building(t.def_id)
	if tdef == null or tdef.inputs <= 0:
		return 0
	var space: int = t.buffer_space(tdef.buffer)
	var send: int = mini(mini(budget, held), space)
	if send <= 0:
		return 0
	var shifted: Dictionary = Economy.drain(b.buffer, send)
	Economy.deposit(t.buffer, shifted)
	return Economy.total_of(shifted)


static func _pull_from_grid(b: BuildingState, bdef: Balance.BuildingDef, budget: int,
		grid: DustGrid, res: TickResult) -> int:
	var room: int = b.buffer_space(bdef.buffer)
	var amount: int = mini(budget, room)
	if amount <= 0:
		return 0
	var centre: Vector2i = b.cell + Vector2i(int(bdef.footprint.x / 2.0), int(bdef.footprint.y / 2.0))
	# Crystals stay a hand-sweeping reward, so automation passes no rng.
	var swept: DustGrid.SweepResult = grid.sweep(centre, bdef.radius_cells, amount)
	if swept.collected <= 0:
		return 0
	Economy.deposit(b.buffer, swept.by_type)
	Economy.deposit(res.pulled_from_grid, swept.by_type)
	return swept.collected
