class_name FootballBotBrain
extends BotBrain
## Bot for football. The player on each team nearest the ball goes for it:
## it gets round behind the ball, lines it up with the other team's goal,
## dribbles it forward and pushes (shoots) once it's lined up. Its teammates
## hang back between the ball and their own goal and clear the ball away when
## it comes near. Aggressive bots also shove opponents who get in the way.
## Reads the goals from the Pitch (group "arena") and the ball from "balls";
## its team is the blob's `team`.

@export var shoot_range := 330.0 # a lined-up ball this close to the goal gets a push
@export var keeper_depth := 0.3 # where a defender waits: this far from its goal toward the ball

var _attacking := false
var _aim_error := 0.0 # radians; re-rolled now and then, bigger for low skill


func _decide() -> void:
	var pitch := get_tree().get_first_node_in_group("arena") as Pitch
	var ball := get_tree().get_first_node_in_group("balls") as Blob
	if pitch == null or ball == null or me.team < 0:
		_desired = Vector2.ZERO
		return
	_react_to_threats()
	if randf() < 0.1:
		_aim_error = randf_range(-1.0, 1.0) * lerpf(0.35, 0.03, skill)
	var bp := ball.global_position + ball.vel * lead * skill
	var goal := pitch.target_goal(me.team)
	var home := pitch.own_goal(me.team)
	_attacking = _nearest_to_ball(ball)
	if not _attacking and bp.distance_to(home) < pitch.size.x * 0.28:
		_attacking = true # the ball is near our goal: everyone helps clear it
	if _attacking:
		_desired = _attack(pitch, ball, bp, goal)
	else:
		_desired = _arrive(home.lerp(bp, keeper_depth + 0.2 * aggression), 60.0)
		_clear(ball, home)
	_shove_opponents(ball)
	if _desired.length() < 0.05:
		_desired = Vector2.ZERO
	_desired = _desired.limit_length(1.0)


## True if no teammate is clearly closer to the ball (with some slack, so two
## teammates don't keep swapping).
func _nearest_to_ball(ball: Blob) -> bool:
	var mine := me.global_position.distance_to(ball.global_position) - (40.0 if _attacking else 0.0)
	for o: Blob in get_tree().get_nodes_in_group("blobs"):
		if o == me or not o.alive or o.team != me.team or o is Ball:
			continue
		if o.global_position.distance_to(ball.global_position) < mine:
			return false
	return true


## Get behind the ball, then drive it at the goal; push when lined up.
func _attack(pitch: Pitch, ball: Blob, bp: Vector2, goal: Vector2) -> Vector2:
	var pos := me.global_position
	var aim := (goal - bp).normalized().rotated(_aim_error)
	var reach := ball.radius + me.radius
	var behind := bp - aim * (reach + 8.0)
	# Keep the spot behind the ball on the pitch (a ball against a wall).
	var half := pitch.size * 0.5 - Vector2(me.radius, me.radius)
	var local := (behind - pitch.global_position).clamp(-half, half)
	behind = pitch.global_position + local
	var to_ball := bp - pos
	var dist := to_ball.length()
	var lined := to_ball.normalized().dot(aim) if dist > 0.001 else 1.0
	if lined > lerpf(0.55, 0.8, skill) and dist < reach + 70.0:
		# Lined up: run through the ball toward the goal.
		if me.push_ready() and not _push_queued() and dist < me.push_reach() + ball.radius * 0.5:
			if bp.distance_to(goal) < shoot_range + 250.0 * aggression or randf() < 0.04 + 0.1 * aggression:
				_queue_push()
		return (aim * 0.7 + to_ball.normalized() * 0.5).normalized()
	# Not lined up: go round to the spot behind it, swinging wide so we don't
	# knock it back toward our own goal.
	var to_spot := behind - pos
	var dir := to_spot.normalized()
	if lined < 0.3 and dist < reach + 90.0:
		var side := Vector2(-aim.y, aim.x)
		if side.dot(pos - bp) < 0.0:
			side = -side
		dir = (dir + side * 1.3).normalized()
	elif to_spot.length() > 260.0 and _dash_ok() and randf() < skill * 0.15:
		me.request_dash(dir)
	return dir * clampf(to_spot.length() / 40.0, 0.5, 1.0)


## A defender with the ball close by pushes it away from its own goal.
func _clear(ball: Blob, home: Vector2) -> void:
	if not me.push_ready() or _push_queued():
		return
	var d := ball.global_position - me.global_position
	if d.length() < me.push_reach() + ball.radius * 0.5 and d.dot(ball.global_position - home) > 0.0:
		_queue_push()


## Shove an opponent who is right next to us and between us and the ball.
func _shove_opponents(ball: Blob) -> void:
	if not me.push_ready() or _push_queued() or randf() > aggression * 0.3:
		return
	var to_ball := ball.global_position - me.global_position
	for o: Blob in get_tree().get_nodes_in_group("blobs"):
		if o == me or not o.alive or o.team == me.team or o is Ball:
			continue
		var d := o.global_position - me.global_position
		if d.length() - o.radius < me.push_reach() * 0.8 and d.dot(to_ball) > 0.0:
			_queue_push()
			return


## Toward `spot`, slowing down within `slow` pixels of it.
func _arrive(spot: Vector2, slow: float) -> Vector2:
	var d := spot - me.global_position
	return d.normalized() * clampf(d.length() / slow, 0.0, 1.0) if d.length() > 1.0 else Vector2.ZERO

