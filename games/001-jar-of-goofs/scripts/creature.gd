class_name Creature
extends RigidBody2D
## One creature in the jar. Builds its own collision shape and greybox visual
## (colored circle + tier number) from Tiers data, and reports same-tier
## contacts to the game for merging.

signal same_tier_contact(a: Creature, b: Creature)

const BOUNCE: float = 0.2
const FRICTION: float = 0.8
## Sprites are stickers larger than the collision circle (ears, hats, arms),
## so draw wider than the physics diameter; slight visual overlap is fine.
const SPRITE_DIAMETER_FACTOR: float = 2.35
const MERGE_POP_SEC: float = 0.25
const MERGE_POP_FROM: float = 0.4
## Tier-1 radius; mass scales with area relative to it so big creatures sink.
const BASE_RADIUS: float = 40.0

var tier: int = 1
var radius: float = Tiers.RADII[1]
## True after the first physics contact — only settled creatures can trigger
## the danger line (fresh drops pass through it harmlessly).
var activated: bool = false
## Claimed by a merge this frame; ignore further contacts.
var merging: bool = false
## Seconds spent continuously above the danger line (tracked by game.gd).
var danger_time: float = 0.0
## Visual-only scale for the merge pop; the collider stays full size.
var visual_scale: float = 1.0:
	set(value):
		visual_scale = value
		queue_redraw()

func setup(new_tier: int) -> void:
	tier = new_tier
	radius = Tiers.RADII[tier]
	mass = pow(radius / BASE_RADIUS, 2.0)
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	var material := PhysicsMaterial.new()
	material.bounce = BOUNCE
	material.friction = FRICTION
	physics_material_override = material
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)


func pop_in() -> void:
	var tween := create_tween()
	tween.tween_property(self, "visual_scale", 1.0, MERGE_POP_SEC) \
		.from(MERGE_POP_FROM).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_body_entered(body: Node) -> void:
	activated = true
	var other := body as Creature
	if other == null:
		return
	if merging or other.merging:
		return
	if other.tier != tier or tier >= Tiers.COUNT:
		return
	# Both bodies report the same contact — only one side claims it.
	if get_instance_id() > other.get_instance_id():
		return
	same_tier_contact.emit(self, other)


func _draw() -> void:
	var side := radius * SPRITE_DIAMETER_FACTOR * visual_scale
	draw_texture_rect(
		Tiers.TEXTURES[tier],
		Rect2(Vector2(-side / 2.0, -side / 2.0), Vector2(side, side)),
		false
	)
