class_name GameMode
extends Node2D
## Round rules shared by the modes: the lineup, spawning blobs, the countdown,
## reacting to eliminations, the win check and its banners, and the pause menu. A mode script extends this, places one blob per slot in
## _spawn_blobs() with spawn_slot(), says which bot brain its CPUs use in
## _new_brain(), starts its hazards in _on_play_started() and stops them in
## _on_round_over(). Whatever knocks a blob out (an arena, a laser) just calls
## `blob.die()`; the mode hears it through `Blob.died`. START or ESC pauses
## (PauseMenu: resume, restart, quit); R restarts at once on the keyboard.
##
## Who plays comes from the lobby (Session.lineup). Started on its own (F6),
## a mode makes the default lineup from `info`: P1 on the keyboard, a
## connected gamepad as P2, computers in the other seats.

enum State { COUNTDOWN, PLAYING, OVER }

@export var info: ModeInfo # name and player counts (also what the lobby shows)
@export var blob_scene: PackedScene = preload("res://entities/blob/blob.tscn")
@export var pause_scene: PackedScene = preload("res://ui/menus/pause/pause_menu.tscn")
@export var blobs_node: Node2D # spawned blobs go here
@export var hud: Hud
@export var countdown_time := 2.4
@export var hint := "" # controls line shown at the bottom
@export var go_text := "BUMP!" # flashed when the countdown ends
@export_file("*.tscn") var menu_path := "res://ui/menus/main_menu.tscn" # Esc, when started on its own
@export_file("*.tscn") var lobby_path := "res://ui/menus/lobby/lobby.tscn" # Esc, when started from the lobby

@export_group("Names")
@export var player_name := "You" # the human's name when there's only one
## The `i`th computer gets the `i`th name.
@export var bot_names := PackedStringArray(["Bonk", "Wobbles", "Gummy", "Blorb", "Mochi", "Squish"])

var state := State.COUNTDOWN
var slots: Array[PlayerSlot] = [] # who plays, one blob each
var humans := 0 # how many of the slots are human


## Before any child is ready, so everything in the scene draws in the mode's own theme, if it has one.
func _enter_tree() -> void:
	Session.theme_override = info.theme if info != null else ""


func _exit_tree() -> void:
	Session.theme_override = ""


func _ready() -> void:
	slots = lineup()
	humans = 0
	for s in slots:
		if s.human:
			humans += 1
	hud.set_hint(hint)
	_spawn_blobs()
	await hud.play_countdown(countdown_time, go_text)
	if state != State.COUNTDOWN:
		return
	state = State.PLAYING
	for b in living_blobs():
		b.active = true
	_on_play_started()


func _unhandled_input(event: InputEvent) -> void:
	var esc: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	var start: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if esc or start:
		get_viewport().set_input_as_handled()
		pause()
	elif event is InputEventKey and event.is_action_pressed("restart"):
		restart()


## Stop the game and show the pause menu.
func pause() -> void:
	var menu: PauseMenu = pause_scene.instantiate()
	add_child(menu)
	menu.restart_requested.connect(restart)
	menu.quit_requested.connect(leave)
	menu.open(state == State.OVER, "QUIT TO LOBBY" if from_lobby() else "QUIT TO MENU")


func restart() -> void:
	get_tree().reload_current_scene()


## Back to the lobby (same players) or, started on its own, the main menu.
func leave() -> void:
	if from_lobby():
		Session.next_mode = info
		get_tree().change_scene_to_file(lobby_path)
	else:
		get_tree().change_scene_to_file(menu_path)


## The lobby's lineup if it was made for this mode, else the default one.
func lineup() -> Array[PlayerSlot]:
	var out: Array[PlayerSlot] = []
	if from_lobby():
		out.assign(Session.lineup)
	else:
		out = PlayerSlot.default_lineup(info)
	return out


func from_lobby() -> bool:
	return info != null and not Session.lineup.is_empty() and Session.lineup_mode == info.resource_path


## Override: place one blob per entry of `slots` with spawn_slot().
func _spawn_blobs() -> void:
	pass


## Override: a new brain for a computer player in this mode.
func _new_brain() -> BotBrain:
	return RingBotBrain.new()


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
	b.loses_mass = info != null and info.mass_loss
	b.add_child(controller)
	blobs_node.add_child(b)
	b.died.connect(_on_blob_died)
	return b


## The blob for `slots[i]` at `pos`: a human with their keys and gamepad
## (tagged P1..P4 when there's more than one human), or a computer with this
## mode's brain at the slot's level. In a team mode it gets the slot's team
## and plays in its team colour (PlayerSlot.team_in, color_in).
func spawn_slot(i: int, pos: Vector2) -> Blob:
	var b := _spawn_slot_blob(i, pos)
	b.team = slot_team(i)
	return b


## The team of `slots[i]` (PlayerSlot.team_in), -1 without teams.
func slot_team(i: int) -> int:
	return slots[i].team_in(info)


func _spawn_slot_blob(i: int, pos: Vector2) -> Blob:
	var slot := slots[i]
	var color := slot.color_in(info)
	if slot.human:
		var input := PlayerInput.new()
		input.profile = slot.profile
		input.pad_device = slot.pad_device
		input.pad_slot = 0 if slot.any_pad else -1
		var who := player_name if humans == 1 else "Player %d" % slot.number
		var b := spawn_blob(pos, color, who, input)
		if humans > 1:
			b.tag = "P%d" % slot.number
		return b
	var bot_index := 0
	for j in i:
		if not slots[j].human:
			bot_index += 1
	var brain := _new_brain()
	brain.level = slot.bot_level
	return spawn_blob(pos, color, bot_names[bot_index % bot_names.size()], brain)


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
		hud.show_banner("BUMPED OUT!" if b.tag == "" else "%s IS OUT!" % b.tag, b.color if b.tag != "" else Color(1.0, 0.45, 0.4), 2.0)
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
		hud.show_banner("YOU WIN!" if left[0].tag == "" else "%s WINS!" % left[0].tag, Color(1.0, 0.9, 0.35) if left[0].tag == "" else left[0].color)
	else:
		hud.show_banner("%s WINS" % left[0].display_name.to_upper(), left[0].color)
	hud.set_hint("Start or Esc: play again or quit   ·   R: play again")
