extends "res://scripts/blob.gd"
## Same jelly blob, drawn as neon: dark glassy body, glowing double rim,
## glowing eyes. Only the drawing changes; physics and push are inherited.

const NT = preload("res://scripts/neon/neon_tuning.gd")


static func hdr(c: Color, k: float, a: float = 1.0) -> Color:
	k *= NT.BRIGHTNESS
	return Color(c.r * k, c.g * k, c.b * k, a)


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

	var glow := NT.BLOB_GLOW + flash * 2.0
	var rim := color.lerp(Color.WHITE, flash * 0.6)
	# Soft halo (also looks fine with glow turned off), then the dark glass body.
	draw_colored_polygon(halo, hdr(rim, 1.0, 0.12))
	draw_colored_polygon(outer, Color(color.r * 0.12, color.g * 0.12, color.b * 0.18, 0.92))
	draw_polyline(inner, hdr(rim, 1.1, 0.45), 1.5, true)
	draw_polyline(outer_line, hdr(rim, glow), 3.5 if windup <= 0.0 else 5.0, true)

	_draw_eyes(r)
	_draw_status(r)


func _draw_eyes(r: float) -> void:
	var side := Vector2(-look.y, look.x)
	var dizzy := stun > 0.0 or not alive
	var bright := hdr(Color.WHITE, 2.2)
	for s: float in [-1.0, 1.0]:
		var c := _xf(look * 0.36 + side * (0.3 * s)) * r
		var er := r * 0.18
		if dizzy:
			var e := er * 0.75
			draw_line(c + Vector2(-e, -e), c + Vector2(e, e), hdr(color, 2.5), 2.5, true)
			draw_line(c + Vector2(-e, e), c + Vector2(e, -e), hdr(color, 2.5), 2.5, true)
		elif _blink > 0.0:
			draw_line(c - side * er, c + side * er, bright, 2.5, true)
		else:
			draw_circle(c, er, bright)
			draw_circle(c + look * er * 0.4, er * 0.45, Color(0.02, 0.0, 0.05))
		if windup > 0.0 or (push_cooldown > T.PUSH_COOLDOWN - 0.15):
			var brow_in := c + look * er * 0.9 - side * (er * 0.5 * s)
			var brow_out := c + look * er * 1.6 + side * (er * 0.9 * s)
			draw_line(brow_in, brow_out, hdr(color, 2.5), 3.0, true)


func _draw_status(r: float) -> void:
	if not alive:
		return
	if is_player:
		var ring_r := r + 11.0
		if push_cooldown > 0.0:
			var frac := 1.0 - push_cooldown / T.PUSH_COOLDOWN
			if frac > 0.01:
				draw_arc(Vector2.ZERO, ring_r, -PI / 2.0, -PI / 2.0 + TAU * frac, 48, hdr(color, 1.2, 0.5), 2.5, true)
		else:
			draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, hdr(color, 2.0, 0.9), 2.0, true)
		var tip := Vector2(0.0, -r - 16.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-7, -10), tip + Vector2(7, -10)]), hdr(color, 2.5))
		if player_tag != "":
			draw_string(ThemeDB.fallback_font, tip + Vector2(-30.0, -14.0), player_tag,
				HORIZONTAL_ALIGNMENT_CENTER, 60.0, 16, hdr(color, 2.0))
	if outside_time > 0.0:
		var danger := clampf(outside_time / T.RING_OUT_TIME, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		draw_arc(Vector2.ZERO, r + 5.0, -PI / 2.0, -PI / 2.0 + TAU * danger, 48,
			hdr(Color(1.0, 0.15, 0.1), 1.5 + 1.5 * pulse), 4.0, true)
