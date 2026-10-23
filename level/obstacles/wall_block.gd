@tool
class_name WallBlock
extends Node2D
## A rectangular wall centred on this node. Solid and slightly bouncy, or, as a
## pink `kicker`, a pinball wall that flings blobs away at `settings.kicker_speed`.
## A `ghost_proof` wall stops ghost dashes too, like the arena's own walls,
## and is drawn hatched so players can tell. With `slide` it slides side to
## side that many px either way, `slide_time` seconds there and back (Don't
## Get Fat!'s moving walls). Colours from the theme: wall.color, wall.kicker.
## Online, a joined computer shows a copy of the host's (NetGame).

const COLOR := Color(0.55, 0.6, 0.8)
const KICKER_COLOR := Color(1.0, 0.45, 0.7)

@export var size := Vector2(200.0, 24.0):
	set(v):
		size = v
		queue_redraw()
@export var kicker := false:
	set(v):
		kicker = v
		queue_redraw()
@export var ghost_proof := false: # even a ghost dash can't pass
	set(v):
		ghost_proof = v
		queue_redraw()
@export var slide := 0.0 # px either way it slides side to side (0 = it stays put; < 0 starts the other way)
@export var slide_time := 3.0 # seconds per slide, there and back
@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")

var flash := 0.0
var _home := Vector2.ZERO
var _age := 0.0


func _enter_tree() -> void:
	add_to_group("blob_colliders")


func _ready() -> void:
	_home = position


## The wall in world space.
func rect() -> Rect2:
	return Rect2(global_position - size * 0.5, size)


func collide(b: Blob, feel: PhysicsFeel) -> void:
	if b.phases_obstacles() and not ghost_proof:
		return
	var r := rect()
	var pos := b.global_position
	var closest := pos.clamp(r.position, r.end)
	var d := pos - closest
	var dist2 := d.length_squared()
	if dist2 > b.radius * b.radius:
		return
	var n: Vector2
	var depth: float
	if dist2 > 0.0001:
		var dist := sqrt(dist2)
		n = d / dist
		depth = b.radius - dist
	else:
		# Centre ended up inside the box: leave by the nearest face.
		var to_left := pos.x - r.position.x
		var to_right := r.end.x - pos.x
		var to_top := pos.y - r.position.y
		var to_bottom := r.end.y - pos.y
		var nearest := minf(minf(to_left, to_right), minf(to_top, to_bottom))
		if nearest == to_left:
			n = Vector2.LEFT
		elif nearest == to_right:
			n = Vector2.RIGHT
		elif nearest == to_top:
			n = Vector2.UP
		else:
			n = Vector2.DOWN
		depth = nearest + b.radius
	if kicker:
		Bumper.kick(b, n, depth, settings.kicker_speed, settings)
		fx_flash()
	else:
		var impact := BlobPhysics.bounce(b, n, depth, feel.wall_restitution)
		if impact > 0.0:
			BlobPhysics.wall_feedback(b.global_position - n * b.radius, impact, GameTheme.current().value("wall.color", COLOR))


## Light up (a kicker flinging a blob). Online, everyone's does.
func fx_flash() -> void:
	NetGame.relay(self, "fx_flash", [])
	flash = 1.0


## Online (NetGame): a copy made on a joined computer (the treadmill makes
## walls as it goes) has the same shape; a sliding wall's copy follows it.
func net_spawn() -> Array:
	return [size, kicker, ghost_proof]


func net_setup(d: Array) -> void:
	size = d[0]
	kicker = d[1]
	ghost_proof = d[2]


func net_state() -> Array:
	return [position] if slide != 0.0 else []


func net_apply(s: Array) -> void:
	position = s[0]


func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta * 4.0, 0.0)
	if slide != 0.0 and not Engine.is_editor_hint():
		_age += delta
		position = _home + Vector2(sin(_age * TAU / maxf(slide_time, 0.1)) * slide, 0.0)


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		if not is_physics_processing(): # online, a joined computer's copy: fade the flash here
			flash = maxf(flash - delta * 4.0, 0.0)
		queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("wall", self):
		return
	var st := theme.style
	var r := Rect2(-size * 0.5, size)
	var col: Color = theme.value("wall.kicker", KICKER_COLOR) if kicker else theme.value("wall.color", COLOR)
	st.box(self, r, col, flash, 0.8)
	if ghost_proof:
		# Hatching across the long side.
		var along := Vector2.RIGHT if size.x >= size.y else Vector2.DOWN
		var across := Vector2(along.y, along.x)
		var length := maxf(size.x, size.y)
		var thick := minf(size.x, size.y)
		var t := -length * 0.5 + 10.0
		while t < length * 0.5 - 10.0:
			var c := along * t
			st.line(self, c - across * thick * 0.3 - along * 4.0, c + across * thick * 0.3 + along * 4.0,
				col.lightened(0.45), 2.0, 1.4, 0.7)
			t += 16.0
	if kicker and size.x > 14.0 and size.y > 14.0:
		st.outline(self, ThemeStyle.rect_points(r.grow(-6.0)), st.color(col.lightened(0.35), 0.9 + flash, 0.6), 2.0)
