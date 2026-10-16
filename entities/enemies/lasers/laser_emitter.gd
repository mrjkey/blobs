class_name LaserEmitter
extends Node2D
## A laser that fires on the beat. Once a LaserDirector gives it a `fire_beat`,
## it charges (tracking a random blob, with a thin telegraph line), locks its
## aim (bots that notice try to sidestep), fires (knockback, sparks, a grid
## ripple along the beam) and goes back to idle. Subclasses say where the beam
## ends (beam_length), how they move (_idle) and which LaserSkin body they draw
## (_draw_body). Joins group "lasers"; draws above the blobs (z_index 5 in its scene).

@export var settings: LaserSettings = preload("res://entities/enemies/lasers/turret_laser.tres")

var aim := Vector2.LEFT
var fire_beat := -1.0 # < 0 = idle
var length := 0.0 # current beam length

var _fired := false
var _locked := false
var _charging := false
var _target: Blob = null
var _dodgers: Array[Blob] = []


func _enter_tree() -> void:
	add_to_group("lasers")


func _ready() -> void:
	process_physics_priority = -5 # after the bots steer (-10), so dodging wins


func is_idle() -> bool:
	return fire_beat < 0.0


## Override: distance from `from` to where a beam along `dir` stops.
func beam_length(_from: Vector2, _dir: Vector2) -> float:
	return 1400.0


## Override: move and aim while not charging.
func _idle(_delta: float) -> void:
	pass


## Override: turn a wanted aim into an allowed one.
func _limit_aim(want: Vector2) -> Vector2:
	return want


## Override: called when charging starts, and when the shot is over.
func _on_charge_start() -> void:
	pass


func _on_reset() -> void:
	pass


func _physics_process(delta: float) -> void:
	if delta <= 0.0: # hitstop: catch up afterwards
		return
	var s := settings
	var pos := global_position
	var to_fire := fire_beat - Techno.current_beat(get_tree())

	if fire_beat < 0.0 or to_fire > s.charge_beats:
		_idle(delta)
		return

	if to_fire > s.lock_beats:
		# Charging: track a victim.
		if not _charging:
			_charging = true
			_on_charge_start()
			var blobs := _living_blobs()
			_target = blobs.pick_random() if not blobs.is_empty() else null
			Sfx.play("charge", randf_range(0.95, 1.05), -12.0, 0.0)
		if _target != null and is_instance_valid(_target) and _target.alive:
			var want := _limit_aim((_target.global_position + _target.vel * 0.15 - pos).normalized())
			aim = aim.slerp(want, 1.0 - exp(-7.0 * delta)).normalized()
		length = beam_length(pos, aim)
		return

	if to_fire > 0.0:
		# Locked: aim is frozen. Bots that noticed try to sidestep.
		if not _locked:
			_locked = true
			_dodgers.clear()
			for b in _living_blobs():
				var bot := b.controller as BotBrain
				if bot != null and randf() < 0.35 + 0.5 * bot.skill:
					_dodgers.append(b)
		_dodge(pos)
		return

	if not _fired:
		_fired = true
		_fire(pos)
	if to_fire < -s.fire_beats:
		_reset()


func _reset() -> void:
	fire_beat = -1.0
	_fired = false
	_locked = false
	_charging = false
	_target = null
	_dodgers.clear()
	length = 0.0
	_on_reset()


func _living_blobs() -> Array[Blob]:
	var out: Array[Blob] = []
	for b: Blob in get_tree().get_nodes_in_group("blobs"):
		if b.alive:
			out.append(b)
	return out


func _dodge(pos: Vector2) -> void:
	var d := aim
	for b in _dodgers:
		if not is_instance_valid(b) or not b.alive:
			continue
		var rel := b.global_position - pos
		var off := rel - d * clampf(rel.dot(d), 0.0, length)
		if off.length() > b.radius + settings.width + 40.0:
			continue
		var side := Vector2(-d.y, d.x)
		if side.dot(off) < 0.0:
			side = -side
		b.move_dir = side


func _fire(pos: Vector2) -> void:
	var s := settings
	var d := aim
	length = beam_length(pos, d)
	Sfx.play("zap", randf_range(0.95, 1.05), 0.0, 0.0)
	Juice.shake(5.0)
	var hit_any := false
	for b in _living_blobs():
		var rel := b.global_position - pos
		var off := rel - d * clampf(rel.dot(d), 0.0, length)
		if off.length() > b.radius + s.width * 0.5:
			continue
		var dv := s.impulse / pow(b.mass, b.stats.push_resist_exp)
		b.take_hit(d, dv, b.stats.push_stun, false)
		Juice.burst(b.global_position, GameTheme.current().laser.beam_color, 18, 500.0)
		hit_any = true
	if hit_any:
		Juice.hitstop(Juice.settings.hitstop_push)
		Juice.shake(6.0)
	for i in int(length / 70.0) + 1:
		get_tree().call_group("grid", "impulse", pos + d * (i * 70.0), 260.0, 90.0)
	Juice.burst(pos + d * length, GameTheme.current().laser.beam_color, 12, 350.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var s := settings
	var skin := GameTheme.current().laser
	var beat := ThemeSkin.beat(self)
	var to_fire := fire_beat - beat if fire_beat >= 0.0 else 99.0
	var charge := 0.0
	if to_fire > 0.0 and to_fire <= s.charge_beats:
		charge = 1.0 - to_fire / s.charge_beats
	skin.draw_beam(self, beat, to_fire, charge)
	_draw_body(skin, ThemeSkin.kick(self), charge)


## Override: draw the emitter at the origin, pointing along `aim`, with the skin.
func _draw_body(_skin: LaserSkin, _kick: float, _charge: float) -> void:
	pass
