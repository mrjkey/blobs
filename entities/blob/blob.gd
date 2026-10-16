class_name Blob
extends Node2D
## One bumper blob: its movement, push ability and mass. It doesn't steer
## itself: a controller child (PlayerInput, a BotBrain) sets `move_dir` and
## calls `request_push()`. BlobPhysics moves and collides it, and the Body
## child draws it. Works in any scene that has a BlobPhysics node.

signal pushed(blob: Blob, hits: int)
signal ate_food(blob: Blob)
signal died(blob: Blob)

@export var stats: BlobStats = preload("res://entities/blob/stats/default.tres")
@export var color := Color.WHITE
@export var display_name := "Blob"
@export var tag := "" # "P1"/"P2", shown over the head in multiplayer

var vel := Vector2.ZERO
var mass := 1.0
var move_dir := Vector2.ZERO # steering input, length <= 1, set by the controller
var alive := true
var active := true # false = controllers leave it alone (e.g. during the countdown)
var controller: Node # the PlayerInput or BotBrain steering this blob
var push_cooldown := 0.0
var push_buffer := 0.0 # > 0 means "push as soon as you can"
var windup := 0.0
var stun := 0.0
var ring_danger := 0.0 # 0..1, set by the arena while outside the ring

## Worked out from `stats` every time, so editing the .tres resizes blobs live.
var radius: float:
	get:
		return stats.base_radius * pow(mass, stats.size_radius_exp)

var _death_t := 0.0

@onready var body: BlobBody = $Body


func _enter_tree() -> void:
	add_to_group("blobs")


func _ready() -> void:
	process_physics_priority = 10 # after controllers and BlobPhysics
	set_mass(mass)


func set_mass(m: float) -> void:
	mass = clampf(m, 0.5, stats.max_mass)


func max_speed() -> float:
	return stats.base_speed / pow(mass, stats.size_speed_exp)


func accel() -> float:
	return stats.base_accel / pow(mass, stats.size_accel_exp)


func push_power() -> float:
	return pow(mass, stats.push_mass_exp)


## Distance from this blob's centre that a push can reach.
func push_reach() -> float:
	return radius + stats.push_range * pow(mass, stats.push_range_mass_exp)


func push_ready() -> bool:
	return push_cooldown <= 0.0 and windup <= 0.0


func is_winding_up() -> bool:
	return windup > 0.0


func is_human() -> bool:
	return controller is PlayerInput


func request_push() -> void:
	push_buffer = stats.push_buffer


## Called by BlobPhysics once per substep. `in_mud` slows the blob down.
func step_motion(h: float, in_mud: bool) -> void:
	var control := 1.0
	if stun > 0.0:
		control = stats.stun_control
	if in_mud:
		control *= stats.outside_control
	var top := max_speed()
	# Flying faster than you could run means you got launched: keep the momentum,
	# but bleed it off fast so hits read as a sharp shove, not a slow drift.
	var launched := vel.length() > top * 1.05
	if launched:
		control *= stats.knockback_control
	var target := move_dir * top
	var acc := accel()
	if move_dir.dot(vel) < 0.0:
		acc *= stats.turn_accel_mult  # snappy direction changes
	vel += (target - vel).limit_length(acc * control * h)
	var drag := stats.knockback_drag if launched else stats.drag
	if in_mud:
		drag += stats.outside_drag
	vel *= exp(-drag * h)
	global_position += vel * h


func _physics_process(delta: float) -> void:
	if not alive:
		return
	push_cooldown = maxf(push_cooldown - delta, 0.0)
	push_buffer = maxf(push_buffer - delta, 0.0)
	stun = maxf(stun - delta, 0.0)
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			windup = 0.0
			push_cooldown = stats.push_cooldown
			body.swell_kick(stats.push_swell * 22.0)
			_release_push()
	elif push_buffer > 0.0 and push_cooldown <= 0.0:
		push_buffer = 0.0
		windup = stats.push_windup
		body.swell_kick(-3.0)  # tense up before the blast


func _release_push() -> void:
	var js := Juice.settings
	var reach := push_reach()
	Juice.shockwave(global_position, radius, reach, color.lightened(0.5))
	Sfx.play("push", randf_range(0.95, 1.05) / sqrt(mass), 0.0, 0.0)
	var hits := 0
	for other: Blob in get_tree().get_nodes_in_group("blobs"):
		if other == self or not other.alive:
			continue
		var d := other.global_position - global_position
		var dist := d.length()
		if dist - other.radius > reach:
			continue
		var n := d / dist if dist > 0.001 else Vector2.from_angle(randf() * TAU)
		var gap := maxf(dist - other.radius - radius, 0.0)
		var falloff := lerpf(1.0, stats.push_falloff, clampf(gap / (reach - radius), 0.0, 1.0))
		var dv := stats.push_impulse * push_power() * falloff / pow(other.mass, other.stats.push_resist_exp)
		other.take_hit(n, dv, other.stats.push_stun)
		vel -= n * dv * stats.push_recoil * other.mass / mass
		Juice.burst(other.global_position - n * other.radius, other.color.lightened(0.4), 10, dv * 0.6)
		hits += 1
	Juice.impact_at(global_position, stats.push_impulse * (1.0 if hits > 0 else 0.5))
	if hits > 0:
		Juice.hitstop(js.hitstop_push)
		Juice.shake(js.shake_push * mini(hits, 2))
		Sfx.play("boing", randf_range(0.7, 0.8), 3.0, 0.0)
	else:
		Juice.shake(js.shake_whiff)
	pushed.emit(self, hits)


## Knocked along `n` at `speed` px/s (a push, a laser...). With `clean_hit`,
## any motion back toward the hit is cancelled first so the shove always lands.
func take_hit(n: Vector2, speed: float, stun_time: float, clean_hit := true) -> void:
	if clean_hit:
		var incoming := vel.dot(n)
		if incoming < 0.0:
			vel -= n * incoming
	vel += n * speed
	stun = maxf(stun, stun_time)
	body.flash = 1.0
	body.bump(n, speed)


## Squash along n. `impact_speed` is in px/s.
func bump(n: Vector2, impact_speed: float) -> void:
	body.bump(n, impact_speed)


func eat() -> void:
	set_mass(mass + stats.food_mass)
	body.swell_kick(5.0)
	body.flash = 0.6
	ate_food.emit(self)


## Out of the round: burst, then spin, shrink and fade away.
func die() -> void:
	if not alive:
		return
	alive = false
	_death_t = 0.0
	var js := Juice.settings
	Juice.impact_at(global_position, 1500.0)
	Juice.burst(global_position, color, 28, 380.0)
	Juice.shockwave(global_position, radius, radius * 4.0, color, 0.45)
	Sfx.play("out", randf_range(0.9, 1.1))
	Juice.shake(js.shake_elimination)
	Juice.hitstop(js.hitstop_elimination)
	died.emit(self)


func _process(delta: float) -> void:
	if alive:
		return
	_death_t += delta
	var k := _death_t / 0.45
	if k >= 1.0:
		queue_free()
		return
	global_position += vel * delta
	vel *= exp(-4.0 * delta)
	rotation += delta * 12.0
	scale = Vector2.ONE * (1.0 - k * k)
	modulate.a = 1.0 - k
