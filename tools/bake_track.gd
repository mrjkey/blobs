extends SceneTree
## Bakes a generated treadmill track into a map you can open and edit in the
## editor: level/maps/<name>/<name>.tscn. Runs the TrackGenerator with a fixed
## seed from the bottom of the starting belt up to `length` px, then turns
## what it built into a Map: walls and bumpers as they are, food as FoodSpots,
## four SpawnPoints on the start line and a FinishLine at the top.
##
##   godot --headless --path <project> -s tools/bake_track.gd -- name=course_2 seed=7 length=8000
##
## Every argument is optional (defaults below). It overwrites a map of the same
## name: commit first. The new map shows up in the lobby once it's added to
## the TRACK option (GameSettings.OPTIONS, key "track_map").
##
## The game's classes are reached through load(), not by name: this script
## compiles before the autoloads exist, and those classes use them.

const DEFAULTS := {"name": "course_1", "seed": "1", "length": "8000", "respawn": "20"}


func _initialize() -> void:
	var args := DEFAULTS.duplicate()
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var map_name: String = args["name"]
	var length := float(args["length"])
	seed(int(args["seed"]))

	var settings = load("res://level/arenas/track/track_settings.tres")
	var gen = load("res://level/arenas/track/track_generator.gd").new()
	gen.auto = false
	root.add_child(gen)
	gen.build(-length, settings.belt_height * 0.5)

	var map := _node("res://level/maps/map.gd", map_name.to_pascal_case())
	var groups := {}
	for g in ["Walls", "Obstacles", "Food", "Spawns", "Finish"]:
		groups[g] = Node2D.new()
		groups[g].name = g
		_add(map, groups[g], map)

	var counts := {}
	for piece: Node2D in gen.get_children():
		var kind := piece.scene_file_path.get_file().get_basename()
		counts[kind] = counts.get(kind, 0) + 1
		var label := "%s%d" % [kind.to_pascal_case(), counts[kind]]
		match kind:
			"wall_block":
				piece.name = label
				piece.reparent(groups["Walls"])
				piece.owner = map
			"bumper":
				piece.name = label
				piece.reparent(groups["Obstacles"])
				piece.owner = map
			"food":
				var spot := _node("res://level/maps/food_spot.gd", "Food%d" % counts[kind])
				spot.set("respawn", float(args["respawn"]))
				spot.position = piece.global_position
				_add(groups["Food"], spot, map)

	# P1 and P2 near the middle, P3 and P4 outside them.
	var w: float = settings.track_width
	for i in 4:
		var spawn := _node("res://level/maps/spawn_point.gd", "P%d" % (i + 1))
		spawn.set("seat", i + 1)
		spawn.position = Vector2([-0.12, 0.12, -0.35, 0.35][i] * w, settings.spawn_y)
		_add(groups["Spawns"], spawn, map)
	var finish := _node("res://level/maps/finish_line.gd", "FinishLine")
	finish.position = Vector2(0.0, -length)
	_add(groups["Finish"], finish, map)

	var dir := "res://level/maps/%s" % map_name
	DirAccess.make_dir_recursive_absolute(dir)
	var packed := PackedScene.new()
	var err := packed.pack(map)
	var path := "%s/%s.tscn" % [dir, map_name]
	if err == OK:
		err = ResourceSaver.save(packed, path)
	if err == OK:
		_tidy(path)
	print("baked %s: %s (%s)" % [path, error_string(err), counts])
	quit(0 if err == OK else 1)


func _node(script_path: String, node_name: String) -> Node2D:
	var n := Node2D.new()
	n.set_script(load(script_path))
	n.name = node_name
	return n


func _add(parent: Node, child: Node, owner_node: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node


## Drop the `script = ...` lines the saver repeats on every wall and bumper
## (their scenes already have it), and the ext_resources only those used.
func _tidy(path: String) -> void:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var ids := []
	for line in lines:
		if line.begins_with("[ext_resource type=\"Script\"") and ("wall_block.gd" in line or "bumper.gd" in line):
			ids.append(line.get_slice("id=\"", 1).get_slice("\"", 0))
	var out := PackedStringArray()
	for line in lines:
		var drop := false
		for id in ids:
			if line == "script = ExtResource(\"%s\")" % id or (line.begins_with("[ext_resource") and line.ends_with("id=\"%s\"]" % id)):
				drop = true
		if not drop:
			out.append(line)
	FileAccess.open(path, FileAccess.WRITE).store_string("\n".join(out))
