class_name Blob
extends Node2D
## One bumper blob: its movement, its moves (push, dash, slash, spit, shield),
## energy and mass. It doesn't steer itself: a controller child (PlayerInput,
## a BotBrain) sets `move_dir` and calls `request_push()`, `request_dash()`,
## `request_slash()`, `request_spit()`, `request_shield()`. Which moves it has
## comes from `rules`. BlobPhysics moves and collides it, and the Body child
## draws it. A slash is a Slash scene spawned on the blob; spit is a Shot,
## spawned next to it. The shield blocks pushes and slashes and sends shots
## back. Works in any scene that has a BlobPhysics node.

signal pushed(blob: Blob, hits: int)
signal ate_food(blob: Blob)
signal died(blob: Blob)
signal dashed(blob: Blob)
signal slashed(blob: Blob)
signal spat(blob: Blob)
signal blocked(blob: Blob, attacker: Blob) # its shield stopped a push or a slash
signal reflected(blob: Blob, shot: Shot) # its shield sent a shot back

@export var stats: BlobStats = preload("res://entities/blob/stats/default.tres")
@export var color := Color.WHITE
@export var display_name := "Blob"
@export var tag := "" # "P1"/"P2", shown over the head in multiplayer
@export var team := -1 # in team modes (football): 0 or 1, shown as a coloured spot under it; -1 = no team
@export_file("*.tscn") var slash_scene := "res://entities/slash/slash.tscn"
@export_file("*.tscn") var spit_scene := "res://entities/shots/spit.tscn"

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
var push_cooldown_full := 1.0 # what push_cooldown started at (for the cooldown ring)
var rules := GameSettings.rules() # which moves this blob has: the player's settings, shared by every blob
var dash_t := 0.0 # > 0 while dashing
var dash_dir := Vector2.RIGHT
var dash_cooldown := 0.0
var dash_buffer := 0.0 # > 0 means "dash as soon as you can"
var energy := -1.0 # in segments, up to stats.energy_segments (filled in _ready)
var energy_delay := 0.0 # refilling waits until this runs out
var energy_denied := 0.0 # 1 -> 0 after trying a move without the energy (meters flash)
var slash_cooldown := 0.0
var slash_buffer := 0.0
var spit_cooldown := 0.0
var spit_buffer := 0.0
var shield_t := 0.0 # > 0 while the shield is up
var shield_cooldown := 0.0
var shield_buffer := 0.0
var shield_flash := 0.0 # 1 -> 0 after the shield stops something (it lights up)

## Worked out from `stats` every time, so editing the .tres resizes blobs live.
var radius: float:
	get:
		return stats.base_radius * pow(mass, stats.size_radius_exp)

var _death_t := 0.0
var _dash_aim := Vector2.ZERO
var _slash_aim := Vector2.ZERO
var _slash_side := 1.0 # flips every swing, so a combo goes back and forth
var _spit_aim := Vector2.ZERO

@onready var body: BlobBody = $Body


func _enter_tree() -> void:
	add_to_group("blobs")


func _ready() -> void:
	process_physics_priority = 10 # after controllers and BlobPhysics
	set_mass(mass)
	energy = stats.energy_segments


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
	return push_cooldown <= 0.0 and windup <= 0.0 and shield_t <= 0.0 \
		and (not rules.push_costs_energy() or energy >= stats.push_cost)


func slash_ready() -> bool:
	return _can_slash() and (not rules.attacks_cost_energy() or energy >= stats.slash_cost)


func spit_ready() -> bool:
	return _can_spit() and (not rules.attacks_cost_energy() or energy >= stats.spit_cost)


func shield_ready() -> bool:
	return _can_shield() and (not rules.shield_costs_energy() or energy >= stats.shield_cost)


func is_shielding() -> bool:
	return shield_t > 0.0


func _can_slash() -> bool:
	return rules.slash and slash_cooldown <= 0.0 and windup <= 0.0 and shield_t <= 0.0


