class_name Goofdex
extends CanvasLayer
## Collection screen: all 11 goofs in a grid, silhouettes until discovered.
## Pauses the game while open. Runs while paused.

const DISCOVERED_KEY: String = "goofdex.discovered"
const BG_COLOR: Color = Color(0.1, 0.08, 0.16, 1.0)
const SILHOUETTE: Color = Color(0.06, 0.05, 0.1, 0.95)
const CELL_SPRITE: float = 250.0
const COLUMNS: int = 3

const FONT: FontFile = preload("res://assets/fonts/Baloo2.ttf")
const SFX_TAP: AudioStream = preload("res://assets/audio/tap.wav")

var _root: Control
var _counter: Label
var _cells: Array[Dictionary] = []

static func discovered_tiers() -> Array[int]:
	var out: Array[int] = []
	for value in SaveManager.get_value(DISCOVERED_KEY, []):
		out.append(int(value))
	return out


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var title := Label.new()
	title.text = "GOOFDEX"
	title.offset_top = 60.0
	title.offset_right = 1080.0
	title.offset_bottom = 170.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 92)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	_root.add_child(title)

	_counter = Label.new()
	_counter.offset_top = 175.0
	_counter.offset_right = 1080.0
	_counter.offset_bottom = 235.0
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.add_theme_font_override("font", FONT)
	_counter.add_theme_font_size_override("font_size", 42)
	_counter.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.6))
	_root.add_child(_counter)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.offset_left = 60.0
	grid.offset_top = 270.0
	grid.offset_right = 1020.0
	grid.offset_bottom = 1680.0
	grid.add_theme_constant_override("h_separation", 35)
	grid.add_theme_constant_override("v_separation", 24)
	_root.add_child(grid)

	for tier in range(1, Tiers.COUNT + 1):
		var cell := VBoxContainer.new()
		var sprite := TextureRect.new()
		sprite.texture = Tiers.TEXTURES[tier]
		sprite.custom_minimum_size = Vector2(CELL_SPRITE, CELL_SPRITE)
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(sprite)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(CELL_SPRITE, 0.0)
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", 34)
		cell.add_child(label)
		grid.add_child(cell)
		_cells.append({"tier": tier, "sprite": sprite, "label": label})

	var close := Button.new()
	close.text = "CLOSE"
	close.offset_left = 380.0
	close.offset_top = 1740.0
	close.offset_right = 700.0
	close.offset_bottom = 1850.0
	close.add_theme_font_override("font", FONT)
	close.add_theme_font_size_override("font_size", 48)
	close.pressed.connect(close_dex)
	_root.add_child(close)


func open() -> void:
	_refresh()
	_root.visible = true
	get_tree().paused = true
	AudioManager.play_sfx(SFX_TAP)


func close_dex() -> void:
	_root.visible = false
	get_tree().paused = false
	AudioManager.play_sfx(SFX_TAP)


func _refresh() -> void:
	var found := discovered_tiers()
	_counter.text = "%d / %d discovered" % [found.size(), Tiers.COUNT]
	for cell in _cells:
		var known: bool = cell.tier in found
		cell.sprite.self_modulate = Color.WHITE if known else SILHOUETTE
		cell.label.text = Tiers.NAMES[cell.tier] if known else "???"
		cell.label.add_theme_color_override("font_color",
			Color.WHITE if known else Color(1.0, 1.0, 1.0, 0.35))
