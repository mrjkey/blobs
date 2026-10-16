class_name BlobTrail
extends Node2D
## A motion trail behind the parent Blob: its last few positions, drawn by the
## theme's TrailSkin (themes without one have no trails). Sits at z_index -1 so
## trails go under every blob; arenas sit at -1 too, earlier in the tree, so
## trails still draw over the floor. Gone as soon as the blob dies.

var points: Array[Vector2] = [] # world positions, oldest first

@onready var blob: Blob = get_parent()


func _process(delta: float) -> void:
	var skin := GameTheme.current().trail
	if not blob.alive or skin == null:
		points.clear()
	elif delta > 0.0: # hold still during hitstop
		points.append(blob.global_position)
		while points.size() > skin.frames:
			points.pop_front()
	queue_redraw()


func _draw() -> void:
	var skin := GameTheme.current().trail
	if skin != null:
		skin.draw(self)
