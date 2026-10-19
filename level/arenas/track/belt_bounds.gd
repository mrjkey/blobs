class_name BeltBounds
extends Node2D
## Keeps blobs between two lines across the track: `top` px above this node
## and `bottom` px below it (Don't Get Fat! moves it along with the camera).
## Blobs bump softly off the top one. The bottom one, the edge of the helpers'
## zone, is a dashed line they bump off too, or, while `lethal`, a laser:
## running into it bumps a blob back with a spark, but a blob shoved through
## it (its centre past the line: a wall pushing it) is zapped
## (`blob.die(true)`; the mode brings it back). spare() keeps a blob safe from
## it for a moment (just back in). Pickups that
## get past the bottom line fade away untouched. Group "belt_bounds" (at most
## one). Colours from the theme: belt_bounds.color, kill_lasers.color.

const COLOR := Color(1.0, 1.0, 1.0, 0.4)
const LASER_BOUNCE := 0.6 # restitution off the laser: a blob that runs into it is knocked back up

@export var top := 545.0
@export var bottom := 300.0
@export var restitution := 0.3
@export var lethal := false # the bottom line is a laser
@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")

var _spared := {} # blob -> seconds it's still safe from the laser
var _clock := 0.0


func _enter_tree() -> void:
	add_to_group("blob_colliders")
	add_to_group("belt_bounds")


func top_y() -> float:
	return global_position.y - top


func bottom_y() -> float:
	return global_position.y + bottom


## Keep `b` safe from the laser for `seconds` (it bumps off the line instead).
func spare(b: Blob, seconds: float) -> void:
	_spared[b] = seconds


func collide(b: Blob, _feel: PhysicsFeel) -> void:
	var y := b.global_position.y
	if y < top_y() + b.radius:
		BlobPhysics.bounce(b, Vector2.DOWN, top_y() + b.radius - y, restitution)
	elif y > bottom_y() - b.radius:
		if lethal and b.alive and not _spared.has(b):
			if y >= bottom_y():
				Juice.burst(Vector2(b.global_position.x, bottom_y()), _laser_color(), 24, 500.0)
				Sfx.play("zap", randf_range(0.9, 1.1), 0.0, 0.0)
				b.die(true)
				return
			if b.vel.y > 120.0: # ran into it: a spark, and it's bounced back harder
				Juice.burst(Vector2(b.global_position.x, bottom_y()), _laser_color(), 6, 220.0, Vector2.UP, 0.8)
				Sfx.play("zap", 1.8, -12.0, 0.15)
			BlobPhysics.bounce(b, Vector2.UP, y - (bottom_y() - b.radius), LASER_BOUNCE)
			return
		BlobPhysics.bounce(b, Vector2.UP, y - (bottom_y() - b.radius), restitution)


func _physics_process(delta: float) -> void:
	for b in _spared.keys():
		_spared[b] -= delta
		if _spared[b] <= 0.0 or not is_instance_valid(b):
			_spared.erase(b)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _laser_color() -> Color:
	return GameTheme.current().value("kill_lasers.color", KillLasers.COLOR)


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("belt_bounds", self):
		return
	var st := theme.style
	var half := settings.track_width * 0.5
	if lethal:
		var col := _laser_color()
		var flicker := 0.85 + 0.15 * sin(_clock * 40.0)
		st.line(self, Vector2(-half, bottom), Vector2(half, bottom), col, 14.0, 0.9, 0.2)
		st.line(self, Vector2(-half, bottom), Vector2(half, bottom), col, 4.0, 2.2 * flicker, flicker)
		for x: float in [-half, half]:
			st.dot(self, Vector2(x, bottom), 7.0, col, 2.5)
		return
	var col: Color = theme.value("belt_bounds.color", COLOR)
	const DASH := 26.0
	var x := -half
	while x < half:
		st.line(self, Vector2(x, bottom), Vector2(minf(x + DASH, half), bottom), col, 4.0)
		x += DASH * 2.0
