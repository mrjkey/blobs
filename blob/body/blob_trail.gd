class_name BlobTrail
extends Node2D
## A glowing motion trail behind the parent Blob: its last few positions, drawn
## as a tapering line. Sits at z_index -1 so trails go under every blob; put the
## arena at -1 too (earlier in the tree) so trails still draw over the floor.
## Length comes from NeonLook.palette.trail_frames. Gone as soon as the blob dies.

var points: Array[Vector2] = [] # world positions, oldest first

@onready var blob: Blob = get_parent()


func _process(delta: float) -> void:
	if not blob.alive:
		points.clear()
	elif delta > 0.0: # hold still during hitstop
		points.append(blob.global_position)
		while points.size() > NeonLook.palette.trail_frames:
			points.pop_front()
	queue_redraw()


func _draw() -> void:
	var n := points.size()
	for i in range(1, n):
		var f := float(i) / n
		draw_line(to_local(points[i - 1]), to_local(points[i]), NeonLook.hdr(blob.color, 1.5, 0.35 * f),
			maxf(blob.radius * 1.3 * f, 1.0), true)
