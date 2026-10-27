class_name Balance
extends RefCounted
## Single source of truth for every tunable number, loaded from
## res://data/balance.json so numbers change without touching code.
##
## Validation is deliberately loud: JSON parses every number as float and a
## mistyped key silently reads as 0, which looks like a balance problem for
## hours instead of a typo. load_default() reports the offending key by name.

const PATH: String = "res://data/balance.json"
const SCHEMA_VERSION: int = 1


class ToolDef extends RefCounted:
	var id: String
	var name: String
	var radius_cells: int
	var sweep_rate: float
	var cost: int


class UpgradeDef extends RefCounted:
	var id: String
	var name: String
	var cost_base: int
	var cost_growth: float
	var effect_base: float
	var effect_step: float
	var max_level: int


class DustTypeDef extends RefCounted:
	var id: String
	var name: String
	var value_mult: float
	var color: Color


class ZoneDef extends RefCounted:
	var id: String
	var name: String
	var grid_w: int
	var grid_h: int
	var cell_size: float          ## world metres per cell
	var seed: int
	var dust_density: float
	var dust_mix: Dictionary      ## dust_type id -> weight
	var target_clean_pct: float
	var unlock_cost: int
	var payout_mult: float
	var introduces: String        ## "" | "dust_type:x" | "hazard:x" | "building:x"

	func cells() -> int:
		return grid_w * grid_h

	## World size in metres.
	func extent() -> Vector2:
		return Vector2(float(grid_w) * cell_size, float(grid_h) * cell_size)


class BuildingDef extends RefCounted:
	var id: String
	var name: String
	var cost: int
	var footprint: Vector2i
	var rate_per_sec: float
	var radius_cells: int
	var buffer: int
	var inputs: int


# --- loaded data ----------------------------------------------------------

var base_move_speed: float
var base_carry_capacity: int
var depot_base_capacity: int

var offline_rate_multiplier: float
var offline_cap_hours: float

var rocket_base_capacity: int
var rocket_auto_launch_seconds: float
var rocket_cash_per_dust: float
var rocket_full_load_bonus: float
var rocket_launch_seconds: float

var crystal_find_chance_per_cell: float
var crystal_rewarded_grant: int

var contract_duration_seconds: float
var contract_target_clean_pct: float
var contract_reward_crystals: int

var rewarded_shipment_multiplier: float
var rewarded_speed_boost_mult: float
var rewarded_speed_boost_seconds: float

var tools: Array = []            ## of ToolDef, ordered by tier
var dust_types: Array = []        ## of DustTypeDef, index == stored type byte
var zones: Array = []             ## of ZoneDef, ordered by unlock order
var upgrades: Dictionary = {}     ## track id -> UpgradeDef
var buildings: Dictionary = {}    ## building id -> BuildingDef

var errors: PackedStringArray = []


static func load_default() -> Balance:
	return load_from(PATH)


static func load_from(path: String) -> Balance:
	var b := Balance.new()
	if not FileAccess.file_exists(path):
		b.errors.append("balance file missing: %s" % path)
		push_error("Balance: %s" % b.errors[0])
		return b
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		b.errors.append("balance file is not a JSON object: %s" % path)
		push_error("Balance: %s" % b.errors[0])
		return b
	b._parse(parsed as Dictionary)
	for e: String in b.errors:
		push_error("Balance: %s" % e)
	return b


func is_valid() -> bool:
	return errors.is_empty()


func tool_at(tier: int) -> ToolDef:
	var t: int = clampi(tier, 0, tools.size() - 1)
	return tools[t]


func max_tool_tier() -> int:
	return tools.size() - 1


func zone_def(id: String) -> ZoneDef:
	for z: ZoneDef in zones:
		if z.id == id:
			return z
	return null


func zone_index(id: String) -> int:
	for i: int in zones.size():
		if (zones[i] as ZoneDef).id == id:
			return i
	return -1


func dust_type_index(id: String) -> int:
	for i: int in dust_types.size():
		if (dust_types[i] as DustTypeDef).id == id:
			return i
	return -1


func upgrade(track: String) -> UpgradeDef:
	return upgrades.get(track, null)


