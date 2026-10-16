@tool
class_name RingSkin
extends ThemeSkin
## Classic sumo ring: striped mud, a flat floor with faint guide circles, a
## pulsing edge, and a thick wall that flashes white where it's hit.

@export var floor_color := Color(0.19, 0.22, 0.31)
@export var moat_color := Color(0.14, 0.08, 0.11)
@export var edge_color := Color(1.0, 0.85, 0.55)
@export var wall_color := Color(0.55, 0.6, 0.8)
@export var spark_color := Color(0.55, 0.6, 0.8) # sparks when a blob hits the wall


func draw(arena: RingArena) -> void:
	var ring_r := arena.ring_radius
	var wall_radius := arena.wall_radius
	var clock := arena.clock
	# Out-of-bounds mud between the ring and the wall, with slow hazard stripes.
	arena.draw_circle(Vector2.ZERO, wall_radius, moat_color)
	var mid := (wall_radius + ring_r) * 0.5
	var stripe_w := wall_radius - ring_r
	var stripes := 36
	for i in stripes:
		var a0 := TAU * i / stripes + clock * 0.05
		arena.draw_arc(Vector2.ZERO, mid, a0, a0 + TAU / stripes * 0.5, 6, Color(1.0, 0.3, 0.25, 0.07), stripe_w, false)

	# Ring floor.
	arena.draw_circle(Vector2.ZERO, ring_r, floor_color)
	for k: float in [0.33, 0.66]:
		arena.draw_arc(Vector2.ZERO, ring_r * k, 0.0, TAU, 96, Color(1, 1, 1, 0.05), 2.0, true)
	arena.draw_circle(Vector2.ZERO, 6.0, Color(1, 1, 1, 0.08))
	var edge_col := edge_color
	edge_col.a = 0.85 + 0.15 * sin(clock * 3.0)
	arena.draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 128, edge_col, 5.0, true)

	# Bouncy wall, with a flash where something just hit it.
	var wall_r := wall_radius + 7.0
	arena.draw_arc(Vector2.ZERO, wall_r, 0.0, TAU, 128, wall_color, 14.0, true)
	for hit in arena.wall_hits:
		var t: float = hit["age"] / RingArena.WALL_FLASH_TIME
		var power: float = hit["power"]
		var ang: float = hit["angle"]
		var span := 0.15 + 0.2 * power
		arena.draw_arc(Vector2.ZERO, wall_r, ang - span, ang + span, 16,
			Color(1, 1, 1, (1.0 - t) * 0.9), 14.0 + 8.0 * power * (1.0 - t), true)
