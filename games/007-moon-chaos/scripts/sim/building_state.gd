class_name BuildingState
extends RefCounted
## One placed automation building. Carries no sunk-cost bookkeeping because
## refunds are 100% and buildings move for free — so there is nothing to
## depreciate and nothing to get wrong.

## Grid-space facing. Index is stored in saves, so this order is fixed.
const DIRS: Array[Vector2i] = [
	Vector2i(0, -1),  # 0 north
	Vector2i(1, 0),   # 1 east
	Vector2i(0, 1),   # 2 south
	Vector2i(-1, 0),  # 3 west
]

var uid: int = 0
var def_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var facing: int = 0
var buffer: Dictionary = {}   ## dust type index -> amount

## Fractional throughput carried between ticks. Transient and deliberately not
## persisted: at 60 fps a 30/sec conveyor earns 0.5 dust per frame, which would
## floor to zero forever without an accumulator.
var credit: float = 0.0


func buffer_total() -> int:
	return Economy.total_of(buffer)


func buffer_space(cap: int) -> int:
	return maxi(cap - buffer_total(), 0)


func dir() -> Vector2i:
	return DIRS[posmod(facing, DIRS.size())]


## The cell this building pushes into. Footprint-aware: a 2x2 collector facing
## south outputs below its whole body, not into its own second row.
func output_cell(def: Balance.BuildingDef) -> Vector2i:
	var size: Vector2i = Vector2i.ONE if def == null else def.footprint
	size.x = maxi(size.x, 1)
	size.y = maxi(size.y, 1)
	match posmod(facing, DIRS.size()):
		0: return cell + Vector2i(0, -1)
		1: return cell + Vector2i(size.x, 0)
		2: return cell + Vector2i(0, size.y)
		_: return cell + Vector2i(-1, 0)


## Cells this building draws from: directly behind for a conveyor, and the
## three non-output neighbours for a merger.
func input_cells(def: Balance.BuildingDef) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if def == null or def.inputs <= 0:
		return out
	if def.inputs == 1:
		out.append(cell - dir())
		return out
	var skip: Vector2i = dir()
	for d: Vector2i in DIRS:
		if d != skip:
			out.append(cell + d)
	return out


## Cells occupied, honouring footprint.
func occupied_cells(def: Balance.BuildingDef) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var size: Vector2i = Vector2i.ONE if def == null else def.footprint
	for y: int in maxi(size.y, 1):
		for x: int in maxi(size.x, 1):
			out.append(cell + Vector2i(x, y))
	return out


func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"def_id": def_id,
		"cx": cell.x,
		"cy": cell.y,
		"facing": facing,
		"buffer": buffer.duplicate(),
	}


static func from_dict(d: Dictionary) -> BuildingState:
	var b := BuildingState.new()
	b.uid = int(d.get("uid", 0))
	b.def_id = String(d.get("def_id", ""))
	b.cell = Vector2i(int(d.get("cx", 0)), int(d.get("cy", 0)))
	b.facing = int(d.get("facing", 0))
	var buf: Variant = d.get("buffer", {})
	if buf is Dictionary:
		for key: Variant in (buf as Dictionary).keys():
			b.buffer[int(key)] = int((buf as Dictionary)[key])
	return b
