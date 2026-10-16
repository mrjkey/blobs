extends "res://scripts/game.gd"
## Neon night-club variant of the game. Same rules and physics (inherited from
## game.gd); this adds:
##   - HDR glow (anything drawn brighter than 1.0 blooms)
##   - a warping background grid that ripples on hits
##   - neon blobs with motion trails
##   - a synthesised techno loop that the visuals pulse to
##   - laser turrets outside the wall that fire on the beat

const NT = preload("res://scripts/neon/neon_tuning.gd")
const NeonLook = preload("res://scripts/neon/neon_look.gd")
const NeonBlob = preload("res://scripts/neon/neon_blob.gd")
const NeonFx = preload("res://scripts/neon/neon_fx.gd")
const NeonGrid = preload("res://scripts/neon/neon_grid.gd")
const Techno = preload("res://scripts/neon/techno.gd")
const NEON_GLOW = preload("res://neon/neon_glow.tscn")

var grid: NeonGrid
var music: Techno
var turrets: Array = []      # one Dictionary per turret, see _make_turrets()
var trails := {}             # blob instance id -> Array of recent positions
var _overlay: Node2D         # draws turrets and beams above the blobs
var _play_time := 0.0
var _last_bar := -1


func _ready() -> void:
	bot_looks = [
		{"name": "Bonk", "color": Color(1.0, 0.2, 0.25)},
		{"name": "Wobbles", "color": Color(0.2, 1.0, 0.5)},
		{"name": "Gummy", "color": Color(0.65, 0.3, 1.0)},
		{"name": "Blorb", "color": Color(1.0, 0.35, 0.85)},
		{"name": "Mochi", "color": Color(1.0, 0.5, 0.1)},
		{"name": "Squish", "color": Color(0.3, 0.5, 1.0)},
	]
	view_margin = 2.0 * (NT.TURRET_DISTANCE + 40.0)  # zoom out so turrets fit
	add_child(NEON_GLOW.instantiate())
	grid = NeonGrid.new()
	grid.z_index = -10
	add_child(grid)
	music = Techno.new()
	add_child(music)
	_overlay = Node2D.new()
	_overlay.z_index = 5
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	super._ready()

	sfx.add_tone("zap", 0.4, 1600.0, 90.0, 0.0, 0.3, 3.5)
	sfx.add_tone("charge", 0.9, 180.0, 700.0, 0.05, 0.0, 0.8)
	_make_turrets()
	_restyle_hud()


func _restyle_hud() -> void:
	for l: Label in [_status, _hint, _banner]:
		l.label_settings.font_color = Color(0.8, 0.95, 1.0)
		l.label_settings.outline_color = Color(0.3, 0.0, 0.4, 0.9)
	_hint.text = "WASD move   ·   SPACE push   ·   lasers fire on the beat   ·   R restart"


func _make_blob() -> OldBlob:
	return NeonBlob.new()


func _make_fx() -> Fx:
	return NeonFx.new()


func _on_impact(pos: Vector2, strength: float) -> void:
	if strength < 120.0:
		return
	grid.impulse(pos, strength * NT.GRID_IMPACT_SCALE, 60.0 + strength * 0.08)


func _process(delta: float) -> void:
	super._process(delta)
	var k := music.kick_env()
	camera.zoom *= 1.0 + NT.BEAT_PULSE * k
	grid.pulse = k
	_record_trails()
	_overlay.queue_redraw()


func _record_trails() -> void:
	var seen := {}
	for other in blobs:
		var b: OldBlob = other
		var id := b.get_instance_id()
		seen[id] = true
		if not trails.has(id):
			trails[id] = []
		var pts: Array = trails[id]
		pts.append(b.position)
		while pts.size() > NT.TRAIL_FRAMES:
			pts.pop_front()
	for id in trails.keys():
		if not seen.has(id):
			trails.erase(id)


# --- Lasers ------------------------------------------------------------------

func _make_turrets() -> void:
	for i in NT.TURRET_COUNT:
		var t := {"angle": TAU * i / NT.TURRET_COUNT}
		_reset_turret(t)
		t["aim"] = -Vector2.from_angle(t["angle"])
		turrets.append(t)


func _reset_turret(t: Dictionary) -> void:
	t["fire_beat"] = -1.0
	t["fired"] = false
	t["locked"] = false
	t["charging"] = false
	t["target"] = null
	t["dodgers"] = []
	t["length"] = 0.0


func _turret_pos(t: Dictionary) -> Vector2:
	return Vector2.from_angle(t["angle"]) * (T.WALL_RADIUS + NT.TURRET_DISTANCE)


## Distance from a turret to the far side of the wall along `dir`.
func _beam_length(from: Vector2, dir: Vector2) -> float:
	var b := from.dot(dir)
	var disc := b * b - (from.length_squared() - T.WALL_RADIUS * T.WALL_RADIUS)
	if disc <= 0.0:
		return 1400.0
	return -b + sqrt(disc)


func _before_simulate(delta: float) -> void:
	var beat := music.beat()
	if state == "playing":
		_play_time += delta
		_schedule_lasers(beat)
	for t in turrets:
		_update_turret(t, beat, delta)


