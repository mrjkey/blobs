extends GameMode
## Classic sumo ring: you and the bots start on a circle facing the centre.
## Push everyone out of the ring; food makes you bigger. Neon uses the same
## script with a LaserDirector set.

@export var arena: RingArena
@export var food_spawner: FoodSpawner
@export var laser_director: LaserDirector # optional
@export var bot_count := 1


func _ready() -> void:
	arena.counting = false
	food_spawner.enabled = false
	if laser_director != null:
		laser_director.enabled = false
	super._ready()


func _spawn_blobs() -> void:
	var count := bot_count + 1
	var start_angle := randf() * TAU
	for i in count:
		var pos := arena.global_position + Vector2.from_angle(start_angle + TAU * i / count) * arena.ring_radius * 0.6
		var b: Blob = spawn_player(pos) if i == 0 else spawn_bot(pos, i - 1, RingBotBrain.new())
		b.body.look = (arena.global_position - pos).normalized()


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
