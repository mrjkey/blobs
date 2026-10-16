class_name NeonBlobBody
extends BlobBody
## Same jelly blob, drawn as neon: dark glassy body, glowing double rim,
## glowing eyes. Only the drawing changes.


func _draw() -> void:
	var r := draw_radius * (1.0 + swell)
	var outer := PackedVector2Array()
	var halo := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var p := _xf(Vector2(cos(a), sin(a)))
		outer.append(p * r)
		halo.append(p * (r + 7.0))
		inner.append(p * r * 0.68)
	# Polygons must not repeat their first point; outlines need it to close.
	var outer_line := outer.duplicate()
	outer_line.append(outer[0])
	inner.append(inner[0])

	var color := blob.color
	var glow := NeonLook.palette.blob_glow + flash * 2.0
	var rim := color.lerp(Color.WHITE, flash * 0.6)
	# Soft halo (also looks fine with glow turned off), then the dark glass body.
	draw_colored_polygon(halo, NeonLook.hdr(rim, 1.0, 0.12))
	draw_colored_polygon(outer, Color(color.r * 0.12, color.g * 0.12, color.b * 0.18, 0.92))
	draw_polyline(inner, NeonLook.hdr(rim, 1.1, 0.45), 1.5, true)
	draw_polyline(outer_line, NeonLook.hdr(rim, glow), 3.5 if blob.windup <= 0.0 else 5.0, true)

	_draw_eyes(r)
	_draw_status(r)


func _draw_eyes(r: float) -> void:
	var color := blob.color
	var side := Vector2(-look.y, look.x)
	var dizzy := blob.stun > 0.0 or not blob.alive
	var bright := NeonLook.hdr(Color.WHITE, 2.2)
	for s: float in [-1.0, 1.0]:
		var c := _xf(look * 0.36 + side * (0.3 * s)) * r
		var er := r * 0.18
		if dizzy:
			var e := er * 0.75
			draw_line(c + Vector2(-e, -e), c + Vector2(e, e), NeonLook.hdr(color, 2.5), 2.5, true)
			draw_line(c + Vector2(-e, e), c + Vector2(e, -e), NeonLook.hdr(color, 2.5), 2.5, true)
		elif _blink > 0.0:
			draw_line(c - side * er, c + side * er, bright, 2.5, true)
		else:
			draw_circle(c, er, bright)
			draw_circle(c + look * er * 0.4, er * 0.45, Color(0.02, 0.0, 0.05))
		if blob.windup > 0.0 or (blob.push_cooldown > blob.stats.push_cooldown - 0.15):
			var brow_in := c + look * er * 0.9 - side * (er * 0.5 * s)
			var brow_out := c + look * er * 1.6 + side * (er * 0.9 * s)
			draw_line(brow_in, brow_out, NeonLook.hdr(color, 2.5), 3.0, true)


func _draw_status(r: float) -> void:
	if not blob.alive:
		return
	var color := blob.color
	if blob.is_human():
		var ring_r := r + 11.0
		if blob.push_cooldown > 0.0:
			var frac := 1.0 - blob.push_cooldown / blob.stats.push_cooldown
			if frac > 0.01:
				draw_arc(Vector2.ZERO, ring_r, -PI / 2.0, -PI / 2.0 + TAU * frac, 48, NeonLook.hdr(color, 1.2, 0.5), 2.5, true)
		else:
			draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, NeonLook.hdr(color, 2.0, 0.9), 2.0, true)
		var tip := Vector2(0.0, -r - 16.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-7, -10), tip + Vector2(7, -10)]), NeonLook.hdr(color, 2.5))
		if blob.tag != "":
			draw_string(ThemeDB.fallback_font, tip + Vector2(-30.0, -14.0), blob.tag,
				HORIZONTAL_ALIGNMENT_CENTER, 60.0, 16, NeonLook.hdr(color, 2.0))
	if blob.ring_danger > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		draw_arc(Vector2.ZERO, r + 5.0, -PI / 2.0, -PI / 2.0 + TAU * blob.ring_danger, 48,
			NeonLook.hdr(Color(1.0, 0.15, 0.1), 1.5 + 1.5 * pulse), 4.0, true)