func building(id: String) -> BuildingDef:
	return buildings.get(id, null)


# --- parsing --------------------------------------------------------------

func _parse(d: Dictionary) -> void:
	var version: int = _int(d, "schema_version", "root")
	if version != SCHEMA_VERSION:
		errors.append("schema_version is %d, expected %d" % [version, SCHEMA_VERSION])

	var player: Dictionary = _dict(d, "player", "root")
	base_move_speed = _float(player, "base_move_speed", "player")
	base_carry_capacity = _int(player, "base_carry_capacity", "player")

	depot_base_capacity = _int(_dict(d, "depot", "root"), "base_capacity", "depot")

	var off: Dictionary = _dict(d, "offline", "root")
	offline_rate_multiplier = _float(off, "rate_multiplier", "offline")
	offline_cap_hours = _float(off, "cap_hours", "offline")

	var rocket: Dictionary = _dict(d, "rocket", "root")
	rocket_base_capacity = _int(rocket, "base_capacity", "rocket")
	rocket_auto_launch_seconds = _float(rocket, "auto_launch_seconds", "rocket")
	rocket_cash_per_dust = _float(rocket, "cash_per_dust", "rocket")
	rocket_full_load_bonus = _float(rocket, "full_load_bonus", "rocket")
	rocket_launch_seconds = _float(rocket, "launch_seconds", "rocket")

	var crystals: Dictionary = _dict(d, "crystals", "root")
	crystal_find_chance_per_cell = _float(crystals, "find_chance_per_cell", "crystals")
	crystal_rewarded_grant = _int(crystals, "rewarded_grant", "crystals")

	var contract: Dictionary = _dict(d, "contract", "root")
	contract_duration_seconds = _float(contract, "duration_seconds", "contract")
	contract_target_clean_pct = _float(contract, "target_clean_pct", "contract")
	contract_reward_crystals = _int(contract, "reward_crystals", "contract")

	var rew: Dictionary = _dict(d, "rewarded", "root")
	rewarded_shipment_multiplier = _float(rew, "shipment_multiplier", "rewarded")
	rewarded_speed_boost_mult = _float(rew, "speed_boost_mult", "rewarded")
	rewarded_speed_boost_seconds = _float(rew, "speed_boost_seconds", "rewarded")

	_parse_tools(_array(d, "tools", "root"))
	_parse_dust_types(_array(d, "dust_types", "root"))
	_parse_zones(_array(d, "zones", "root"))
	_parse_upgrades(_dict(d, "upgrades", "root"))
	_parse_buildings(_array(d, "buildings", "root"))


func _parse_tools(arr: Array) -> void:
	for i: int in arr.size():
		if not arr[i] is Dictionary:
			errors.append("tools[%d] is not an object" % i)
			continue
		var src: Dictionary = arr[i]
		var ctx := "tools[%d]" % i
		var t := ToolDef.new()
		t.id = _str(src, "id", ctx)
		t.name = _str(src, "name", ctx)
		t.radius_cells = _int(src, "radius_cells", ctx)
		t.sweep_rate = _float(src, "sweep_rate", ctx)
		t.cost = _int(src, "cost", ctx)
		tools.append(t)
	if tools.is_empty():
		errors.append("tools list is empty")


func _parse_dust_types(arr: Array) -> void:
	for i: int in arr.size():
		if not arr[i] is Dictionary:
			errors.append("dust_types[%d] is not an object" % i)
			continue
		var src: Dictionary = arr[i]
		var ctx := "dust_types[%d]" % i
		var t := DustTypeDef.new()
		t.id = _str(src, "id", ctx)
		t.name = _str(src, "name", ctx)
		t.value_mult = _float(src, "value_mult", ctx)
		t.color = Color(_str(src, "color", ctx))
		dust_types.append(t)
	if dust_types.is_empty():
		errors.append("dust_types list is empty")


