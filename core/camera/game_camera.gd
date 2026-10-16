class_name GameCamera
extends Camera2D
## Keeps `view_size` world units in view whatever the window size, and shakes
## by Juice.shake_amount. `zoom_pulse` adds a little extra zoom; with the
## theme's `beat_zoom` set, it thumps on every kick of the music.

@export var view_size := Vector2(820.0, 820.0) # world area that must always fit on screen

var zoom_pulse := 0.0


func _process(_delta: float) -> void:
	var beat_zoom := GameTheme.current().beat_zoom
	if beat_zoom > 0.0:
		zoom_pulse = beat_zoom * Techno.current_kick(get_tree())
	var vp := get_viewport_rect().size
	var fit := minf(vp.x / view_size.x, vp.y / view_size.y)
	zoom = Vector2.ONE * fit * (1.0 + zoom_pulse)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * Juice.shake_amount


## The part of the world on screen (ignoring shake and the beat pulse).
func visible_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var size := vp / minf(vp.x / view_size.x, vp.y / view_size.y)
	return Rect2(global_position - size * 0.5, size)


## What `node`'s current camera shows, or an empty Rect2 without a GameCamera.
static func view_of(node: Node) -> Rect2:
	var cam := node.get_viewport().get_camera_2d() as GameCamera
	return cam.visible_rect() if cam != null else Rect2()
