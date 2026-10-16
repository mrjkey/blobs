class_name KillLasers
extends Node2D
## Two lasers across the track, just inside the top and bottom of the screen:
## they follow the camera, and a blob that ends up past either one is out
## (`blob.die()`). With `lethal` off they hold blobs on screen instead (the
## round's over: keep the winner in view). Group "kill_lasers"; bots read
## kill_top() / kill_bottom() to keep clear. Draw above the blobs (z_index 5).

signal blob_lasered(blob: Blob)

@export var settings: TrackSettings = preload("res://track/track_settings.tres")
@export var enabled := true # off = do nothing (e.g. during the countdown)
@export var lethal := true

var _clock := 0.0


func _enter_tree() -> void:
	add_to_group("kill_lasers")


func _ready() -> void:
	process_physics_priority = 20 # after blob abilities (10)


func kill_top() -> float:
	return GameCamera.view_of(self).position.y + settings.edge_inset


func kill_bottom() -> float:
	return GameCamera.view_of(self).end.y - settings.edge_inset


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	var top := kill_top()
	var bottom := kill_bottom()
	for b: Blob in get_tree().get_nodes_in_group("blobs"):
		if not b.alive:
			continue
		var y := b.global_position.y
		if y <= bottom and y >= top:
			continue
		if lethal:
			var edge_y := bottom if y > bottom else top
			Juice.burst(Vector2(b.global_position.x, edge_y), settings.edge_laser_color, 24, 500.0)
			Sfx.play("zap", randf_range(0.9, 1.1), 0.0, 0.0)
			b.die()
			blob_lasered.emit(b)
		else:
			b.global_position.y = clampf(y, top, bottom)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var k := NeonLook.kick(get_tree())
	var half := settings.track_width * 0.5
	var col := settings.edge_laser_color
	for y: float in [kill_top(), kill_bottom()]:
		var flicker := 0.85 + 0.15 * sin(_clock * 40.0 + y * 0.1)
		var a := to_local(Vector2(-half, y))
		var b := to_local(Vector2(half, y))
		draw_line(a, b, NeonLook.hdr(col, 0.9, 0.25), 14.0, true)
		draw_line(a, b, NeonLook.hdr(col, (2.2 + 0.5 * k) * flicker), 3.0, true)
		for end: Vector2 in [a, b]:
			draw_circle(end, 6.0, NeonLook.hdr(col, 2.5))
