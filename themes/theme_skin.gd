@tool
class_name ThemeSkin
extends Resource
## An optional replacement for an element's default drawing in one theme. Put
## an instance in the theme's `overrides` under the element's name (e.g.
## "bumper"); the element's _draw() then calls draw() instead of drawing
## itself. Rarely needed: most looks come from the theme's ThemeStyle.


func draw(_node: CanvasItem) -> void:
	pass
