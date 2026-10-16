class_name LaserDirector
extends Node
## Once per bar of the music, picks idle lasers (group "lasers") to fire on the
## next downbeat: none for the first `start_delay` seconds, then more the
## longer the round goes on. Only counts and schedules while `enabled`.

@export var enabled := true # the mode turns it on when play starts
@export var start_delay := 4.0 # seconds of peace after "BUMP!"

var _play_time := 0.0
var _last_bar := -1


func _ready() -> void:
	process_physics_priority = -6 # just before the emitters (-5)


func _physics_process(delta: float) -> void:
	if delta <= 0.0 or not enabled:
		return
	_play_time += delta
	var bar := int(floorf(NeonLook.beat(get_tree()) / 4.0))
	if bar == _last_bar:
		return
	_last_bar = bar
	if _play_time < start_delay:
		return
	var count := 1 if randf() < 0.7 else 0
	if _play_time > 30.0 and randf() < 0.5:
		count += 1
	if _play_time > 60.0 and randf() < 0.5:
		count += 1
	var idle := get_tree().get_nodes_in_group("lasers").filter(func(l: LaserEmitter): return l.is_idle())
	idle.shuffle()
	for i in mini(count, idle.size()):
		idle[i].fire_beat = float(bar + 1) * 4.0
