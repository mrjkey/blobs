extends Node
## Bot brain. Picks a victim, tries to get between them and the ring centre,
## charges, and pushes when they're in reach. Also grabs food and keeps away
## from the edge. Personality numbers make each bot play a little differently.

@export var randomize_personality := true # re-roll the four numbers below on spawn

@export_group("Personality")
@export_range(0, 1) var aggression := 0.7 # fighting vs. eating
@export_range(0, 1) var caution := 0.55   # how far from the edge they like to stay
@export_range(0, 1) var greed := 0.55     # how tempting food is
@export_range(0, 1) var skill := 0.65     # flanking, push timing, reactions

@export_group("Reflexes")
@export var think_time := 0.15    # seconds between decisions
@export var reaction := 0.18      # delay before they actually push
@export var turn_rate := 7.0      # how fast their steering follows their intent
@export var wobble := 0.25        # random wiggle so they don't look robotic
@export var lead := 0.25          # how far ahead they aim at a moving target (s)
@export var player_bias := 60.0   # how much more they like picking on the player

## Used until there is an Arena node in the "arena" group to read it from.
@export var fallback_ring_radius := 300.0

@onready var me: Blob = get_parent()

var target: Blob = null
var _desired := Vector2.ZERO
var _steer := Vector2.ZERO
var _think_timer := 0.0
var _push_timer := -1.0
var _wander := randf() * TAU
var _center := Vector2.ZERO
var _ring_r := 300.0


func _ready() -> void:
	if randomize_personality:
		aggression = randf_range(0.4, 1.0)
		caution = randf_range(0.2, 0.9)
		greed = randf_range(0.2, 0.9)
		skill = randf_range(0.3, 1.0)
	_think_timer = randf() * think_time


func _physics_process(delta: float) -> void:
	if not me.alive:
		return
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = think_time * randf_range(0.7, 1.3)
		_decide()
	if _push_timer > 0.0:
		_push_timer -= delta
		if _push_timer <= 0.0:
			me.request_push()
	# Smooth, slightly wobbly steering so they look alive rather than robotic.
	_wander += randf_range(-3.0, 3.0) * delta
	var wiggle := Vector2.from_angle(_wander) * wobble
	_steer = _steer.lerp((_desired + wiggle).limit_length(1.0), 1.0 - exp(-turn_rate * delta))
	me.move_dir = _steer


## Read the ring from the Arena if there is one, else assume it's at the origin.
func _update_ring() -> void:
	var arena = get_tree().get_first_node_in_group("arena")
	if arena != null:
		_center = arena.global_position
		_ring_r = arena.ring_radius
	else:
		_center = Vector2.ZERO
		_ring_r = fallback_ring_radius


## A position relative to the ring centre.
func _rel(p: Vector2) -> Vector2:
	return p - _center


func _decide() -> void:
	_update_ring()
	var pos := me.global_position
	var from_center := _rel(pos).length()
	var home := -_rel(pos) / from_center if from_center > 1.0 else Vector2.ZERO
	var edge_panic := _ring_r * 0.93
	var safe_r := _ring_r * lerpf(0.8, 0.55, caution)

	# Outside the ring (or about to be)? Nothing matters except getting back.
	if from_center > edge_panic:
		_desired = home
		return

	_pick_target()
	var dir := Vector2.ZERO

	var food := _best_food()
	var going_for_food := false
	if food != null:
		var fpos := food.global_position
		var food_dist := fpos.distance_to(pos)
		var target_dist := INF
		if target != null:
			target_dist = target.global_position.distance_to(pos) - target.radius
		var tempting := 60.0 + 220.0 * greed * (1.0 - 0.5 * aggression)
		if target == null or (food_dist < tempting and target_dist > 110.0):
			dir = (fpos - pos).normalized()
			going_for_food = true

	if not going_for_food and target != null:
		dir = _attack_dir()

	_react_to_threats()

	# Edge safety: blend back toward the centre, and never sprint outward near the edge.
	if from_center > safe_r:
		var danger := clampf((from_center - safe_r) / (edge_panic - safe_r), 0.0, 1.0)
		var outward := dir.dot(-home)
		if outward > 0.0:
			dir += home * outward * danger
		dir = dir.lerp(home, danger * 0.6)

	if dir.length() < 0.1:
		dir = home * 0.4 + Vector2.from_angle(_wander) * 0.4
	_desired = dir.limit_length(1.0)


func _attack_dir() -> Vector2:
	var pos := me.global_position
	var tpos := target.global_position
	var aim := tpos + target.vel * lead * skill
	var to_t := aim - pos
	var dist := to_t.length()
	var to_t_n := to_t / maxf(dist, 0.001)
	var t_rel := _rel(tpos)
	var t_out := t_rel.normalized() if t_rel.length() > 1.0 else to_t_n
	# 1.0 = the target is directly between me and the edge: a perfect push angle.
	var lined_up := to_t_n.dot(t_out)
	var reach := me.push_reach()
	var gap := dist - target.radius  # my centre to their edge

	var dir := to_t_n
	if lined_up < 0.2 and gap > reach * 0.8 and randf() < skill:
		# Circle round to the centre side of them first.
		var spot := tpos - t_out * (target.radius + me.radius + 50.0)
		var to_spot := spot - pos
		dir = to_spot.normalized()
		if dist < 140.0:
			# Don't plough straight through them on the way round.
			var side := Vector2(-to_t_n.y, to_t_n.x)
			if side.dot(to_spot) < 0.0:
				side = -side
			dir = (dir + side * 1.2).normalized()

	if me.push_ready() and _push_timer <= 0.0 and gap < reach * 0.9:
		var near_edge := t_rel.length() > _ring_r * 0.6
		if lined_up > -0.1 or near_edge:
			_push_timer = reaction * randf_range(0.6, 1.4) * lerpf(1.6, 0.6, skill)
	return dir


## Counter-push anyone who is winding up a push right next to us.
func _react_to_threats() -> void:
	if not me.push_ready() or _push_timer > 0.0:
		return
	for o: Blob in get_tree().get_nodes_in_group("blobs"):
		if o == me or not o.is_winding_up():
			continue
		var dist := o.global_position.distance_to(me.global_position) - me.radius
		if dist < o.push_reach() + 20.0 and randf() < skill * 0.5:
			_push_timer = 0.01
			return


func _pick_target() -> void:
	if target != null and (not is_instance_valid(target) or not target.alive):
		target = null
	var best: Blob = null
	var best_score := -INF
	for o: Blob in get_tree().get_nodes_in_group("blobs"):
		if o == me or not o.alive:
			continue
		var score := -o.global_position.distance_to(me.global_position)
		score += _rel(o.global_position).length() / _ring_r * 160.0 * aggression  # love targets near the edge
		score += (me.mass - o.mass) * 80.0 * caution                              # pick on smaller ones
		if o.has_node("PlayerInput"):
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
		if _rel(f.global_position).length() > _ring_r * 0.85:
			continue
		var d := f.global_position.distance_to(me.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best
