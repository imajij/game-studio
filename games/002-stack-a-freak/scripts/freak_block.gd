class_name FreakBlock
extends RigidBody2D
## One dropped freak: a square physics body. Greybox draws a rounded square
## with googly eyes; the art pass swaps in sticker textures via Freaks.TEXTURES.

const FRICTION: float = 1.0
const BOUNCE: float = 0.04
const BASE_SIZE: float = 170.0
const SETTLE_SPEED: float = 10.0
const CORNER: float = 18.0

var freak: int = 0
var side: float = BASE_SIZE
## Set once the block has been still long enough to score.
var counted: bool = false
var still_time: float = 0.0

func setup(freak_index: int) -> void:
	freak = freak_index
	side = Freaks.SIZES[freak]
	mass = pow(side / BASE_SIZE, 2.0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(side, side)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	var material := PhysicsMaterial.new()
	material.friction = FRICTION
	material.bounce = BOUNCE
	physics_material_override = material


func is_still() -> bool:
	return linear_velocity.length() < SETTLE_SPEED and absf(angular_velocity) < 0.6


func _draw() -> void:
	var half := side / 2.0
	if freak < Freaks.TEXTURES.size() and Freaks.TEXTURES[freak] != null:
		draw_texture_rect(Freaks.TEXTURES[freak],
			Rect2(Vector2(-half, -half) * 1.08, Vector2(side, side) * 1.08), false)
		return
	var color := Freaks.COLORS[freak]
	var rect := Rect2(Vector2(-half, -half), Vector2(side, side))
	draw_rect(rect, color)
	draw_rect(rect, color.darkened(0.35), false, 6.0)
	var eye_y := -side * 0.15
	for ex in [-side * 0.18, side * 0.18]:
		draw_circle(Vector2(ex, eye_y), side * 0.13, Color.WHITE)
		draw_circle(Vector2(ex, eye_y + side * 0.03), side * 0.06, Color(0.1, 0.1, 0.15))
