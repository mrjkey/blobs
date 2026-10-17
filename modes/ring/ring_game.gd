extends GameMode
## Classic sumo ring: everyone in the lineup starts on a circle facing the centre.
## Push everyone out of the ring; food makes you bigger. Neon uses the same
## script with a LaserDirector set.

@export var arena: RingArena
@export var food_spawner: FoodSpawner
@export var laser_director: LaserDirector # optional


func _ready() -> void:
	arena.counting = false
	food_spawner.enabled = false
	if laser_director != null:
		laser_director.enabled = false
	super._ready()


func _spawn_blobs() -> void:
	var count := slots.size()
	var start_angle := randf() * TAU
	for i in count:
		var pos := arena.global_position + Vector2.from_angle(start_angle + TAU * i / count) * arena.ring_radius * 0.6
		var b := spawn_slot(i, pos)
		b.body.look = (arena.global_position - pos).normalized()


func _new_brain() -> BotBrain:
	return RingBotBrain.new()


func _on_play_started() -> void:
	arena.counting = true
	food_spawner.enabled = true
	if laser_director != null:
		laser_director.enabled = true


func _on_round_over() -> void:
	arena.counting = false
	food_spawner.enabled = false
	if laser_director != null:
		laser_director.enabled = false


func _process(_delta: float) -> void:
	var status := "Blobs left: %d" % living_blobs().size()
	var you := human_alive()
	if you != null:
		status += "     Your size: %.2fx" % you.mass
	hud.set_status(status)
