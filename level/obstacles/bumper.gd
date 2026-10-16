@tool
class_name Bumper
extends Node2D
## A round pinball bumper: flings any blob that touches it away at
## `settings.bumper_kick`, and pops bigger for a moment.

@export var radius := 27.0:
	set(v):
		radius = v
		queue_redraw()
@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")

var flash := 0.0


func _enter_tree() -> void:
	add_to_group("blob_colliders")


func collide(b: Blob, _feel: PhysicsFeel) -> void:
	var d := b.global_position - global_position
	var dist := d.length()
	if dist >= b.radius + radius:
		return
	var n := d / dist if dist > 0.001 else Vector2.UP
	kick(b, n, b.radius + radius - dist, settings.bumper_kick, settings)
	flash = 1.0


## Pinball-style: push `b` out by `depth` along `n` and always fling it away at
## `speed`, however softly it touched. Kicker walls use this too.
static func kick(b: Blob, n: Vector2, depth: float, speed: float, ts: TrackSettings) -> void:
	b.global_position += n * depth
	var vn := b.vel.dot(n)
	if vn < 0.0:
		b.vel -= n * vn
	b.vel += n * speed / sqrt(b.mass)
	b.stun = maxf(b.stun, ts.bumper_stun)
	b.body.flash = 0.8
	b.bump(n, speed)
	var contact := b.global_position - n * b.radius
	Juice.burst(contact, ts.bumper_color, 12, 420.0)
	Juice.impact_at(contact, speed)
	Sfx.play("bumper", randf_range(0.95, 1.1), -2.0)
	Juice.shake(4.0)


func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta * 4.0, 0.0)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var col := settings.bumper_color
	var k := 0.0 if Engine.is_editor_hint() else NeonLook.kick(get_tree())
	var rr := radius * (1.0 + 0.25 * flash)
	draw_circle(Vector2.ZERO, rr, Color(0.08, 0.06, 0.0, 0.9))
	draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, NeonLook.hdr(col, 1.8 + 3.0 * flash + 0.4 * k), 4.0, true)
	draw_arc(Vector2.ZERO, rr * 0.6, 0.0, TAU, 32, NeonLook.hdr(col, 1.2 + 2.0 * flash, 0.7), 2.0, true)
	draw_circle(Vector2.ZERO, rr * 0.22, NeonLook.hdr(col, 1.5 + 3.0 * flash))
