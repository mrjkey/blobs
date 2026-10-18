@tool
class_name FoodSpot
extends Node2D
## A pellet in a map: there when the map loads, and back `respawn` seconds
## after it's eaten (0 = gone for good). The pellet is a `food_scene` child.
## In the editor: a pellet, ringed if it comes back.

const COLOR := Color(1.0, 0.9, 0.35)

@export var respawn := 20.0:
	set(v):
		respawn = v
		queue_redraw()
@export var food_scene: PackedScene = preload("res://level/pickups/food/food.tscn")

var _food: Node2D
var _waiting := false # eaten, counting down to the next one
var _timer := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		_spawn()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or is_instance_valid(_food):
		return
	if not _waiting: # just eaten
		_waiting = true
		_timer = respawn
		if respawn <= 0.0:
			set_physics_process(false)
			return
	_timer -= delta
	if _timer <= 0.0:
		_spawn()


func _spawn() -> void:
	_waiting = false
	_food = food_scene.instantiate()
	add_child(_food)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var col: Color = GameTheme.current().value("food.color", COLOR)
	draw_circle(Vector2.ZERO, 7.0, col)
	if respawn > 0.0:
		draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color(col, 0.6), 2.0, true)
