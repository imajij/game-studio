class_name DustGrid
extends RefCounted
## The zone's dust, as two flat byte arrays (amount + type per cell).
##
## Why bytes and not nodes: the largest zone is 56x64 = 3584 cells. As nodes
## that is a frame-killer on a 2 GB phone; as two PackedByteArrays it is 7 KB
## of state the view renders into a single texture.
##
## _remaining is kept in sync incrementally so clean_pct() is O(1) — rescanning
## thousands of cells every frame just to fill a progress bar is exactly the
## kind of cost that quietly eats the 60 fps budget.
##
## Pure sim: no Node, no autoloads, deterministic from the zone seed.

const MAX_DUST: int = 255

## Cached nearest-first cell offsets per sweep radius, so a sweep clears as an
## expanding circle instead of a scanline.
static var _offset_cache: Dictionary = {}


class SweepResult extends RefCounted:
	var collected: int = 0
	var by_type: Dictionary = {}       ## dust type index -> amount
	var crystals_found: int = 0
	var had_change: bool = false
	var dirty_min: Vector2i = Vector2i.ZERO
	var dirty_max: Vector2i = Vector2i.ZERO

	## Inclusive rect of touched cells; only meaningful when had_change.
	func dirty_rect() -> Rect2i:
		if not had_change:
			return Rect2i()
		return Rect2i(dirty_min, dirty_max - dirty_min + Vector2i.ONE)

	func _touch(c: Vector2i) -> void:
		if not had_change:
			dirty_min = c
			dirty_max = c
			had_change = true
			return
		dirty_min.x = mini(dirty_min.x, c.x)
		dirty_min.y = mini(dirty_min.y, c.y)
		dirty_max.x = maxi(dirty_max.x, c.x)
		dirty_max.y = maxi(dirty_max.y, c.y)


var w: int = 0
var h: int = 0

var _dust: PackedByteArray = PackedByteArray()
var _type: PackedByteArray = PackedByteArray()
var _initial_total: int = 0
var _remaining: int = 0


static func create(width: int, height: int) -> DustGrid:
	var g := DustGrid.new()
	g.w = maxi(width, 0)
	g.h = maxi(height, 0)
	g._dust.resize(g.w * g.h)
	g._type.resize(g.w * g.h)
	return g


## Deterministic from zone.seed: the same zone always generates the same dust,
## which is what makes the daily contract fair and the tests meaningful.
static func generate(zone: Balance.ZoneDef, balance: Balance) -> DustGrid:
	var g := DustGrid.create(zone.grid_w, zone.grid_h)

	var rng := RandomNumberGenerator.new()
	rng.seed = zone.seed

	# Clumped rather than per-cell random, so the surface reads as drifts of
	# dust instead of TV static.
	var noise := FastNoiseLite.new()
	noise.seed = zone.seed
	noise.frequency = 0.08
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	var weights: Array = g._resolve_mix(zone.dust_mix, balance)
	# density 0..1 -> noise threshold; higher density means more cells pass.
	var threshold: float = 1.0 - 2.0 * clampf(zone.dust_density, 0.0, 1.0)

	var total: int = 0
	for y: int in g.h:
		for x: int in g.w:
			var n: float = noise.get_noise_2d(float(x), float(y))
			if n < threshold:
				continue
			# Map how far above threshold into a dust depth.
			var span: float = maxf(1.0 - threshold, 0.0001)
			var depth: float = clampf((n - threshold) / span, 0.0, 1.0)
			var amount: int = clampi(int(round(60.0 + depth * 195.0)), 1, MAX_DUST)
			var i: int = y * g.w + x
			g._dust[i] = amount
			g._type[i] = g._pick_type(weights, rng)
			total += amount

	g._initial_total = total
	g._remaining = total
	return g


func cells() -> int:
	return w * h


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func dust_at(c: Vector2i) -> int:
	if not in_bounds(c):
		return 0
	return _dust[c.y * w + c.x]


func type_at(c: Vector2i) -> int:
	if not in_bounds(c):
		return 0
	return _type[c.y * w + c.x]


func initial_total() -> int:
	return _initial_total


func remaining() -> int:
	return _remaining


func collected_total() -> int:
	return _initial_total - _remaining


## O(1) — see the note at the top of this file.
func clean_pct() -> float:
	if _initial_total <= 0:
		return 100.0
	return (1.0 - float(_remaining) / float(_initial_total)) * 100.0