func _schedule_lasers(beat: float) -> void:
	var bar := int(floorf(beat / 4.0))
	if bar == _last_bar:
		return
	_last_bar = bar
	if _play_time < NT.LASER_START_DELAY:
		return
	# More lasers the longer the round goes on.
	var count := 1 if randf() < 0.7 else 0
	if _play_time > 30.0 and randf() < 0.5:
		count += 1
	if _play_time > 60.0 and randf() < 0.5:
		count += 1
	var idle := turrets.filter(func(t): return t["fire_beat"] < 0.0)
	idle.shuffle()
	for i in mini(count, idle.size()):
		var t: Dictionary = idle[i]
		t["fire_beat"] = float(bar + 1) * 4.0  # fires on the next downbeat


func _update_turret(t: Dictionary, beat: float, delta: float) -> void:
	var pos := _turret_pos(t)
	var aim: Vector2 = t["aim"]
	var fire_beat: float = t["fire_beat"]
	var to_fire := fire_beat - beat

	if fire_beat < 0.0 or to_fire > NT.LASER_CHARGE_BEATS:
		# Idle (or waiting for its slot): drift round the arena, face the middle.
		t["angle"] = float(t["angle"]) + NT.TURRET_ORBIT_SPEED * delta
		t["aim"] = aim.slerp(-pos.normalized(), 1.0 - exp(-3.0 * delta)).normalized()
		return

	if to_fire > NT.LASER_LOCK_BEATS:
		# Charging: track a victim.
		if not t["charging"]:
			t["charging"] = true
			t["target"] = blobs.pick_random() if not blobs.is_empty() else null
			sfx.play("charge", randf_range(0.95, 1.05), -12.0, 0.0)
		var target = t["target"]
		if target != null and is_instance_valid(target) and target.alive:
			var want: Vector2 = (target.position + target.vel * 0.15 - pos).normalized()
			aim = aim.slerp(want, 1.0 - exp(-7.0 * delta)).normalized()
			t["aim"] = aim
		t["length"] = _beam_length(pos, aim)
		return

	if to_fire > 0.0:
		# Locked: aim is frozen. Bots that noticed try to sidestep.
		if not t["locked"]:
			t["locked"] = true
			var dodgers := []
			for other in blobs:
				if other.brain and randf() < 0.35 + 0.5 * other.brain.skill:
					dodgers.append(other)
			t["dodgers"] = dodgers
		_dodge(t, pos)
		return

	if not t["fired"]:
		t["fired"] = true
		_fire(t, pos)
	if to_fire < -NT.LASER_FIRE_BEATS:
		_reset_turret(t)


func _dodge(t: Dictionary, pos: Vector2) -> void:
	var d: Vector2 = t["aim"]
	var length: float = t["length"]
	for other in t["dodgers"]:
		if not is_instance_valid(other) or not other.alive:
			continue
		var b: OldBlob = other
		var rel := b.position - pos
		var off := rel - d * clampf(rel.dot(d), 0.0, length)
		if off.length() > b.radius + NT.LASER_WIDTH + 40.0:
			continue
		var side := Vector2(-d.y, d.x)
		if side.dot(off) < 0.0:
			side = -side
		b.move_dir = side


