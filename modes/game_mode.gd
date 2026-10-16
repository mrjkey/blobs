class_name GameMode
extends Node2D
## Round rules shared by the modes: spawning blobs, the countdown, reacting to
## eliminations, the win check and its banners, R to restart, Esc to quit.
## A mode script extends this, spawns its blobs in _spawn_blobs(), starts its
## hazards in _on_play_started() and stops them in _on_round_over(). Whatever
## knocks a blob out (an arena, a laser) just calls `blob.die()`; the mode
## hears it through `Blob.died`.

enum State { COUNTDOWN, PLAYING, OVER }

@export var blob_scene: PackedScene = preload("res://blob/blob.tscn")
@export var blobs_node: Node2D # spawned blobs go here
@export var hud: Hud
@export var countdown_time := 2.4
@export var hint := "" # controls line shown at the bottom
@export_file("*.tscn") var menu_path := "res://ui/menus/main_menu.tscn"

@export_group("Looks")
@export var player_color := Color(0.3, 0.85, 1.0)
@export var player_name := "You"
@export var bot_names := PackedStringArray(["Bonk", "Wobbles", "Mochi", "Gummy", "Blorb", "Squish"])
@export var bot_colors := PackedColorArray([
	Color(1.0, 0.36, 0.36), Color(0.45, 0.9, 0.4), Color(1.0, 0.7, 0.25),
	Color(0.75, 0.45, 1.0), Color(1.0, 0.5, 0.8), Color(0.95, 0.95, 0.4),
])

var state := State.COUNTDOWN


func _ready() -> void:
	hud.set_hint(hint)
	_spawn_blobs()
	await hud.play_countdown(countdown_time)
	if state != State.COUNTDOWN:
		return
	state = State.PLAYING
	for b in living_blobs():
		b.active = true
	_on_play_started()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("quit"):
		get_tree().change_scene_to_file(menu_path)


## Override: place the blobs with spawn_player() / spawn_bot().
func _spawn_blobs() -> void:
	pass


## Override: turn on hazards, food and the like once the countdown is over.
func _on_play_started() -> void:
	pass


## Override: turn them off again when the round is decided.
func _on_round_over() -> void:
	pass


## Add a blob from `blob_scene`, steered by `controller`, frozen until the countdown ends.
func spawn_blob(pos: Vector2, color: Color, display_name: String, controller: Node, stats: BlobStats = null) -> Blob:
	var b: Blob = blob_scene.instantiate()
	b.position = pos
	b.color = color
	b.display_name = display_name
	if stats != null:
		b.stats = stats
	b.active = false
	b.add_child(controller)
	blobs_node.add_child(b)
	b.died.connect(_on_blob_died)
	return b


func spawn_player(pos: Vector2) -> Blob:
	return spawn_blob(pos, player_color, player_name, PlayerInput.new())


## The `index`th bot (0-based) gets the `index`th name and colour.
func spawn_bot(pos: Vector2, index: int, brain: BotBrain) -> Blob:
	return spawn_blob(pos, bot_colors[index % bot_colors.size()], bot_names[index % bot_names.size()], brain)


func living_blobs() -> Array[Blob]:
	var out: Array[Blob] = []
	for b: Blob in get_tree().get_nodes_in_group("blobs"):
		if b.alive:
			out.append(b)
	return out


func human_alive() -> Blob:
	for b in living_blobs():
		if b.is_human():
			return b
	return null


func _on_blob_died(b: Blob) -> void:
	if b.is_human():
		hud.show_banner("BUMPED OUT!", Color(1.0, 0.45, 0.4), 2.0)
	_check_round_over()


## Override for other win rules. Default: last blob standing.
func _check_round_over() -> void:
	if state != State.PLAYING:
		return
	var left := living_blobs()
	if left.size() > 1:
		return
	state = State.OVER
	_on_round_over()
	if left.is_empty():
		hud.show_banner("DRAW!", Color.WHITE)
	elif left[0].is_human():
		hud.show_banner("YOU WIN!", Color(1.0, 0.9, 0.35))
	else:
		hud.show_banner("%s WINS" % left[0].display_name.to_upper(), left[0].color)
	hud.set_hint("Press R to play again")
