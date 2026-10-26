class_name Tiers
## Static data for the 11-creature merge chain. Arrays are 1-indexed by tier
## (index 0 is padding) so code reads as Tiers.NAMES[tier].

const COUNT: int = 11
## Only tiers 1–4 can appear as a fresh drop.
const MAX_DROP_TIER: int = 4

const NAMES: Array[String] = [
	"",
	"Bloop",
	"Sir Crumbs",
	"Sock Goblin",
	"Toastradamus",
	"Croissant Crab",
	"Lord Pickleton",
	"Bananarchy",
	"Fridge Philosopher",
	"Capybara in a Suit",
	"Grandpa Galaxy",
	"The Cosmic Bloop",
]

## Collision radii in px at the 1080x1920 base resolution. Tier 11's diameter
## (584) still fits the 920 px jar interior.
const RADII: Array[float] = [
	0.0, 40.0, 49.0, 60.0, 73.0, 89.0, 108.0, 132.0, 160.0, 196.0, 240.0, 292.0,
]

## Points awarded for CREATING a creature of this tier via a merge
## (triangular numbers — higher tiers pay much more).
const POINTS: Array[int] = [0, 0, 1, 3, 6, 10, 15, 21, 28, 36, 45, 55]

## Character art (1-indexed like the other tables; index 0 is padding).
const TEXTURES: Array[Texture2D] = [
	null,
	preload("res://assets/art/creatures/t01-bloop.png"),
	preload("res://assets/art/creatures/t02-sir-crumbs.png"),
	preload("res://assets/art/creatures/t03-sock-goblin.png"),
	preload("res://assets/art/creatures/t04-toastradamus.png"),
	preload("res://assets/art/creatures/t05-croissant-crab.png"),
	preload("res://assets/art/creatures/t06-lord-pickleton.png"),
	preload("res://assets/art/creatures/t07-bananarchy.png"),
	preload("res://assets/art/creatures/t08-fridge-philosopher.png"),
	preload("res://assets/art/creatures/t09-capybara-suit.png"),
	preload("res://assets/art/creatures/t10-grandpa-galaxy.png"),
	preload("res://assets/art/creatures/t11-cosmic-bloop.png"),
]

## Accent colors per tier (used for UI tints; sprites carry the real look).
const COLORS: Array[Color] = [
	Color.BLACK,
	Color(0.55, 0.85, 0.35), # Bloop — pea green
	Color(0.85, 0.65, 0.35), # Sir Crumbs — cookie brown
	Color(0.60, 0.55, 0.75), # Sock Goblin — dusty purple
	Color(0.93, 0.78, 0.50), # Toastradamus — toast tan
	Color(0.95, 0.55, 0.30), # Croissant Crab — baked orange
	Color(0.45, 0.65, 0.30), # Lord Pickleton — pickle green
	Color(0.98, 0.85, 0.25), # Bananarchy — yellow
	Color(0.60, 0.85, 0.95), # Fridge Philosopher — ice blue
	Color(0.65, 0.45, 0.30), # Capybara in a Suit — fur brown
	Color(0.45, 0.30, 0.70), # Grandpa Galaxy — deep purple
	Color(0.90, 0.30, 0.75), # The Cosmic Bloop — cosmic magenta
]
