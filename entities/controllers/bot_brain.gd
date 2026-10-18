class_name BotBrain
extends Node
## Shared bot plumbing: a decision every `think_time`, smooth wobbly steering,
## delayed pushes, slashes and spit, counter-pushes, shields and target picking. Subclasses say where to
## go in _decide() and what makes a good target in _target_score().
## Personality numbers make each bot play a little differently; `level` says
## what it may do and the ranges they're rolled from.

@export var level: BotLevel = preload("res://entities/controllers/levels/normal.tres")
@export var randomize_personality := true # re-roll the four numbers below on spawn, inside the level's ranges

@export_group("Personality")
@export_range(0, 1) var aggression := 0.7 # fighting vs. eating
@export_range(0, 1) var caution := 0.55   # how far from danger they like to stay
@export_range(0, 1) var greed := 0.55     # how tempting food is
@export_range(0, 1) var skill := 0.65     # positioning, push timing, reactions, dodging

@export_group("Reflexes")
@export var think_time := 0.15    # seconds between decisions
@export var reaction := 0.18      # delay before they actually push
@export var turn_rate := 7.0      # how fast their steering follows their intent
@export var wobble := 0.25        # random wiggle so they don't look robotic
@export var lead := 0.25          # how far ahead they aim at a moving target (s)
@export var player_bias := 60.0   # how much more they like picking on a human

var target: Blob = null
var _desired := Vector2.ZERO # where _decide() wants to go, length <= 1
var _steer := Vector2.ZERO
var _think_timer := 0.0
var _attack_timer := -1.0
var _attack_kind := "push" # what fires when _attack_timer runs out: "push", "slash" or "spit"
var _attack_at: Blob = null # who a slash or spit is aimed at
var _shield_plans := {} # Shot -> [its reflections, shield it?, raise it this many s before impact]: rolled once per shot and bounce
var _wander := randf() * TAU

@onready var me: Blob = get_parent()


func _ready() -> void:
	process_physics_priority = -10 # before BlobPhysics moves the blob
	me.controller = self
	if randomize_personality:
		aggression = randf_range(level.aggression.x, level.aggression.y)
		caution = randf_range(level.caution.x, level.caution.y)
		greed = randf_range(level.greed.x, level.greed.y)
		skill = randf_range(level.skill.x, level.skill.y)
	_think_timer = randf() * think_time


func _physics_process(delta: float) -> void:
	if not me.alive or not me.active:
		return
	if not level.moves:
		me.move_dir = Vector2.ZERO
		return
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = think_time * randf_range(0.7, 1.3)
		_decide()
	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0 and level.pushes:
			_fire_attack()
	_watch_shots()
	# Smooth, slightly wobbly steering so they look alive rather than robotic.
	_wander += randf_range(-3.0, 3.0) * delta
	var wiggle := Vector2.from_angle(_wander) * wobble
	_steer = _steer.lerp((_desired + wiggle).limit_length(1.0), 1.0 - exp(-turn_rate * delta))
	me.move_dir = _steer


## Override: set `_desired`.
func _decide() -> void:
	pass


## Override: extra score for picking `o` as the target (higher = more tempting).
func _target_score(_o: Blob) -> float:
	return 0.0


## Override: false for food that isn't worth going for.
func _food_ok(_pos: Vector2) -> bool:
	return true


## Push after a short, skill-dependent reaction delay.
func _queue_push() -> void:
	_queue_attack("push")


## Push, slash or spit (at `at`) after a short, skill-dependent reaction delay.
func _queue_attack(kind: String, at: Blob = null) -> void:
	_attack_kind = kind
	_attack_at = at
	_attack_timer = reaction * level.reaction_scale * randf_range(0.6, 1.4) * lerpf(1.6, 0.6, skill)


func _attack_queued() -> bool:
	return _attack_timer > 0.0


func _fire_attack() -> void:
	match _attack_kind:
		"push":
			me.request_push()
		"slash":
			me.request_slash(_aim_at(_attack_at, INF))
		"spit":
			me.request_spit(_aim_at(_attack_at, me.stats.spit_speed))


## Toward `o`, leading it (better with skill) by how long a shot at `shot_speed` takes to get there.
func _aim_at(o: Blob, shot_speed: float) -> Vector2:
	if o == null or not is_instance_valid(o) or not o.alive:
		return Vector2.ZERO
	var to_o := o.global_position - me.global_position
	var t := to_o.length() / maxf(shot_speed, 1.0)
	return (to_o + o.vel * t * skill).normalized()