func _can_spit() -> bool:
	return rules.spit and spit_cooldown <= 0.0 and windup <= 0.0 and shield_t <= 0.0


func _can_shield() -> bool:
	return rules.shield and shield_t <= 0.0 and shield_cooldown <= 0.0


func dash_ready() -> bool:
	return _can_dash() and (not rules.dash_costs_energy() or energy >= stats.dash_cost)


## Everything but the energy: has a dash, isn't busy, isn't stunned, no cooldown.
func _can_dash() -> bool:
	return rules.dash != MoveRules.Dash.NONE and dash_t <= 0.0 and windup <= 0.0 \
		and stun <= 0.0 and dash_cooldown <= 0.0


func is_dashing() -> bool:
	return dash_t > 0.0


## Mid ghost dash: blobs, pushes and lasers pass through.
func is_ghost() -> bool:
	return dash_t > 0.0 and rules.dash == MoveRules.Dash.GHOST


## Mid ghost dash with rules that let it pass through walls and bumpers too.
func phases_obstacles() -> bool:
	return is_ghost() and rules.ghost_obstacles


func dash_speed() -> float:
	return stats.dash_speed / pow(mass, stats.size_speed_exp)


func is_winding_up() -> bool:
	return windup > 0.0


func is_human() -> bool:
	return controller is PlayerInput


func request_push() -> void:
	push_buffer = stats.push_buffer


## Dash along `dir`; with no direction, the way it's steering or facing.
func request_dash(dir := Vector2.ZERO) -> void:
	dash_buffer = stats.push_buffer
	_dash_aim = dir


## Slash along `dir`; with no direction, the way it's steering or facing.
func request_slash(dir := Vector2.ZERO) -> void:
	slash_buffer = stats.push_buffer
	_slash_aim = dir


## Spit along `dir`; with no direction, the way it's steering or facing.
func request_spit(dir := Vector2.ZERO) -> void:
	spit_buffer = stats.push_buffer
	_spit_aim = dir


func request_shield() -> void:
	shield_buffer = stats.push_buffer


## `dir` if it's a direction, else the way the blob is steering, else the way it faces.
func aim(dir := Vector2.ZERO) -> Vector2:
	if dir.length() < 0.1:
		dir = move_dir
	if dir.length() < 0.1:
		dir = body.look
	return dir.normalized()


