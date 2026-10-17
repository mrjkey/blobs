extends GameMode
## Treadmill: the world stands still and the camera scrolls up through it, so
## the floor seems to slide down the screen. Fall behind the bottom laser (or
## fly past the top one) and you're out. Who plays comes from the lineup:
## any mix of humans and computers, or only computers to watch them.

@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")
@export var camera: GameCamera
@export var kill_lasers: KillLasers
@export var laser_director: LaserDirector

var cam_y := 0.0 # world y at the centre of the screen
var scroll_speed := 0.0
var distance := 0.0
var _play_time := 0.0


func _ready() -> void:
	process_physics_priority = -8 # scroll before the generator (-7) and lasers look at the view
	kill_lasers.enabled = false
	laser_director.enabled = false
	_follow_camera()
	super._ready()


func _spawn_blobs() -> void:
	var total := slots.size()
	for i in total:
		var x := lerpf(-settings.track_width * 0.35, settings.track_width * 0.35, (i + 0.5) / total)
		var b := spawn_slot(i, Vector2(x, cam_y + 150.0))
		b.body.look = Vector2.UP

	if humans == 0:
		hud.set_hint("Watching the bots  ·  R restart  ·  Esc back")
	else:
		hud.set_hint("Move  ·  push  ·  dash  ·  stay ahead of the laser  ·  R restart  ·  Esc back")


func _new_brain() -> BotBrain:
	return TrackBotBrain.new()


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


func _check_round_over() -> void:
	if state != State.PLAYING:
		return
	var left := living_blobs()
	var humans_alive := 0
	for b in left:
		if b.is_human():
			humans_alive += 1
	if left.size() > 1 and (humans_alive > 0 or humans == 0):
		return
	state = State.OVER
	_on_round_over()
	if humans == 1 and humans_alive == 0:
		hud.show_banner("GAME OVER", Color(1.0, 0.4, 0.4))
	elif left.size() == 1 and left[0].is_human():
		var winner := left[0]
		hud.show_banner("YOU WIN!" if humans == 1 else "%s WINS!" % winner.tag, winner.color)
	elif left.size() == 1:
		hud.show_banner("%s WINS" % left[0].display_name.to_upper(), left[0].color)
	elif humans_alive == 0 and humans > 0:
		hud.show_banner("THE BOTS WIN", Color(1.0, 0.4, 0.4))
	else:
		hud.show_banner("DRAW!", Color.WHITE)
	hud.set_hint("%d m   ·   R or Start: rematch   ·   Esc or Back: menu" % int(distance / 10.0))
