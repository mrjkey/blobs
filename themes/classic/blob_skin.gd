@tool
class_name BlobSkin
extends ThemeSkin
## Classic blob: a solid jelly body with a dark rim, a shine and cartoon eyes,
## plus the status rings (push recharge and the "that's you" arrow for humans,
## the ring-out timer). Reads everything from the BlobBody it draws.

const SEGMENTS := 40
const INK := Color(0.08, 0.08, 0.12)


func draw(body: BlobBody) -> void:
	var blob := body.blob
	var r := body.draw_radius * (1.0 + body.swell)
	var pts := PackedVector2Array()
	var shadow := PackedVector2Array()
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var p := body.xf(Vector2(cos(a), sin(a))) * r
		pts.append(p)
		shadow.append(p + Vector2(3.0, 6.0))

	body.draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
	body.draw_colored_polygon(pts, blob.color.lerp(Color.WHITE, body.flash * 0.7))
	var rim := pts.duplicate()
	rim.append(pts[0])
	var rim_col := blob.color.darkened(0.45)
	if blob.windup > 0.0:
		rim_col = Color.WHITE
	body.draw_polyline(rim, rim_col, 3.0, true)
	body.draw_circle(body.xf(Vector2(-0.38, -0.4)) * r, r * 0.22, Color(1, 1, 1, 0.3))

	_draw_eyes(body, r)
	_draw_status(body, r)


func _draw_eyes(body: BlobBody, r: float) -> void:
	var blob := body.blob
	var look := body.look
	var side := Vector2(-look.y, look.x)
	var dizzy := blob.stun > 0.0 or not blob.alive
	for s: float in [-1.0, 1.0]:
		var c := body.xf(look * 0.38 + side * (0.3 * s)) * r
		var er := r * 0.2
		if dizzy:
			var e := er * 0.7
			body.draw_line(c + Vector2(-e, -e), c + Vector2(e, e), INK, 2.5, true)
			body.draw_line(c + Vector2(-e, e), c + Vector2(e, -e), INK, 2.5, true)
		elif body.blink > 0.0:
			body.draw_line(c - side * er, c + side * er, INK, 2.5, true)
		else:
			body.draw_circle(c, er, Color.WHITE)
			body.draw_circle(c + look * er * 0.4, er * 0.5, INK)
		if blob.windup > 0.0 or (blob.push_cooldown > blob.stats.push_cooldown - 0.15):
			# angry brows while pushing
			var brow_in := c + look * er * 0.9 - side * (er * 0.5 * s)
			var brow_out := c + look * er * 1.5 + side * (er * 0.9 * s)
			body.draw_line(brow_in, brow_out, INK, 3.0, true)


func _draw_status(body: BlobBody, r: float) -> void:
	var blob := body.blob
	if not blob.alive:
		return
	if blob.is_human():
		var ring_r := r + 8.0
		if blob.push_cooldown > 0.0:
			var frac := 1.0 - blob.push_cooldown / blob.stats.push_cooldown
			if frac > 0.01:
				body.draw_arc(Vector2.ZERO, ring_r, -PI / 2.0, -PI / 2.0 + TAU * frac, 48, Color(1, 1, 1, 0.3), 3.0, true)
		else:
			body.draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 2.0, true)
		var tip := Vector2(0.0, -r - 14.0)
		body.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-7, -10), tip + Vector2(7, -10)]), Color.WHITE)
		if blob.tag != "":
			body.draw_string(ThemeDB.fallback_font, tip + Vector2(-30.0, -14.0), blob.tag,
				HORIZONTAL_ALIGNMENT_CENTER, 60.0, 16, Color.WHITE)
	if blob.ring_danger > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		body.draw_arc(Vector2.ZERO, r + 4.0, -PI / 2.0, -PI / 2.0 + TAU * blob.ring_danger, 48,
			Color(1.0, 0.25, 0.2, 0.6 + 0.4 * pulse), 4.0, true)
