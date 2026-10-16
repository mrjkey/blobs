class_name TrackBotBrain
extends BotBrain
## Bot for the treadmill. Keeps pace with the scrolling screen, steers round
## walls, keeps clear of bumpers and the kill lasers, and tries to get above
## other blobs to shove them down into the bottom laser. Reads the kill lines
## from the node in group "kill_lasers" (without one: ±`fallback_half_span`
## around its own start height) and obstacles from group "blob_colliders".

@export var track: TrackSettings = preload("res://level/arenas/track/track_settings.tres")
@export var fallback_half_span := 380.0

var _home_y := 0.0


func _ready() -> void:
	super._ready()
	_desired = Vector2.UP
	_home_y = me.global_position.y


func _decide() -> void:
	var pos := me.global_position
	var lines := _kill_lines()
	var top := lines.x
	var bottom := lines.y
	var span := bottom - top
	# Where this bot likes to hang out: the upper-middle of the screen.
	var comfy_y := top + span * lerpf(0.5, 0.3, caution)

	_pick_target()
	var dir := Vector2.ZERO
	var going_for_food := false
	var food := _best_food()
	if food != null:
		var fpos := food.global_position
		var target_gap := INF
		if target != null:
			target_gap = target.global_position.distance_to(pos) - target.radius
		var tempting := 60.0 + 220.0 * greed * (1.0 - 0.5 * aggression)
		if target == null or (fpos.distance_to(pos) < tempting and target_gap > 110.0):
			dir = (fpos - pos).normalized()
			going_for_food = true
	if not going_for_food:
		if target != null:
			dir = _attack_dir(top, bottom)
		else:
			dir = Vector2.from_angle(_wander) * 0.4

	# Never follow anything down into the bottom danger zone.
	if dir.y > 0.0 and pos.y > bottom - 240.0:
		dir.y = 0.0

	# Keep pace with the treadmill: drift back toward the comfy height.
	var lag := (pos.y - comfy_y) / span  # positive = lower than they'd like
	dir.y -= clampf(lag * 4.0, -0.6, 1.6)

	# Hard danger near the kill lasers.
	var bottom_danger := clampf((pos.y - (bottom - 170.0)) / 150.0, 0.0, 1.0)
	var top_danger := clampf(((top + 140.0) - pos.y) / 120.0, 0.0, 1.0)
	dir = dir.lerp(Vector2.UP, bottom_danger)
	dir = dir.lerp(Vector2.DOWN, top_danger)

	_react_to_threats()
	_desired = _avoid_obstacles(pos, dir).limit_length(1.0)


func _target_score(o: Blob) -> float:
	var lines := _kill_lines()
	var span := lines.y - lines.x
	var score := (o.global_position.y - lines.x) / span * 150.0 * aggression  # love targets near the bottom laser
	score += clampf(o.global_position.y - me.global_position.y, -100.0, 100.0) * 0.5  # easier when they're below me
	return score


## Off screen, or too close to the bottom laser to be worth it?
func _food_ok(pos: Vector2) -> bool:
	var lines := _kill_lines()
	return pos.y >= lines.x + 60.0 and pos.y <= lines.y - 180.0


func _attack_dir(top: float, bottom: float) -> Vector2:
	var pos := me.global_position
	var tpos := target.global_position
	var aim := tpos + target.vel * lead * skill
	var to_t := aim - pos
	var dist := to_t.length()
	var to_t_n := to_t / maxf(dist, 0.001)
	# 1.0 = they're right below me, the perfect angle to shove them at the bottom laser.
	var lined_up := to_t_n.dot(Vector2.DOWN)
	var reach := me.push_reach()
	var gap := dist - target.radius

	var dir := to_t_n
	if lined_up < 0.3 and gap > reach * 0.7 and randf() < skill:
		# Get above them first.
		var spot := tpos + Vector2.UP * (target.radius + me.radius + 45.0)
		var to_spot := spot - pos
		dir = to_spot.normalized()
		if dist < 120.0:
			var side := Vector2(-to_t_n.y, to_t_n.x)
			if side.dot(to_spot) < 0.0:
				side = -side
			dir = (dir + side * 1.2).normalized()

	if me.push_ready() and not _push_queued() and gap < reach * 0.9:
		var near_bottom := tpos.y > bottom - 260.0
		var near_top := tpos.y < top + 200.0 and lined_up < -0.3
		if lined_up > -0.1 or near_bottom or near_top or randf() < 0.3 * aggression:
			_queue_push()
	return dir


## Look a little way ahead; if a wall is in the way, head for its nearer open end.
## Also shy away from bumpers and the side walls.
func _avoid_obstacles(pos: Vector2, dir: Vector2) -> Vector2:
	if dir.length() < 0.05:
		return dir
	var walls: Array[WallBlock] = []
	var bumpers: Array[Bumper] = []
	for c in get_tree().get_nodes_in_group("blob_colliders"):
		if c is WallBlock:
			walls.append(c)
		elif c is Bumper:
			bumpers.append(c)
	var ahead := dir.normalized()
	var pad := me.radius + 8.0
	for dist: float in [35.0, 70.0, 110.0]:
		var p := pos + ahead * dist
		for w in walls:
			var rect := w.rect()
			if rect.grow(pad).has_point(p):
				return _go_around(pos, rect, dir)
	var out := dir
	for bp in bumpers:
		var away := pos - bp.global_position
		var room := away.length() - bp.radius - me.radius
		if room < 70.0:
			out += away.normalized() * (1.0 - room / 70.0) * 1.2
	var half := track.track_width * 0.5
	if pos.x < -half + 60.0:
		out.x += 0.5
	elif pos.x > half - 60.0:
		out.x -= 0.5
	return out


func _go_around(pos: Vector2, rect: Rect2, dir: Vector2) -> Vector2:
	var half := track.track_width * 0.5
	var clearance := me.radius + 20.0
	var left_x := rect.position.x - clearance
	var right_x := rect.end.x + clearance
	var left_ok := left_x > -half + me.radius
	var right_ok := right_x < half - me.radius
	var go_left := left_ok
	if left_ok and right_ok:
		go_left = absf(pos.x - left_x) < absf(pos.x - right_x)
	var tx := left_x if go_left else right_x
	if absf(tx - pos.x) < 6.0:
		return dir
	return Vector2(signf(tx - pos.x), 0.25 * signf(dir.y)).normalized()


## (top, bottom) world y of the kill lasers.
func _kill_lines() -> Vector2:
	var kl := get_tree().get_first_node_in_group("kill_lasers")
	if kl != null:
		return Vector2(kl.kill_top(), kl.kill_bottom())
	return Vector2(_home_y - fallback_half_span, _home_y + fallback_half_span)
