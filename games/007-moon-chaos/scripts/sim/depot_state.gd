class_name DepotState
extends RefCounted
## The dust stockpile the rocket loads from. One depot across the whole run,
## physically placed in whichever zone is active.

var stored: Dictionary = {}   ## dust type index -> amount


func total() -> int:
	return Economy.total_of(stored)


func space(capacity: int) -> int:
	return maxi(capacity - total(), 0)


func is_full(capacity: int) -> bool:
	return total() >= capacity


## Accept as much of `bag` as fits. Returns what did NOT fit, so the caller
## keeps holding the remainder rather than it vanishing.
func accept(bag: Dictionary, capacity: int) -> Dictionary:
	var room: int = space(capacity)
	var incoming: int = Economy.total_of(bag)
	if room <= 0 or incoming <= 0:
		return bag.duplicate()
	if incoming <= room:
		Economy.deposit(stored, bag)
		return {}
	var working: Dictionary = bag.duplicate()
	var moved: Dictionary = Economy.drain(working, room)
	Economy.deposit(stored, moved)
	return working


## Move up to `amount` out of the depot (into the rocket).
func withdraw(amount: int) -> Dictionary:
	return Economy.drain(stored, amount)


func to_dict() -> Dictionary:
	return {"stored": stored.duplicate()}


static func from_dict(d: Dictionary) -> DepotState:
	var s := DepotState.new()
	var stored_raw: Variant = d.get("stored", {})
	if stored_raw is Dictionary:
		for key: Variant in (stored_raw as Dictionary).keys():
			s.stored[int(key)] = int((stored_raw as Dictionary)[key])
	return s
