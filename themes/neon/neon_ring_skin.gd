@tool
class_name NeonRingSkin
extends RingSkin
## Neon ring: see-through floor and mud (so the grid behind shows), a ring
## edge that thumps with the music's kick, glowing wall flashes.

@export var ring_glow := 1.4 # ring edge brightness between beats
@export var ring_pulse := 0.6 # extra ring brightness on each kick (0 = no pulse)
@export var ring_pulse_width := 1.0 # extra ring line width on each kick


func draw(arena: RingArena) -> void:
	var ring_r := arena.ring_radius
	var wall_radius := arena.wall_radius
	var k := kick(arena)

	# Out-of-bounds zone and ring floor are see-through so the grid shows.
	arena.draw_circle(Vector2.ZERO, wall_radius, moat_color)
	var mid := (wall_radius + ring_r) * 0.5
	var dashes := 48
	for i in dashes:
		var a0 := TAU * i / dashes + arena.clock * 0.15
		arena.draw_arc(Vector2.ZERO, mid, a0, a0 + TAU / dashes * 0.35, 4, Color(1.0, 0.1, 0.3, 0.3), 3.0, true)
	arena.draw_circle(Vector2.ZERO, ring_r, floor_color)

	# Ring edge thumps with the kick drum.
	arena.draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 128, NeonLook.hdr(edge_color, ring_glow + ring_pulse * k),
		4.0 + ring_pulse_width * k, true)
	arena.draw_arc(Vector2.ZERO, ring_r + 9.0, 0.0, TAU, 128, NeonLook.hdr(edge_color, 0.8, 0.35), 1.5, true)

	# Wall, flashing where it was hit.
	var wall_r := wall_radius + 6.0
	arena.draw_arc(Vector2.ZERO, wall_r, 0.0, TAU, 128, NeonLook.hdr(wall_color, 1.4), 4.0, true)
	for hit in arena.wall_hits:
		var t: float = hit["age"] / RingArena.WALL_FLASH_TIME
		var power: float = hit["power"]
		var ang: float = hit["angle"]
		var span := 0.15 + 0.2 * power
		arena.draw_arc(Vector2.ZERO, wall_r, ang - span, ang + span, 16, NeonLook.hdr(Color.WHITE, 3.0, 1.0 - t),
			4.0 + 6.0 * power * (1.0 - t), true)
