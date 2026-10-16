@tool
class_name Bumper
extends Node2D
## A round pinball bumper: flings any blob that touches it away at
## `settings.bumper_kick`, and pops bigger for a moment. Colour from the theme:
## bumper.color (also the burst whenever anything kicks a blob).

const COLOR := Color(1.0, 0.8, 0.25)

@export var radius := 27.0:
	set(v):
		radius = v
		queue_redraw()
@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")

var flash := 0.0


func _enter_tree() -> void:
	add_to_group("blob_colliders")


func collide(b: Blob, _feel: PhysicsFeel) -> void:
	if b.phases_obstacles():
		return
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
	Juice.burst(contact, GameTheme.current().value("bumper.color", COLOR), 12, 420.0)
	Juice.impact_at(contact, speed)
	Sfx.play("bumper", randf_range(0.95, 1.1), -2.0)
	Juice.shake(4.0)


func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta * 4.0, 0.0)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("bumper", self):
		return
	var st := theme.style
	var col: Color = theme.value("bumper.color", COLOR)
	var rr := radius * (1.0 + 0.25 * flash)
	st.disc(self, Vector2.ZERO, rr, col, flash * 0.8, 0.85, 1.1 + 0.25 * st.kick(self))
	st.ring(self, Vector2.ZERO, rr * 0.6, col.lightened(0.3), 2.0, 1.2 + 2.0 * flash, 0.8)
	st.dot(self, Vector2.ZERO, rr * 0.22, col.lerp(Color.WHITE, 0.7), 1.5 + 3.0 * flash)
