class_name Food
extends Node2D
## A pellet. The first living blob to touch it eats it (and grows). Drawn by
## the theme's FoodSkin.

@export var radius := 7.0

var age := 0.0
var phase := randf() * TAU # so pellets don't all bob in step


func _enter_tree() -> void:
	add_to_group("food")


func _ready() -> void:
	process_physics_priority = 20 # after blob abilities (10)


func _physics_process(_delta: float) -> void:
	for b: Blob in get_tree().get_nodes_in_group("blobs"):
		if b.alive and b.global_position.distance_to(global_position) < b.radius + radius:
			b.eat()
			Juice.burst(global_position, GameTheme.current().food.color, 10, 160.0)
			Sfx.play("pop", randf_range(0.95, 1.1), -2.0)
			queue_free()
			return


func _process(delta: float) -> void:
	age += delta
	queue_redraw()


func _draw() -> void:
	GameTheme.current().food.draw(self)
