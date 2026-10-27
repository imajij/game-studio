extends "res://tests/test_case.gd"
## The daily contract has to be identical for every player on a given date, so
## determinism is the whole point of this suite.


func suite_name() -> String:
	return "contract"


func run() -> void:
	var b: Balance = Balance.load_default()
	if not b.is_valid():
		ok(false, "balance.json invalid — " + str(b.errors))
		return

	_seed_stability()
	_generation(b)
	_grid_determinism(b)


func _seed_stability() -> void:
	eq(Contract.seed_for_date("2026-10-27"), Contract.seed_for_date("2026-10-27"),
			"the same date always seeds the same")

	var a: int = Contract.seed_for_date("2026-10-27")
	var c: int = Contract.seed_for_date("2026-10-28")
	ok(a != c, "consecutive dates seed differently")

	# Spot-check a run of dates for collisions; a clash would hand two days the
	# same contract.
	var seen: Dictionary = {}
	var collisions: int = 0
	for day: int in range(1, 29):
		var date: String = "2026-03-%02d" % day
		var s: int = Contract.seed_for_date(date)
		if seen.has(s):
			collisions += 1
		seen[s] = true
		if s < 0 or s > 0xFFFFFFFF:
			ok(false, "seed for " + date + " escaped 32 bits")
	eq(collisions, 0, "28 consecutive dates produce 28 distinct seeds")

	eq(Contract.seed_for_date(""), Contract.FNV_OFFSET, "an empty date gives the FNV offset basis")

	var today: String = Contract.today_utc()
	eq(today.length(), 10, "today_utc is YYYY-MM-DD")
	eq(today.count("-"), 2, "today_utc is hyphen separated")


func _generation(b: Balance) -> void:
	var def: Contract.Def = Contract.generate("2026-10-27", b)
	eq(def.date, "2026-10-27", "the contract records its date")
	ok(not def.zone_def_id.is_empty(), "the contract picks a zone")
	ok(b.zone_def(def.zone_def_id) != null, "the chosen zone exists in balance")
	approx(def.target_clean_pct, b.contract_target_clean_pct, "target comes from balance")
	approx(def.duration_seconds, b.contract_duration_seconds, "duration comes from balance")
	eq(def.reward_crystals, b.contract_reward_crystals, "reward comes from balance")

	var again: Contract.Def = Contract.generate("2026-10-27", b)
	eq(again.zone_def_id, def.zone_def_id, "the same date picks the same zone")
	eq(again.seed, def.seed, "the same date gives the same seed")

	# Across a month the contract should not sit on one zone forever.
	var zones_seen: Dictionary = {}
	for day: int in range(1, 29):
		var d: Contract.Def = Contract.generate("2026-05-%02d" % day, b)
		zones_seen[d.zone_def_id] = true
	ok(zones_seen.size() > 1, "the contract zone varies across a month")


func _grid_determinism(b: Balance) -> void:
	var def: Contract.Def = Contract.generate("2026-10-27", b)
	var g1: DustGrid = Contract.build_grid(def, b)
	var g2: DustGrid = Contract.build_grid(def, b)

	ok(g1.initial_total() > 0, "the contract grid has dust")
	eq(g1.initial_total(), g2.initial_total(), "the contract grid is deterministic")

	var identical: bool = true
	for y: int in g1.h:
		for x: int in g1.w:
			if g1.dust_at(Vector2i(x, y)) != g2.dust_at(Vector2i(x, y)):
				identical = false
				break
	ok(identical, "the contract grid is cell-for-cell reproducible")

	# The contract reshuffles the zone rather than replaying its stock layout.
	var base: Balance.ZoneDef = b.zone_def(def.zone_def_id)
	var stock: DustGrid = DustGrid.generate(base, b)
	eq(g1.w, stock.w, "the contract keeps the zone's dimensions")
	ok(g1.initial_total() != stock.initial_total(),
			"the contract layout differs from the zone's stock layout")

	var missing: Contract.Def = Contract.Def.new()
	missing.zone_def_id = "no_such_zone"
	eq(Contract.build_grid(missing, b).cells(), 0, "an unknown zone yields an empty grid")
