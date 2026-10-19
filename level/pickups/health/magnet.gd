class_name Magnet
extends Node2D
## The MAGNET power-up, on the blob that caught it (a child of the Blob): for
## FatSettings.magnet_time it pulls everything "magnetic" within magnet_radius
## toward the blob, the good and the bad alike, harder the closer it is.
## Rings closing in on the blob show it, with a magnet over its head that
## blinks when it's about to run out. Frees itself when the time is up.

const COLOR := Color(0.35, 0.6, 1.0)

@export var settings: FatSettings = preload("res://modes/dont_get_fat/fat_settings.tres")

var time_left := 0.0
var _clock := 0.0


func _ready() -> void:
	process_physics_priority = 15 # after the blob moves, before pickups look for it (20)
	restart()


## Full time again (another magnet caught while this one runs).
func restart() -> void:
	time_left = settings.magnet_time


func _physics_process(delta: float) -> void:
	var blob := get_parent() as Blob
	time_left -= delta
	if blob == null or not blob.alive or time_left <= 0.0:
		queue_free()
		return
	var reach := settings.magnet_radius
	for n: BeltPickup in get_tree().get_nodes_in_group("magnetic"):
		var d := global_position.distance_to(n.global_position)
		if d < reach:
			n.pull(global_position, settings.magnet_pull * (1.0 - 0.6 * d / reach) * delta)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("magnet", self):
		return
	var st := theme.style
	var reach := settings.magnet_radius
	for i in 3:
		var k := 1.0 - fmod(_clock * 0.8 + i / 3.0, 1.0)
		st.ring(self, Vector2.ZERO, 30.0 + (reach - 30.0) * k, COLOR, 3.0, 1.2, 0.35 * (1.0 - k))
	if time_left > 1.5 or int(_clock * 8.0) % 2 == 0:
		PowerUp.draw_magnet_icon(self, st, Vector2(0.0, -62.0), 34.0)
