class_name PlayerState
extends RefCounted
## The player's in-zone, transient state.
##
## Position is a Vector2 in grid-plane metres measured from the zone's corner,
## not a Vector3: the moon surface is flat, so keeping the sim planar keeps the
## maths and the tests simple. The view maps it to Vector3(x, 0, y).

var pos: Vector2 = Vector2.ZERO
var carrying: Dictionary = {}          ## dust type index -> amount
var speed_boost_until: float = 0.0     ## sim clock seconds; 0 == no boost


func carry_total() -> int:
	return Economy.total_of(carrying)


func carry_space(capacity: int) -> int:
	return maxi(capacity - carry_total(), 0)


func is_full(capacity: int) -> bool:
	return carry_total() >= capacity


func has_speed_boost(sim_time: float) -> bool:
	return sim_time < speed_boost_until


## Hand the whole load over (to the depot) and come back empty.
func take_all() -> Dictionary:
	var out: Dictionary = carrying.duplicate()
	carrying.clear()
	return out


func to_dict() -> Dictionary:
	return {
		"pos_x": pos.x,
		"pos_y": pos.y,
		"carrying": carrying.duplicate(),
	}


static func from_dict(d: Dictionary) -> PlayerState:
	var p := PlayerState.new()
	p.pos = Vector2(float(d.get("pos_x", 0.0)), float(d.get("pos_y", 0.0)))
	var c: Variant = d.get("carrying", {})
	if c is Dictionary:
		for key: Variant in (c as Dictionary).keys():
			p.carrying[int(key)] = int((c as Dictionary)[key])
	return p
