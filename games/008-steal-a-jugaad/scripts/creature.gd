class_name JugaadCreature
extends Node2D
## One creature, drawn as an original flat-sticker blob with a per-creature
## accessory. Used on the conveyor (with a price tag), on base pedestals,
## and inside the raid overlay.

const BODY_RADIUS: float = 78.0

var id: int = 0
var show_price: bool = false
var asleep: bool = false
var walk_phase: float = randf() * TAU

func setup(creature_id: int, with_price: bool = false) -> void:
	id = creature_id
	show_price = with_price
	queue_redraw()


func _process(delta: float) -> void:
	if show_price:
		walk_phase += delta * 9.0
		rotation = sin(walk_phase) * 0.06
		queue_redraw()


func _draw() -> void:
	var body := JugaadDB.body_color(id)
	var outline := body.darkened(0.45)
	var ring := JugaadDB.RARITY_COLORS[JugaadDB.rarity(id)]
	# rarity ring under the feet
	draw_set_transform(Vector2(0.0, BODY_RADIUS * 0.9), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, BODY_RADIUS * 1.15, Color(ring.r, ring.g, ring.b, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# body + outline
	draw_circle(Vector2.ZERO, BODY_RADIUS + 7.0, outline)
	draw_circle(Vector2.ZERO, BODY_RADIUS, body)
	# belly highlight
	draw_circle(Vector2(0.0, BODY_RADIUS * 0.35), BODY_RADIUS * 0.52, body.lightened(0.18))
	_draw_accessory(outline, body)
	_draw_face(outline)


func _draw_accessory(outline: Color, body: Color) -> void:
	match id:
		0:  # Samosa Sherni — crispy samosa hat + whiskers
			var hat := PackedVector2Array([Vector2(-52, -60), Vector2(52, -60), Vector2(0, -132)])
			draw_colored_polygon(hat, Color(0.85, 0.55, 0.18))
			draw_polyline(hat + PackedVector2Array([hat[0]]), outline, 6.0)
			for side in [-1.0, 1.0]:
				draw_line(Vector2(side * 60, 8), Vector2(side * 108, 0), outline, 5.0)
				draw_line(Vector2(side * 60, 20), Vector2(side * 106, 26), outline, 5.0)
		1:  # Chai Walrus — tusks + steam curl
			for side in [-1.0, 1.0]:
				draw_rect(Rect2(side * 26.0 - 9.0, 34.0, 18.0, 52.0), Color(0.97, 0.95, 0.88))
				draw_rect(Rect2(side * 26.0 - 9.0, 34.0, 18.0, 52.0), outline, false, 4.0)
			draw_arc(Vector2(64, -92), 16.0, 0.0, PI * 1.5, 12, Color(0.9, 0.9, 0.95, 0.8), 6.0)
		2:  # Vada Pav Vulture — beak + bun head
			draw_circle(Vector2(0, -74), 34.0, Color(0.93, 0.80, 0.55))
			draw_arc(Vector2(0, -74), 34.0, 0.0, TAU, 24, outline, 5.0)
			var beak := PackedVector2Array([Vector2(-6, -20), Vector2(46, -2), Vector2(-6, 14)])
			draw_colored_polygon(beak, Color(0.95, 0.62, 0.22))
		3:  # Paneer Panda — ears + eye patches
			for side in [-1.0, 1.0]:
				draw_circle(Vector2(side * 56, -62), 26.0, outline)
				draw_circle(Vector2(side * 30, -16), 20.0, Color(0.25, 0.22, 0.28))
		4:  # Jalebi Cobra — orange coil crown
			draw_arc(Vector2(0, -96), 30.0, 0.0, TAU, 20, Color(0.98, 0.55, 0.12), 12.0)
			draw_arc(Vector2(0, -96), 16.0, 0.0, TAU, 14, Color(0.99, 0.75, 0.25), 8.0)
		5:  # Dhokla Dino — back spikes
			for i in 3:
				var cx := -44.0 + i * 44.0
				var spike := PackedVector2Array([
					Vector2(cx - 18, -64), Vector2(cx + 18, -64), Vector2(cx, -108)])
				draw_colored_polygon(spike, Color(0.55, 0.72, 0.30))
		6:  # Auto Ostrich — long neck + tiny auto-rickshaw hood
			draw_rect(Rect2(-14, -150, 28, 90), body)
			draw_rect(Rect2(-14, -150, 28, 90), outline, false, 5.0)
			draw_circle(Vector2(0, -156), 26.0, body)
			draw_arc(Vector2(0, -156), 26.0, 0.0, TAU, 20, outline, 5.0)
			draw_rect(Rect2(-30, -200, 60, 22), Color(0.95, 0.85, 0.30))
		7:  # Mirchi Moose — antlers + chilli
			for side in [-1.0, 1.0]:
				draw_line(Vector2(side * 34, -70), Vector2(side * 70, -120), outline, 9.0)
				draw_line(Vector2(side * 52, -96), Vector2(side * 86, -96), outline, 8.0)
			draw_arc(Vector2(0, 46), 18.0, 0.2, PI - 0.2, 10, Color(0.85, 0.20, 0.15), 10.0)
		8:  # Lassi Yeti — fur tufts + lassi glass
			for i in 5:
				var a := -PI * 0.8 + i * (PI * 0.6 / 4.0)
				var from := Vector2(cos(a), sin(a)) * BODY_RADIUS
				draw_line(from, from * 1.25, Color(0.80, 0.86, 0.95), 7.0)
			draw_rect(Rect2(44, -30, 30, 44), Color(0.98, 0.93, 0.85))
			draw_rect(Rect2(44, -30, 30, 44), outline, false, 4.0)
		9:  # Disco Buffalo — horns + disco sparkle
			for side in [-1.0, 1.0]:
				draw_arc(Vector2(side * 44, -58), 26.0, PI, TAU, 14, outline, 10.0)
			for i in 4:
				var a := i * TAU / 4.0 + 0.4
				var p := Vector2(cos(a), sin(a)) * 30.0 + Vector2(0, -96)
				draw_line(p - Vector2(8, 0), p + Vector2(8, 0), Color(1, 1, 0.8), 4.0)
				draw_line(p - Vector2(0, 8), p + Vector2(0, 8), Color(1, 1, 0.8), 4.0)


func _draw_face(outline: Color) -> void:
	if asleep:
		for side in [-1.0, 1.0]:
			draw_line(Vector2(side * 30 - 14, -12), Vector2(side * 30 + 14, -12), outline, 6.0)
		draw_arc(Vector2(0, 26), 12.0, 0.1, PI - 0.1, 10, outline, 5.0)
		return
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(side * 30, -14), 15.0, Color.WHITE)
		draw_circle(Vector2(side * 30 + 4, -12), 7.0, Color(0.12, 0.10, 0.16))
	draw_arc(Vector2(0, 24), 16.0, 0.15, PI - 0.15, 12, outline, 6.0)
	if show_price:
		_draw_price_tag()


func _draw_price_tag() -> void:
	var font := ThemeDB.fallback_font
	var text := "₹%s" % _fmt(JugaadDB.price(id))
	var size := 40
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	var rect := Rect2(-w / 2.0 - 16.0, -BODY_RADIUS - 112.0, w + 32.0, 56.0)
	draw_rect(rect, Color(0.10, 0.09, 0.14, 0.88))
	draw_rect(rect, JugaadDB.RARITY_COLORS[JugaadDB.rarity(id)], false, 4.0)
	draw_string(font, Vector2(-w / 2.0, -BODY_RADIUS - 70.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 0.9))


static func _fmt(value: int) -> String:
	if value >= 1000:
		return "%.1fk" % (value / 1000.0)
	return str(value)