## Queue a slash at `o` when they're inside the blade's reach (the push isn't
## ready, or this bot just likes slashing), or a spit when they're far. A
## spit keeps energy back for a push; the slash is the cheap jab, so it
## doesn't. Returns true if it queued one.
func _try_shoot(o: Blob) -> bool:
	if o == null or _attack_queued() or not level.pushes:
		return false
	var gap := o.global_position.distance_to(me.global_position) - o.radius - me.radius
	if me.slash_ready() and gap < me.stats.slash_range * 0.85 \
			and randf() < 0.3 + 0.5 * aggression:
		_queue_attack("slash", o)
		return true
	if me.spit_ready() and _spare_energy(me.stats.spit_cost) \
			and gap > me.stats.push_range * 1.5 and gap < me.stats.spit_range * 0.7 \
			and randf() < 0.25 * aggression * skill:
		_queue_attack("spit", o)
		return true
	return false


## A move costing `cost` still leaves enough energy for a push (or moves are free).
func _spare_energy(cost: float) -> bool:
	return not me.rules.attacks_cost_energy() or me.energy >= cost + me.stats.push_cost


## Maybe raise the shield before spit lands. Whether to try is rolled once
## per shot (and again after each bounce, less likely the faster the rally),
## from skill, and so is the timing: sloppier bots raise it too early and it
## runs out first. It costs energy, so most shots just get dodged or taken.
func _watch_shots() -> void:
	if not me.rules.shield or not level.shields:
		return
	for gone in _shield_plans.keys():
		if not is_instance_valid(gone):
			_shield_plans.erase(gone)
	for shot: Shot in get_tree().get_nodes_in_group("shots"):
		if shot.shooter == me:
			continue
		var t := shot.time_to_reach(me)
		if t == INF:
			continue
		var plan: Array = _shield_plans.get(shot, [])
		if plan.is_empty() or plan[0] != shot.reflections:
			var lead_time := me.stats.shield_time * randf_range(0.2, lerpf(1.4, 0.7, skill))
			plan = [shot.reflections, randf() < 0.45 * skill * pow(0.75, shot.reflections), lead_time]
			_shield_plans[shot] = plan
		if plan[1] and t < plan[2] and me.shield_ready():
			me.request_shield()


## Dodge-dash away from, shield against, or counter-push anyone winding up a
## push right next to us. Now and then, shield against someone in slash
## reach who is facing us (a slash has no windup to react to).
func _react_to_threats() -> void:
	var can_push := me.push_ready() and not _attack_queued()
	var can_dash := _dash_ok()
	var can_shield := _shield_ok()
	if not can_push and not can_dash and not can_shield:
		return
	for o: Blob in get_tree().get_nodes_in_group("blobs"):
		if o == me or not o.alive or o.controller == null:
			continue
		var dist := o.global_position.distance_to(me.global_position) - me.radius
		if not o.is_winding_up():
			var facing := o.body.look.dot((me.global_position - o.global_position).normalized())
			if can_shield and o.rules.slash and dist < o.radius + o.stats.slash_range \
					and facing > 0.7 and randf() < skill * 0.06:
				me.request_shield()
				return
			continue
		if dist >= o.push_reach() + 20.0:
			continue
		if can_dash and randf() < skill * 0.6:
			me.request_dash(_dodge_dir(o))
			return
		if can_shield and randf() < skill * 0.25:
			me.request_shield()
			return
		if can_push and randf() < skill * 0.5:
			_attack_kind = "push"
			_attack_timer = 0.01
			return


## The shield is ready and the level allows it. When it costs energy, bots
## keep enough back for a push.
func _shield_ok() -> bool:
	if not me.rules.shield or not level.shields or not me.shield_ready():
		return false
	if me.rules.shield_costs_energy() and me.rules.push_costs_energy():
		return me.energy >= me.stats.shield_cost + me.stats.push_cost
	return true


## The rules let bots dash and the dash is ready. When pushes cost energy too,
## bots keep enough back for a push.
func _dash_ok() -> bool:
	if not me.rules.bots_dash or not level.dashes or not me.dash_ready():
		return false
	if me.rules.push_costs_energy():
		return me.energy >= me.stats.dash_cost + me.stats.push_cost
	return true


## Override: which way to dash to get out of `threat`'s push. Default: away and to the side.
func _dodge_dir(threat: Blob) -> Vector2:
	var away := (me.global_position - threat.global_position).normalized()
	var side := Vector2(-away.y, away.x)
	if side.dot(me.vel) < 0.0:
		side = -side
	return (away + side).normalized()


func _pick_target() -> void:
	if target != null and (not is_instance_valid(target) or not target.alive):
		target = null
	var best: Blob = null
	var best_score := -INF
	for o: Blob in get_tree().get_nodes_in_group("blobs"):
		if o == me or not o.alive:
			continue
		var score := -o.global_position.distance_to(me.global_position)
		score += _target_score(o)
		score += (me.mass - o.mass) * 80.0 * caution  # pick on smaller ones
		if o.is_human():
			score += player_bias
		if o == target:
			score += 60.0  # don't flip-flop between targets
		if score > best_score:
			best_score = score
			best = o
	target = best


func _best_food() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for f: Node2D in get_tree().get_nodes_in_group("food"):
		if not _food_ok(f.global_position):
			continue
		var d := f.global_position.distance_to(me.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best
