@tool
class_name WallBlock
extends Node2D
## A rectangular wall centred on this node. Solid and slightly bouncy, or, as a
## pink `kicker`, a pinball wall that flings blobs away at `settings.kicker_speed`.
## Colours from the theme: wall.color, wall.kicker.

const COLOR := Color(0.55, 0.6, 0.8)
const KICKER_COLOR := Color(1.0, 0.45, 0.7)

@export var size := Vector2(200.0, 24.0):
	set(v):
		size = v
		queue_redraw()
@export var kicker := false:
	set(v):
		kicker = v
		queue_redraw()
@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")

var flash := 0.0


func _enter_tree() -> void:
	add_to_group("blob_colliders")


## The wall in world space.
func rect() -> Rect2:
	return Rect2(global_position - size * 0.5, size)


func collide(b: Blob, feel: PhysicsFeel) -> void:
	if b.phases_obstacles():
		return
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
			BlobPhysics.wall_feedback(b.global_position - n * b.radius, impact, GameTheme.current().value("wall.color", COLOR))


func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta * 4.0, 0.0)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("wall", self):
		return
	var st := theme.style
	var r := Rect2(-size * 0.5, size)
	var col: Color = theme.value("wall.kicker", KICKER_COLOR) if kicker else theme.value("wall.color", COLOR)
	st.box(self, r, col, flash, 0.8)
	if kicker and size.x > 14.0 and size.y > 14.0:
		st.outline(self, ThemeStyle.rect_points(r.grow(-6.0)), st.color(col.lightened(0.35), 0.9 + flash, 0.6), 2.0)
