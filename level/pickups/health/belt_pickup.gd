@tool
class_name BeltPickup
extends Node2D
## The base of what blobs catch on Don't Get Fat!'s belt (HealthItem,
## PowerUp). It stays where the map put it (the belt scrolls past), or sways
## side to side with `sway`. The first living blob to touch it catches it:
## _caught() says what that does, and _carried() runs every frame after (a
## HealthItem flies to the buddy). Once it's past the helpers' zone
## (BeltBounds) it fades away untouched. Group "on_belt" until it's caught.
## @tool so maps show it in the editor. Online, a joined computer shows a
## copy of the host's (NetGame); one that sits still sends nothing.

@export var sway := 0.0 # drifts this many px either way (0 = stays put, < 0 = starts the other way)
@export var sway_time := 3.0 # seconds per sway, there and back
@export var settings: FatSettings = preload("res://modes/dont_get_fat/fat_settings.tres")

var home := Vector2.ZERO # where it is without the sway
var age := 0.0
var taken := false # caught: no more catching, pulling or fading
var _fade := 1.0


func _enter_tree() -> void:
	add_to_group("on_belt")


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	home = position
	process_physics_priority = 20 # after blobs move (BlobPhysics 0, Blob 10)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	age += delta
	if taken:
		_carried(delta)
		return
	position = home + Vector2(sin(age * TAU / maxf(sway_time, 0.1)) * sway, 0.0)
	var bounds := get_tree().get_first_node_in_group("belt_bounds") as BeltBounds
	if bounds != null and global_position.y > bounds.bottom_y():
		_fade -= delta * 4.0
		modulate.a = _fade
		if _fade <= 0.0:
			queue_free()
		return
	for b: Blob in get_tree().get_nodes_in_group("blobs"):
		if b.alive and b.global_position.distance_to(global_position) < b.radius + settings.catch_radius:
			taken = true
			remove_from_group("on_belt")
			_caught(b)
			return


## Override: what catching it does. Free it here, or leave it for _carried().
func _caught(_b: Blob) -> void:
	queue_free()


## Override: every frame once caught, until it frees itself.
func _carried(_delta: float) -> void:
	pass


## Online (NetGame): where it is and how it looks, once it moves at all.
func net_state() -> Array:
	if _still():
		return []
	return [position, age, taken, modulate.a, rotation, scale, z_index]


func net_apply(s: Array) -> void:
	position = s[0]
	age = s[1]
	taken = s[2]
	modulate.a = s[3]
	rotation = s[4]
	scale = s[5]
	z_index = s[6]


## Sitting where the map put it, untouched: a joined computer's copy needs no updates.
func _still() -> bool:
	return not taken and sway == 0.0 and _fade >= 1.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_physics_processing(): # online, a joined computer's copy: its own clock, for the bob
		age += delta
	var view := GameCamera.view_of(self)
	if not view.has_area() or view.grow(120.0).has_point(global_position):
		queue_redraw()


## Points round an ellipse, for drawing.
static func ellipse(centre: Vector2, rx: float, ry: float, segments := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Points round a rectangle with rounded corners of radius `r`, for drawing.
static func round_rect(rect: Rect2, r: float) -> PackedVector2Array:
	r = minf(r, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [rect.end - Vector2(r, r), Vector2(rect.position.x + r, rect.end.y - r), rect.position + Vector2(r, r),
		Vector2(rect.end.x - r, rect.position.y + r)]
	for i in 4:
		for j in 5:
			pts.append(corners[i] + Vector2.from_angle(PI * 0.5 * i + PI * 0.125 * j) * r)
	return pts
