class_name FoodSpawner
extends Node2D
## Drops a `food_scene` every `interval` seconds (give or take 30%) at a free
## spot inside the ring, up to `max_food` at once. The ring comes from the node
## in group "arena" (`ring_radius`); without one, food lands within
## `fallback_radius` of this node. Food is added as a child of this node.

@export var food_scene: PackedScene = preload("res://food/food.tscn")
@export var enabled := true # the mode turns it on when play starts
@export var interval := 2.0
@export var max_food := 6
@export_range(0.0, 1.0) var ring_fraction := 0.8 # how far out from the centre food may land
@export var fallback_radius := 300.0
@export var first_delay := 1.0 # seconds before the first pellet

var _timer := 0.0


func _ready() -> void:
	_timer = first_delay


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval * randf_range(0.7, 1.3)
		if get_tree().get_nodes_in_group("food").size() < max_food:
			_spawn()


func _spawn() -> void:
	var center := global_position
	var area := fallback_radius * ring_fraction
	var arena := get_tree().get_first_node_in_group("arena")
	if arena != null and "ring_radius" in arena:
		center = arena.global_position
		area = arena.ring_radius * ring_fraction
	for _attempt in 12:
		var p := center + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * area
		if _clear(p):
			var f: Node2D = food_scene.instantiate()
			add_child(f)
			f.global_position = p
			return


func _clear(p: Vector2) -> bool:
	for b: Blob in get_tree().get_nodes_in_group("blobs"):
		if b.alive and b.global_position.distance_to(p) < b.radius + 30.0:
			return false
	return true
