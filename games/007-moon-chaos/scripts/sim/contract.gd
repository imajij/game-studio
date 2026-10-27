class_name Contract
extends RefCounted
## The daily contract: one seeded zone, one target clean %, one time limit,
## identical for every player on a given UTC date.
##
## The seed is a hand-rolled FNV-1a rather than String.hash(), because "same
## for everyone" is a correctness requirement and the engine's hash carries no
## cross-version stability guarantee.

const FNV_OFFSET: int = 0x811c9dc5
const FNV_PRIME: int = 0x01000193
const MASK32: int = 0xFFFFFFFF


class Def extends RefCounted:
	var date: String = ""
	var zone_def_id: String = ""
	var seed: int = 0
	var target_clean_pct: float = 0.0
	var duration_seconds: float = 0.0
	var reward_crystals: int = 0


## Stable 32-bit FNV-1a over the date's UTF-8 bytes.
static func seed_for_date(utc_date: String) -> int:
	var hash_value: int = FNV_OFFSET
	for byte: int in utc_date.to_utf8_buffer():
		hash_value = (hash_value ^ byte) & MASK32
		hash_value = (hash_value * FNV_PRIME) & MASK32
	return hash_value


## Today's date in UTC as YYYY-MM-DD. Kept separate from generate() so tests
## can pass a fixed date.
static func today_utc() -> String:
	var d: Dictionary = Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


## Deterministic from the date alone — never from player progress, or the
## contract would differ per player and the leaderboard would be meaningless.
static func generate(utc_date: String, balance: Balance) -> Def:
	var def := Def.new()
	def.date = utc_date
	def.seed = seed_for_date(utc_date)
	def.target_clean_pct = balance.contract_target_clean_pct
	def.duration_seconds = balance.contract_duration_seconds
	def.reward_crystals = balance.contract_reward_crystals
	if not balance.zones.is_empty():
		var idx: int = def.seed % balance.zones.size()
		def.zone_def_id = (balance.zones[idx] as Balance.ZoneDef).id
	return def


## A contract zone is generated from the contract seed, not the zone's own, so
## the layout is fresh each day while staying identical across players.
static func build_grid(def: Def, balance: Balance) -> DustGrid:
	var base: Balance.ZoneDef = balance.zone_def(def.zone_def_id)
	if base == null:
		return DustGrid.create(0, 0)
	var shaped := Balance.ZoneDef.new()
	shaped.id = base.id
	shaped.name = base.name
	shaped.grid_w = base.grid_w
	shaped.grid_h = base.grid_h
	shaped.cell_size = base.cell_size
	shaped.seed = def.seed
	shaped.dust_density = base.dust_density
	shaped.dust_mix = base.dust_mix
	shaped.target_clean_pct = def.target_clean_pct
	shaped.unlock_cost = 0
	shaped.payout_mult = base.payout_mult
	shaped.introduces = ""
	return DustGrid.generate(shaped, balance)
