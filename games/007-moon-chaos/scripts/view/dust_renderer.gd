class_name DustRenderer
extends MeshInstance3D
## Renders the dust layer as ONE textured plane over the clean ground.
##
## The mask's alpha is the dust depth and its colour is the dust type, so the
## reveal needs no custom shader at all — just alpha blending over the ground
## plane underneath. CLAUDE.md rules out heavy shaders on low-end Android and
## this is the cheapest way to get a real before/after surface.
##
## Mask resolution is PIXELS_PER_CELL times the sim grid, which is what keeps
## the per-frame texture upload small: the largest zone (56x64 cells) is a
## 112x128 RGBA texture, ~57 KB, versus megabytes at screen resolution.

const PIXELS_PER_CELL: int = 2

## Dust depth at which the layer is fully opaque. Dust generates in the 60-255
## range, so mapping alpha straight from depth/255 left most of the surface
## half-transparent and swept ground looked barely different from dirty.
const OPAQUE_DEPTH: float = 150.0

var _image: Image = null
var _texture: ImageTexture = null
var _grid: DustGrid = null
var _colors: PackedColorArray = PackedColorArray()


func setup(grid: DustGrid, def: Balance.ZoneDef, balance: Balance) -> void:
	_grid = grid

	# Cache one colour per dust type; set_pixel is called a lot.
	_colors.clear()
	for t: Balance.DustTypeDef in balance.dust_types:
		_colors.append(t.color)
	if _colors.is_empty():
		_colors.append(Color(0.6, 0.62, 0.66))

	var pw: int = maxi(grid.w * PIXELS_PER_CELL, 1)
	var ph: int = maxi(grid.h * PIXELS_PER_CELL, 1)
	_image = Image.create_empty(pw, ph, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)

	var plane := PlaneMesh.new()
	plane.size = def.extent()
	mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _texture
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Unshaded: the dust should read as a flat layer and it costs no lighting.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	material_override = mat

	refresh_all()


func refresh_all() -> void:
	if _grid == null or _image == null:
		return
	for y: int in _grid.h:
		for x: int in _grid.w:
			_write_cell(x, y)
	_texture.update(_image)


## Redraw only the cells a sweep actually touched — the whole point of
## SweepResult carrying a dirty rect.
func refresh_rect(rect: Rect2i) -> void:
	if _grid == null or _image == null or rect.size == Vector2i.ZERO:
		return
	var x0: int = maxi(rect.position.x, 0)
	var y0: int = maxi(rect.position.y, 0)
	var x1: int = mini(rect.position.x + rect.size.x, _grid.w)
	var y1: int = mini(rect.position.y + rect.size.y, _grid.h)
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			_write_cell(x, y)
	_texture.update(_image)


func _write_cell(x: int, y: int) -> void:
	var cell := Vector2i(x, y)
	var depth: int = _grid.dust_at(cell)
	var type_index: int = _grid.type_at(cell)
	var col: Color = _colors[clampi(type_index, 0, _colors.size() - 1)]
	col.a = clampf(float(depth) / OPAQUE_DEPTH, 0.0, 1.0)

	var px: int = x * PIXELS_PER_CELL
	var py: int = y * PIXELS_PER_CELL
	for oy: int in PIXELS_PER_CELL:
		for ox: int in PIXELS_PER_CELL:
			_image.set_pixel(px + ox, py + oy, col)
