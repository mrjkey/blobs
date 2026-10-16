@tool
class_name NeonLaserSkin
extends LaserSkin
## Neon lasers: a glowing telegraph, an over-bright beam, and arrowhead
## outlines that pulse on the kick and light up while charging.


func draw_beam(e: LaserEmitter, beat: float, to_fire: float, charge: float) -> void:
	var s := e.settings
	# Telegraph: a thin tracking line that blinks once the aim locks.
	if charge > 0.0:
		var alpha := 0.15 + 0.5 * charge
		var width := 1.5
		if to_fire <= s.lock_beats:
			alpha = 0.9 if int(beat * 16.0) % 2 == 0 else 0.3
			width = 2.5
		e.draw_line(Vector2.ZERO, e.aim * e.length, NeonLook.hdr(beam_color, 1.0 + 2.0 * charge, alpha), width, true)
	# The beam itself.
	if e.fire_beat >= 0.0 and beat >= e.fire_beat and beat < e.fire_beat + s.fire_beats:
		var q := (beat - e.fire_beat) / s.fire_beats
		var end := e.aim * e.length
		e.draw_line(Vector2.ZERO, end, NeonLook.hdr(beam_color, 3.0, 1.0 - q), s.width * 1.4 * (1.0 - q) + 1.0, true)
		e.draw_line(Vector2.ZERO, end, NeonLook.hdr(Color.WHITE, 3.0, 1.0 - q), s.width * 0.35 * (1.0 - q) + 1.0, true)


func draw_turret(e: LaserEmitter, kick: float, charge: float) -> void:
	var aim := e.aim
	var side := Vector2(-aim.y, aim.x)
	var tip := aim * 16.0
	var body := PackedVector2Array([tip, -aim * 10.0 + side * 12.0, -aim * 4.0, -aim * 10.0 - side * 12.0, tip])
	e.draw_polyline(body, NeonLook.hdr(body_color, 1.5 + 1.5 * kick + 3.0 * charge), 2.5, true)
	if charge > 0.0:
		e.draw_circle(tip, 2.0 + 6.0 * charge, NeonLook.hdr(beam_color, 2.0 + 2.0 * charge, 0.9))


func draw_ship(e: LaserEmitter, kick: float, charge: float) -> void:
	var aim := e.aim
	var side_v := Vector2(-aim.y, aim.x)
	var tip := aim * 18.0
	var body := PackedVector2Array([tip, -aim * 12.0 + side_v * 14.0, -aim * 5.0, -aim * 12.0 - side_v * 14.0, tip])
	e.draw_polyline(body, NeonLook.hdr(body_color, 1.5 + 1.0 * kick + 3.0 * charge), 2.5, true)
	for s: float in [-1.0, 1.0]:
		e.draw_circle(-aim * 13.0 + side_v * (8.0 * s), 2.5, NeonLook.hdr(body_color, 2.0 + 1.5 * kick))
	if charge > 0.0:
		e.draw_circle(tip, 2.0 + 6.0 * charge, NeonLook.hdr(beam_color, 2.0 + 2.0 * charge, 0.9))
