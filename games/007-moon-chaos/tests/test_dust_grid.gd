extends "res://tests/test_case.gd"


func suite_name() -> String:
	return "dust_grid"


func run() -> void:
	var b: Balance = Balance.load_default()
	ok(b.is_valid(), "balance.json loads clean — " + str(b.errors))
	if not b.is_valid() or b.zones.is_empty():
		return

	var def: Balance.ZoneDef = b.zones[0]

	_determinism(def, b)
	_clean_pct(def, b)
	_sweep_conservation(def, b)
	_full_clean(def, b)
	_rescatter(def, b)
	_round_trip(def, b)


func _determinism(def: Balance.ZoneDef, b: Balance) -> void:
	var a := DustGrid.generate(def, b)
	var c := DustGrid.generate(def, b)
	eq(a.initial_total(), c.initial_total(), "same seed gives same total dust")
	ok(a.initial_total() > 0, "zone 1 actually has dust on it")

	var identical: bool = true
	for y: int in def.grid_h:
		for x: int in def.grid_w:
			var p := Vector2i(x, y)
			if a.dust_at(p) != c.dust_at(p) or a.type_at(p) != c.type_at(p):
				identical = false
				break
	ok(identical, "same seed gives cell-for-cell identical grids")


func _clean_pct(def: Balance.ZoneDef, b: Balance) -> void:
	var g := DustGrid.generate(def, b)
	approx(g.clean_pct(), 0.0, "a fresh grid is 0% clean")
	ok(not g.is_complete(def.target_clean_pct), "a fresh grid is not complete")

	var empty := DustGrid.create(4, 4)
	approx(empty.clean_pct(), 100.0, "a grid with no dust reads as 100% clean")
	ok(empty.is_complete(100.0), "an empty grid counts as complete")


func _sweep_conservation(def: Balance.ZoneDef, b: Balance) -> void:
	var g := DustGrid.generate(def, b)
	var initial: int = g.initial_total()
	var collected: int = 0
	var never_over_budget: bool = true

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i: int in 2000:
		var budget: int = rng.randi_range(0, 30)
		var c := Vector2i(rng.randi_range(0, def.grid_w - 1), rng.randi_range(0, def.grid_h - 1))
		var res: DustGrid.SweepResult = g.sweep(c, 2, budget)
		if res.collected > budget:
			never_over_budget = false
		collected += res.collected
		# by_type must always account for exactly what was collected.
		if Economy.total_of(res.by_type) != res.collected:
			never_over_budget = false

	ok(never_over_budget, "sweep never exceeds its budget and by_type always balances")
	eq(g.remaining() + collected, initial, "dust is conserved across 2000 sweeps")
	eq(g.collected_total(), collected, "collected_total tracks what sweeping removed")


func _full_clean(def: Balance.ZoneDef, b: Balance) -> void:
	var g := DustGrid.generate(def, b)
	# Big budget, every cell: should end bare.
	for y: int in def.grid_h:
		for x: int in def.grid_w:
			g.sweep(Vector2i(x, y), 1, 100000)
	eq(g.remaining(), 0, "sweeping every cell clears the zone")
	approx(g.clean_pct(), 100.0, "a cleared zone reads as 100% clean")
	ok(g.is_complete(def.target_clean_pct), "a cleared zone satisfies its target")

	var after: DustGrid.SweepResult = g.sweep(Vector2i(0, 0), 3, 500)
	eq(after.collected, 0, "sweeping bare ground collects nothing")
	ok(not after.had_change, "sweeping bare ground reports no dirty rect")


func _rescatter(def: Balance.ZoneDef, b: Balance) -> void:
	var g := DustGrid.generate(def, b)
	for y: int in def.grid_h:
		for x: int in def.grid_w:
			g.sweep(Vector2i(x, y), 1, 100000)

	var put: int = g.add_dust(Vector2i(1, 1), 50)
	eq(put, 50, "re-scattered dust lands on the cell")
	eq(g.remaining(), 50, "re-scattered dust counts as remaining again")
	ok(g.clean_pct() < 100.0, "re-scattering drops clean% back below 100")

	# The hazard must never let clean% run past 100 by re-counting the same
	# dust twice, so the initial total grows alongside it.
	var topped: int = g.add_dust(Vector2i(1, 1), 10000)
	eq(g.dust_at(Vector2i(1, 1)), DustGrid.MAX_DUST, "a cell caps at MAX_DUST")
	ok(topped < 10000, "add_dust reports only what actually fit")
	ok(g.clean_pct() >= 0.0 and g.clean_pct() <= 100.0, "clean% stays inside 0..100")


func _round_trip(def: Balance.ZoneDef, b: Balance) -> void:
	var g := DustGrid.generate(def, b)
	g.sweep(Vector2i(5, 5), 3, 400)
	var restored := DustGrid.from_dict(g.to_dict())

	eq(restored.w, g.w, "round-trip keeps width")
	eq(restored.h, g.h, "round-trip keeps height")
	eq(restored.remaining(), g.remaining(), "round-trip keeps remaining dust")
	eq(restored.initial_total(), g.initial_total(), "round-trip keeps the initial total")
	approx(restored.clean_pct(), g.clean_pct(), "round-trip keeps clean%")

	var identical: bool = true
	for y: int in g.h:
		for x: int in g.w:
			var p := Vector2i(x, y)
			if restored.dust_at(p) != g.dust_at(p) or restored.type_at(p) != g.type_at(p):
				identical = false
				break
	ok(identical, "round-trip is cell-for-cell exact")
