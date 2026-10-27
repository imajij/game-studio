class_name Deco
extends Node2D
## Draws whatever the owner paints. Lets a game place custom drawing at any
## point in the tree (e.g. above a background sprite) without a new script:
##   $Deco.painter = _paint_deco   # func (canvas: CanvasItem) -> void
##   $Deco.queue_redraw()

var painter: Callable = Callable()

func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