func _parse_zones(arr: Array) -> void:
	for i: int in arr.size():
		if not arr[i] is Dictionary:
			errors.append("zones[%d] is not an object" % i)
			continue
		var src: Dictionary = arr[i]
		var ctx := "zones[%d]" % i
		var z := ZoneDef.new()
		z.id = _str(src, "id", ctx)
		z.name = _str(src, "name", ctx)
		var grid: Array = _array(src, "grid", ctx)
		if grid.size() == 2:
			z.grid_w = int(grid[0])
			z.grid_h = int(grid[1])
		else:
			errors.append("%s.grid must be [w, h]" % ctx)
		z.cell_size = _float(src, "cell_size", ctx)
		z.seed = _int(src, "seed", ctx)
		z.dust_density = _float(src, "dust_density", ctx)
		z.dust_mix = _dict(src, "dust_mix", ctx)
		z.target_clean_pct = _float(src, "target_clean_pct", ctx)
		z.unlock_cost = _int(src, "unlock_cost", ctx)
		z.payout_mult = _float(src, "payout_mult", ctx)
		z.introduces = String(src.get("introduces", ""))
		if z.grid_w <= 0 or z.grid_h <= 0:
			errors.append("%s.grid must be positive" % ctx)
		if z.cell_size <= 0.0:
			errors.append("%s.cell_size must be positive" % ctx)
		zones.append(z)
	if zones.is_empty():
		errors.append("zones list is empty")


func _parse_upgrades(d: Dictionary) -> void:
	for track: String in d.keys():
		if not d[track] is Dictionary:
			errors.append("upgrades.%s is not an object" % track)
			continue
		var src: Dictionary = d[track]
		var ctx := "upgrades.%s" % track
		var u := UpgradeDef.new()
		u.id = track
		u.name = _str(src, "name", ctx)
		u.cost_base = _int(src, "cost_base", ctx)
		u.cost_growth = _float(src, "cost_growth", ctx)
		u.effect_base = _float(src, "effect_base", ctx)
		u.effect_step = _float(src, "effect_step", ctx)
		u.max_level = _int(src, "max_level", ctx)
		if u.cost_growth <= 1.0:
			errors.append("%s.cost_growth must be > 1.0 or upgrades never get harder" % ctx)
		upgrades[track] = u
	if upgrades.is_empty():
		errors.append("upgrades table is empty")


func _parse_buildings(arr: Array) -> void:
	for i: int in arr.size():
		if not arr[i] is Dictionary:
			errors.append("buildings[%d] is not an object" % i)
			continue
		var src: Dictionary = arr[i]
		var ctx := "buildings[%d]" % i
		var b := BuildingDef.new()
		b.id = _str(src, "id", ctx)
		b.name = _str(src, "name", ctx)
		b.cost = _int(src, "cost", ctx)
		var fp: Array = _array(src, "footprint", ctx)
		if fp.size() == 2:
			b.footprint = Vector2i(int(fp[0]), int(fp[1]))
		else:
			errors.append("%s.footprint must be [w, h]" % ctx)
		b.rate_per_sec = _float(src, "rate_per_sec", ctx)
		b.radius_cells = _int(src, "radius_cells", ctx)
		b.buffer = _int(src, "buffer", ctx)
		b.inputs = _int(src, "inputs", ctx)
		buildings[b.id] = b
	if buildings.is_empty():
		errors.append("buildings list is empty")


# --- typed readers (JSON gives every number as float) ---------------------

func _float(d: Dictionary, key: String, ctx: String) -> float:
	if not d.has(key):
		errors.append("%s.%s is missing" % [ctx, key])
		return 0.0
	return float(d[key])


func _int(d: Dictionary, key: String, ctx: String) -> int:
	if not d.has(key):
		errors.append("%s.%s is missing" % [ctx, key])
		return 0
	return int(d[key])


func _str(d: Dictionary, key: String, ctx: String) -> String:
	if not d.has(key):
		errors.append("%s.%s is missing" % [ctx, key])
		return ""
	return String(d[key])


func _dict(d: Dictionary, key: String, ctx: String) -> Dictionary:
	if not d.has(key) or not d[key] is Dictionary:
		errors.append("%s.%s is missing or not an object" % [ctx, key])
		return {}
	return d[key]


func _array(d: Dictionary, key: String, ctx: String) -> Array:
	if not d.has(key) or not d[key] is Array:
		errors.append("%s.%s is missing or not an array" % [ctx, key])
		return []
	return d[key]
