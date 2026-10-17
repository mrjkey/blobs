class_name BotBrain
extends Node
## Shared bot plumbing: a decision every `think_time`, smooth wobbly steering,
## delayed pushes, counter-pushes and target picking. Subclasses say where to
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
var _push_timer := -1.0
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
	if _push_timer > 0.0:
		_push_timer -= delta
		if _push_timer <= 0.0 and level.pushes:
			me.request_push()
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
	_push_timer = reaction * level.reaction_scale * randf_range(0.6, 1.4) * lerpf(1.6, 0.6, skill)


func _push_queued() -> bool:
	return _push_timer > 0.0


## Dodge-dash away from, or counter-push, anyone winding up a push right next to us.
func _react_to_threats() -> void:
	var can_push := me.push_ready() and not _push_queued()
	var can_dash := _dash_ok()
	if not can_push and not can_dash:
		return
	for o: Blob in get_tree().get_nodes_in_group("blobs"):
		if o == me or not o.alive or not o.is_winding_up():
			continue
		var dist := o.global_position.distance_to(me.global_position) - me.radius
		if dist >= o.push_reach() + 20.0:
			continue
		if can_dash and randf() < skill * 0.6:
			me.request_dash(_dodge_dir(o))
			return
		if can_push and randf() < skill * 0.5:
			_push_timer = 0.01
			return


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
