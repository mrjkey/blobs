@tool
class_name RingArena
extends Node2D
## The sumo ring: a round floor inside a bouncy circular wall, with slow "mud"
## between the two. A blob that stays in the mud for `ring_out_time` is out:
## the arena calls `die()` on it and emits `blob_ringed_out`. Centred on this node.

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

@export_group("Colours")
@export var floor_color := Color(0.19, 0.22, 0.31):
	set(v):
		floor_color = v
		queue_redraw()
@export var moat_color := Color(0.14, 0.08, 0.11):
	set(v):
		moat_color = v
		queue_redraw()
@export var ring_edge_color := Color(1.0, 0.85, 0.55):
	set(v):
		ring_edge_color = v
		queue_redraw()
@export var wall_color := Color(0.55, 0.6, 0.8):
	set(v):
		wall_color = v
		queue_redraw()

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
	BlobPhysics.wall_feedback(point, impact, wall_color)
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
	# Out-of-bounds mud between the ring and the wall, with slow hazard stripes.
	draw_circle(Vector2.ZERO, wall_radius, moat_color)
	var mid := (wall_radius + ring_radius) * 0.5
	var stripe_w := wall_radius - ring_radius
	var stripes := 36
	for i in stripes:
		var a0 := TAU * i / stripes + clock * 0.05
		draw_arc(Vector2.ZERO, mid, a0, a0 + TAU / stripes * 0.5, 6, Color(1.0, 0.3, 0.25, 0.07), stripe_w, false)

	# Ring floor.
	draw_circle(Vector2.ZERO, ring_radius, floor_color)
	for k: float in [0.33, 0.66]:
		draw_arc(Vector2.ZERO, ring_radius * k, 0.0, TAU, 96, Color(1, 1, 1, 0.05), 2.0, true)
	draw_circle(Vector2.ZERO, 6.0, Color(1, 1, 1, 0.08))
	var edge_col := ring_edge_color
	edge_col.a = 0.85 + 0.15 * sin(clock * 3.0)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 128, edge_col, 5.0, true)

	# Bouncy wall, with a flash where something just hit it.
	var wall_r := wall_radius + 7.0
	draw_arc(Vector2.ZERO, wall_r, 0.0, TAU, 128, wall_color, 14.0, true)
	for hit in wall_hits:
		var t: float = hit["age"] / WALL_FLASH_TIME
		var power: float = hit["power"]
		var ang: float = hit["angle"]
		var span := 0.15 + 0.2 * power
		draw_arc(Vector2.ZERO, wall_r, ang - span, ang + span, 16,
			Color(1, 1, 1, (1.0 - t) * 0.9), 14.0 + 8.0 * power * (1.0 - t), true)