## Called by BlobPhysics once per substep. `in_mud` slows the blob down.
func step_motion(h: float, in_mud: bool) -> void:
	if dash_t > 0.0:
		# Dashing: fly straight, no steering, no drag. Anything that knocks it
		# off course (a blob, a wall) ends the dash and normal physics takes over.
		if vel.dot(dash_dir) > dash_speed() * 0.6:
			global_position += vel * h
			return
		dash_t = 0.0
	var control := 1.0
	if stun > 0.0:
		control = stats.stun_control
	if in_mud:
		control *= stats.outside_control
	var top := max_speed()
	if shield_t > 0.0:
		top *= stats.shield_move
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
	dash_cooldown = maxf(dash_cooldown - delta, 0.0)
	dash_buffer = maxf(dash_buffer - delta, 0.0)
	stun = maxf(stun - delta, 0.0)
	energy_denied = maxf(energy_denied - delta * 2.5, 0.0)
	energy_delay = maxf(energy_delay - delta, 0.0)
	slash_cooldown = maxf(slash_cooldown - delta, 0.0)
	slash_buffer = maxf(slash_buffer - delta, 0.0)
	spit_cooldown = maxf(spit_cooldown - delta, 0.0)
	spit_buffer = maxf(spit_buffer - delta, 0.0)
	shield_cooldown = maxf(shield_cooldown - delta, 0.0)
	shield_buffer = maxf(shield_buffer - delta, 0.0)
	shield_flash = maxf(shield_flash - delta * 6.0, 0.0)
	if energy_delay <= 0.0:
		energy = minf(energy + stats.energy_regen * delta, stats.energy_segments)
	if dash_t > 0.0:
		dash_t -= delta
		if dash_t <= 0.0:
			dash_t = 0.0
			vel = vel.limit_length(max_speed() * stats.dash_exit_speed)
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			windup = 0.0
			push_cooldown_full = stats.push_energy_cooldown if rules.push_costs_energy() else stats.push_cooldown
			push_cooldown = push_cooldown_full
			body.swell_kick(stats.push_swell * 22.0)
			_release_push()
	elif push_buffer > 0.0 and push_cooldown <= 0.0 and shield_t <= 0.0:
		push_buffer = 0.0
		if not rules.push_costs_energy() or _spend(stats.push_cost):
			windup = stats.push_windup
			body.swell_kick(-3.0)  # tense up before the blast
	if dash_buffer > 0.0 and _can_dash():
		dash_buffer = 0.0
		if not rules.dash_costs_energy() or _spend(stats.dash_cost):
			_start_dash()
	if slash_buffer > 0.0 and _can_slash():
		slash_buffer = 0.0
		if not rules.attacks_cost_energy() or _spend(stats.slash_cost):
			_release_slash()
	if spit_buffer > 0.0 and _can_spit():
		spit_buffer = 0.0
		if not rules.attacks_cost_energy() or _spend(stats.spit_cost):
			_release_spit()
	if shield_t > 0.0:
		shield_t -= delta
		if shield_t <= 0.0:
			shield_t = 0.0
			shield_cooldown = stats.shield_energy_cooldown if rules.shield_costs_energy() else stats.shield_cooldown
			Juice.shockwave(global_position, radius + 12.0, radius + 30.0, color.lerp(Color.WHITE, 0.6), 0.18)
			Sfx.play("shield_down", randf_range(0.95, 1.05), -6.0)
	elif shield_buffer > 0.0 and _can_shield():
		shield_buffer = 0.0
		if not rules.shield_costs_energy() or _spend(stats.shield_cost):
			_raise_shield()


## Takes `cost` energy, or flashes the meters and returns false if there isn't enough.
func _spend(cost: float) -> bool:
	if energy < cost:
		energy_denied = 1.0
		if is_human():
			Sfx.play("deny", 1.0, -4.0)
		return false
	energy -= cost
	energy_delay = stats.energy_regen_delay
	return true


func _start_dash() -> void:
	dash_dir = aim(_dash_aim)
	dash_t = stats.dash_time
	if not rules.dash_costs_energy():
		dash_cooldown = stats.dash_cooldown
	vel = dash_dir * dash_speed()
	var ghost := rules.dash == MoveRules.Dash.GHOST
	body.swell_kick(-4.0)
	body.bump(dash_dir, 600.0)
	Juice.burst(global_position - dash_dir * radius, color.lightened(0.4), 8, 260.0)
	Juice.impact_at(global_position, 350.0)
	if ghost:
		Juice.shockwave(global_position, radius, radius * 2.2, color.lightened(0.6), 0.22)
	Sfx.play("dash", randf_range(1.15, 1.25) if ghost else randf_range(0.9, 1.0), -2.0)
	dashed.emit(self)


func _release_push() -> void:
	var js := Juice.settings
	var reach := push_reach()
	Juice.shockwave(global_position, radius, reach, color.lightened(0.5))
	Sfx.play("push", randf_range(0.95, 1.05) / sqrt(mass), 0.0, 0.0)
	var hits := 0
	for other: Blob in get_tree().get_nodes_in_group("blobs"):
		if other == self or not other.alive or other.is_ghost():
			continue
		var d := other.global_position - global_position
		var dist := d.length()
		if dist - other.radius > reach:
			continue
		var n := d / dist if dist > 0.001 else Vector2.from_angle(randf() * TAU)
		if other.try_block(self, other.global_position - n * other.radius):
			continue
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


