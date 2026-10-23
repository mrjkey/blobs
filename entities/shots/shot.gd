class_name Shot
extends Node2D
## Something a blob fires that flies on its own, like a Spit. It knocks back
## the blobs it reaches (never the one that fired it, never ghosts). A blob
## with its shield up sends it back at whoever fired it (Blob.try_reflect()):
## now it's that blob's shot, faster and harder, and it can be sent back again.
## Subclasses give the rest: how it moves (_advance), what it touches
## (_touches), what a hit does (_hit_blob), how a shield turns it round
## (_reflect), when it's spent, and how bots see it coming (time_to_reach).
## Joins "shots"; draws above the blobs (z_index 4 in its scene). Online, a
## joined computer shows a copy of the host's (NetGame).

var shooter: Blob # who fired it last; it never hits them
var stats: BlobStats # the numbers: those of whoever fired it
var color := Color.WHITE
var dir := Vector2.RIGHT
var speed := 0.0
var power := 1.0 # the shooter's strength, times the reflect boost for each reflection
var reflections := 0 # how many times a shield has sent it back
var age := 0.0

var _launched := false
var _done := false
var _skip: Array[Blob] = [] # blobs it already reached (each is hit once)


func _enter_tree() -> void:
	add_to_group("shots")


func _ready() -> void:
	process_physics_priority = 15 # after blobs move (0) and fire (10)


## Fire from `pos` along `aim`, hitting with `strength`. A shield fires it
## again with the shield's blob as `by` and one more reflection.
func launch(by: Blob, pos: Vector2, aim: Vector2, strength := 1.0, reflected := 0) -> void:
	shooter = by
	stats = by.stats
	color = by.color
	global_position = pos
	dir = aim.normalized()
	power = strength
	reflections = reflected
	speed = minf(_base_speed() * pow(stats.reflect_speedup, reflections), stats.shot_max_speed)
	_launched = true


func _physics_process(delta: float) -> void:
	if delta <= 0.0 or not _launched:
		return
	age += delta
	_advance(delta)
	for b: Blob in get_tree().get_nodes_in_group("blobs"):
		if _done:
			break
		if b == shooter or not b.alive or b.is_ghost() or _skip.has(b) or not _touches(b):
			continue
		_skip.append(b)
		if b.try_reflect(self):
			_reflect(b)
		else:
			_hit_blob(b)
	if _done or _spent():
		_fizzle()
		queue_free()


## Seconds until it reaches `b`, or INF if it won't. Bots use it to shield.
func time_to_reach(_b: Blob) -> float:
	return INF


## Which way a shot reflected by `by` goes: at whoever fired it.
func _aim_back(by: Blob) -> Vector2:
	if is_instance_valid(shooter) and shooter.alive:
		return (shooter.global_position - by.global_position).normalized()
	return -dir


func _base_speed() -> float:
	return 600.0


func _advance(_delta: float) -> void:
	pass


func _touches(_b: Blob) -> bool:
	return false


func _hit_blob(_b: Blob) -> void:
	pass


func _reflect(_by: Blob) -> void:
	pass


func _spent() -> bool:
	return true


## Called once as it disappears (spent or used up).
func _fizzle() -> void:
	pass


func _process(_delta: float) -> void:
	queue_redraw()


## Online (NetGame): a copy on a joined computer has the shooter's numbers, and only shows.
func net_spawn() -> Array:
	return [stats.resource_path if stats != null else ""]


func net_setup(d: Array) -> void:
	stats = load(d[0]) if d[0] != "" and ResourceLoader.exists(d[0]) else BlobStats.new()
	_launched = true


func net_state() -> Array:
	return [global_position, dir, speed, color, reflections, power, age]


func net_apply(s: Array) -> void:
	global_position = s[0]
	dir = s[1]
	speed = s[2]
	color = s[3]
	reflections = s[4]
	power = s[5]
	age = s[6]
