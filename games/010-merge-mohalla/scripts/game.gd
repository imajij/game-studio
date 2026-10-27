extends Node2D
## Merge Mohalla — drop desi street objects into the gali; two of a kind merge
## into the next, bigger thing, all the way to the Cursed Hybrid. Overfill the
## gali and it's game over. Rewarded ad = Jhadu Sweep (clears the small stuff).

enum State { PLAYING, GAME_OVER }

const BEST_KEY: String = "best"
const DISCOVERED_KEY: String = "discovered"

const WALL_LEFT: float = 70.0
const WALL_RIGHT: float = 1010.0
const FLOOR_Y: float = 1660.0
const DROP_Y: float = 300.0
const DANGER_Y: float = 430.0
const DANGER_SEC: float = 1.8
const DROP_COOLDOWN: float = 0.5
const MAX_DROP_TIER: int = 4
const SWEEP_COOLDOWN: float = 120.0
const RESTART_LOCKOUT_SEC: float = 0.6

const SFX_DROP: AudioStream = preload("res://assets/audio/drop.wav")
const SFX_MERGE: AudioStream = preload("res://assets/audio/merge.wav")
const SFX_BIG: AudioStream = preload("res://assets/audio/big_merge.wav")
const SFX_WARN: AudioStream = preload("res://assets/audio/warn.wav")
const SFX_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var state: State = State.PLAYING
var score: int = 0
var best: int = 0
var next_tier: int = 0
var drop_x: float = 540.0
var drop_ready_at: float = 0.0
var danger_time: float = 0.0
var warned: bool = false
var sweep_ready_at: float = 0.0
var discovered: Array = []
var restarting: bool = false
var game_over_at_sec: float = 0.0

@onready var deco: Deco = $Deco
@onready var container: Node2D = $Container
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var next_label: Label = $UI/NextLabel
@onready var sweep_button: Button = $UI/SweepButton
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_score_label: Label = $UI/GameOverPanel/FinalScore

func _ready() -> void:
	randomize()
	deco.painter = _paint
	sweep_button.pressed.connect(_on_sweep_pressed)
	AdsManager.rewarded_earned.connect(_on_rewarded_earned)
	AdsManager.rewarded_closed.connect(func() -> void: get_tree().paused = false)
	AdsManager.rewarded_unavailable.connect(func() -> void: get_tree().paused = false)
	best = int(SaveManager.get_value(BEST_KEY, 0))
	var saved: Variant = SaveManager.get_value(DISCOVERED_KEY, [0])
	discovered = saved if saved is Array else [0]
	_build_walls()
	next_tier = randi_range(0, 1)
	Analytics.log_event("round_start")
	_refresh_ui()


func _process(delta: float) -> void:
	deco.queue_redraw()
	if state != State.PLAYING:
		return
	# overflow check: slow bodies sitting above the danger line
	var in_danger := false
	for child in container.get_children():
		var item := child as MohallaItem
		if item == null or item.merging:
			continue
		if item.position.y - item.radius() < DANGER_Y \
				and item.linear_velocity.length() < 60.0:
			in_danger = true
			break
	if in_danger:
		danger_time += delta
		if not warned and danger_time > 0.5:
			warned = true
			AudioManager.play_sfx(SFX_WARN)
			Haptics.medium()
		if danger_time >= DANGER_SEC:
			_game_over()
	else:
		danger_time = maxf(danger_time - delta * 2.0, 0.0)
		warned = false
	sweep_button.visible = AdsManager.is_rewarded_ready() \
		and _now_sec() >= sweep_ready_at and container.get_child_count() > 8


func _unhandled_input(event: InputEvent) -> void:
	if state == State.GAME_OVER:
		var touch := event as InputEventScreenTouch
		if touch != null and touch.pressed:
			_try_restart()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		drop_x = clampf(touch.position.x, WALL_LEFT + 60.0, WALL_RIGHT - 60.0)
		if not touch.pressed:
			_drop()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		drop_x = clampf(drag.position.x, WALL_LEFT + 60.0, WALL_RIGHT - 60.0)


func _drop() -> void:
	if _now_sec() < drop_ready_at:
		return
	drop_ready_at = _now_sec() + DROP_COOLDOWN
	var item := MohallaItem.new()
	item.position = Vector2(clampf(drop_x, WALL_LEFT + MohallaItem.TIERS[next_tier][1] + 8.0,
		WALL_RIGHT - MohallaItem.TIERS[next_tier][1] - 8.0), DROP_Y)
	container.add_child(item)
	item.setup(next_tier, _on_merge)
	AudioManager.play_sfx(SFX_DROP, 0.1)
	Haptics.light()
	next_tier = randi_range(0, MAX_DROP_TIER - 1) if randf() < 0.85 else MAX_DROP_TIER
	_refresh_ui()


