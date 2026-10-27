class_name ZoneState
extends RefCounted
## Runtime state for one zone. Only def_id is stored, never a copy of the
## zone's numbers, so retuning balance.json never invalidates a save.

var def_id: String = ""
var unlocked: bool = false
var completed: bool = false
var grid: DustGrid = null
var buildings: Array = []      ## of BuildingState
var next_building_uid: int = 1


static func fresh(def: Balance.ZoneDef, balance: Balance, unlocked_now: bool) -> ZoneState:
	var z := ZoneState.new()
	z.def_id = def.id
	z.unlocked = unlocked_now
	z.grid = DustGrid.generate(def, balance)
	return z


## Footprint of the depot pad, in cells.
const DEPOT_SIZE: Vector2i = Vector2i(3, 3)

## Where the depot and rocket sit: bottom-centre of the zone, so the player
## always carries dust "downhill" towards a fixed, learnable spot.
static func depot_cell_for(def: Balance.ZoneDef) -> Vector2i:
	return Vector2i(int(def.grid_w / 2.0), maxi(def.grid_h - 3, 0))


## Every cell the depot pad covers; buildings pointing into any of them deliver.
static func depot_cells_for(def: Balance.ZoneDef) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if def == null:
		return out
	var origin: Vector2i = depot_cell_for(def) - DEPOT_SIZE / 2
	for y: int in DEPOT_SIZE.y:
		for x: int in DEPOT_SIZE.x:
			out.append(origin + Vector2i(x, y))
	return out


func building_at(c: Vector2i, balance: Balance) -> BuildingState:
	for b: BuildingState in buildings:
		var def: Balance.BuildingDef = balance.building(b.def_id)
		for occupied: Vector2i in b.occupied_cells(def):
			if occupied == c:
				return b
	return null


func add_building(def_id: String, c: Vector2i, facing: int) -> BuildingState:
	var b := BuildingState.new()
	b.uid = next_building_uid
	next_building_uid += 1
	b.def_id = def_id
	b.cell = c
	b.facing = facing
	buildings.append(b)
	return b


## Remove a building and hand back whatever it was holding, so a refund can
## never silently destroy buffered dust.
func remove_building(uid: int) -> Dictionary:
	for i: int in buildings.size():
		var b: BuildingState = buildings[i]
		if b.uid == uid:
			var held: Dictionary = b.buffer.duplicate()
			buildings.remove_at(i)
			return held
	return {}


func to_dict() -> Dictionary:
	var built: Array = []
	for b: BuildingState in buildings:
		built.append(b.to_dict())
	return {
		"def_id": def_id,
		"unlocked": unlocked,
		"completed": completed,
		"grid": grid.to_dict() if grid != null else {},
		"buildings": built,
		"next_building_uid": next_building_uid,
	}


static func from_dict(d: Dictionary, def: Balance.ZoneDef, balance: Balance) -> ZoneState:
	var z := ZoneState.new()
	z.def_id = String(d.get("def_id", ""))
	z.unlocked = bool(d.get("unlocked", false))
	z.completed = bool(d.get("completed", false))
	z.next_building_uid = int(d.get("next_building_uid", 1))

	var grid_raw: Variant = d.get("grid", {})
	if grid_raw is Dictionary and (grid_raw as Dictionary).has("dust"):
		z.grid = DustGrid.from_dict(grid_raw as Dictionary)
	elif def != null:
		# Save predates this zone, or the grid was unreadable: regenerate.
		z.grid = DustGrid.generate(def, balance)

	var built: Variant = d.get("buildings", [])
	if built is Array:
		for raw: Variant in built as Array:
			if raw is Dictionary:
				z.buildings.append(BuildingState.from_dict(raw as Dictionary))
	return z
