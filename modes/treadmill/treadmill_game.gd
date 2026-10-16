extends GameMode
## Treadmill: the world stands still and the camera scrolls up through it, so
## the floor seems to slide down the screen. Fall behind the bottom laser (or
## fly past the top one) and you're out. The mode (1P vs computer, 2P versus,
## 2P + computer, watch) comes from Session.treadmill_mode, set by
## ui/menus/treadmill_menu.tscn, or from `--mode=N` on the command line.

enum Mode { VS_CPU, VERSUS, VERSUS_PLUS_CPU, WATCH } # same numbers as the menu's buttons

@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")
@export var camera: GameCamera
@export var kill_lasers: KillLasers
@export var laser_director: LaserDirector

@export_group("Controls")
@export var solo_profile: InputProfile = preload("res://entities/controllers/profiles/solo.tres")
@export var p1_profile: InputProfile = preload("res://entities/controllers/profiles/p1.tres")
@export var p2_profile: InputProfile = preload("res://entities/controllers/profiles/p2.tres")

var mode: int = Mode.VS_CPU
var cam_y := 0.0 # world y at the centre of the screen
var scroll_speed := 0.0
var distance := 0.0
var _humans := 0
var _play_time := 0.0


func _ready() -> void:
	process_physics_priority = -8 # scroll before the generator (-7) and lasers look at the view
	kill_lasers.enabled = false
	laser_director.enabled = false
	# Launch option to pick the mode, e.g. "godot modes/treadmill/treadmill.tscn -- --mode=3".
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode=") and Session.treadmill_mode < 0:
			Session.treadmill_mode = clampi(int(arg.get_slice("=", 1)), 0, Mode.size() - 1)
	# Run on its own (F6) with no mode chosen: 1P vs computer.
	mode = Session.treadmill_mode if Session.treadmill_mode >= 0 else Mode.VS_CPU
	_follow_camera()
	super._ready()


func _spawn_blobs() -> void:
	var pads := Input.get_connected_joypads().size()
	var inputs: Array[PlayerInput] = []
	if mode == Mode.VS_CPU:
		inputs.append(_make_input(solo_profile, 0))
	elif mode != Mode.WATCH:
		# Two pads: one each. One pad: P2 gets it, P1 keeps the keyboard.
		inputs.append(_make_input(p1_profile, 0 if pads >= 2 else -1))
		inputs.append(_make_input(p2_profile, pads - 1 if pads >= 1 else -1))
	_humans = inputs.size()

	var bot_count := 0
	if mode == Mode.VS_CPU:
		bot_count = settings.bots_vs_cpu
	elif mode == Mode.VERSUS_PLUS_CPU:
		bot_count = settings.bots_with_two_players
	elif mode == Mode.WATCH:
		bot_count = bot_names.size()

	var total := _humans + bot_count
	for i in total:
		var x := lerpf(-settings.track_width * 0.35, settings.track_width * 0.35, (i + 0.5) / total)
		var pos := Vector2(x, cam_y + 150.0)
		var b: Blob
		if i < _humans:
			var theme := GameTheme.current()
			b = spawn_blob(pos, theme.player_color if i == 0 else theme.p2_color, "Player %d" % (i + 1), inputs[i])
			if _humans > 1:
				b.tag = "P%d" % (i + 1)
		else:
			b = spawn_bot(pos, i - _humans, TrackBotBrain.new())
		b.body.look = Vector2.UP

	if _humans == 0:
		hud.set_hint("Watching the bots  ·  R restart  ·  Esc menu")
	elif _humans == 1:
		hud.set_hint("WASD move  ·  SPACE push  ·  stay ahead of the laser  ·  R restart  ·  Esc menu")
	else:
		hud.set_hint("P1: WASD + Space    P2: Arrows + Enter    ·    R restart  ·  Esc menu")


func _make_input(profile: InputProfile, pad_slot: int) -> PlayerInput:
	var p := PlayerInput.new()
	p.profile = profile
	p.pad_slot = pad_slot
	return p


func _on_play_started() -> void:
	kill_lasers.enabled = true
	laser_director.enabled = true


func _on_round_over() -> void:
	kill_lasers.lethal = false # keep the winner on screen
	laser_director.enabled = false


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	if state == State.PLAYING:
		_play_time += delta
		scroll_speed = lerpf(settings.scroll_start, settings.scroll_max, clampf(_play_time / settings.scroll_ramp_time, 0.0, 1.0))
		cam_y -= scroll_speed * delta
		distance += scroll_speed * delta
	_follow_camera()


func _follow_camera() -> void:
	camera.global_position = Vector2(0.0, cam_y)
	get_tree().call_group("grid", "follow_y", cam_y) # a theme backdrop that scrolls with the world


func _process(_delta: float) -> void:
	hud.set_status("Distance: %d m     Blobs left: %d" % [int(distance / 10.0), living_blobs().size()])


func _on_blob_died(b: Blob) -> void:
	if b.is_human():
		var who := "BUMPED OUT!" if b.tag == "" else "%s IS OUT!" % b.tag
		hud.show_banner(who, b.color, 1.6)
	_check_round_over()


func _check_round_over() -> void:
	if state != State.PLAYING:
		return
	var left := living_blobs()
	var humans_alive := 0
	for b in left:
		if b.is_human():
			humans_alive += 1
	if left.size() > 1 and (humans_alive > 0 or _humans == 0):
		return
	state = State.OVER
	_on_round_over()
	if _humans == 1 and humans_alive == 0:
		hud.show_banner("GAME OVER", Color(1.0, 0.4, 0.4))
	elif left.size() == 1 and left[0].is_human():
		var winner := left[0]
		hud.show_banner("YOU WIN!" if _humans == 1 else "%s WINS!" % winner.tag, winner.color)
	elif left.size() == 1:
		hud.show_banner("%s WINS" % left[0].display_name.to_upper(), left[0].color)
	elif humans_alive == 0 and _humans > 0:
		hud.show_banner("THE BOTS WIN", Color(1.0, 0.4, 0.4))
	else:
		hud.show_banner("DRAW!", Color.WHITE)
	hud.set_hint("%d m   ·   R or Start: rematch   ·   Esc or Back: menu" % int(distance / 10.0))
