class_name LaserTurret
extends LaserEmitter
## A laser turret orbiting slowly just outside the ring wall (of the node in
## group "arena"), facing the middle, firing across to the far side of the wall.
## Place it anywhere: it keeps its angle around the arena and snaps to its orbit.

@export var orbit_speed := 0.12 # radians/second while idle
@export var distance := 50.0 # outside the wall
@export var fallback_wall_radius := 380.0 # used when there's no arena

var _angle := 0.0


func _ready() -> void:
	super._ready()
	_angle = (global_position - _center()).angle()
	global_position = _center() + Vector2.from_angle(_angle) * (_wall_radius() + distance)
	aim = -Vector2.from_angle(_angle)


func _idle(delta: float) -> void:
	# Drift round the arena, face the middle.
	var c := _center()
	var inward := (c - global_position).normalized()
	_angle += orbit_speed * delta
	aim = aim.slerp(inward, 1.0 - exp(-3.0 * delta)).normalized()
	global_position = c + Vector2.from_angle(_angle) * (_wall_radius() + distance)


## Distance from `from` to the far side of the wall along `dir`.
func beam_length(from: Vector2, dir: Vector2) -> float:
	var rel := from - _center()
	var r := _wall_radius()
	var b := rel.dot(dir)
	var disc := b * b - (rel.length_squared() - r * r)
	if disc <= 0.0:
		return 1400.0
	return -b + sqrt(disc)


func _draw_body(kick: float, charge: float) -> void:
	var s := settings
	var side := Vector2(-aim.y, aim.x)
	var tip := aim * 16.0
	var body := PackedVector2Array([tip, -aim * 10.0 + side * 12.0, -aim * 4.0, -aim * 10.0 - side * 12.0, tip])
	draw_polyline(body, NeonLook.hdr(s.body_color, 1.5 + 1.5 * kick + 3.0 * charge), 2.5, true)
	if charge > 0.0:
		draw_circle(tip, 2.0 + 6.0 * charge, NeonLook.hdr(s.beam_color, 2.0 + 2.0 * charge, 0.9))


func _center() -> Vector2:
	var arena := get_tree().get_first_node_in_group("arena")
	return arena.global_position if arena != null else Vector2.ZERO


func _wall_radius() -> float:
	var arena := get_tree().get_first_node_in_group("arena")
	return arena.wall_radius if arena != null and "wall_radius" in arena else fallback_wall_radius
