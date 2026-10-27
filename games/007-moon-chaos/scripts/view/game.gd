extends Node3D
## Greybox view for the core loop: sweep, carry, dump, launch, upgrade, next
## zone. Shapes only, no art.
##
## The world is built in code rather than authored as a .tscn on purpose: while
## the loop is still being tuned, primitives in script are far quicker to
## reshape than hand-edited scene files. Once the loop is confirmed fun on a
## phone this becomes real scenes with real art.
##
## The sim is authoritative for position and state; everything here only reads
## it and draws. All autoload calls live in this layer, never in sim/.

const GROUND_Y: float = 0.0
const DUST_Y: float = 0.02
const PLAYER_RADIUS: float = 0.28
## Dark lunar rock around the playable zone, so the camera never shows the
## void past the edge of the world and the zone reads as a bounded area.
const APRON_MARGIN: float = 30.0
## How far inside the zone the camera stops following, for the same reason.
const CAMERA_EDGE_MARGIN: float = 1.5
## Bias toward the zone centre. Standing at the depot on the zone edge would
## otherwise spend most of the screen on empty rock behind the player.
const CAMERA_CENTRE_BIAS: float = 0.3

var sim: GameSim = null

var _hud: Control = null
var _rig: CameraRig = null
var _apron: MeshInstance3D = null
var _ground: MeshInstance3D = null
var _dust: DustRenderer = null
var _player: Node3D = null
var _depot: Node3D = null
var _rocket: Node3D = null
var _sweep_fx: GPUParticles3D = null
var _rocket_home: Vector3 = Vector3.ZERO


func _ready() -> void:
	sim = Session.sim
	if sim == null:
		push_error("Game: Session has no sim — check autoload order in project.godot")
		return

	_hud = get_node_or_null("HudLayer/Hud")
	_build_static_world()
	_build_zone()
	_connect_sim()

	if _hud != null and _hud.has_method("bind"):
		_hud.bind(sim, self)

	Analytics.log_event("app_open")
	# Offline earnings were credited by Session before the scene existed.
	if Session.pending_offline != null and _hud != null and _hud.has_method("show_offline"):
		_hud.show_offline(Session.pending_offline)
		Session.pending_offline = null


func _process(delta: float) -> void:
	if sim == null:
		return
	sim.step(_input_dir(), delta)
	_sync(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _rig != null:
		_rig.handle_input(event)


# --- world construction ---------------------------------------------------

func _build_static_world() -> void:
	# One shadowless directional light: the ground and dust are unshaded, so
	# this only gives the player, depot and rocket some form.
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	light.light_energy = 1.1
	light.shadow_enabled = false
	add_child(light)

	_rig = CameraRig.new()
	add_child(_rig)

	# Surrounding rock sits just below the zone floor and extends well past it.
	_apron = MeshInstance3D.new()
	_apron.position.y = GROUND_Y - 0.02
	var apron_mat := StandardMaterial3D.new()
	apron_mat.albedo_color = Color(0.16, 0.17, 0.21)
	apron_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_apron.material_override = apron_mat
	add_child(_apron)

	_ground = MeshInstance3D.new()
	var ground_mat := StandardMaterial3D.new()
	# Clean lunar surface: the white-blue the dust is swept away to reveal.
	ground_mat.albedo_color = Color(0.91, 0.95, 1.0)
	ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ground.material_override = ground_mat
	add_child(_ground)

	_dust = DustRenderer.new()
	_dust.position.y = DUST_Y
	add_child(_dust)

	_player = _make_player()
	add_child(_player)

	_depot = _make_depot()
	add_child(_depot)

	_rocket = _make_rocket()
	add_child(_rocket)


func _make_player() -> Node3D:
	var root := Node3D.new()

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = 1.0
	body.mesh = capsule
	body.position.y = 0.5
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.95, 0.78, 0.25)
	body.material_override = body_mat
	root.add_child(body)

	# Stand-in for the tool, so the sweep radius is visible while greyboxing.
	var tool_node := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.4
	disc.bottom_radius = 0.4
	disc.height = 0.04
	tool_node.mesh = disc
	tool_node.position = Vector3(0.0, 0.03, 0.0)
	var tool_mat := StandardMaterial3D.new()
	tool_mat.albedo_color = Color(0.2, 0.9, 0.8, 0.35)
	tool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tool_node.material_override = tool_mat
	tool_node.name = "ToolDisc"
	root.add_child(tool_node)

	_sweep_fx = _make_sweep_particles()
	root.add_child(_sweep_fx)
	return root


