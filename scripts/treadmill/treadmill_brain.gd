extends RefCounted
## Bot brain for the treadmill. Keeps pace with the scrolling screen, steers
## round walls, keeps clear of bumpers and the kill lasers, and tries to get
## above other blobs to shove them down into the bottom laser.

const T = preload("res://scripts/tuning.gd")
const TT = preload("res://scripts/treadmill/treadmill_tuning.gd")
const Blob = preload("res://scripts/blob.gd")

var me: Blob
var game                                  # treadmill_game.gd

var aggression := randf_range(0.4, 1.0)   # fighting vs. eating
var caution := randf_range(0.2, 0.9)      # how high up the screen they like to stay
var greed := randf_range(0.2, 0.9)        # how tempting food is
var skill := randf_range(0.3, 1.0)        # positioning, push timing, dodging

var target: Blob = null
var _desired := Vector2.UP
var _steer := Vector2.ZERO
var _think_timer := randf() * T.BOT_THINK_TIME
var _push_timer := -1.0
var _wander := randf() * TAU


func _init(blob: Blob, g) -> void:
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
	_wander += randf_range(-3.0, 3.0) * delta
	var wobble := Vector2.from_angle(_wander) * T.BOT_WOBBLE
	_steer = _steer.lerp((_desired + wobble).limit_length(1.0), 1.0 - exp(-T.BOT_TURN_RATE * delta))
	me.move_dir = _steer


func _decide() -> void:
	var pos := me.position
	var top: float = game.kill_top()
	var bottom: float = game.kill_bottom()
	var span := bottom - top
	# Where this bot likes to hang out: the upper-middle of the screen.
	var comfy_y := top + span * lerpf(0.5, 0.3, caution)

	_pick_target()
	var dir := Vector2.ZERO
	var going_for_food := false
	var food := _best_food(top, bottom)
	if not food.is_empty():
		var fpos: Vector2 = food["pos"]
		var target_gap := INF
		if target != null:
			target_gap = target.position.distance_to(pos) - target.radius
		var tempting := 60.0 + 220.0 * greed * (1.0 - 0.5 * aggression)
		if target == null or (fpos.distance_to(pos) < tempting and target_gap > 110.0):
			dir = (fpos - pos).normalized()
			going_for_food = true
	if not going_for_food:
		if target != null:
			dir = _attack_dir()
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


func _attack_dir() -> Vector2:
	var pos := me.position
	var aim := target.position + target.vel * T.BOT_LEAD * skill
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
		var spot := target.position + Vector2.UP * (target.radius + me.radius + 45.0)
		var to_spot := spot - pos
		dir = to_spot.normalized()
		if dist < 120.0:
			var side := Vector2(-to_t_n.y, to_t_n.x)
			if side.dot(to_spot) < 0.0:
				side = -side
			dir = (dir + side * 1.2).normalized()

	if me.push_ready() and _push_timer <= 0.0 and gap < reach * 0.9:
		var near_bottom: bool = target.position.y > game.kill_bottom() - 260.0
		var near_top: bool = target.position.y < game.kill_top() + 200.0 and lined_up < -0.3
		if lined_up > -0.1 or near_bottom or near_top or randf() < 0.3 * aggression:
			_push_timer = T.BOT_REACTION * randf_range(0.6, 1.4) * lerpf(1.6, 0.6, skill)
	return dir


## Look a little way ahead; if a wall is in the way, head for its nearer open end.
## Also shy away from bumpers and the side walls.
func _avoid_obstacles(pos: Vector2, dir: Vector2) -> Vector2:
	if dir.length() < 0.05:
		return dir
	var ahead := dir.normalized()
	var pad := me.radius + 8.0
	for dist: float in [35.0, 70.0, 110.0]:
		var p := pos + ahead * dist
		for w in game.walls:
			var rect: Rect2 = w["rect"]
			if rect.grow(pad).has_point(p):
				return _go_around(pos, rect, dir)
	var out := dir
	for bp in game.bumpers:
		var bpos: Vector2 = bp["pos"]
		var br: float = bp["radius"]
		var away := pos - bpos
		var room := away.length() - br - me.radius
		if room < 70.0:
			out += away.normalized() * (1.0 - room / 70.0) * 1.2
	var half := TT.TRACK_WIDTH * 0.5
	if pos.x < -half + 60.0:
		out.x += 0.5
	elif pos.x > half - 60.0:
		out.x -= 0.5
	return out


func _go_around(pos: Vector2, rect: Rect2, dir: Vector2) -> Vector2:
	var half := TT.TRACK_WIDTH * 0.5
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


## Counter-push anyone who is winding up a push right next to us.
func _react_to_threats() -> void:
	if not me.push_ready() or _push_timer > 0.0:
		return
	for other in game.blobs:
		var o: Blob = other
		if o == me or not o.is_winding_up():
			continue
		var dist := o.position.distance_to(me.position) - me.radius
		if dist < o.push_reach() + 20.0 and randf() < skill * 0.5:
			_push_timer = 0.01
			return


func _pick_target() -> void:
	if target != null and (not is_instance_valid(target) or not target.alive):
		target = null
	var top: float = game.kill_top()
	var span: float = game.kill_bottom() - top
	var best: Blob = null
	var best_score := -INF
	for other in game.blobs:
		var o: Blob = other
		if o == me:
			continue
		var score := -o.position.distance_to(me.position)
		score += (o.position.y - top) / span * 150.0 * aggression     # love targets near the bottom laser
		score += clampf(o.position.y - me.position.y, -100.0, 100.0) * 0.5  # easier when they're below me
		score += (me.mass - o.mass) * 80.0 * caution
		if o.is_player:
			score += T.BOT_PLAYER_BIAS
		if o == target:
			score += 60.0
		if score > best_score:
			best_score = score
			best = o
	target = best


func _best_food(top: float, bottom: float) -> Dictionary:
	var best := {}
	var best_d := INF
	for f in game.foods:
		var p: Vector2 = f["pos"]
		if p.y < top + 60.0 or p.y > bottom - 180.0:
			continue  # off screen, or too close to the bottom laser to be worth it
		var d := p.distance_to(me.position)
		if d < best_d:
			best_d = d
			best = f
	return best
