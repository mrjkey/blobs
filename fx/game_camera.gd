class_name GameCamera
extends Camera2D
## Keeps `view_size` world units in view whatever the window size, and shakes
## by Juice.shake_amount. `zoom_pulse` adds a little extra zoom (the neon beat thump).

@export var view_size := Vector2(820.0, 820.0) # world area that must always fit on screen

var zoom_pulse := 0.0


func _process(_delta: float) -> void:
	var vp := get_viewport_rect().size
	var fit := minf(vp.x / view_size.x, vp.y / view_size.y)
	zoom = Vector2.ONE * fit * (1.0 + zoom_pulse)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * Juice.shake_amount