func _fire(t: Dictionary, pos: Vector2) -> void:
	var d: Vector2 = t["aim"]
	var length := _beam_length(pos, d)
	t["length"] = length
	sfx.play("zap", randf_range(0.95, 1.05), 0.0, 0.0)
	add_shake(5.0)
	var hit_any := false
	for other in blobs:
		var b: OldBlob = other
		var rel := b.position - pos
		var off := rel - d * clampf(rel.dot(d), 0.0, length)
		if off.length() > b.radius + NT.LASER_WIDTH * 0.5:
			continue
		var dv := NT.LASER_IMPULSE / pow(b.mass, T.PUSH_RESIST_EXP)
		b.vel += d * dv
		b.stun = maxf(b.stun, T.PUSH_STUN)
		b.flash = 1.0
		b.bump(d, dv)
		fx.burst(b.position, NT.LASER_COLOR, 18, 500.0)
		hit_any = true
	if hit_any:
		hitstop = maxf(hitstop, T.HITSTOP_PUSH)
		add_shake(6.0)
	var steps := int(length / 70.0)
	for i in steps + 1:
		grid.impulse(pos + d * (i * 70.0), 260.0, 90.0)
	fx.burst(pos + d * length, NT.LASER_COLOR, 12, 350.0)


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	var k := music.kick_env()

	# Out-of-bounds zone and ring floor are see-through so the grid shows.
	draw_circle(Vector2.ZERO, T.WALL_RADIUS, NT.MOAT_COLOR)
	var mid := (T.WALL_RADIUS + T.RING_RADIUS) * 0.5
	var dashes := 48
	for i in dashes:
		var a0 := TAU * i / dashes + clock * 0.15
		draw_arc(Vector2.ZERO, mid, a0, a0 + TAU / dashes * 0.35, 4, Color(1.0, 0.1, 0.3, 0.3), 3.0, true)
	draw_circle(Vector2.ZERO, T.RING_RADIUS, NT.FLOOR_COLOR)

	# Motion trails, under the blobs.
	for other in blobs:
		var b: OldBlob = other
		var id := b.get_instance_id()
		if not trails.has(id):
			continue
		var pts: Array = trails[id]
		var n := pts.size()
		for i in range(1, n):
			var f := float(i) / n
			draw_line(pts[i - 1], pts[i], NeonLook.hdr(b.color, 1.5, 0.35 * f), maxf(b.radius * 1.3 * f, 1.0), true)

	# Ring edge thumps with the kick drum.
	draw_arc(Vector2.ZERO, T.RING_RADIUS, 0.0, TAU, 128, NeonLook.hdr(NT.RING_COLOR, NT.RING_GLOW + NT.RING_PULSE * k), 4.0 + NT.RING_PULSE_WIDTH * k, true)
	draw_arc(Vector2.ZERO, T.RING_RADIUS + 9.0, 0.0, TAU, 128, NeonLook.hdr(NT.RING_COLOR, 0.8, 0.35), 1.5, true)

	# Wall, flashing where it was hit.
	var wall_r := T.WALL_RADIUS + 6.0
	draw_arc(Vector2.ZERO, wall_r, 0.0, TAU, 128, NeonLook.hdr(NT.WALL_COLOR, 1.4), 4.0, true)
	for hit in wall_hits:
		var t: float = hit["age"] / 0.35
		var power: float = hit["power"]
		var ang: float = hit["angle"]
		var span := 0.15 + 0.2 * power
		draw_arc(Vector2.ZERO, wall_r, ang - span, ang + span, 16, NeonLook.hdr(Color.WHITE, 3.0, 1.0 - t), 4.0 + 6.0 * power * (1.0 - t), true)

	# Food: spinning neon diamonds.
	for f in foods:
		var age: float = f["age"]
		var fpos: Vector2 = f["pos"]
		var fseed: float = f["seed"]
		var pop := minf(age / 0.25, 1.0)
		var r := T.FOOD_RADIUS * (1.0 + 0.4 * sin(pop * PI)) * pop * (1.3 + 0.2 * k)
		var pts := PackedVector2Array()
		for j in 4:
			pts.append(fpos + Vector2.from_angle(clock * 2.0 + fseed + j * PI / 2.0) * r)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_colored_polygon(pts, NeonLook.hdr(NT.FOOD_COLOR, 0.5, 0.5))
		draw_polyline(outline, NeonLook.hdr(NT.FOOD_COLOR, 2.5), 2.0, true)


func _draw_overlay() -> void:
	var beat := music.beat()
	var k := music.kick_env()
	for t in turrets:
		var pos := _turret_pos(t)
		var aim: Vector2 = t["aim"]
		var fire_beat: float = t["fire_beat"]
		var length: float = t["length"]
		var to_fire := fire_beat - beat if fire_beat >= 0.0 else 99.0

		var charge := 0.0
		if to_fire > 0.0 and to_fire <= NT.LASER_CHARGE_BEATS:
			charge = 1.0 - to_fire / NT.LASER_CHARGE_BEATS

		# Telegraph: a thin tracking line that blinks once the aim locks.
		if charge > 0.0:
			var alpha := 0.15 + 0.5 * charge
			var width := 1.5
			if to_fire <= NT.LASER_LOCK_BEATS:
				alpha = 0.9 if int(beat * 16.0) % 2 == 0 else 0.3
				width = 2.5
			_overlay.draw_line(pos, pos + aim * length, NeonLook.hdr(NT.LASER_COLOR, 1.0 + 2.0 * charge, alpha), width, true)

		# The beam itself.
		if fire_beat >= 0.0 and beat >= fire_beat and beat < fire_beat + NT.LASER_FIRE_BEATS:
			var q := (beat - fire_beat) / NT.LASER_FIRE_BEATS
			var end := pos + aim * length
			_overlay.draw_line(pos, end, NeonLook.hdr(NT.LASER_COLOR, 3.0, 1.0 - q), NT.LASER_WIDTH * 1.4 * (1.0 - q) + 1.0, true)
			_overlay.draw_line(pos, end, NeonLook.hdr(Color.WHITE, 3.0, 1.0 - q), NT.LASER_WIDTH * 0.35 * (1.0 - q) + 1.0, true)

		# Turret: a neon arrowhead pointing where it aims.
		var side := Vector2(-aim.y, aim.x)
		var tip := pos + aim * 16.0
		var body := PackedVector2Array([tip, pos - aim * 10.0 + side * 12.0, pos - aim * 4.0, pos - aim * 10.0 - side * 12.0, tip])
		_overlay.draw_polyline(body, NeonLook.hdr(NT.TURRET_COLOR, 1.5 + 1.5 * k + 3.0 * charge), 2.5, true)
		if charge > 0.0:
			_overlay.draw_circle(tip, 2.0 + 6.0 * charge, NeonLook.hdr(NT.LASER_COLOR, 2.0 + 2.0 * charge, 0.9))
