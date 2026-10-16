class_name LaserShip
extends LaserEmitter
## A laser ship beside the treadmill: cruises up and down its side of the
## screen, stops while it charges, never aims along the wall, and fires across
## to the far side wall. `side` is -1 (left) or 1 (right); `slot` spreads the
## ships on one side apart.

@export_range(-1, 1, 2) var side := -1
@export var slot := 0
@export var track: TrackSettings = preload("res://track/track_settings.tres")

var _phase := 0.0
var _rel_y := 0.0 # height relative to the camera centre while cruising
var _clock := 0.0


func _ready() -> void:
	super._ready()
	_phase = randf() * TAU + slot * PI
	_rel_y = sin(_phase) * _cruise()
	aim = Vector2(-side, 0.0)
	global_position = Vector2(_x(), _cam_y() + _rel_y)


func _physics_process(delta: float) -> void:
	_clock += delta
	super._physics_process(delta)


func _idle(delta: float) -> void:
	# Cruise up and down beside the track, facing across it.
	var want := sin(_clock * track.ship_speed + _phase) * _cruise()
	_rel_y = lerpf(_rel_y, want, 1.0 - exp(-2.0 * delta))
	global_position = Vector2(_x(), _cam_y() + _rel_y)
	aim = aim.slerp(Vector2(-side, 0.0), 1.0 - exp(-3.0 * delta)).normalized()


func _limit_aim(want: Vector2) -> Vector2:
	if want.x * -side < 0.3:
		return Vector2(-side * 0.3, signf(want.y) * 0.95).normalized() # never aim along the wall
	return want


## _idle() isn't called while charging and firing, so the ship holds still in
## the world; afterwards it picks up cruising from where it is.
func _on_reset() -> void:
	_rel_y = global_position.y - _cam_y()


## Distance from a ship to the far side wall along `dir`.
func beam_length(from: Vector2, dir: Vector2) -> float:
	if absf(dir.x) < 0.05:
		return 2400.0
	var far_x := -signf(from.x) * track.track_width * 0.5
	return clampf((far_x - from.x) / dir.x, 0.0, 2400.0)


func _draw_body(kick: float, charge: float) -> void:
	var s := settings
	var side_v := Vector2(-aim.y, aim.x)
	var tip := aim * 18.0
	var body := PackedVector2Array([tip, -aim * 12.0 + side_v * 14.0, -aim * 5.0, -aim * 12.0 - side_v * 14.0, tip])
	draw_polyline(body, NeonLook.hdr(s.body_color, 1.5 + 1.0 * kick + 3.0 * charge), 2.5, true)
	for e: float in [-1.0, 1.0]:
		draw_circle(-aim * 13.0 + side_v * (8.0 * e), 2.5, NeonLook.hdr(s.body_color, 2.0 + 1.5 * kick))
	if charge > 0.0:
		draw_circle(tip, 2.0 + 6.0 * charge, NeonLook.hdr(s.beam_color, 2.0 + 2.0 * charge, 0.9))


func _x() -> float:
	return side * (track.track_width * 0.5 + track.side_zone * 0.45)


func _cruise() -> float:
	var view := GameCamera.view_of(self)
	return (view.size.y if view.has_area() else 820.0) * 0.36


func _cam_y() -> float:
	var cam := get_viewport().get_camera_2d()
	return cam.global_position.y if cam != null else 0.0
