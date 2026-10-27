class_name PlayerProfile
extends RefCounted
## Everything about the player that survives a restart. Upgrade levels are
## stored, never their computed effects, so retuning balance.json immediately
## applies to existing saves instead of baking old numbers in forever.

const TRACK_CARRY: String = "carry_capacity"
const TRACK_SPEED: String = "move_speed"
const TRACK_DEPOT: String = "depot_capacity"
const TRACK_PAYOUT: String = "rocket_payout"

var cash: int = 0
var crystals: int = 0
var tool_tier: int = 0
var upgrade_levels: Dictionary = {}   ## track id -> int
var entitlements: Dictionary = {}     ## reserved for IAP; v1 never writes true
var last_seen_unix: int = 0
var contract_last_completed_date: String = ""


func level_of(track: String) -> int:
	return int(upgrade_levels.get(track, 0))


func set_level(track: String, level: int) -> void:
	upgrade_levels[track] = maxi(level, 0)


func ads_removed() -> bool:
	return bool(entitlements.get("ads_removed", false))


# --- derived stats (never stored) -----------------------------------------

func carry_capacity(balance: Balance) -> int:
	return int(round(Economy.upgrade_effect(balance.upgrade(TRACK_CARRY), level_of(TRACK_CARRY))))


func move_speed(balance: Balance) -> float:
	var mult: float = Economy.upgrade_effect(balance.upgrade(TRACK_SPEED), level_of(TRACK_SPEED))
	return balance.base_move_speed * mult


func depot_capacity(balance: Balance) -> int:
	return int(round(Economy.upgrade_effect(balance.upgrade(TRACK_DEPOT), level_of(TRACK_DEPOT))))


func payout_mult(balance: Balance) -> float:
	return Economy.upgrade_effect(balance.upgrade(TRACK_PAYOUT), level_of(TRACK_PAYOUT))


func tool(balance: Balance) -> Balance.ToolDef:
	return balance.tool_at(tool_tier)


# --- serialisation --------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"cash": cash,
		"crystals": crystals,
		"tool_tier": tool_tier,
		"upgrade_levels": upgrade_levels.duplicate(),
		"entitlements": entitlements.duplicate(),
		"last_seen_unix": last_seen_unix,
		"contract_last_completed_date": contract_last_completed_date,
	}


static func from_dict(d: Dictionary) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.cash = int(d.get("cash", 0))
	p.crystals = int(d.get("crystals", 0))
	p.tool_tier = int(d.get("tool_tier", 0))
	p.last_seen_unix = int(d.get("last_seen_unix", 0))
	p.contract_last_completed_date = String(d.get("contract_last_completed_date", ""))
	var levels: Variant = d.get("upgrade_levels", {})
	if levels is Dictionary:
		for key: Variant in (levels as Dictionary).keys():
			p.upgrade_levels[String(key)] = int((levels as Dictionary)[key])
	var ent: Variant = d.get("entitlements", {})
	if ent is Dictionary:
		p.entitlements = (ent as Dictionary).duplicate()
	return p