func _make_sweep_particles() -> GPUParticles3D:
	var fx := GPUParticles3D.new()
	fx.amount = 24
	fx.lifetime = 0.7
	fx.emitting = false
	fx.position.y = 0.1

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.35
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 45.0
	process.initial_velocity_min = 0.4
	process.initial_velocity_max = 1.2
	# Moon gravity: dust should float, not drop like on Earth.
	process.gravity = Vector3(0.0, -1.6, 0.0)
	process.scale_min = 0.3
	process.scale_max = 0.7
	fx.process_material = process

	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.1
	dot.radial_segments = 6
	dot.rings = 3
	var dot_mat := StandardMaterial3D.new()
	dot_mat.albedo_color = Color(0.75, 0.78, 0.85)
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot.material = dot_mat
	fx.draw_pass_1 = dot
	return fx


func _make_depot() -> Node3D:
	var root := Node3D.new()
	var pad := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 0.18, 1.6)
	pad.mesh = box
	pad.position.y = 0.09
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.34, 0.42)
	pad.material_override = mat
	root.add_child(pad)
	return root


func _make_rocket() -> Node3D:
	var root := Node3D.new()

	var body := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.22
	tube.bottom_radius = 0.3
	tube.height = 1.4
	body.mesh = tube
	body.position.y = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.9, 0.95)
	body.material_override = mat
	root.add_child(body)

	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.22
	cone.height = 0.45
	nose.mesh = cone
	nose.position.y = 1.62
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.95, 0.35, 0.3)
	nose.material_override = nose_mat
	root.add_child(nose)
	return root


## Rebuild everything that depends on which zone is active.
func _build_zone() -> void:
	var def: Balance.ZoneDef = sim.active_zone_def()
	var zone: ZoneState = sim.active_zone()
	if def == null or zone == null:
		return

	var extent: Vector2 = def.extent()
	var plane := PlaneMesh.new()
	plane.size = extent
	_ground.mesh = plane
	_ground.position = Vector3(0.0, GROUND_Y, 0.0)

	var apron_plane := PlaneMesh.new()
	apron_plane.size = extent + Vector2(APRON_MARGIN, APRON_MARGIN)
	_apron.mesh = apron_plane

	_dust.setup(zone.grid, def, sim.balance)

	var depot_world: Vector3 = local_to_world(sim.depot_local_pos())
	_depot.global_position = depot_world
	# Rocket stands just beside the pad so it never hides the dump target.
	_rocket_home = depot_world + Vector3(1.6, 0.0, 0.0)
	_rocket.global_position = _rocket_home

	_player.global_position = local_to_world(sim.player.pos)
	_rig.snap_to(_camera_target(_player.global_position))
	_update_tool_disc()


## Stop the camera short of the zone edge, so walking into a corner shows the
## corner rather than a screenful of empty space.
func _camera_target(player_world: Vector3) -> Vector3:
	var def: Balance.ZoneDef = sim.active_zone_def()
	if def == null:
		return player_world
	var extent: Vector2 = def.extent()
	var biased: Vector3 = player_world.lerp(Vector3(0.0, player_world.y, 0.0), CAMERA_CENTRE_BIAS)
	var limit_x: float = maxf(extent.x * 0.5 - CAMERA_EDGE_MARGIN, 0.0)
	var limit_z: float = maxf(extent.y * 0.5 - CAMERA_EDGE_MARGIN, 0.0)
	return Vector3(
		clampf(biased.x, -limit_x, limit_x),
		player_world.y,
		clampf(biased.z, -limit_z, limit_z)
	)


# --- sim plumbing ---------------------------------------------------------

