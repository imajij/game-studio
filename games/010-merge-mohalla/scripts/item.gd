class_name MohallaItem
extends RigidBody2D
## One droppable street object. Same-tier contact asks the game to merge.

const TIERS: Array = [
	# name, radius, color
	["Chai Cup", 44.0, Color(0.85, 0.60, 0.35)],
	["Samosa", 56.0, Color(0.93, 0.72, 0.28)],
	["Jalebi", 70.0, Color(0.96, 0.55, 0.15)],
	["Auto Horn", 86.0, Color(0.35, 0.70, 0.75)],
	["Pressure Cooker", 104.0, Color(0.75, 0.78, 0.82)],
	["Ceiling Fan", 124.0, Color(0.55, 0.65, 0.90)],
	["Scooty", 147.0, Color(0.90, 0.45, 0.60)],
	["Water Tanki", 173.0, Color(0.25, 0.55, 0.85)],
	["Band Speaker", 203.0, Color(0.50, 0.40, 0.80)],
	["Cursed Hybrid", 238.0, Color(0.30, 0.85, 0.55)],
]

var tier: int = 0
var merging: bool = false
var merge_handler: Callable = Callable()

func setup(new_tier: int, handler: Callable) -> void:
	tier = new_tier
	merge_handler = handler
	mass = 1.0 + tier * 0.6
	gravity_scale = 1.5
	contact_monitor = true
	max_contacts_reported = 6
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.12
	physics_material_override.friction = 0.6
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius()
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func radius() -> float:
	return TIERS[tier][1]


static func tier_color(t: int) -> Color:
	return TIERS[t][2]


func _on_body_entered(body: Node) -> void:
	var other := body as MohallaItem
	if other == null or other.tier != tier or merging or other.merging:
		return
	if get_instance_id() > other.get_instance_id():
		return
	merging = true
	other.merging = true
	if merge_handler.is_valid():
		merge_handler.call(self, other)


func _draw() -> void:
	var body_color: Color = TIERS[tier][2]
	var outline := body_color.darkened(0.45)
	var r := radius()
	draw_circle(Vector2.ZERO, r + 6.0, outline)
	draw_circle(Vector2.ZERO, r, body_color)
	draw_circle(Vector2(0.0, r * 0.3), r * 0.55, body_color.lightened(0.15))
	# tier accent
	match tier % 5:
		0:
			draw_arc(Vector2(r * 0.55, -r * 0.2), r * 0.3, -PI / 2.0, PI / 2.0, 12, outline, 6.0)
		1:
			var tri := PackedVector2Array([
				Vector2(-r * 0.4, -r * 0.5), Vector2(r * 0.4, -r * 0.5), Vector2(0, -r * 1.0)])
			draw_colored_polygon(tri, body_color.darkened(0.2))
		2:
			draw_arc(Vector2(0, -r * 0.55), r * 0.3, 0.0, TAU, 16, outline, 7.0)
		3:
			for i in 3:
				var a := i * TAU / 3.0
				draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * r * 0.65, outline, 8.0)
		4:
			draw_rect(Rect2(-r * 0.5, -r * 0.75, r, r * 0.3), outline)
	# face (every mohalla object is alive, obviously)
	var eye_y := -r * 0.18
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(side * r * 0.3, eye_y), r * 0.14, Color.WHITE)
		draw_circle(Vector2(side * r * 0.3 + 3.0, eye_y + 2.0), r * 0.07, Color(0.1, 0.1, 0.15))
	draw_arc(Vector2(0.0, r * 0.22), r * 0.16, 0.15, PI - 0.15, 10, outline, 5.0)
