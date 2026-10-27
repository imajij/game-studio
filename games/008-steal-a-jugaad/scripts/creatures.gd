class_name JugaadDB
extends RefCounted
## Static creature catalogue for Steal a Jugaad. All creatures are original
## desi-absurd inventions — no borrowed meme or franchise IP.

const RARITY_NAMES: Array[String] = ["COMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC"]
const RARITY_COLORS: Array[Color] = [
	Color(0.62, 0.66, 0.70),
	Color(0.35, 0.62, 0.95),
	Color(0.70, 0.42, 0.95),
	Color(1.00, 0.78, 0.25),
	Color(0.98, 0.33, 0.42),
]
## Conveyor spawn weights per rarity — mythics are the FOMO.
const RARITY_WEIGHTS: Array[float] = [52.0, 28.0, 13.0, 5.5, 1.5]

## id → [name, rarity, price, income per second, body color]
const CREATURES: Array = [
	["Samosa Sherni", 0, 50, 1, Color(0.93, 0.68, 0.30)],
	["Chai Walrus", 0, 80, 2, Color(0.72, 0.52, 0.38)],
	["Vada Pav Vulture", 1, 300, 5, Color(0.80, 0.72, 0.55)],
	["Paneer Panda", 1, 450, 7, Color(0.92, 0.90, 0.86)],
	["Jalebi Cobra", 2, 1500, 16, Color(0.95, 0.60, 0.20)],
	["Dhokla Dino", 2, 2200, 22, Color(0.85, 0.88, 0.45)],
	["Auto Ostrich", 3, 8000, 55, Color(0.30, 0.75, 0.65)],
	["Mirchi Moose", 3, 12000, 75, Color(0.45, 0.80, 0.35)],
	["Lassi Yeti", 4, 40000, 220, Color(0.88, 0.93, 1.00)],
	["Disco Buffalo", 4, 65000, 340, Color(0.45, 0.40, 0.75)],
]

static func creature_name(id: int) -> String:
	return String(CREATURES[id][0])


static func rarity(id: int) -> int:
	return int(CREATURES[id][1])


static func price(id: int) -> int:
	return int(CREATURES[id][2])


static func income(id: int) -> int:
	return int(CREATURES[id][3])


static func body_color(id: int) -> Color:
	return CREATURES[id][4]


## Weighted random creature id; featured_id spawns twice as often.
static func roll(featured_id: int = -1) -> int:
	var weights: Array[float] = []
	var total: float = 0.0
	for id in CREATURES.size():
		var w := RARITY_WEIGHTS[rarity(id)] / 2.0
		if id == featured_id:
			w *= 2.0
		weights.append(w)
		total += w
	var pick := randf() * total
	for id in CREATURES.size():
		pick -= weights[id]
		if pick <= 0.0:
			return id
	return 0


## Weighted roll skewed toward higher rarities (rewarded crate).
static func roll_lucky() -> int:
	var lucky_weights: Array[float] = [18.0, 30.0, 28.0, 17.0, 7.0]
	var by_rarity: Array = [[], [], [], [], []]
	for id in CREATURES.size():
		by_rarity[rarity(id)].append(id)
	var total: float = 0.0
	for w in lucky_weights:
		total += w
	var pick := randf() * total
	for r in 5:
		pick -= lucky_weights[r]
		if pick <= 0.0:
			var ids: Array = by_rarity[r]
			return ids[randi() % ids.size()]
	return 0
