extends GameMode
## Treadmill: the world stands still and the belt, the stretch between the
## two kill lasers, scrolls up through it. Fall behind the bottom laser (or
## fly past the top one) and you're out. The camera rides with the belt and
## always shows all of it, so nobody is ever off screen. Blobs shrink as they go (this
## mode's ModeInfo turns mass loss on): eat, but don't get too big for the
## gaps. Who plays comes from the lineup: any mix of humans and computers, or
## only computers to watch them.
##
## The track is generated as the belt climbs, unless a hand-made Map is
## chosen (`map_path`, or the lobby's TRACK option): then the map replaces the
## generator, blobs start on its SpawnPoints, the belt stops just past its
## FinishLine, and the first blob across the line wins.

@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")
@export var camera: GameCamera
@export var kill_lasers: KillLasers
@export var laser_director: LaserDirector
@export var generator: TrackGenerator
@export_file("*.tscn") var map_path := "" # a map to play instead of the generated track (overrides the TRACK option)

var map: Map # the hand-made map, if one is played
var finish: FinishLine # its finish line, if it has one
var belt_y := 0.0 # world y of the belt's centre, between the kill lasers
var scroll_speed := 0.0
var distance := 0.0
var _play_time := 0.0


func _ready() -> void:
	process_physics_priority = -8 # scroll before the generator (-7) and lasers look at the view
	kill_lasers.enabled = false
	laser_director.enabled = false
	_load_map()
	_follow_belt()
	super._ready()


## Swap the generator for the chosen map, if there is one.
func _load_map() -> void:
	var path := map_path if map_path != "" else GameSettings.track_map()
	if path == "" or not ResourceLoader.exists(path):
		return
	map = (load(path) as PackedScene).instantiate()
	finish = map.finish()
	add_child(map)
	move_child(map, generator.get_index())
	remove_child(generator)
	generator.queue_free()


func _spawn_blobs() -> void:
	var total := slots.size()
	var points: Array[SpawnPoint] = []
	if map != null:
		points = map.spawn_points()
	for i in total:
		var at := Vector2(lerpf(-settings.track_width * 0.35, settings.track_width * 0.35, (i + 0.5) / total),
			belt_y + settings.spawn_y)
		if i < points.size():
			at = points[i].global_position
		var b := spawn_slot(i, at)
		b.body.look = Vector2.UP

	if humans == 0:
		hud.set_hint("Watching the bots  ·  Start or Esc: pause")
	else:
		hud.set_hint("Stay ahead of the laser  ·  eat to keep your size, but big blobs get stuck  ·  Start or Esc: pause")


func _new_brain() -> BotBrain:
	return TrackBotBrain.new()


func _on_play_started() -> void:
	kill_lasers.enabled = true
	laser_director.enabled = true


func _on_round_over() -> void:
	kill_lasers.lethal = false # keep the winner on screen
	laser_director.enabled = false
	for b in living_blobs():
		b.loses_mass = false # nobody pops behind the banner


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	if state == State.PLAYING:
		_play_time += delta
		scroll_speed = lerpf(settings.scroll_start, settings.scroll_max, clampf(_play_time / settings.scroll_ramp_time, 0.0, 1.0)) \
			* GameSettings.track_speed()
		var step := scroll_speed * delta
		if finish != null: # stop once the top laser is a little past the line
			step = minf(step, maxf(kill_lasers.kill_top() - (finish.global_position.y - settings.finish_overshoot), 0.0))
		belt_y -= step
		distance += step
		if finish != null:
			_check_finish(finish.global_position.y)
	_follow_belt()


## The kill lasers and the camera ride with the belt. The camera frames the
## whole belt (its height comes from the TRACK VIEW setting) and the ships'
## lanes beside it, whatever the window's shape. Blobs run at BLOB SPEED.
func _follow_belt() -> void:
	kill_lasers.global_position.y = belt_y
	camera.global_position = Vector2(0.0, belt_y)
	camera.view_size = Vector2(settings.track_width + settings.side_zone * 2.0,
		kill_lasers.belt_height() + settings.camera_margin * 2.0)
	for b in living_blobs():
		b.speed_scale = GameSettings.blob_speed()
	get_tree().call_group("grid", "follow_y", belt_y) # a theme backdrop that scrolls with the world


func _process(_delta: float) -> void:
	var of := " / %d m" % int(-finish.global_position.y / 10.0) if finish != null else ""
	hud.set_status("Distance: %d m%s     Blobs left: %d" % [int(distance / 10.0), of, living_blobs().size()])


## The first blob above the finish line wins the run.
func _check_finish(line_y: float) -> void:
	if state != State.PLAYING:
		return
	for b in living_blobs():
		if b.global_position.y >= line_y:
			continue
		state = State.OVER
		_on_round_over()
		if b.is_human():
			hud.show_banner("YOU WIN!" if humans == 1 else "%s WINS!" % b.tag, b.color)
		else:
			hud.show_banner("%s WINS" % b.display_name.to_upper(), b.color)
		hud.set_hint("Finished!   ·   Start or Esc: rematch or quit   ·   R: rematch")
		return


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
	hud.set_hint("%d m   ·   Start or Esc: rematch or quit   ·   R: rematch" % int(distance / 10.0))
