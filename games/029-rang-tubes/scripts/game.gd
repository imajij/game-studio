extends Node3D
## Rang Tubes 3D — ball-sort puzzle in glass tubes. Tap a tube to lift its top
## ball, tap another to pour every matching ball over. One color per tube wins.
## Levels are reverse-shuffled from solved, so every vat is provably solvable.
## Rewarded ad = +5 undos; interstitial at result screens.

enum State { PLAYING, RESULT }

const BALL_R: float = 0.34
const TUBE_CAP: int = 4
const LEVEL_KEY: String = "level"
const FREE_UNDOS: int = 3

const SFX_POUR: AudioStream = preload("res://assets/audio/pour.wav")
const SFX_PLACE: AudioStream = preload("res://assets/audio/place.wav")
const SFX_WIN: AudioStream = preload("res://assets/audio/win.wav")
const SFX_UNDO: AudioStream = preload("res://assets/audio/undo.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var level: int = 1
var tubes: Array = []      # arrays of color indices (bottom..top)
var tube_nodes: Array = [] # Node3D roots
var ball_nodes: Array = [] # per-tube arrays of MeshInstance3D
var selected: int = -1
var undos: int = FREE_UNDOS
var history: Array = []    # {from, to, n}
var restarting: bool = false

var cam: Camera3D = null
var level_label: Label = null
var undo_button: Button = null
var undo_ad_button: Button = null
var overlay: Dictionary = {}

const PALETTE: Array[Color] = [Kit.PINK, Kit.SUN, Kit.TEAL, Kit.LIME, Kit.PURPLE, Kit.ORANGE, Kit.SKY]

func _ready() -> void:
	randomize()
	level = int(SaveManager.get_value(LEVEL_KEY, 1))
	Kit.sky(self, Color(0.95, 0.75, 0.85), Color(1.0, 0.92, 0.75), Color(0.85, 0.7, 0.8))
	cam = Camera3D.new()
	cam.position = Vector3(0.0, 0.6, 10.5)
	cam.fov = 46.0
	add_child(cam)
	var backdrop := Kit.texbox(Vector3(18.0, 14.0, 0.2), "tex1", Color(0.98, 0.9, 0.92), 1.0)
	backdrop.position = Vector3(0.0, 1.0, -3.0)
	add_child(backdrop)
	var shelf := Kit.box(Vector3(14.0, 0.4, 3.0), Color(0.8, 0.6, 0.45), true)
	shelf.position = Vector3(0.0, -3.4, 0.0)
	add_child(shelf)
	_build_level()
	_build_ui()
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	Analytics.log_event("round_start")
	_refresh()


func colors_for_level() -> int:
	return clampi(3 + level / 3, 3, 7)


func _build_level() -> void:
	var colors := colors_for_level()
	var count := colors + 2
	# solved state
	tubes.clear()
	for c in colors:
		var t: Array = []
		for k in TUBE_CAP:
			t.append(c)
		tubes.append(t)
	tubes.append([])
	tubes.append([])
	# reverse shuffle: random legal back-moves from solved
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 90001
	for i in 60 + level * 10:
		var from := rng.randi_range(0, count - 1)
		var to := rng.randi_range(0, count - 1)
		if from == to or tubes[from].is_empty() or tubes[to].size() >= TUBE_CAP:
			continue
		tubes[to].append(tubes[from].pop_back())
	# layout: two rows
	var per_row := int(ceil(count / 2.0))
	for i in count:
		var row := i / per_row
		var col := i % per_row
		var root := Node3D.new()
		root.position = Vector3((col - (per_row - 1) / 2.0) * 2.1, 1.2 - row * 4.4, 0.0)
		var glass := Kit.cyl(BALL_R + 0.12, TUBE_CAP * BALL_R * 2.0 + 0.4, Color(0.75, 0.9, 1.0, 0.22))
		glass.position.y = (TUBE_CAP * BALL_R * 2.0) / 2.0 - BALL_R
		root.add_child(glass)
		var base := Kit.cyl(BALL_R + 0.18, 0.15, Color(0.6, 0.75, 0.9))
		base.position.y = -BALL_R - 0.1
		root.add_child(base)
		add_child(root)
		tube_nodes.append(root)
		var balls: Array = []
		for k in tubes[i].size():
			var ball := Kit.sphere(BALL_R, PALETTE[tubes[i][k]], true)
			ball.position.y = k * BALL_R * 2.0
			root.add_child(ball)
			balls.append(ball)
		ball_nodes.append(balls)


func _top_run(t: Array) -> int:
	if t.is_empty():
		return 0
	var c: int = t.back()
	var n := 0
	for i in range(t.size() - 1, -1, -1):
		if t[i] == c:
			n += 1
		else:
			break
	return n


func _unhandled_input(event: InputEvent) -> void:
	if state == State.RESULT:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed and not restarting:
			restarting = true
			if AdsManager.maybe_show_interstitial():
				await AdsManager.interstitial_closed
			get_tree().reload_current_scene()
		return
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	var pick := -1
	var best_d := 120.0
	for i in tube_nodes.size():
		var screen := cam.unproject_position(tube_nodes[i].global_position + Vector3(0.0, 1.0, 0.0))
		var d := screen.distance_to(touch.position)
		if d < best_d:
			best_d = d
			pick = i
	if pick < 0:
		return
	if selected < 0:
		if tubes[pick].is_empty():
			return
		selected = pick
		AudioManager.play_sfx(SFX_TAP)
		_lift(pick, true)
	elif selected == pick:
		_lift(pick, false)
		selected = -1
	else:
		_pour(selected, pick)
		selected = -1


func _lift(i: int, up: bool) -> void:
	var balls: Array = ball_nodes[i]
	if balls.is_empty():
		return
	var top: Node3D = balls.back()
	var tween := create_tween()
	tween.tween_property(top, "position:y",
		(balls.size() - 1) * BALL_R * 2.0 + (1.2 if up else 0.0), 0.12)


func _pour(from: int, to: int) -> void:
	var src: Array = tubes[from]
	var dst: Array = tubes[to]
	if src.is_empty():
		_lift(from, false)
		return
	var color: int = src.back()
	if not dst.is_empty() and dst.back() != color:
		_lift(from, false)
		AudioManager.play_sfx(SFX_TAP)
		Haptics.light()
		return
	var run := _top_run(src)
	var space := TUBE_CAP - dst.size()
	var n := mini(run, space)
	if n <= 0:
		_lift(from, false)
		return
	history.append({ "from": from, "to": to, "n": n })
	AudioManager.play_sfx(SFX_POUR)
	Haptics.light()
	for k in n:
		src.pop_back()
		dst.append(color)
		var ball: Node3D = ball_nodes[from].pop_back()
		ball.get_parent().remove_child(ball)
		tube_nodes[to].add_child(ball)
		var idx: int = dst.size() - 1
		ball.position = Vector3(0.0, TUBE_CAP * BALL_R * 2.0 + 1.6, 0.0)
		var tween := create_tween()
		tween.tween_property(ball, "position:y", idx * BALL_R * 2.0, 0.16 + k * 0.05) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		ball_nodes[to].append(ball)
	AudioManager.play_sfx(SFX_PLACE, 0.05, 1.0 + dst.size() * 0.06)
	_refresh()
	_check_win()


func _check_win() -> void:
	for t: Array in tubes:
		if t.is_empty():
			continue
		if t.size() != TUBE_CAP:
			return
		for c in t:
			if c != t[0]:
				return
	state = State.RESULT
	level += 1
	SaveManager.set_value(LEVEL_KEY, level)
	AudioManager.play_sfx(SFX_WIN)
	Haptics.medium()
	for i in 4:
		Kit.burst(self, Vector3(randf_range(-3, 3), randf_range(-2, 2), 1.0), Kit.CANDY[i], 26, 7.0)
	Analytics.log_event("game_over", {"won": true, "level": level - 1})
	AdsManager.round_finished()
	overlay.title.text = "SORTED!"
	overlay.body.text = "vat %d done\n\ntap for vat %d" % [level - 1, level]
	overlay.panel.visible = true


func _on_undo() -> void:
	if history.is_empty() or undos <= 0 or state != State.PLAYING:
		return
	undos -= 1
	var move: Dictionary = history.pop_back()
	AudioManager.play_sfx(SFX_UNDO)
	for k in int(move.n):
		var color: int = tubes[move.to].pop_back()
		tubes[move.from].append(color)
		var ball: Node3D = ball_nodes[move.to].pop_back()
		ball.get_parent().remove_child(ball)
		tube_nodes[move.from].add_child(ball)
		ball.position = Vector3(0.0, (tubes[move.from].size() - 1) * BALL_R * 2.0, 0.0)
		ball_nodes[move.from].append(ball)
	_refresh()


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "undos":
		return
	undos += 5
	Analytics.log_event("undos_bought")
	Haptics.medium()
	_refresh()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	level_label = Kit.label("VAT 1", 80, Kit.MAGENTA)
	level_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_top = 44.0
	level_label.offset_bottom = 146.0
	layer.add_child(level_label)
	undo_button = Kit.button("UNDO (3)", 44, Kit.TEAL)
	undo_button.position = Vector2(60.0, 1740.0)
	undo_button.size = Vector2(300.0, 110.0)
	undo_button.pressed.connect(_on_undo)
	layer.add_child(undo_button)
	undo_ad_button = Kit.button("+5 UNDO · AD", 42, Kit.PURPLE)
	undo_ad_button.position = Vector2(680.0, 1740.0)
	undo_ad_button.size = Vector2(340.0, 110.0)
	undo_ad_button.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX_TAP)
		AdsManager.show_rewarded("undos"))
	layer.add_child(undo_ad_button)
	overlay = Kit.overlay("", Kit.MAGENTA)
	layer.add_child(overlay.panel)


func _refresh() -> void:
	level_label.text = "VAT %d" % level
	undo_button.text = "UNDO (%d)" % undos
	undo_button.disabled = history.is_empty() or undos <= 0
	undo_ad_button.visible = AdsManager.is_rewarded_ready()
