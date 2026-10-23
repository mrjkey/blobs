class_name Food
extends Node2D
## A pellet. The first living blob to touch it eats it (and grows). Pops in
## with an overshoot. From the theme: food.color (also the burst when eaten) and
## food.shape: "round" (bobs, default) or "diamond" (spins, swells on the kick).

const COLOR := Color(1.0, 0.9, 0.35)

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
			Juice.burst(global_position, GameTheme.current().value("food.color", COLOR), 10, 160.0)
			Sfx.play("pop", randf_range(0.95, 1.1), -2.0)
			queue_free()
			return


## Online (NetGame): food stays put, so a joined computer's copy only needs to be where the host's is.
func net_state() -> Array:
	return []


func _process(delta: float) -> void:
	age += delta
	queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("food", self):
		return
	var st := theme.style
	var col: Color = theme.value("food.color", COLOR)
	var pop := minf(age / 0.25, 1.0)
	var grow := (1.0 + 0.4 * sin(pop * PI)) * pop
	if theme.value("food.shape", "round") == "diamond":
		var r := radius * grow * (1.3 + 0.2 * st.kick(self))
		var pts := PackedVector2Array()
		for j in 4:
			pts.append(Vector2.from_angle(age * 2.0 + phase + j * PI / 2.0) * r)
		draw_colored_polygon(pts, st.color(col, 0.5, 0.5))
		st.outline(self, pts, st.color(col, 2.5), 2.0)
		return
	var r := radius * grow * (1.0 + 0.12 * sin(age * 6.0 + phase))
	st.dot(self, Vector2.ZERO, r * 2.0, col, 1.0, 0.15)
	st.dot(self, Vector2.ZERO, r, col, 2.0)
	if st.highlights:
		draw_circle(Vector2(-r, -r) * 0.3, r * 0.35, Color(1, 1, 1, 0.6))
