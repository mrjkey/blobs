class_name LaserDirector
extends Node
## Once per bar of the music, picks idle lasers (group "lasers") to fire on the
## next downbeat: none for the first `start_delay` seconds, then one (most
## bars), plus one more for each time in `ramp` the round has passed (each a
## `ramp_chance` coin flip). Only counts and schedules while `enabled`.

@export var enabled := true # the mode turns it on when play starts
@export var start_delay := 4.0 # seconds of peace after "BUMP!"
@export_range(0.0, 1.0) var first_chance := 0.7 # chance a bar gets a laser at all
@export var ramp := PackedFloat32Array([30.0, 60.0]) # seconds of play after which a bar may get one more
@export_range(0.0, 1.0) var ramp_chance := 0.5

var _play_time := 0.0
var _last_bar := -1


func _ready() -> void:
	process_physics_priority = -6 # just before the emitters (-5)


func _physics_process(delta: float) -> void:
	if delta <= 0.0 or not enabled:
		return
	_play_time += delta
	var bar := int(floorf(Techno.current_beat(get_tree()) / 4.0))
	if bar == _last_bar:
		return
	_last_bar = bar
	if _play_time < start_delay:
		return
	var count := 1 if randf() < first_chance else 0
	for t in ramp:
		if _play_time > t and randf() < ramp_chance:
			count += 1
	var idle := get_tree().get_nodes_in_group("lasers").filter(func(l: LaserEmitter): return l.is_idle())
	idle.shuffle()
	for i in mini(count, idle.size()):
		idle[i].fire_beat = float(bar + 1) * 4.0
