class_name Food
extends Node2D
## A pellet. The first living blob to touch it eats it (and grows). Pops in
## with an overshoot, then bobs.

@export var radius := 7.0
@export var color := Color(1.0, 0.9, 0.35)

var age := 0.0
var _seed := randf() * TAU


func _enter_tree() -> void:
	add_to_group("food")


func _ready() -> void:
	process_physics_priority = 20 # after blob abilities (10)


func _physics_process(_delta: float) -> void:
	for b: Blob in get_tree().get_nodes_in_group("blobs"):
		if b.alive and b.global_position.distance_to(global_position) < b.radius + radius:
			b.eat()
			Juice.burst(global_position, color, 10, 160.0)
			Sfx.play("pop", randf_range(0.95, 1.1), -2.0)
			queue_free()
			return


func _process(delta: float) -> void:
	age += delta
	queue_redraw()


func _draw() -> void:
	var pop := minf(age / 0.25, 1.0)
	var s := (1.0 + 0.4 * sin(pop * PI)) * pop
	var r := radius * s * (1.0 + 0.12 * sin(age * 6.0 + _seed))
	draw_circle(Vector2.ZERO, r * 2.0, Color(color, 0.15))
	draw_circle(Vector2.ZERO, r, color)
	draw_circle(Vector2(-r, -r) * 0.3, r * 0.35, Color(1, 1, 1, 0.6))
