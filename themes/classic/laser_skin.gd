@tool
class_name LaserSkin
extends ThemeSkin
## Classic lasers: a thin aiming line, a solid beam with a white core, and
## flat arrowhead turrets and ships with a dark outline.

@export var beam_color := Color(1.0, 0.3, 0.35) # also the sparks where the beam hits
@export var body_color := Color(0.95, 0.5, 0.6) # the turret or ship


## The telegraph and the beam. `to_fire` = beats until it fires; `charge` 0..1.
func draw_beam(e: LaserEmitter, beat: float, to_fire: float, charge: float) -> void:
	var s := e.settings
	if charge > 0.0:
		var alpha := 0.15 + 0.5 * charge
		var width := 1.5
		if to_fire <= s.lock_beats:
			alpha = 0.9 if int(beat * 16.0) % 2 == 0 else 0.3
			width = 2.5
		e.draw_line(Vector2.ZERO, e.aim * e.length, Color(beam_color, alpha), width, true)
	if e.fire_beat >= 0.0 and beat >= e.fire_beat and beat < e.fire_beat + s.fire_beats:
		var q := (beat - e.fire_beat) / s.fire_beats
		var end := e.aim * e.length
		e.draw_line(Vector2.ZERO, end, Color(beam_color, 1.0 - q), s.width * 1.4 * (1.0 - q) + 1.0, true)
		e.draw_line(Vector2.ZERO, end, Color(1, 1, 1, 1.0 - q), s.width * 0.35 * (1.0 - q) + 1.0, true)


func draw_turret(e: LaserEmitter, _kick: float, charge: float) -> void:
	var aim := e.aim
	var side := Vector2(-aim.y, aim.x)
	var tip := aim * 16.0
	var body := PackedVector2Array([tip, -aim * 10.0 + side * 12.0, -aim * 4.0, -aim * 10.0 - side * 12.0])
	_draw_body(e, body, charge)
	if charge > 0.0:
		e.draw_circle(tip, 2.0 + 6.0 * charge, Color(beam_color, 0.9))


func draw_ship(e: LaserEmitter, _kick: float, charge: float) -> void:
	var aim := e.aim
	var side := Vector2(-aim.y, aim.x)
	var tip := aim * 18.0
	var body := PackedVector2Array([tip, -aim * 12.0 + side * 14.0, -aim * 5.0, -aim * 12.0 - side * 14.0])
	_draw_body(e, body, charge)
	for s: float in [-1.0, 1.0]:
		e.draw_circle(-aim * 13.0 + side * (8.0 * s), 3.0, Color(1.0, 0.75, 0.3))
	if charge > 0.0:
		e.draw_circle(tip, 2.0 + 6.0 * charge, Color(beam_color, 0.9))


func _draw_body(e: LaserEmitter, body: PackedVector2Array, charge: float) -> void:
	var shadow := PackedVector2Array()
	for p in body:
		shadow.append(p + Vector2(3.0, 6.0))
	e.draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
	e.draw_colored_polygon(body, body_color.lerp(Color.WHITE, charge * 0.5))
	var outline := body.duplicate()
	outline.append(body[0])
	e.draw_polyline(outline, body_color.darkened(0.5), 2.5, true)