func is_complete(target_pct: float) -> bool:
	# Dust is integral, so a target of 100% is reachable exactly; the epsilon
	# only guards float comparison on fractional targets.
	return clean_pct() >= target_pct - 0.0001


## Clear up to `budget` dust from an expanding circle around `center`.
## `budget` is the caller's min(sweep_rate * delta, carry space left), so the
## grid never hands back more than the player can hold.
func sweep(center: Vector2i, radius: int, budget: int,
		rng: RandomNumberGenerator = null, crystal_chance: float = 0.0) -> SweepResult:
	var res := SweepResult.new()
	if budget <= 0 or _remaining <= 0:
		return res

	var left: int = budget
	for off: Vector2i in _offsets_for(radius):
		if left <= 0:
			break
		var c: Vector2i = center + off
		if not in_bounds(c):
			continue
		var i: int = c.y * w + c.x
		var have: int = _dust[i]
		if have <= 0:
			continue

		var take: int = mini(have, left)
		_dust[i] = have - take
		left -= take
		_remaining -= take
		res.collected += take

		var t: int = _type[i]
		res.by_type[t] = int(res.by_type.get(t, 0)) + take
		res._touch(c)

		# Crystals only on a cell cleared to bare ground, so they reward
		# finishing patches rather than brushing over everything.
		if _dust[i] == 0 and crystal_chance > 0.0 and rng != null:
			if rng.randf() < crystal_chance:
				res.crystals_found += 1

	return res


## Add dust back to a cell (zone 3's static-cling hazard). Returns what stuck.
func add_dust(c: Vector2i, amount: int) -> int:
	if not in_bounds(c) or amount <= 0:
		return 0
	var i: int = c.y * w + c.x
	var room: int = MAX_DUST - _dust[i]
	var put: int = mini(room, amount)
	if put <= 0:
		return 0
	_dust[i] = _dust[i] + put
	_remaining += put
	# Re-scattered dust must not push clean% above its own history, so the
	# initial total grows with it; without this, re-sweeping the same cell
	# would count twice and clean% could exceed 100.
	_initial_total += put
	return put


# --- serialisation --------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"w": w,
		"h": h,
		"dust": Marshalls.raw_to_base64(_dust),
		"type": Marshalls.raw_to_base64(_type),
		"initial_total": _initial_total,
	}


static func from_dict(d: Dictionary) -> DustGrid:
	var g := DustGrid.create(int(d.get("w", 0)), int(d.get("h", 0)))
	var expected: int = g.w * g.h
	g._dust = Marshalls.base64_to_raw(String(d.get("dust", "")))
	g._type = Marshalls.base64_to_raw(String(d.get("type", "")))
	if g._dust.size() != expected or g._type.size() != expected:
		push_warning("DustGrid: save/grid size mismatch, regenerating empty grid")
		return DustGrid.create(g.w, g.h)
	g._initial_total = int(d.get("initial_total", 0))
	var rem: int = 0
	for v: int in g._dust:
		rem += v
	g._remaining = rem
	return g


# --- internals ------------------------------------------------------------

## Cell offsets within `radius`, nearest first. Cached because a roller rig
## sweeps radius 5 (81 candidate cells) every frame.
static func _offsets_for(radius: int) -> Array:
	var r: int = maxi(radius, 0)
	if _offset_cache.has(r):
		return _offset_cache[r]
	var list: Array = []
	var rf: float = float(r) + 0.5
	for y: int in range(-r, r + 1):
		for x: int in range(-r, r + 1):
			if Vector2(float(x), float(y)).length() <= rf:
				list.append(Vector2i(x, y))
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).length_squared() < Vector2(b).length_squared()
	)
	_offset_cache[r] = list
	return list


func _resolve_mix(mix: Dictionary, balance: Balance) -> Array:
	var out: Array = []
	var total: float = 0.0
	for id: String in mix.keys():
		var idx: int = balance.dust_type_index(id)
		if idx < 0:
			push_warning("DustGrid: unknown dust type '%s' in zone mix" % id)
			continue
		var weight: float = maxf(float(mix[id]), 0.0)
		if weight <= 0.0:
			continue
		total += weight
		out.append({"index": idx, "cum": total})
	if out.is_empty():
		out.append({"index": 0, "cum": 1.0})
		total = 1.0
	for entry: Dictionary in out:
		entry["cum"] = float(entry["cum"]) / total
	return out


func _pick_type(weights: Array, rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	for entry: Dictionary in weights:
		if roll <= float(entry["cum"]):
			return int(entry["index"])
	return int((weights[weights.size() - 1] as Dictionary)["index"])
