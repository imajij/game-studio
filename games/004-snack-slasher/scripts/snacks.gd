class_name Snacks
## The sliceable cast. Index 5 is Sir Soap — slicing him ends the round.

const COUNT: int = 6
const SOAP: int = 5

const NAMES: Array[String] = [
	"Pizza Pete", "Donut Diane", "Burrito Bandit",
	"Sad Samosa", "Chip Commander", "Sir Soap",
]

const RADII: Array[float] = [95.0, 90.0, 85.0, 80.0, 88.0, 92.0]

const COLORS: Array[Color] = [
	Color(0.95, 0.62, 0.35), # Pizza Pete
	Color(0.93, 0.55, 0.70), # Donut Diane
	Color(0.80, 0.68, 0.42), # Burrito Bandit
	Color(0.90, 0.78, 0.45), # Sad Samosa
	Color(0.96, 0.82, 0.30), # Chip Commander
	Color(0.55, 0.85, 0.95), # Sir Soap — suspiciously clean blue
]

const TEXTURES: Array[Texture2D] = [
	preload("res://assets/art/characters/pizza-pete.png"),
	preload("res://assets/art/characters/donut-diane.png"),
	preload("res://assets/art/characters/burrito-bandit.png"),
	preload("res://assets/art/characters/sad-samosa.png"),
	preload("res://assets/art/characters/chip-commander.png"),
	preload("res://assets/art/characters/sir-soap.png"),
]
