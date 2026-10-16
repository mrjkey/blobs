class_name RingBotBrain
extends BotBrain
## Bot for ring arenas. Picks a victim, tries to get between them and the ring
## centre, charges, and pushes when they're in reach. Also grabs food and keeps
## away from the edge. Reads the ring from the node in group "arena"; without
## one it assumes a ring of `fallback_ring_radius` around the origin.

@export var fallback_ring_radius := 300.0

var _center := Vector2.ZERO
var _ring_r := 300.0


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


func _target_score(o: Blob) -> float:
	return _rel(o.global_position).length() / _ring_r * 160.0 * aggression  # love targets near the edge


func _food_ok(pos: Vector2) -> bool:
	return _rel(pos).length() <= _ring_r * 0.85


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

	if me.push_ready() and not _push_queued() and gap < reach * 0.9:
		var near_edge := t_rel.length() > _ring_r * 0.6
		if lined_up > -0.1 or near_edge:
			_queue_push()
	if _dash_ok() and randf() < skill * 0.5:
		var dash_len := me.dash_speed() * me.stats.dash_time
		var closing := lined_up > 0.2 and gap > reach * 0.8 and gap < dash_len + reach * 0.6
		if me.rules.dash == MoveRules.Dash.GHOST and lined_up < -0.3 and dist < 170.0:
			me.request_dash(to_t_n) # on the wrong side of them: phase straight through
		elif closing:
			me.request_dash(to_t_n) # just out of reach: ram them (bump), or close in to push (ghost)
			if me.rules.dash == MoveRules.Dash.GHOST:
				_queue_push()
	return dir


## Dodge sideways and toward the middle; a ghost dash goes straight through
## the attacker when that's toward the middle.
func _dodge_dir(threat: Blob) -> Vector2:
	var pos := me.global_position
	var to_t := (threat.global_position - pos).normalized()
	var home := -_rel(pos).normalized() if _rel(pos).length() > 1.0 else -to_t
	if me.rules.dash == MoveRules.Dash.GHOST and to_t.dot(home) > 0.3:
		return to_t
	var side := Vector2(-to_t.y, to_t.x)
	if side.dot(home) < 0.0:
		side = -side
	return (side + home * 0.5 - to_t * 0.3).normalized()


## Read the ring from the Arena if there is one, else assume it's at the origin.
func _update_ring() -> void:
	var arena := get_tree().get_first_node_in_group("arena")
	if arena != null and "ring_radius" in arena:
		_center = arena.global_position
		_ring_r = arena.ring_radius
	else:
		_center = Vector2.ZERO
		_ring_r = fallback_ring_radius


## A position relative to the ring centre.
func _rel(p: Vector2) -> Vector2:
	return p - _center