## Swing at once: no windup, so the button press and the cut are the same frame.
func _release_slash() -> void:
	slash_cooldown = stats.slash_cooldown
	var d := aim(_slash_aim)
	_slash_side = -_slash_side
	var slash: Slash = load(slash_scene).instantiate()
	add_child(slash)
	slash.launch(self, d, _slash_side, push_power())
	vel += d * stats.slash_lunge
	body.look = d
	body.bump(-d, 450.0) # stretch into the swing
	body.swell_kick(4.0)
	Sfx.play("slash", randf_range(0.92, 1.08) / sqrt(mass), 0.0, 0.0)
	slashed.emit(self)


func _raise_shield() -> void:
	shield_t = stats.shield_time
	body.swell_kick(-4.0)
	Juice.shockwave(global_position, radius, radius + 16.0, color.lerp(Color.WHITE, 0.7), 0.14)
	Juice.impact_at(global_position, 300.0)
	Sfx.play("shield", randf_range(0.95, 1.05), 0.0)


func _release_spit() -> void:
	spit_cooldown = stats.spit_energy_cooldown if rules.attacks_cost_energy() else stats.spit_cooldown
	var d := aim(_spit_aim)
	var spit: Shot = _spawn(spit_scene)
	spit.launch(self, global_position + d * (radius + stats.spit_radius), d, push_power())
	vel -= d * stats.spit_recoil
	set_mass(mass - stats.spit_mass)
	body.swell_kick(-4.0)
	body.bump(d, 300.0)
	Juice.burst(global_position + d * radius, color.lightened(0.4), 5, 180.0)
	Sfx.play("spit", randf_range(0.9, 1.1) / sqrt(mass), -2.0, 0.0)
	spat.emit(self)


## A Shot scene, added next to this blob (so it outlives it).
func _spawn(path: String) -> Shot:
	var shot: Shot = load(path).instantiate()
	get_parent().add_child(shot)
	return shot


## A push or a slash from `attacker`, landing at `at`, asks whether the shield
## stops it. True: blocked, and the shield shows it; the attack does nothing.
func try_block(attacker: Blob, at: Vector2) -> bool:
	if shield_t <= 0.0:
		return false
	var js := Juice.settings
	var n := (at - global_position).normalized()
	shield_flash = 1.0
	body.swell_kick(5.0)
	body.bump(n, 350.0)
	Juice.burst(at, Color.WHITE, 14, 520.0, n, 0.8)
	Juice.burst(at, color.lerp(Color.WHITE, 0.5), 8, 300.0, n, 1.4)
	Juice.impact_at(at, 800.0)
	Juice.hitstop(js.hitstop_block)
	Juice.shake(js.shake_push * 0.5)
	Sfx.play("clang", randf_range(0.95, 1.05), 0.0, 0.0)
	blocked.emit(self, attacker)
	return true


## A Shot touching this blob asks whether it gets reflected. True: the shield
## is up, so it flies back (the Shot does that) and this blob shows the catch.
func try_reflect(shot: Shot) -> bool:
	if shield_t <= 0.0:
		return false
	var js := Juice.settings
	var n := (shot.global_position - global_position).normalized()
	shield_flash = 1.0
	body.swell_kick(6.0)
	body.bump(n, 500.0)
	Juice.shockwave(global_position, radius + 14.0, radius * 3.0, Color.WHITE, 0.25)
	Juice.burst(global_position + n * (radius + 14.0), Color.WHITE, 16, 450.0, n, 1.0)
	Juice.impact_at(global_position, 900.0)
	Juice.hitstop(js.hitstop_push)
	Juice.shake(js.shake_push * 0.7)
	Sfx.play("reflect", randf_range(0.95, 1.05) * pow(1.06, shot.reflections), 0.0, 0.0)
	reflected.emit(self, shot)
	return true


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
