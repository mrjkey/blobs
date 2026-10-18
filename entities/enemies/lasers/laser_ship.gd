class_name LaserShip
extends LaserEmitter
## A laser ship beside the treadmill: cruises up and down its side of the
## screen, stops while it charges, and fires straight across to the far side
## wall. It never tilts to track anyone: it's a line on the beat to dodge.
## `side` is -1 (left) or 1 (right); `slot` (0..2) spreads the ships on one
## side apart.

@export_range(-1, 1, 2) var side := -1
@export var slot := 0
@export var track: TrackSettings = preload("res://level/arenas/track/track_settings.tres")

var _phase := 0.0
var _rel_y := 0.0 # height relative to the camera centre while cruising
var _clock := 0.0


func _ready() -> void:
	super._ready()
	_phase = slot * TAU / 3.0 + (0.0 if side < 0 else PI / 3.0) + randf_range(-0.4, 0.4)
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
	aim = Vector2(-side, 0.0)


func _limit_aim(_want: Vector2) -> Vector2:
	return Vector2(-side, 0.0) # straight across, always


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


func _body_points(side_v: Vector2) -> PackedVector2Array:
	return PackedVector2Array([aim * 18.0, -aim * 12.0 + side_v * 14.0, -aim * 5.0, -aim * 12.0 - side_v * 14.0])


## Two engine glows at the back.
func _draw_extras(theme: GameTheme, side_v: Vector2) -> void:
	var st := theme.style
	for e: float in [-1.0, 1.0]:
		st.dot(self, -aim * 13.0 + side_v * (8.0 * e), 3.0, theme.value("laser.engine", Color(1.0, 0.75, 0.3)),
			2.0 + 1.5 * st.kick(self))


func _x() -> float:
	return side * (track.track_width * 0.5 + track.side_zone * 0.45)


func _cruise() -> float:
	var view := GameCamera.view_of(self)
	return (view.size.y if view.has_area() else 820.0) * 0.36


func _cam_y() -> float:
	var cam := get_viewport().get_camera_2d()
	return cam.global_position.y if cam != null else 0.0
