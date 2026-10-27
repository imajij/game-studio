class_name Economy
extends RefCounted
## Pure economy maths. Every function here is static and side-effect free so
## the balance can be unit-tested headlessly without booting a scene.

## Cost of buying the NEXT level when you currently hold `level`.
static func upgrade_cost(def: Balance.UpgradeDef, level: int) -> int:
	if def == null or level >= def.max_level:
		return -1  # sold out
	return int(round(float(def.cost_base) * pow(def.cost_growth, float(level))))


## Effect value at `level` (level 0 == effect_base, i.e. unupgraded).
static func upgrade_effect(def: Balance.UpgradeDef, level: int) -> float:
	if def == null:
		return 0.0
	var l: int = clampi(level, 0, def.max_level)
	return def.effect_base + def.effect_step * float(l)


static func is_maxed(def: Balance.UpgradeDef, level: int) -> bool:
	return def != null and level >= def.max_level


## Raw dust value, weighted by each dust type's multiplier.
static func dust_value(by_type: Dictionary, balance: Balance) -> float:
	var total: float = 0.0
	for key: Variant in by_type.keys():
		var idx: int = int(key)
		var amount: float = float(by_type[key])
		var mult: float = 1.0
		if idx >= 0 and idx < balance.dust_types.size():
			mult = (balance.dust_types[idx] as Balance.DustTypeDef).value_mult
		total += amount * mult
	return total


## Cash for one rocket load. `ad_mult` is 1.0 normally, or the rewarded 2x.
static func shipment_payout(by_type: Dictionary, capacity: int, zone_mult: float,
		payout_upgrade_mult: float, ad_mult: float, balance: Balance) -> int:
	var payload: int = total_of(by_type)
	if payload <= 0:
		return 0
	var cash: float = dust_value(by_type, balance) * balance.rocket_cash_per_dust
	cash *= maxf(zone_mult, 0.0)
	cash *= maxf(payout_upgrade_mult, 0.0)
	# Rewarding a full rocket is what makes depot/capacity upgrades feel worth
	# buying, rather than just shipping early and often.
	if capacity > 0 and payload >= capacity:
		cash *= 1.0 + balance.rocket_full_load_bonus
	cash *= maxf(ad_mult, 0.0)
	return int(round(cash))


static func total_of(by_type: Dictionary) -> int:
	var sum: int = 0
	for key: Variant in by_type.keys():
		sum += int(by_type[key])
	return sum


## Move `amount` out of a by-type bag, draining types in index order.
## Returns what was actually removed; the bag is mutated in place.
## Paired with deposit() this is what keeps dust conserved end to end.
static func drain(bag: Dictionary, amount: int) -> Dictionary:
	var out: Dictionary = {}
	var left: int = amount
	if left <= 0:
		return out
	var keys: Array = bag.keys()
	keys.sort()
	for key: Variant in keys:
		if left <= 0:
			break
		var have: int = int(bag[key])
		if have <= 0:
			continue
		var take: int = mini(have, left)
		bag[key] = have - take
		if bag[key] == 0:
			bag.erase(key)
		out[key] = int(out.get(key, 0)) + take
		left -= take
	return out


## Add a by-type bag into another, in place.
static func deposit(bag: Dictionary, add: Dictionary) -> void:
	for key: Variant in add.keys():
		bag[key] = int(bag.get(key, 0)) + int(add[key])
