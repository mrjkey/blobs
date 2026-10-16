class_name BlobTrail
extends Node2D
## A motion trail behind the parent Blob: a tapering line through its last few
## positions, as long as the theme's `style.trail_frames` (0 = no trail). Sits at
## z_index -1 so trails go under every blob; arenas sit at -1 too, earlier in
## the tree, so trails still draw over the floor. Gone as soon as the blob dies.

var points: Array[Vector2] = [] # world positions, oldest first

@onready var blob: Blob = get_parent()


func _process(delta: float) -> void:
	var frames := GameTheme.current().style.trail_frames
	if not blob.alive or frames <= 0:
		points.clear()
	elif delta > 0.0: # hold still during hitstop
		points.append(blob.global_position)
		while points.size() > frames:
			points.pop_front()
	queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("trail", self):
		return
	var n := points.size()
	for i in range(1, n):
		var f := float(i) / n
		theme.style.line(self, to_local(points[i - 1]), to_local(points[i]), blob.color,
			maxf(blob.radius * 1.3 * f, 1.0), 1.5, 0.35 * f)
