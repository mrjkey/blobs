@tool
class_name RingArena
extends Node2D
## The sumo ring: a round floor inside a bouncy circular wall, with slow "mud"
## between the two. A blob that stays in the mud for `ring_out_time` is out:
## the arena calls `die()` on it and emits `blob_ringed_out`. Centred on this node.
## Drawn by the theme's RingSkin.

signal blob_ringed_out(blob: Blob)

const WALL_FLASH_TIME := 0.35

@export var ring_radius := 300.0: # the sumo ring; leave it and the clock starts
	set(v):
		ring_radius = v
		queue_redraw()
@export var wall_radius := 380.0: # bouncy outer wall (keeps blobs on screen)
	set(v):
		wall_radius = v
		queue_redraw()
@export var ring_out_time := 1.0 # how long you can be outside the ring before you're out
## Off = blobs can sit in the mud without being knocked out (e.g. during a countdown).
@export var counting := true

var wall_hits: Array = [] # {angle, age, power}
var clock := 0.0
var _outside := {} # Blob -> seconds spent outside the ring


func _enter_tree() -> void:
	add_to_group("arena")
	add_to_group("blob_colliders")


func _ready() -> void:
	process_physics_priority = 20 # after blob abilities (10)


func is_in_mud(pos: Vector2) -> bool:
	return (pos - global_position).length() > ring_radius


func collide(b: Blob, feel: PhysicsFeel) -> void:
	var p := b.global_position - global_position
	var dist := p.length()
	var limit := wall_radius - b.radius
	if dist <= limit:
		return
	var n := p / dist # outward
	var impact := BlobPhysics.bounce(b, -n, dist - limit, feel.wall_restitution)
	if impact <= 0.0:
		return
	var point := b.global_position + n * b.radius
	BlobPhysics.wall_feedback(point, impact, GameTheme.current().ring.spark_color)
	if impact > 120.0:
		wall_hits.append({"angle": n.angle(), "age": 0.0, "power": clampf(impact / 600.0, 0.0, 1.0)})


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for b: Blob in get_tree().get_nodes_in_group("blobs"):
		if not b.alive:
			_outside.erase(b)
			continue
		var t: float = _outside.get(b, 0.0)
		if is_in_mud(b.global_position):
			t += delta
			if t >= ring_out_time and counting:
				_outside.erase(b)
				b.ring_danger = 0.0
				b.die()
				blob_ringed_out.emit(b)
				continue
		else:
			t = maxf(t - delta * 2.0, 0.0)
		_outside[b] = t
		b.ring_danger = clampf(t / ring_out_time, 0.0, 1.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	clock += delta
	for hit in wall_hits:
		hit["age"] += delta
	wall_hits = wall_hits.filter(func(hit): return hit["age"] < WALL_FLASH_TIME)
	queue_redraw()


func _draw() -> void:
	GameTheme.current().ring.draw(self)
