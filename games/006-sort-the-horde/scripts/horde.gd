class_name Horde
## The sortable mob. Ghouls go LEFT (dungeon), babies go RIGHT (daycare).
## Disguises appear later: ghouls in bows, babies with fangs — type is
## unchanged, only the look lies.

const GHOULS: Array[String] = ["Grimble", "Soggy Joe", "Bitey"]
const BABIES: Array[String] = ["Beanie", "Pudge", "Sprout"]

const GHOUL_COLORS: Array[Color] = [
	Color(0.55, 0.62, 0.5),
	Color(0.45, 0.55, 0.65),
	Color(0.62, 0.5, 0.62),
]

const BABY_COLORS: Array[Color] = [
	Color(0.95, 0.75, 0.78),
	Color(0.95, 0.85, 0.6),
	Color(0.72, 0.88, 0.65),
]

## 3 ghouls then 3 babies.
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/art/characters/grimble.png"),
	preload("res://assets/art/characters/soggy-joe.png"),
	preload("res://assets/art/characters/bitey.png"),
	preload("res://assets/art/characters/beanie.png"),
	preload("res://assets/art/characters/pudge.png"),
	preload("res://assets/art/characters/sprout.png"),
]