func _connect_sim() -> void:
	sim.dust_swept.connect(_on_dust_swept)
	sim.zone_completed.connect(_on_zone_completed)
	sim.zone_unlocked.connect(_on_zone_unlocked)
	sim.shipment_launch_started.connect(_on_launch_started)
	sim.shipment_launched.connect(_on_launched)
	sim.tool_upgraded.connect(_on_tool_upgraded)
	sim.carry_full.connect(_on_carry_full)


func _on_dust_swept(result: DustGrid.SweepResult) -> void:
	if result.had_change:
		_dust.refresh_rect(result.dirty_rect())
	if result.crystals_found > 0:
		Haptics.light()


func _on_zone_completed(zone_id: String) -> void:
	Haptics.heavy()
	AudioManager.play_sfx(null)
	# A completed zone is the only natural break this game has, and the only
	# place CLAUDE.md and the design both allow an interstitial.
	AdsManager.round_finished()
	AdsManager.maybe_show_interstitial()
	Analytics.log_event("zone_completed", {"zone": zone_id})
	if _hud != null and _hud.has_method("show_zone_complete"):
		_hud.show_zone_complete(zone_id)


func _on_zone_unlocked(_zone_id: String) -> void:
	Haptics.medium()
	var next: int = sim.active_zone_index + 1
	if next < sim.zones.size() and (sim.zones[next] as ZoneState).unlocked:
		if sim.set_active_zone(next):
			_build_zone()


func _on_launch_started() -> void:
	Haptics.heavy()
	var tween := create_tween()
	tween.tween_property(_rocket, "global_position",
			_rocket_home + Vector3(0.0, 26.0, 0.0), sim.balance.rocket_launch_seconds)
	tween.tween_callback(func() -> void:
		_rocket.global_position = _rocket_home
	)


func _on_launched(payout: int, payload: int) -> void:
	Haptics.medium()
	if _hud != null and _hud.has_method("show_payout"):
		_hud.show_payout(payout, payload)


func _on_tool_upgraded(_tier: int) -> void:
	Haptics.medium()
	_update_tool_disc()


func _on_carry_full() -> void:
	Haptics.light()


# --- per-frame sync -------------------------------------------------------

func _sync(delta: float) -> void:
	var target: Vector3 = local_to_world(sim.player.pos)
	_player.global_position = target
	_rig.follow(_camera_target(target), delta)

	# Particles only while dust is actually coming up.
	var sweeping: bool = sim.player.carry_total() < sim.carry_capacity() \
			and sim.active_zone() != null \
			and sim.active_zone().grid.dust_at(sim.cell_of(sim.player.pos)) > 0
	if _sweep_fx.emitting != sweeping:
		_sweep_fx.emitting = sweeping


func _update_tool_disc() -> void:
	var disc: MeshInstance3D = _player.get_node_or_null("ToolDisc")
	var def: Balance.ZoneDef = sim.active_zone_def()
	if disc == null or def == null:
		return
	# Show the real sweep footprint, so a tool upgrade is visibly bigger.
	var radius: float = (float(sim.current_tool().radius_cells) + 0.5) * def.cell_size
	var cyl := disc.mesh as CylinderMesh
	cyl.top_radius = radius
	cyl.bottom_radius = radius


func _input_dir() -> Vector2:
	# Keyboard for desktop greyboxing; the joystick is the real control.
	var keys: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if keys.length_squared() > 0.01:
		return keys
	if _hud != null and _hud.has_method("joystick_vector"):
		return _hud.joystick_vector()
	return Vector2.ZERO


# --- helpers --------------------------------------------------------------

## Grid-plane metres (corner origin) to world space (zone centred on origin).
func local_to_world(local: Vector2) -> Vector3:
	var def: Balance.ZoneDef = sim.active_zone_def()
	if def == null:
		return Vector3.ZERO
	var extent: Vector2 = def.extent()
	return Vector3(local.x - extent.x * 0.5, GROUND_Y, local.y - extent.y * 0.5)


## Called by the HUD after it changes zones through an upgrade panel.
func rebuild_zone() -> void:
	_build_zone()
