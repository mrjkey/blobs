class_name TrackGenerator
extends Node2D
## Builds the treadmill as the camera climbs: one chunk at a time just above
## the screen, a few walls (some of them kickers), bumpers and food, denser the
## further up it is. Pieces that fall well below the screen are freed. The
## pieces are added as children of this node, in world coordinates.

@export var settings: TrackSettings = preload("res://track/track_settings.tres")
@export var wall_scene: PackedScene = preload("res://track/wall_block.tscn")
@export var bumper_scene: PackedScene = preload("res://track/bumper.tscn")
@export var food_scene: PackedScene = preload("res://food/neon_food.tscn")

var _next_chunk_y := 0.0
var _prev_rects: Array[Rect2] = []


func _ready() -> void:
	process_physics_priority = -7 # after the mode scrolls the camera (-8)
	_next_chunk_y = -settings.start_clear
	_generate_ahead()


func _physics_process(_delta: float) -> void:
	_generate_ahead()
	_cull_behind()


func _generate_ahead() -> void:
	var view := GameCamera.view_of(self)
	var want_top := view.position.y - settings.chunk_height
	while _next_chunk_y > want_top:
		_gen_chunk(_next_chunk_y - settings.chunk_height, _next_chunk_y)
		_next_chunk_y -= settings.chunk_height


func _gen_chunk(y0: float, y1: float) -> void:
	var half := settings.track_width * 0.5
	var difficulty := clampf(-y1 / settings.difficulty_distance, 0.0, 1.0)
	var placed: Array[Rect2] = []

	for _i in randi_range(1, 2 + int(difficulty * 1.5)):
		for _try in 15:
			var rect := _random_wall_rect(y0, y1, half)
			if rect.size.x <= 0.0 or _blocked(rect, placed):
				continue
			placed.append(rect)
			var w: WallBlock = wall_scene.instantiate()
			w.size = rect.size
			w.kicker = randf() < 0.15 + 0.25 * difficulty
			_place(w, rect.get_center())
			break

	for _i in randi_range(0, 2 + int(difficulty * 2.0)):
		for _try in 15:
			var br := randf_range(22.0, 32.0)
			var p := Vector2(randf_range(-half + 70.0, half - 70.0), randf_range(y0 + 40.0, y1 - 40.0))
			var rect := Rect2(p - Vector2(br, br), Vector2(br, br) * 2.0)
			if _blocked(rect, placed):
				continue
			placed.append(rect)
			var bumper: Bumper = bumper_scene.instantiate()
			bumper.radius = br
			_place(bumper, p)
			break

	for _i in randi_range(0, settings.food_per_chunk_max):
		for _try in 10:
			var p := Vector2(randf_range(-half + 40.0, half - 40.0), randf_range(y0 + 20.0, y1 - 20.0))
			var clear := true
			for r: Rect2 in placed:
				if r.grow(30.0).has_point(p):
					clear = false
					break
			if clear:
				_place(food_scene.instantiate(), p)
				break

	_prev_rects = placed


func _place(piece: Node2D, world_pos: Vector2) -> void:
	add_child(piece)
	piece.global_position = world_pos


func _random_wall_rect(y0: float, y1: float, half: float) -> Rect2:
	var roll := randf()
	var w: float
	var h: float
	if roll < 0.55:      # horizontal bar
		w = randf_range(120.0, settings.track_width * 0.42)
		h = settings.wall_thickness
	elif roll < 0.75:    # vertical bar
		w = settings.wall_thickness
		h = randf_range(90.0, 170.0)
	else:                # block
		w = randf_range(50.0, 80.0)
		h = w
	var y := randf_range(y0 + 20.0, y1 - 20.0 - h)
	var x: float
	if roll < 0.55 and randf() < 0.5:
		x = -half if randf() < 0.5 else half - w  # bar sticking out of a side wall
	else:
		var lo := -half + settings.obstacle_gap
		var hi := half - settings.obstacle_gap - w
		if hi < lo:
			return Rect2()
		x = randf_range(lo, hi)
	return Rect2(x, y, w, h)


## Too close to something already placed (in this chunk or the one below)?
func _blocked(rect: Rect2, placed: Array[Rect2]) -> bool:
	for other: Rect2 in placed + _prev_rects:
		if other.grow(settings.obstacle_gap).intersects(rect):
			return true
	return false


func _cull_behind() -> void:
	var limit := GameCamera.view_of(self).end.y + 300.0
	for piece: Node2D in get_children():
		var top := piece.global_position.y
		if piece is WallBlock:
			top = (piece as WallBlock).rect().position.y
		if top >= limit:
			piece.queue_free()
