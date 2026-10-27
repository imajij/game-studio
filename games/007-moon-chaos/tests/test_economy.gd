extends "res://tests/test_case.gd"


func suite_name() -> String:
	return "economy"


func run() -> void:
	var b: Balance = Balance.load_default()
	if not b.is_valid():
		ok(false, "balance.json invalid — " + str(b.errors))
		return

	_upgrade_curves(b)
	_dust_values(b)
	_payouts(b)
	_bag_maths()
	_profile_stats(b)


func _upgrade_curves(b: Balance) -> void:
	var carry: Balance.UpgradeDef = b.upgrade(PlayerProfile.TRACK_CARRY)
	ok(carry != null, "carry_capacity track exists")
	if carry == null:
		return

	eq(Economy.upgrade_cost(carry, 0), carry.cost_base, "level 0 costs cost_base")
	eq(Economy.upgrade_cost(carry, 1), int(round(float(carry.cost_base) * carry.cost_growth)),
			"level 1 applies growth once")
	ok(Economy.upgrade_cost(carry, 5) > Economy.upgrade_cost(carry, 4), "costs rise with level")
	eq(Economy.upgrade_cost(carry, carry.max_level), -1, "a maxed track reports -1")
	ok(Economy.is_maxed(carry, carry.max_level), "is_maxed at max_level")
	ok(not Economy.is_maxed(carry, carry.max_level - 1), "not maxed one below")

	approx(Economy.upgrade_effect(carry, 0), carry.effect_base, "level 0 gives effect_base")
	approx(Economy.upgrade_effect(carry, 3), carry.effect_base + 3.0 * carry.effect_step,
			"effect steps linearly")
	approx(Economy.upgrade_effect(carry, carry.max_level + 50),
			Economy.upgrade_effect(carry, carry.max_level),
			"effect clamps past max_level")
	eq(Economy.upgrade_cost(null, 0), -1, "a missing track costs -1 rather than crashing")


func _dust_values(b: Balance) -> void:
	var regular: int = b.dust_type_index("regular")
	var glint: int = b.dust_type_index("glint")
	ok(regular >= 0 and glint >= 0, "regular and glint dust types resolve")
	if regular < 0 or glint < 0:
		return

	approx(Economy.dust_value({regular: 100}, b), 100.0, "regular dust is worth face value")
	var glint_def: Balance.DustTypeDef = b.dust_types[glint]
	approx(Economy.dust_value({glint: 100}, b), 100.0 * glint_def.value_mult,
			"glint dust is worth its multiplier")
	approx(Economy.dust_value({}, b), 0.0, "an empty bag is worth nothing")
	# An unknown type must not silently zero the load's value.
	approx(Economy.dust_value({99: 10}, b), 10.0, "an out-of-range type falls back to 1x")


func _payouts(b: Balance) -> void:
	var regular: int = b.dust_type_index("regular")
	var capacity: int = b.rocket_base_capacity

	eq(Economy.shipment_payout({}, capacity, 1.0, 1.0, 1.0, b), 0, "an empty rocket pays nothing")

	var partial: int = Economy.shipment_payout({regular: 100}, capacity, 1.0, 1.0, 1.0, b)
	eq(partial, int(round(100.0 * b.rocket_cash_per_dust)), "a partial load pays face value")

	var doubled: int = Economy.shipment_payout({regular: 100}, capacity, 1.0, 1.0, 2.0, b)
	eq(doubled, partial * 2, "the rewarded 2x doubles the payout")

	var zone_boosted: int = Economy.shipment_payout({regular: 100}, capacity, 2.0, 1.0, 1.0, b)
	eq(zone_boosted, partial * 2, "zone multiplier scales the payout")

	# A full rocket should beat shipping the same dust in dribbles, or depot and
	# capacity upgrades would never be worth buying.
	var full: int = Economy.shipment_payout({regular: capacity}, capacity, 1.0, 1.0, 1.0, b)
	var unbonused: float = float(capacity) * b.rocket_cash_per_dust
	eq(full, int(round(unbonused * (1.0 + b.rocket_full_load_bonus))), "a full load earns the bonus")
	ok(float(full) > unbonused, "the full-load bonus is actually positive")

	var just_under: int = Economy.shipment_payout({regular: capacity - 1}, capacity, 1.0, 1.0, 1.0, b)
	ok(just_under < full, "one short of full misses the bonus")


func _bag_maths() -> void:
	eq(Economy.total_of({0: 5, 1: 7}), 12, "total_of sums a bag")
	eq(Economy.total_of({}), 0, "total_of an empty bag is 0")

	var bag: Dictionary = {0: 10, 1: 5}
	var moved: Dictionary = Economy.drain(bag, 12)
	eq(Economy.total_of(moved), 12, "drain removes exactly what was asked")
	eq(Economy.total_of(bag), 3, "the source keeps the remainder")
	eq(Economy.total_of(moved) + Economy.total_of(bag), 15, "drain conserves the total")
	ok(not bag.has(0), "a fully drained type is erased rather than left at zero")

	var over: Dictionary = Economy.drain(bag, 999)
	eq(Economy.total_of(over), 3, "draining more than held takes only what is there")
	eq(Economy.total_of(bag), 0, "the source ends empty")

	var dest: Dictionary = {1: 2}
	Economy.deposit(dest, {1: 3, 2: 4})
	eq(dest[1], 5, "deposit merges into an existing type")
	eq(dest[2], 4, "deposit adds a new type")

	eq(Economy.total_of(Economy.drain({}, 10)), 0, "draining an empty bag yields nothing")
	eq(Economy.total_of(Economy.drain({0: 5}, 0)), 0, "draining zero yields nothing")
	eq(Economy.total_of(Economy.drain({0: 5}, -3)), 0, "draining a negative yields nothing")


func _profile_stats(b: Balance) -> void:
	var p := PlayerProfile.new()
	eq(p.level_of("anything"), 0, "an unbought track reads level 0")
	eq(p.carry_capacity(b), b.base_carry_capacity, "base carry capacity matches balance")
	ok(not p.ads_removed(), "ads are not removed by default in v1")

	p.set_level(PlayerProfile.TRACK_CARRY, 2)
	ok(p.carry_capacity(b) > b.base_carry_capacity, "buying carry levels raises capacity")

	p.set_level(PlayerProfile.TRACK_SPEED, 3)
	ok(p.move_speed(b) > b.base_move_speed, "buying speed levels raises move speed")

	p.set_level(PlayerProfile.TRACK_PAYOUT, 4)
	ok(p.payout_mult(b) > 1.0, "buying payout levels raises the multiplier")

	# Only levels are persisted, so retuned numbers reach old saves.
	var restored := PlayerProfile.from_dict(p.to_dict())
	eq(restored.level_of(PlayerProfile.TRACK_CARRY), 2, "upgrade levels survive a round-trip")
	eq(restored.carry_capacity(b), p.carry_capacity(b), "derived stats rebuild from levels")
