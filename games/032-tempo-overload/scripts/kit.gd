class_name Kit
extends RefCounted
## Vibrant low-poly 3D + UI helpers for the batch-3 games. Copied per game
## (never synced from shared/ so released games stay untouched). Everything is
## unshaded flat color — the saturated palette IS the art style — with one
## shadowless directional light added by sky() purely so shaded props pop.

const PINK := Color(0.98, 0.32, 0.6)
const CORAL := Color(1.0, 0.45, 0.35)
const ORANGE := Color(1.0, 0.6, 0.15)
const SUN := Color(1.0, 0.84, 0.22)
const LIME := Color(0.56, 0.9, 0.25)
const MINT := Color(0.35, 0.92, 0.68)
const TEAL := Color(0.1, 0.82, 0.78)
const SKY := Color(0.3, 0.68, 1.0)
const BLUE := Color(0.25, 0.47, 0.95)
const PURPLE := Color(0.62, 0.42, 1.0)
const MAGENTA := Color(0.9, 0.3, 0.85)
const RED := Color(0.96, 0.3, 0.3)
const CREAM := Color(1.0, 0.96, 0.88)
const INK := Color(0.16, 0.13, 0.24)
const CANDY: Array[Color] = [PINK, ORANGE, SUN, LIME, TEAL, SKY, PURPLE, CORAL, MINT, MAGENTA]

static var _mats: Dictionary = {}
static var _font: FontFile = null


static func mat(color: Color, shaded: bool = false) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), shaded]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		if not shaded:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = m
	return _mats[key]


## Flow-art textured material: loads res://assets/art/<name>.png when present
## (dropped in by the Flow texture pass), else falls back to the flat color —
## so every surface upgrades automatically the moment the art file lands.
static func texmat(file: String, fallback: Color, tiles: float = 1.0) -> StandardMaterial3D:
	var path := "res://assets/art/%s.png" % file
	var key := "tex|%s|%s" % [path, tiles]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if ResourceLoader.exists(path):
			m.albedo_texture = load(path)
			m.uv1_scale = Vector3(tiles, tiles, tiles)
		else:
			m.albedo_color = fallback
		_mats[key] = m
	return _mats[key]


static func texbox(size: Vector3, file: String, fallback: Color, tiles: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = texmat(file, fallback, tiles)
	return mi


static func box(size: Vector3, color: Color, shaded: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat(color, shaded)
	return mi


static func cyl(radius: float, height: float, color: Color, shaded: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	mi.mesh = mesh
	mi.material_override = mat(color, shaded)
	return mi


static func cone(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mi.mesh = mesh
	mi.material_override = mat(color)
	return mi


static func sphere(radius: float, color: Color, shaded: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mi.mesh = mesh
	mi.material_override = mat(color, shaded)
	return mi


static func capsule(radius: float, height: float, color: Color, shaded: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = mat(color, shaded)
	return mi


## A cute capsule character with a face looking toward -Z.
static func blobby(color: Color, radius: float = 0.3) -> Node3D:
	var root := Node3D.new()
	var body := capsule(radius, radius * 3.0, color)
	body.position.y = radius * 1.5
	root.add_child(body)
	var eye_y := radius * 2.1
	for side: float in [-1.0, 1.0]:
		var white := sphere(radius * 0.22, Color.WHITE)
		white.position = Vector3(side * radius * 0.42, eye_y, -radius * 0.78)
		root.add_child(white)
		var pupil := sphere(radius * 0.1, INK)
		pupil.position = Vector3(side * radius * 0.42, eye_y, -radius * 0.95)
		root.add_child(pupil)
	return root


## Bright gradient sky + warm sun + soft ambient. The vibrancy backbone.
## Returns the ProceduralSkyMaterial so games can recolor the sky live.
static func sky(root: Node, top: Color, horizon: Color, ground: Color = Color(0.9, 0.8, 0.7)) -> ProceduralSkyMaterial:
	var env := Environment.new()
	var sky_res := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_bottom_color = ground
	sky_mat.ground_horizon_color = horizon
	sky_mat.sun_angle_max = 20.0
	sky_res.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	root.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	light.light_energy = 1.2
	light.shadow_enabled = false
	root.add_child(light)
	return sky_mat


static func burst(root: Node, pos: Vector3, color: Color, amount: int = 24, speed: float = 5.0) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 0.12)
	p.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	p.mesh.material = m
	p.color = color
	root.add_child(p)
	p.finished.connect(p.queue_free)


static func squash(node: Node3D, strength: float = 0.3, seconds: float = 0.22) -> void:
	var tween := node.create_tween()
	node.scale = Vector3(1.0 + strength, 1.0 - strength, 1.0 + strength)
	tween.tween_property(node, "scale", Vector3.ONE, seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- UI ---------------------------------------------------------------------

static func font() -> FontFile:
	if _font == null:
		_font = load("res://assets/fonts/Baloo2.ttf")
	return _font


static func label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", maxi(size / 7, 8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, size: int, bg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", size)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(26)
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	var pressed := style.duplicate()
	pressed.bg_color = bg.darkened(0.35)
	var disabled := style.duplicate()
	disabled.bg_color = Color(bg.r * 0.45, bg.g * 0.45, bg.b * 0.45, 0.85)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	return b


## Full-screen overlay panel with title/body, returns {panel, title, body}.
static func overlay(title_text: String, accent: Color) -> Dictionary:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.06, 0.14, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(dim)
	var title := label(title_text, 96, accent)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 640.0
	title.offset_bottom = 780.0
	panel.add_child(title)
	var body := label("", 50)
	body.set_anchors_preset(Control.PRESET_TOP_WIDE)
	body.offset_top = 820.0
	body.offset_bottom = 1100.0
	panel.add_child(body)
	return { "panel": panel, "title": title, "body": body }
