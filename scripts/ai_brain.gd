extends RefCounted
## Bot brain. Picks a victim, tries to get between them and the ring centre,
## charges, and pushes when they're in reach. Also grabs food and keeps away
## from the edge. Personality numbers make each bot play a little differently.

const T = preload("res://scripts/tuning.gd")
const OldBlob = preload("res://scripts/blob.gd")

var me: OldBlob
var game

var aggression := randf_range(0.4, 1.0)  # fighting vs. eating
var caution := randf_range(0.2, 0.9)     # how far from the edge they like to stay
var greed := randf_range(0.2, 0.9)       # how tempting food is
var skill := randf_range(0.3, 1.0)       # flanking, push timing, reactions

var target: OldBlob = null
var _desired := Vector2.ZERO
var _steer := Vector2.ZERO
var _think_timer := randf() * T.BOT_THINK_TIME
var _push_timer := -1.0
var _wander := randf() * TAU


func _init(blob: OldBlob, g) -> void:
	me = blob
	game = g


func think(delta: float) -> void:
	if not me.alive:
		return
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = T.BOT_THINK_TIME * randf_range(0.7, 1.3)
		_decide()
	if _push_timer > 0.0:
		_push_timer -= delta
		if _push_timer <= 0.0:
			me.push_buffer = T.PUSH_BUFFER
	# Smooth, slightly wobbly steering so they look alive rather than robotic.
	_wander += randf_range(-3.0, 3.0) * delta
	var wobble := Vector2.from_angle(_wander) * T.BOT_WOBBLE
	_steer = _steer.lerp((_desired + wobble).limit_length(1.0), 1.0 - exp(-T.BOT_TURN_RATE * delta))
	me.move_dir = _steer


func _decide() -> void:
	var pos := me.position
	var from_center := pos.length()
	var home := -pos / from_center if from_center > 1.0 else Vector2.ZERO
	var edge_panic := T.RING_RADIUS * 0.93
	var safe_r := T.RING_RADIUS * lerpf(0.8, 0.55, caution)

	# Outside the ring (or about to be)? Nothing matters except getting back.
	if from_center > edge_panic:
		_desired = home
		return

	_pick_target()
	var dir := Vector2.ZERO

	var food := _best_food()
	var going_for_food := false
	if not food.is_empty():
		var fpos: Vector2 = food["pos"]
		var food_dist := fpos.distance_to(pos)
		var target_dist := INF
		if target != null:
			target_dist = target.position.distance_to(pos) - target.radius
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
	var pos := me.position
	var aim := target.position + target.vel * T.BOT_LEAD * skill
	var to_t := aim - pos
	var dist := to_t.length()
	var to_t_n := to_t / maxf(dist, 0.001)
	var t_out := target.position.normalized() if target.position.length() > 1.0 else to_t_n
	# 1.0 = the target is directly between me and the edge: a perfect push angle.
	var lined_up := to_t_n.dot(t_out)
	var reach := me.push_reach()
	var gap := dist - target.radius  # my centre to their edge

	var dir := to_t_n
	if lined_up < 0.2 and gap > reach * 0.8 and randf() < skill:
		# Circle round to the centre side of them first.
		var spot := target.position - t_out * (target.radius + me.radius + 50.0)
		var to_spot := spot - pos
		dir = to_spot.normalized()
		if dist < 140.0:
			# Don't plough straight through them on the way round.
			var side := Vector2(-to_t_n.y, to_t_n.x)
			if side.dot(to_spot) < 0.0:
				side = -side
			dir = (dir + side * 1.2).normalized()

	if me.push_ready() and _push_timer <= 0.0 and gap < reach * 0.9:
		var near_edge := target.position.length() > T.RING_RADIUS * 0.6
		if lined_up > -0.1 or near_edge:
			_push_timer = T.BOT_REACTION * randf_range(0.6, 1.4) * lerpf(1.6, 0.6, skill)
	return dir


## Counter-push anyone who is winding up a push right next to us.
func _react_to_threats() -> void:
	if not me.push_ready() or _push_timer > 0.0:
		return
	for other in game.blobs:
		var o: OldBlob = other
		if o == me or not o.is_winding_up():
			continue
		var dist := o.position.distance_to(me.position) - me.radius
		if dist < o.push_reach() + 20.0 and randf() < skill * 0.5:
			_push_timer = 0.01
			return


func _pick_target() -> void:
	if target != null and (not is_instance_valid(target) or not target.alive):
		target = null
	var best: OldBlob = null
	var best_score := -INF
	for other in game.blobs:
		var o: OldBlob = other
		if o == me:
			continue
		var score := -o.position.distance_to(me.position)
		score += o.position.length() / T.RING_RADIUS * 160.0 * aggression  # love targets near the edge
		score += (me.mass - o.mass) * 80.0 * caution                       # pick on smaller ones
		if o.is_player:
			score += T.BOT_PLAYER_BIAS
		if o == target:
			score += 60.0  # don't flip-flop between targets
		if score > best_score:
			best_score = score
			best = o
	target = best


func _best_food() -> Dictionary:
	var best := {}
	var best_d := INF
	for f in game.foods:
		var p: Vector2 = f["pos"]
		if p.length() > T.RING_RADIUS * 0.85:
			continue
		var d := p.distance_to(me.position)
		if d < best_d:
			best_d = d
			best = f
	return best
