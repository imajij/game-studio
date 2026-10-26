class_name Items
## Falling stuff. First four are snacks (catch!), last three are regret
## (dodge!). IS_GOOD is the single source of truth.

const COUNT: int = 7

const NAMES: Array[String] = [
	"Cookie Carl", "Taco Tina", "Melon Mo", "Pie Guy",
	"Angry Anvil", "Spiky Boi", "Uncle Brick",
]

const IS_GOOD: Array[bool] = [true, true, true, true, false, false, false]

const RADII: Array[float] = [70.0, 78.0, 85.0, 80.0, 85.0, 72.0, 80.0]

const COLORS: Array[Color] = [
	Color(0.85, 0.64, 0.38), # Cookie Carl
	Color(0.95, 0.73, 0.35), # Taco Tina
	Color(0.90, 0.36, 0.42), # Melon Mo
	Color(0.93, 0.80, 0.55), # Pie Guy
	Color(0.45, 0.47, 0.55), # Angry Anvil
	Color(0.45, 0.68, 0.35), # Spiky Boi
	Color(0.72, 0.40, 0.32), # Uncle Brick
]

const TEXTURES: Array[Texture2D] = [
	preload("res://assets/art/characters/cookie-carl.png"),
	preload("res://assets/art/characters/taco-tina.png"),
	preload("res://assets/art/characters/melon-mo.png"),
	preload("res://assets/art/characters/pie-guy.png"),
	preload("res://assets/art/characters/angry-anvil.png"),
	preload("res://assets/art/characters/spiky-boi.png"),
	preload("res://assets/art/characters/uncle-brick.png"),
]
