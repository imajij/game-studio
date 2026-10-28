extends Node3D
## Dhulai Deluxe — power-wash ASMR: a filthy 3D object made of dozens of
## panels, your thumb is the spray. Mud melts into vibrant color wherever the
## jet lingers, the clean-meter climbs, 100% sparkles into the next object.
## Rewarded ad = instant foam blast (+25%); interstitial at results.

enum State { WASHING, RESULT }

const CLEAN_RADIUS_PX: float = 95.0
const CLEAN_RATE: float = 2.6
const LEVEL_KEY: String = "level"
const DIRT := Color(0.42, 0.33, 0.24)

const SFX_SPRAY: AudioStream = preload("res://assets/audio/spray.wav")
const SFX_CLEAN: AudioStream = preload("res://assets/audio/clean.wav")
const SFX_DONE: AudioStream = preload("res://assets/audio/done.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.WASHING
var level: int = 1
var panels: Array = []    # {node, mat, true_color, dirty}
var spraying: bool = false
var spray_pos: Vector2 = Vector2.ZERO
var spray_sound_cd: float = 0.0
var sparkle_cd: float = 0.0
var restarting: bool = false
var foam_used: bool = false

var object_root: Node3D = null
var cam: Camera3D = null
var jet: CPUParticles3D = null
var level_label: Label = null
var meter_label: Label = null
var foam_button: Button = null
var overlay: Dictionary = {}

const OBJECT_NAMES: Array[String] = ["auto-rickshaw", "haathi statue", "water tanki"]

func _ready() -> void:
	randomize()
	level = int(SaveManager.get_value(LEVEL_KEY, 1))
	Kit.sky(self, Kit.SKY, Color(1.0, 0.88, 0.66), Color(0.75, 0.7, 0.6))
	cam = Camera3D.new()
	cam.position = Vector3(0.0, 2.4, 7.5)
	cam.fov = 50.0
	add_child(cam)
	cam.look_at(Vector3(0.0, 1.4, 0.0))
	var yard := Kit.texbox(Vector3(22.0, 0.4, 18.0), "tex1", Color(0.75, 0.68, 0.6), 1.0)
	yard.position.y = -0.2
	add_child(yard)
	object_root = Node3D.new()
	add_child(object_root)
	_build_object()
	jet = CPUParticles3D.new()
	jet.amount = 60
	jet.lifetime = 0.3
	jet.emitting = false
	jet.spread = 8.0
	jet.initial_velocity_min = 9.0
	jet.initial_velocity_max = 12.0
	var pm := SphereMesh.new()
	pm.radius = 0.05
	pm.height = 0.1
	jet.mesh = pm
	jet.color = Color(0.6, 0.85, 1.0, 0.9)
	jet.position = Vector3(0.0, 0.6, 5.0)
	add_child(jet)
	_build_ui()
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	Analytics.log_event("round_start")


func _process(delta: float) -> void:
	object_root.rotation.y += delta * 0.12
	spray_sound_cd -= delta
	sparkle_cd -= delta
	if state != State.WASHING:
		return
	if spraying:
		if spray_sound_cd <= 0.0:
			spray_sound_cd = 0.18
			AudioManager.play_sfx(SFX_SPRAY, 0.15)
		jet.emitting = true
		# aim the jet node toward the spray point in world
		var from := cam.project_ray_origin(spray_pos)
		var dir := cam.project_ray_normal(spray_pos)
		var target := from + dir * 7.0
		jet.look_at_from_position(Vector3(0.0, 0.6, 5.0), target)
		var cleaned_any := false
		for p: Dictionary in panels:
			if p.dirty <= 0.0:
				continue
			var screen := cam.unproject_position(p.node.global_position)
			if screen.distance_to(spray_pos) < CLEAN_RADIUS_PX:
				p.dirty = maxf(p.dirty - CLEAN_RATE * delta, 0.0)
				var mat: StandardMaterial3D = p.mat
				mat.albedo_color = DIRT.lerp(p.true_color, 1.0 - p.dirty)
				cleaned_any = true
				if p.dirty <= 0.0 and sparkle_cd <= 0.0:
					sparkle_cd = 0.1
					AudioManager.play_sfx(SFX_CLEAN, 0.1, randf_range(0.95, 1.2))
					Haptics.light()
					Kit.burst(self, p.node.global_position, Color.WHITE, 6, 2.0)
		if cleaned_any:
			_refresh()
	else:
		jet.emitting = false
	_check_done()


func clean_fraction() -> float:
	if panels.is_empty():
		return 0.0
	var total := 0.0
	for p: Dictionary in panels:
		total += 1.0 - p.dirty
	return total / panels.size()


func _check_done() -> void:
	if clean_fraction() < 0.999:
		return
	state = State.RESULT
	AudioManager.play_sfx(SFX_DONE)
	Haptics.medium()
	for i in 4:
		Kit.burst(self, object_root.position + Vector3(randf_range(-1.5, 1.5), 1.5, 0.5),
			Kit.CANDY[i], 26, 7.0)
	level += 1
	SaveManager.set_value(LEVEL_KEY, level)
	Analytics.log_event("game_over", {"level": level - 1})
	AdsManager.round_finished()
	overlay.title.text = "CHAMAK GAYA! ✨"
	overlay.body.text = "%s — spotless\n\ntap for the next dirty thing" \
		% OBJECT_NAMES[(level - 2) % OBJECT_NAMES.size()]
	overlay.panel.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if state == State.RESULT:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed and not restarting:
			restarting = true
			if AdsManager.maybe_show_interstitial():
				await AdsManager.interstitial_closed
			get_tree().reload_current_scene()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		spraying = touch.pressed
		spray_pos = touch.position
	elif event is InputEventScreenDrag:
		spray_pos = (event as InputEventScreenDrag).position


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "foam" or state != State.WASHING:
		return
	foam_used = true
	var budget := int(panels.size() * 0.25)
	for p: Dictionary in panels:
		if budget <= 0:
			break
		if p.dirty > 0.0:
			p.dirty = 0.0
			var mat: StandardMaterial3D = p.mat
			mat.albedo_color = p.true_color
			budget -= 1
	AudioManager.play_sfx(SFX_DONE)
	Haptics.medium()
	Kit.burst(self, object_root.position + Vector3.UP * 1.5, Color.WHITE, 40, 7.0)
	Analytics.log_event("foam_used")
	_refresh()


# --- object building --------------------------------------------------------

func _panel(pos: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = DIRT.lerp(color, 0.0)
	node.material_override = mat
	node.position = pos
	object_root.add_child(node)
	panels.append({ "node": node, "mat": mat, "true_color": color, "dirty": 1.0 })


func _build_object() -> void:
	match (level - 1) % OBJECT_NAMES.size():
		0: _build_rickshaw()
		1: _build_statue()
		2: _build_tank()


func _build_rickshaw() -> void:
	# proper auto proportions: green body shell, yellow canopy, slanted
	# windshield, three wheels with fenders — every box is a washable panel
	for side: float in [-0.72, 0.72]:
		for ix in 4:
			for iy in 2:
				_panel(Vector3(-0.8 + ix * 0.55, 0.55 + iy * 0.45, side),
					Vector3(0.53, 0.43, 0.1), Kit.LIME)
	# rear panel
	for ix in 3:
		for iy in 2:
			_panel(Vector3(1.0, 0.55 + iy * 0.45, -0.48 + ix * 0.48),
				Vector3(0.1, 0.43, 0.46), Kit.LIME)
	# slanted windshield frame
	for ix in 3:
		_panel(Vector3(-1.28 + ix * 0.06, 0.9 + ix * 0.28, 0.0),
			Vector3(0.1, 0.3, 1.3), Kit.SKY.lightened(0.2) if ix == 1 else Kit.LIME)
	# canopy: two angled rows meeting at a ridge
	for ix in 4:
		_panel(Vector3(-0.85 + ix * 0.55, 1.62, 0.42), Vector3(0.53, 0.1, 0.5), Kit.SUN)
		_panel(Vector3(-0.85 + ix * 0.55, 1.68, -0.1), Vector3(0.53, 0.1, 0.5), Kit.SUN)
	# headlight + grill
	_panel(Vector3(-1.42, 0.62, 0.0), Vector3(0.12, 0.3, 0.5), Kit.CREAM)
	# three wheels: front centre + two rear, with fenders
	for seg in 4:
		var a := seg * TAU / 4.0
		_panel(Vector3(-1.25 + cos(a) * 0.2, 0.3 + sin(a) * 0.2, 0.0),
			Vector3(0.2, 0.2, 0.12), Kit.INK.lightened(0.25))
	for side: float in [-0.8, 0.8]:
		for seg in 4:
			var a := seg * TAU / 4.0
			_panel(Vector3(0.85 + cos(a) * 0.22, 0.32 + sin(a) * 0.22, side),
				Vector3(0.22, 0.22, 0.1), Kit.INK.lightened(0.25))
		_panel(Vector3(0.85, 0.64, side), Vector3(0.6, 0.12, 0.14), Kit.TEAL)


func _build_statue() -> void:
	# a chunky elephant: body, head, trunk, legs, ears
	for ix in 4:
		for iy in 3:
			for iz in 2:
				_panel(Vector3(-0.75 + ix * 0.5, 0.9 + iy * 0.5, -0.25 + iz * 0.5),
					Vector3(0.48, 0.48, 0.48), Kit.SKY)
	for iy in 2:
		for iz in 2:
			_panel(Vector3(-1.3, 1.6 + iy * 0.5, -0.25 + iz * 0.5),
				Vector3(0.48, 0.48, 0.48), Kit.SKY.lightened(0.15))
	for k in 4:
		_panel(Vector3(-1.55, 1.3 - k * 0.3, 0.0), Vector3(0.24, 0.28, 0.24), Kit.TEAL)
	for lx: float in [-0.6, 0.7]:
		for lz: float in [-0.3, 0.3]:
			_panel(Vector3(lx, 0.4, lz), Vector3(0.4, 0.8, 0.4), Kit.SKY.darkened(0.1))
	for side: float in [-0.6, 0.6]:
		_panel(Vector3(-1.1, 2.1, side), Vector3(0.15, 0.7, 0.5), Kit.PINK)


func _build_tank() -> void:
	# cylinder tank from panel rings + legs + cap
	for ring in 4:
		for seg in 10:
			var a := seg * TAU / 10.0
			_panel(Vector3(cos(a) * 1.0, 0.9 + ring * 0.55, sin(a) * 1.0),
				Vector3(0.5, 0.52, 0.2), Kit.CORAL if ring % 2 == 0 else Kit.CREAM)
	for seg in 6:
		var a := seg * TAU / 6.0
		_panel(Vector3(cos(a) * 0.55, 3.2, sin(a) * 0.55), Vector3(0.5, 0.15, 0.4), Kit.TEAL)
	for lx: float in [-0.8, 0.8]:
		for lz: float in [-0.8, 0.8]:
			_panel(Vector3(lx, 0.35, lz), Vector3(0.22, 0.7, 0.22), Kit.INK.lightened(0.3))


# --- ui ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	level_label = Kit.label("DHULAI 1", 80, Kit.TEAL)
	level_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_top = 44.0
	level_label.offset_bottom = 146.0
	layer.add_child(level_label)
	meter_label = Kit.label("0% clean", 56, Color.WHITE)
	meter_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	meter_label.offset_top = 150.0
	meter_label.offset_bottom = 225.0
	layer.add_child(meter_label)
	var hint := Kit.label("hold & drag to SPRAY", 42, Color(1, 1, 1, 0.8))
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 1760.0
	hint.offset_bottom = 1820.0
	layer.add_child(hint)
	foam_button = Kit.button("FOAM BLAST · AD", 42, Kit.PURPLE)
	foam_button.position = Vector2(680.0, 250.0)
	foam_button.size = Vector2(360.0, 100.0)
	foam_button.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("foam"))
	layer.add_child(foam_button)
	overlay = Kit.overlay("", Kit.MINT)
	layer.add_child(overlay.panel)
	_refresh()


func _refresh() -> void:
	level_label.text = "DHULAI %d — %s" % [level, OBJECT_NAMES[(level - 1) % OBJECT_NAMES.size()]]
	meter_label.text = "%d%% clean" % int(clean_fraction() * 100.0)
	foam_button.visible = not foam_used and AdsManager.is_rewarded_ready()
