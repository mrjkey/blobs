@tool
class_name RingArena
extends Node2D
## The sumo ring: a round floor inside a bouncy circular wall, with slow "mud"
## between the two. A blob that stays in the mud for `ring_out_time` is out:
## the arena calls `die()` on it and emits `blob_ringed_out`. Centred on this node.
## Colours from the theme: ring.floor, ring.moat, ring.stripes, ring.edge, ring.wall.

signal blob_ringed_out(blob: Blob)

const WALL_FLASH_TIME := 0.35
const WALL_COLOR := Color(0.55, 0.6, 0.8)

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
	BlobPhysics.wall_feedback(point, impact, GameTheme.current().value("ring.wall", WALL_COLOR))
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
	var theme := GameTheme.current()
	if theme.draw_override("ring", self):
		return
	var st := theme.style
	var k := st.kick(self)
	# Out-of-bounds mud between the ring and the wall, with slow hazard stripes.
	draw_circle(Vector2.ZERO, wall_radius, theme.value("ring.moat", Color(0.14, 0.08, 0.11)))
	var mid := (wall_radius + ring_radius) * 0.5
	var stripe_w := wall_radius - ring_radius
	var stripes := 36
	var stripe_col: Color = theme.value("ring.stripes", Color(1.0, 0.3, 0.25, 0.07))
	for i in stripes:
		var a0 := TAU * i / stripes + clock * 0.05
		draw_arc(Vector2.ZERO, mid, a0, a0 + TAU / stripes * 0.5, 6, stripe_col, stripe_w, false)

	# Ring floor, with faint guide circles.
	draw_circle(Vector2.ZERO, ring_radius, theme.value("ring.floor", Color(0.19, 0.22, 0.31)))
	for f: float in [0.33, 0.66]:
		st.ring(self, Vector2.ZERO, ring_radius * f, Color.WHITE, 2.0, 1.0, 0.05)
	st.dot(self, Vector2.ZERO, 6.0, Color.WHITE, 1.0, 0.08)

	# The ring edge: a slow shimmer, and a thump on each kick.
	st.ring(self, Vector2.ZERO, ring_radius, theme.value("ring.edge", Color(1.0, 0.85, 0.55)), 5.0 + k,
		1.4 + 0.6 * k, 0.85 + 0.15 * sin(clock * 3.0))

	# Bouncy wall, with a flash where something just hit it.
	var bold := st.bold
	var wall_r := wall_radius + 7.0 * bold
	st.ring(self, Vector2.ZERO, wall_r, theme.value("ring.wall", WALL_COLOR), 14.0 * bold, 1.4)
	for hit in wall_hits:
		var t: float = hit["age"] / WALL_FLASH_TIME
		var power: float = hit["power"]
		var ang: float = hit["angle"]
		var span := 0.15 + 0.2 * power
		st.ring(self, Vector2.ZERO, wall_r, Color.WHITE, (14.0 + 8.0 * power * (1.0 - t)) * bold, 3.0,
			(1.0 - t) * 0.9, ang - span, ang + span)
