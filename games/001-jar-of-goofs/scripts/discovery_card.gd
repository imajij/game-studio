class_name DiscoveryCard
extends CanvasLayer
## "NEW GOOF UNLOCKED" overlay. Game.gd enqueues first discoveries; the card
## pauses the tree while visible and advances on tap. Runs while paused.

const DIM_COLOR: Color = Color(0.08, 0.06, 0.14, 0.86)
const TITLE_COLOR: Color = Color(1.0, 0.84, 0.35)
const SPRITE_SIDE: float = 460.0
const POP_SEC: float = 0.35
## Ignore taps briefly so a stray tap can't skip a fresh card.
const TAP_LOCKOUT_SEC: float = 0.4

const FONT: FontFile = preload("res://assets/fonts/Baloo2.ttf")
const SFX_UNLOCK: AudioStream = preload("res://assets/audio/unlock.wav")

var _queue: Array[int] = []
var _root: Control
var _sprite: TextureRect
var _name_label: Label
var _bio_label: Label
var _burst: CPUParticles2D
var _shown_at_sec: float = 0.0

func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	_root.gui_input.connect(_on_gui_input)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var title := _make_label("NEW GOOF UNLOCKED!", 72, TITLE_COLOR)
	title.offset_top = 380.0
	title.offset_bottom = 480.0
	_root.add_child(title)

	_burst = CPUParticles2D.new()
	_burst.position = Vector2(540.0, 770.0)
	_burst.one_shot = true
	_burst.emitting = false
	_burst.amount = 28
	_burst.lifetime = 0.9
	_burst.explosiveness = 1.0
	_burst.spread = 180.0
	_burst.gravity = Vector2(0.0, 500.0)
	_burst.initial_velocity_min = 300.0
	_burst.initial_velocity_max = 650.0
	_burst.scale_amount_min = 5.0
	_burst.scale_amount_max = 10.0
	_burst.color = TITLE_COLOR
	_root.add_child(_burst)

	_sprite = TextureRect.new()
	_sprite.position = Vector2(540.0 - SPRITE_SIDE / 2.0, 770.0 - SPRITE_SIDE / 2.0)
	_sprite.size = Vector2(SPRITE_SIDE, SPRITE_SIDE)
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.pivot_offset = Vector2(SPRITE_SIDE / 2.0, SPRITE_SIDE / 2.0)
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_sprite)

	_name_label = _make_label("", 84, Color.WHITE)
	_name_label.offset_top = 1040.0
	_name_label.offset_bottom = 1150.0
	_root.add_child(_name_label)

	_bio_label = _make_label("", 44, Color(1.0, 1.0, 1.0, 0.85))
	_bio_label.offset_left = 120.0
	_bio_label.offset_right = 960.0
	_bio_label.offset_top = 1160.0
	_bio_label.offset_bottom = 1300.0
	_bio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_bio_label)

	var hint := _make_label("tap to continue", 40, Color(1.0, 1.0, 1.0, 0.6))
	hint.offset_top = 1400.0
	hint.offset_bottom = 1460.0
	_root.add_child(hint)


func enqueue(tier: int) -> void:
	_queue.append(tier)
	if not _root.visible:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_root.visible = false
		get_tree().paused = false
		return
	var tier: int = _queue.pop_front()
	_sprite.texture = Tiers.TEXTURES[tier]
	_name_label.text = Tiers.NAMES[tier]
	_bio_label.text = Tiers.BIOS[tier]
	_root.visible = true
	get_tree().paused = true
	_shown_at_sec = Time.get_ticks_msec() / 1000.0
	_burst.restart()
	AudioManager.play_sfx(SFX_UNLOCK)
	_sprite.scale = Vector2(0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2.ONE, POP_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_gui_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	if not pressed:
		return
	if Time.get_ticks_msec() / 1000.0 - _shown_at_sec < TAP_LOCKOUT_SEC:
		return
	_show_next()


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.offset_right = 1080.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
