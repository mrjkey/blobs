@tool
class_name WallBlock
extends Node2D
## A rectangular wall centred on this node. Solid and slightly bouncy, or, as a
## pink `kicker`, a pinball wall that flings blobs away at `settings.kicker_speed`.

@export var size := Vector2(200.0, 24.0):
	set(v):
		size = v
		queue_redraw()
@export var kicker := false:
	set(v):
		kicker = v
		queue_redraw()
@export var settings: TrackSettings = preload("res://track/track_settings.tres")

var flash := 0.0


func _enter_tree() -> void:
	add_to_group("blob_colliders")


## The wall in world space.
func rect() -> Rect2:
	return Rect2(global_position - size * 0.5, size)


func collide(b: Blob, feel: PhysicsFeel) -> void:
	var r := rect()
	var pos := b.global_position
	var closest := pos.clamp(r.position, r.end)
	var d := pos - closest
	var dist2 := d.length_squared()
	if dist2 > b.radius * b.radius:
		return
	var n: Vector2
	var depth: float
	if dist2 > 0.0001:
		var dist := sqrt(dist2)
		n = d / dist
		depth = b.radius - dist
	else:
		# Centre ended up inside the box: leave by the nearest face.
		var to_left := pos.x - r.position.x
		var to_right := r.end.x - pos.x
		var to_top := pos.y - r.position.y
		var to_bottom := r.end.y - pos.y
		var nearest := minf(minf(to_left, to_right), minf(to_top, to_bottom))
		if nearest == to_left:
			n = Vector2.LEFT
		elif nearest == to_right:
			n = Vector2.RIGHT
		elif nearest == to_top:
			n = Vector2.UP
		else:
			n = Vector2.DOWN
		depth = nearest + b.radius
	if kicker:
		Bumper.kick(b, n, depth, settings.kicker_speed, settings)
		flash = 1.0
	else:
		var impact := BlobPhysics.bounce(b, n, depth, feel.wall_restitution)
		if impact > 0.0:
			BlobPhysics.wall_feedback(b.global_position - n * b.radius, impact, settings.wall_color)


func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta * 4.0, 0.0)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	var col := settings.kicker_color if kicker else settings.wall_color
	draw_rect(r, Color(col.r * 0.1, col.g * 0.1, col.b * 0.15, 0.9))
	draw_rect(r, NeonLook.hdr(col, 1.6 + 2.5 * flash), false, 3.0, true)
	if kicker and size.x > 14.0 and size.y > 14.0:
		draw_rect(r.grow(-6.0), NeonLook.hdr(col, 0.9 + flash, 0.6), false, 1.5, true)
