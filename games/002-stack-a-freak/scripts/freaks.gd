class_name Freaks
## The stackable freaks. Arrays are 0-indexed; a random freak is picked per
## drop (visual + size only — gameplay treats them all the same).

const COUNT: int = 6

const NAMES: Array[String] = [
	"Blobby Greg", "Mister Loaf", "Angry Flan",
	"Bricked Frog", "Stressed Mallow", "The Unit",
]

## Side length in px of each freak's square body.
const SIZES: Array[float] = [170.0, 185.0, 160.0, 150.0, 165.0, 200.0]

const COLORS: Array[Color] = [
	Color(0.35, 0.78, 0.72), # Blobby Greg — jelly teal
	Color(0.85, 0.66, 0.38), # Mister Loaf — crust tan
	Color(0.93, 0.74, 0.45), # Angry Flan — caramel
	Color(0.47, 0.72, 0.35), # Bricked Frog — frog green
	Color(0.95, 0.80, 0.85), # Stressed Mallow — pink white
	Color(0.62, 0.64, 0.70), # The Unit — concrete gray
]

const TEXTURES: Array[Texture2D] = [
	preload("res://assets/art/characters/blobby-greg.png"),
	preload("res://assets/art/characters/mister-loaf.png"),
	preload("res://assets/art/characters/angry-flan.png"),
	preload("res://assets/art/characters/bricked-frog.png"),
	preload("res://assets/art/characters/stressed-mallow.png"),
	preload("res://assets/art/characters/the-unit.png"),
]
