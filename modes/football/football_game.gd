extends GameMode
## Football: two teams push a ball into each other's goal. Seats alternate
## between the teams (ModeInfo.team_of: P1 and P3 against P2 and P4); team 0
## defends the left goal. After a goal the ball bursts, play stops, everyone
## goes back to their half, frozen until GO, and the game kicks off again. The match ends when the clock
## runs out (the TIME option; level scores go to a golden goal) or when a
## team reaches the goal count (GOALS), whichever comes first.

@export var pitch: Pitch
@export var ball_scene: PackedScene
@export var goal_pause := 1.4 # after a goal, before everyone is put back
@export var kickoff_pause := 1.0 # back in place and frozen, before play goes on

var score: Array[int] = [0, 0]
var ball: Ball
var _time_left := 0.0 # seconds on the clock
var _timed := false
var _goals_to_win := 0 # 0 = no goal count
var _golden := false # level at the final whistle: the next goal wins
var _pause := 0.0 # > 0 while play is stopped after a goal
var _back_in_place := false
var _kickoff_spots := {} # Blob -> where it starts


func _ready() -> void:
	pitch.counting = false
	pitch.goal_scored.connect(_on_goal_scored)
	var minutes := int(GameSettings.choice("football_time"))
	_timed = minutes > 0
	_time_left = minutes * 60.0
	_goals_to_win = int(GameSettings.choice("football_goals"))
	super._ready()


func _spawn_blobs() -> void:
	ball = ball_scene.instantiate()
	ball.position = pitch.position
	ball.active = false
	blobs_node.add_child(ball)
	var members: Array = [[], []] # slot indices per team
	for i in slots.size():
		members[maxi(slot_team(i), 0)].append(i)
	var half := pitch.size * 0.5
	for team in 2:
		var side := -1.0 if team == 0 else 1.0
		var n: int = members[team].size()
		for k in n:
			var i: int = members[team][k]
			var spot := pitch.position + Vector2(side * half.x * (0.3 + 0.3 * (k % 2)),
				lerpf(-half.y * 0.5, half.y * 0.5, (k + 0.5) / n))
			var b := spawn_slot(i, spot)
			b.body.look = Vector2(-side, 0.0)
			_kickoff_spots[b] = spot


func _new_brain() -> BotBrain:
	return FootballBotBrain.new()


func _on_play_started() -> void:
	pitch.counting = true


func _on_round_over() -> void:
	pitch.counting = false


## Nobody gets knocked out in football: the clock and the goals decide.
func _check_round_over() -> void:
	pass


func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	if _pause > 0.0:
		_pause -= delta
		if not _back_in_place and _pause <= kickoff_pause:
			_back_in_place = true
			_kickoff()
		if _pause <= 0.0:
			for b in living_blobs():
				b.active = true
			pitch.counting = true
			hud.show_banner("GO!", Color(1.0, 0.9, 0.4), 0.6)
			Sfx.play("pop", 0.6)
		return # the clock stops while play does
	if _timed and not _golden:
		_time_left -= delta
		if _time_left <= 0.0:
			_time_left = 0.0
			if score[0] != score[1]:
				_finish()
			else:
				_golden = true
				hud.show_banner("GOLDEN GOAL\nnext goal wins", Color.WHITE, 2.2)


func _on_goal_scored(team: int, scored: Blob) -> void:
	if state != State.PLAYING:
		return
	score[team] += 1
	if scored is Ball:
		(scored as Ball).explode()
	var col := GameTheme.current().team_color(team)
	Juice.burst(scored.global_position, col.lightened(0.3), 40, 520.0)
	Juice.shockwave(scored.global_position, 20.0, 260.0, col.lightened(0.4), 0.5)
	Juice.shake(Juice.settings.shake_elimination)
	Juice.hitstop(Juice.settings.hitstop_elimination)
	Sfx.play("out", 0.8)
	if _golden or (_goals_to_win > 0 and score[team] >= _goals_to_win):
		_finish()
		return
	hud.show_banner("GOAL!\n%s" % _team_name(team), col, goal_pause + 0.2)
	_pause = goal_pause + kickoff_pause
	_back_in_place = false


## Everyone back to their spot and frozen, the ball in the middle.
func _kickoff() -> void:
	ball.reset(pitch.global_position)
	for b: Blob in _kickoff_spots:
		if not is_instance_valid(b):
			continue
		b.active = false
		b.global_position = _kickoff_spots[b]
		b.halt()
		b.body.look = (pitch.global_position - b.global_position).normalized()


func _finish() -> void:
	state = State.OVER
	_on_round_over()
	var winner := 0 if score[0] > score[1] else 1
	var col := GameTheme.current().team_color(winner)
	var mine := _human_team()
	if score[0] == score[1]:
		hud.show_banner("DRAW!", Color.WHITE)
	elif mine >= 0 and humans == 1:
		hud.show_banner("YOU WIN!" if mine == winner else "%s WINS" % _team_name(winner), col)
	else:
		hud.show_banner("%s WINS!" % _team_name(winner), col)
	hud.set_hint("Press R to play again")


## The team of the only human, or -1 (no humans, or humans on both teams).
func _human_team() -> int:
	var team := -1
	for b: Blob in _kickoff_spots:
		if is_instance_valid(b) and b.is_human():
			if team >= 0 and team != b.team:
				return -1
			team = b.team
	return team


func _team_name(team: int) -> String:
	return info.teams[team] if team < info.teams.size() else "TEAM %d" % (team + 1)


func _process(_delta: float) -> void:
	var theme := GameTheme.current()
	var clock := ""
	if _golden:
		clock = "GOLDEN GOAL"
	elif _timed:
		var secs := ceili(_time_left)
		clock = "%d:%02d" % [floori(secs / 60.0), secs % 60]
	elif _goals_to_win > 0:
		clock = "FIRST TO %d" % _goals_to_win
	var pieces := [[_team_name(0), theme.team_color(0)], ["%d - %d" % [score[0], score[1]], Color.WHITE],
		[_team_name(1), theme.team_color(1)]]
	if clock != "":
		pieces.append([clock, Color(0.75, 0.78, 0.95)])
	hud.set_score(pieces)
	var rosters: Array[String] = []
	for team in 2:
		var names: Array[String] = []
		for b: Blob in _kickoff_spots:
			if is_instance_valid(b) and b.team == team:
				names.append(b.display_name)
		rosters.append("%s: %s" % [_team_name(team), ", ".join(names)])
	hud.set_status("\n".join(rosters))
