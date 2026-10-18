class_name TrackGenerator
extends Node2D
## Builds the treadmill as it climbs: one chunk at a time just above what can
## be seen (the screen, or the top kill laser if that's higher). Most chunks
## get a row: a wall right across the track with a few gaps of mixed widths,
## so big blobs have to find the wide one, ghost dash through a piece that
## lets them (if they have the energy), or get stuck. Around it go loose
## walls (some of them kickers), bumpers and food, denser the further up it
## is. The floor around the spawn line is left clear. Pieces that fall well
## below the belt are freed. The pieces are added as children of this node,
## in world coordinates.

@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")
@export var wall_scene: PackedScene = preload("res://level/obstacles/wall_block.tscn")
@export var bumper_scene: PackedScene = preload("res://level/obstacles/bumper.tscn")
@export var food_scene: PackedScene = preload("res://level/pickups/food/food.tscn")

var _next_chunk_y := 0.0
var _prev_rects: Array[Rect2] = []


func _ready() -> void:
	process_physics_priority = -7 # after the mode scrolls the camera (-8)
	_next_chunk_y = _span().y # fill the whole belt below the start, too
	_generate_ahead()


func _physics_process(_delta: float) -> void:
	_generate_ahead()
	_cull_behind()


## (top, bottom) world y of everything that matters: the camera's view and
## the belt between the kill lasers, whichever reaches further.
func _span() -> Vector2:
	var view := GameCamera.view_of(self)
	var top := view.position.y
	var bottom := view.end.y
	var kl := get_tree().get_first_node_in_group("kill_lasers")
	if kl != null:
		top = minf(top, kl.kill_top())
		bottom = maxf(bottom, kl.kill_bottom())
	return Vector2(top, bottom)


func _generate_ahead() -> void:
	var want_top := _span().x - settings.chunk_height
	while _next_chunk_y > want_top:
		_gen_chunk(_next_chunk_y - settings.chunk_height, _next_chunk_y)
		_next_chunk_y -= settings.chunk_height


func _gen_chunk(y0: float, y1: float) -> void:
	var half := settings.track_width * 0.5
	var difficulty := clampf(-y1 / settings.difficulty_distance, 0.0, 1.0)
	var placed: Array[Rect2] = []

	var row_y := y0 + (y1 - y0) * randf_range(0.4, 0.6)
	var has_row := randf() < lerpf(settings.row_chance, 1.0, difficulty) \
		and not _clear_zone().intersects(Rect2(-half, row_y - 60.0, settings.track_width, 120.0))
	if has_row:
		_gen_row(row_y, half, difficulty, placed)

	var walls := randi_range(1 if has_row else 2, (2 if has_row else 3) + int(difficulty * 1.5))
	for _i in walls:
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

	for _i in randi_range(0, (1 if has_row else 2) + int(difficulty * 2.0)):
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

	var food := roundi(randi_range(settings.food_per_chunk.x, settings.food_per_chunk.y) * GameSettings.food_amount())
	for _i in food:
		for _try in 10:
			var p := Vector2(randf_range(-half + 40.0, half - 40.0), randf_range(y0 + 20.0, y1 - 20.0))
			var free := true
			for r: Rect2 in placed:
				if r.grow(30.0).has_point(p):
					free = false
					break
			if free:
				_place(food_scene.instantiate(), p)
				break

	_prev_rects = placed


## A wall across the whole track at `y`, broken by gaps: one wide (from
## `row_widest_gap`) and the rest narrow, in random order and places. The gaps
## go into `placed` too, padded, so nothing else is put in the way.
func _gen_row(y: float, half: float, difficulty: float, placed: Array[Rect2]) -> void:
	var gaps: Array[float] = [randf_range(settings.row_widest_gap.x, settings.row_widest_gap.y)]
	for _i in randi_range(settings.row_gaps.x, settings.row_gaps.y) - 1:
		gaps.append(randf_range(settings.row_narrow_gap.x, settings.row_narrow_gap.y))
	gaps.shuffle()
	var wall_total := settings.track_width
	for g in gaps:
		wall_total -= g
	# Split the wall into gaps + 1 pieces of random length (the outer two may be 0:
	# a gap right against the side wall).
	var weights: Array[float] = []
	var weight_sum := 0.0
	for i in gaps.size() + 1:
		var outer := i == 0 or i == gaps.size()
		var wgt := randf_range(0.0, 1.0) if outer else randf_range(0.4, 1.0)
		weights.append(wgt)
		weight_sum += wgt
	var x := -half
	var t := settings.wall_thickness
	for i in weights.size():
		var length := wall_total * weights[i] / weight_sum
		if length >= 24.0:
			var rect := Rect2(x, y - t * 0.5, length, t)
			placed.append(rect)
			var w: WallBlock = wall_scene.instantiate()
			w.size = rect.size
			w.kicker = randf() < settings.row_kicker_chance * (1.0 + difficulty)
			# Some pieces can't be dashed through: there, too big for the gaps is too big.
			w.ghost_proof = randf() < settings.row_ghost_proof_chance
			_place(w, rect.get_center())
		x += length
		if i < gaps.size():
			placed.append(Rect2(x, y - 50.0, gaps[i], 100.0)) # keep the way through clear
			x += gaps[i]


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


## The floor around the spawn line, kept free of obstacles.
func _clear_zone() -> Rect2:
	var half := settings.track_width * 0.5
	return Rect2(-half, settings.spawn_y - settings.start_clear, settings.track_width, settings.start_clear + 140.0)


## Too close to something already placed (in this chunk or the one below), or in the spawn zone?
func _blocked(rect: Rect2, placed: Array[Rect2]) -> bool:
	if rect.intersects(_clear_zone()):
		return true
	for other: Rect2 in placed + _prev_rects:
		if other.grow(settings.obstacle_gap).intersects(rect):
			return true
	return false


func _cull_behind() -> void:
	var limit := _span().y + 300.0
	for piece: Node2D in get_children():
		var top := piece.global_position.y
		if piece is WallBlock:
			top = (piece as WallBlock).rect().position.y
		if top >= limit:
			piece.queue_free()
