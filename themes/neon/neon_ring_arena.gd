@tool
class_name NeonRingArena
extends RingArena
## The ring drawn in neon: see-through floor and mud (so a NeonGrid behind
## shows), a ring edge that thumps with the music's kick, glowing wall flashes.
## Colours come from NeonLook.palette; the wall's spark colour is still `wall_color`.


func _draw() -> void:
	var pal := NeonLook.palette
	var k := 0.0 if Engine.is_editor_hint() else NeonLook.kick(get_tree())

	# Out-of-bounds zone and ring floor are see-through so the grid shows.
	draw_circle(Vector2.ZERO, wall_radius, pal.moat_color)
	var mid := (wall_radius + ring_radius) * 0.5
	var dashes := 48
	for i in dashes:
		var a0 := TAU * i / dashes + clock * 0.15
		draw_arc(Vector2.ZERO, mid, a0, a0 + TAU / dashes * 0.35, 4, Color(1.0, 0.1, 0.3, 0.3), 3.0, true)
	draw_circle(Vector2.ZERO, ring_radius, pal.floor_color)

	# Ring edge thumps with the kick drum.
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 128, NeonLook.hdr(pal.ring_color, pal.ring_glow + pal.ring_pulse * k),
		4.0 + pal.ring_pulse_width * k, true)
	draw_arc(Vector2.ZERO, ring_radius + 9.0, 0.0, TAU, 128, NeonLook.hdr(pal.ring_color, 0.8, 0.35), 1.5, true)

	# Wall, flashing where it was hit.
	var wall_r := wall_radius + 6.0
	draw_arc(Vector2.ZERO, wall_r, 0.0, TAU, 128, NeonLook.hdr(pal.wall_color, 1.4), 4.0, true)
	for hit in wall_hits:
		var t: float = hit["age"] / WALL_FLASH_TIME
		var power: float = hit["power"]
		var ang: float = hit["angle"]
		var span := 0.15 + 0.2 * power
		draw_arc(Vector2.ZERO, wall_r, ang - span, ang + span, 16, NeonLook.hdr(Color.WHITE, 3.0, 1.0 - t),
			4.0 + 6.0 * power * (1.0 - t), true)