func _on_merge(a: MohallaItem, b: MohallaItem) -> void:
	var tier := a.tier
	var at := (a.position + b.position) / 2.0
	a.queue_free()
	b.queue_free()
	if tier >= MohallaItem.TIERS.size() - 1:
		score += 1000
		AudioManager.play_sfx(SFX_BIG)
		_burst(at, Color(0.3, 0.9, 0.55), 40)
		Haptics.heavy()
	else:
		var merged := MohallaItem.new()
		merged.position = at
		container.add_child(merged)
		merged.setup(tier + 1, _on_merge)
		score += (tier + 1) * 10
		if not discovered.has(tier + 1):
			discovered.append(tier + 1)
			SaveManager.set_value(DISCOVERED_KEY, discovered)
			AudioManager.play_sfx(SFX_BIG)
			_burst(at, MohallaItem.tier_color(tier + 1), 30)
		else:
			AudioManager.play_sfx(SFX_MERGE, 0.05, 1.0 + tier * 0.08)
		Haptics.light()
	if score > best:
		best = score
		SaveManager.set_value(BEST_KEY, best)
	_refresh_ui()


func _on_sweep_pressed() -> void:
	if state != State.PLAYING:
		return
	AudioManager.play_sfx(SFX_TAP)
	AdsManager.show_rewarded("sweep")


func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type != "sweep" or state != State.PLAYING:
		return
	sweep_ready_at = _now_sec() + SWEEP_COOLDOWN
	var swept := 0
	for child in container.get_children():
		var item := child as MohallaItem
		if item != null and item.tier <= 1:
			_burst(item.position, MohallaItem.tier_color(item.tier), 10)
			item.queue_free()
			swept += 1
	Analytics.log_event("sweep_used", {"count": swept})
	AudioManager.play_sfx(SFX_BIG)
	Haptics.medium()


func _game_over() -> void:
	state = State.GAME_OVER
	game_over_at_sec = _now_sec()
	SaveManager.set_value(BEST_KEY, best)
	Analytics.log_event("game_over", {"score": score})
	AdsManager.round_finished()
	AudioManager.play_sfx(SFX_GAME_OVER)
	Haptics.heavy()
	final_score_label.text = "SCORE %d\nBEST %d\nFOUND %d / %d THINGS" \
		% [score, best, discovered.size(), MohallaItem.TIERS.size()]
	game_over_panel.visible = true


func _try_restart() -> void:
	if restarting or _now_sec() - game_over_at_sec < RESTART_LOCKOUT_SEC:
		return
	restarting = true
	if AdsManager.maybe_show_interstitial():
		await AdsManager.interstitial_closed
	get_tree().reload_current_scene()


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	add_child(walls)
	for seg: Array in [
		[Vector2(WALL_LEFT, 200.0), Vector2(WALL_LEFT, FLOOR_Y)],
		[Vector2(WALL_RIGHT, 200.0), Vector2(WALL_RIGHT, FLOOR_Y)],
		[Vector2(WALL_LEFT, FLOOR_Y), Vector2(WALL_RIGHT, FLOOR_Y)],
	]:
		var shape := CollisionShape2D.new()
		var segment := SegmentShape2D.new()
		segment.a = seg[0]
		segment.b = seg[1]
		shape.shape = segment
		walls.add_child(shape)


func _burst(at: Vector2, color: Color, amount: int) -> void:
	var burst := CPUParticles2D.new()
	burst.position = at
	burst.one_shot = true
	burst.emitting = true
	burst.amount = amount
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2(0.0, 600.0)
	burst.initial_velocity_min = 220.0
	burst.initial_velocity_max = 460.0
	burst.scale_amount_min = 4.0
	burst.scale_amount_max = 9.0
	burst.color = color
	add_child(burst)
	burst.finished.connect(burst.queue_free)


func _refresh_ui() -> void:
	score_label.text = str(score)
	best_label.text = "BEST %d" % best
	next_label.text = "NEXT: %s" % String(MohallaItem.TIERS[next_tier][0])


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


func _paint(canvas: CanvasItem) -> void:
	# gali walls
	canvas.draw_rect(Rect2(WALL_LEFT - 26.0, 240.0, 26.0, FLOOR_Y - 214.0), Color(0.42, 0.33, 0.28))
	canvas.draw_rect(Rect2(WALL_RIGHT, 240.0, 26.0, FLOOR_Y - 214.0), Color(0.42, 0.33, 0.28))
	canvas.draw_rect(Rect2(WALL_LEFT - 26.0, FLOOR_Y, WALL_RIGHT - WALL_LEFT + 52.0, 30.0),
		Color(0.42, 0.33, 0.28))
	# danger line
	var danger_color := Color(0.9, 0.3, 0.3, 0.5 + 0.5 * clampf(danger_time / DANGER_SEC, 0.0, 1.0)) \
		if danger_time > 0.0 else Color(0.9, 0.3, 0.3, 0.25)
	canvas.draw_dashed_line(Vector2(WALL_LEFT, DANGER_Y), Vector2(WALL_RIGHT, DANGER_Y),
		danger_color, 6.0, 26.0)
	# drop preview
	if state == State.PLAYING:
		var r: float = MohallaItem.TIERS[next_tier][1]
		var color: Color = MohallaItem.TIERS[next_tier][2]
		canvas.draw_circle(Vector2(drop_x, DROP_Y), r,
			Color(color.r, color.g, color.b, 0.4))
		canvas.draw_dashed_line(Vector2(drop_x, DROP_Y + r), Vector2(drop_x, FLOOR_Y),
			Color(1, 1, 1, 0.15), 4.0, 22.0)
