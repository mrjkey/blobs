@tool
class_name BoxRoom
extends Node2D
## A plain walled rectangle centred on this node: a floor to test things on.
## Blobs bounce off the inside of the walls. Resize it in the editor and it
## redraws live.

@export var size := Vector2(1000.0, 640.0):
	set(v):
		size = v
		queue_redraw()
@export var floor_color := Color(0.19, 0.22, 0.31):
	set(v):
		floor_color = v
		queue_redraw()
@export var wall_color := Color(0.55, 0.6, 0.8):
	set(v):
		wall_color = v
		queue_redraw()


func _enter_tree() -> void:
	add_to_group("blob_colliders")


func collide(b: Blob, feel: PhysicsFeel) -> void:
	var half := size * 0.5
	var p := b.global_position - global_position
	var r := b.radius
	if p.x < -half.x + r:
		_hit(b, Vector2.RIGHT, -half.x + r - p.x, feel)
	elif p.x > half.x - r:
		_hit(b, Vector2.LEFT, p.x - (half.x - r), feel)
	if p.y < -half.y + r:
		_hit(b, Vector2.DOWN, -half.y + r - p.y, feel)
	elif p.y > half.y - r:
		_hit(b, Vector2.UP, p.y - (half.y - r), feel)


func _hit(b: Blob, n: Vector2, depth: float, feel: PhysicsFeel) -> void:
	var impact := BlobPhysics.bounce(b, n, depth, feel.wall_restitution)
	if impact > 0.0:
		BlobPhysics.wall_feedback(b.global_position - n * b.radius, impact, wall_color)


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, floor_color)
	draw_rect(rect.grow(7.0), wall_color, false, 14.0)
