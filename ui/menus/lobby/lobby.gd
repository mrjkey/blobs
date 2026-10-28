extends Control
## The lobby, between the main menu's PLAY and a game. Two views:
##
## GAME: the games as a row of tiles (GameTabs) that never moves, then a list
## like SETTINGS under it: the game's options (ModeInfo.options: football's
## time and goals, the treadmill's track and rules), PLAYERS (how many play:
## computers fill the seats nobody joins) and CPU LEVEL (one level for every
## computer). Anyone drives it: up/down picks a row, left/right changes it
## (on the tiles: the game), A goes on to PLAYERS, B goes back.
##
## PLAYERS: a panel per seat. Anyone joins with A on a controller, SPACE or
## ENTER on the keyboard, and takes the lowest free panel (P1, P2...). Each
## player only ever changes their own panel: left/right their team (team
## games) or colour, A ready, B not ready, then B again to leave. A lone
## keyboard player has every key; a second one joins by holding the other
## half's confirm key (SPACE: WASD + ESC, ENTER: arrows + BACKSPACE). Y or R
## opens GAME again, START or TAB plays right away (just computers if
## nobody joined). Once every player is ready the HOW TO PLAY page shows
## (HowToPlay: the game's moves and their buttons) and the next A (or START)
## starts the game; B un-readies.
##
## Every button means the same thing in both views. The lobby writes
## Session.lineup + Session.lineup_mode and starts the mode; back from the
## game it opens on PLAYERS with the same people.
##
## Online (Net), the host's lobby is the real one. The others show a copy:
## the host sends its state after every change ("lobby_state") and they send
## their players' presses to it ("lobby_act"), which it handles like its own.
## Only the host changes the game and its rules, and starts; everyone joins
## seats from their own keyboard and controllers. So players are keyed by
## computer and device ("1/keys", "2/pad:0"). The strip at the top shows the
## host's addresses (to tell the others) or whose game it is. Back with
## nobody joined, pressed twice, stops hosting or leaves.

enum View { GAME, PLAYERS }

const HOLD_TO_JOIN := 0.5 # seconds a second keyboard player holds their confirm key
const MESSAGE_TIME := 2.6
const TOAST_TIME := 2.2
const NETBAR_REFRESH := 1.0
const JOIN_GLYPHS := ["a", "key:SPACE", "key:ENTER"]
## What another computer may ask for ("lobby_act").
const NET_ACTIONS := ["up", "down", "left", "right", "confirm", "back", "rules", "start", "join_second", "leave"]

## Keyboard keys: physical key -> [the half of the keyboard ("" = any), action].
const KEYS := {
	KEY_W: ["keys_left", "up"], KEY_S: ["keys_left", "down"],
	KEY_A: ["keys_left", "left"], KEY_D: ["keys_left", "right"],
	KEY_SPACE: ["keys_left", "confirm"], KEY_ESCAPE: ["keys_left", "back"],
	KEY_UP: ["keys_right", "up"], KEY_DOWN: ["keys_right", "down"],
	KEY_LEFT: ["keys_right", "left"], KEY_RIGHT: ["keys_right", "right"],
	KEY_ENTER: ["keys_right", "confirm"], KEY_KP_ENTER: ["keys_right", "confirm"],
	KEY_BACKSPACE: ["keys_right", "back"],
	KEY_R: ["", "rules"], KEY_TAB: ["", "start"],
}
const PAD_BUTTONS := {
	JOY_BUTTON_A: "confirm", JOY_BUTTON_B: "back", JOY_BUTTON_Y: "rules", JOY_BUTTON_START: "start",
	JOY_BUTTON_DPAD_UP: "up", JOY_BUTTON_DPAD_DOWN: "down",
	JOY_BUTTON_DPAD_LEFT: "left", JOY_BUTTON_DPAD_RIGHT: "right",
}

@export var modes: Array[ModeInfo] = [] # the games, in the GAME row's order; the first is the default
@export var bot_levels: Array[BotLevel] = [] # CPU LEVEL's levels: the cpu_level option's ids are their names in lower case
@export var row_scene: PackedScene # an OptionRow, for the GAME list
@export_file("*.tscn") var main_menu_path := "res://ui/menus/main_menu.tscn"

var info: ModeInfo
var view := View.GAME
## The people who joined: "<computer>/<device>" (_key()) -> {peer, device,
## panel: card index, slot: PlayerSlot, ready: bool, order: join count}.
## A device is "keys" (a lone keyboard player, who has every key),
## "keys_left", "keys_right" or "pad:<id>", on computer `peer` (1 offline).
var players := {}
var lineup: Array = [] # per card: the PlayerSlot that plays there, or null (free); from _make_lineup()
var _row := 0 # the focused row in GAME
var _joins := 0
var _keyboard_home := {} # computer -> the half its lone keyboard player joined with
var _hold := {} # {key, half, t} while a second keyboard player holds their confirm key
var _sticks := StickRepeat.new() # one step per push of a stick, like the d-pad
var _message := "" # a short note under the panels
var _message_time := 0.0
var _toasts := {} # card index -> [text, seconds left]
var _leave_t := 0.0 # online: > 0 after back was pressed once; again stops hosting or leaves
var _synced := false # another computer's copy: the host's state has arrived
var _starting := false # the game is loading
var _host_view := -1 # another computer's copy: the host's view last time; when it changes, this copy follows
var _addresses := PackedStringArray() # hosting: this computer's addresses, for the others to type
var _netbar_t := 0.0

@onready var cards: Array[Node] = %Cards.get_children()
@onready var rows: VBoxContainer = %Rows
@onready var tabs: GameTabs = %GameTabs


func _ready() -> void:
	info = Session.next_mode if Session.next_mode is ModeInfo and modes.has(Session.next_mode) else modes[0]
	var titles := PackedStringArray()
	for m in modes:
		titles.append(m.title)
	tabs.titles = titles
	tabs.picked.connect(_pick_game)
	lineup.resize(cards.size())
	if Net.is_client():
		Net.send(1, "lobby_hello")
	elif _restore():
		view = View.PLAYERS
	if Net.is_host():
		Net.set_status("")
		_addresses = LanDiscovery.lan_addresses()
	Net.message.connect(_on_net_message)
	Net.peers_changed.connect(_on_peers_changed)
	Net.status_changed.connect(_refresh_players)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_build_rows()


func _process(delta: float) -> void:
	var me := Net.my_id()
	for r: Array in _sticks.repeats(delta):
		_act(me, "pad:%d" % r[0], r[1])
	var redraw := false
	if not _hold.is_empty():
		_hold.t += delta
		if _hold.t >= HOLD_TO_JOIN:
			var half: String = _hold.half
			_hold = {}
			_act(me, half, "join_second")
			return
		redraw = true
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message = ""
			redraw = true
	_leave_t = maxf(_leave_t - delta, 0.0)
	for i: int in _toasts.keys():
		_toasts[i][1] -= delta
		if _toasts[i][1] <= 0.0:
			_toasts.erase(i)
			redraw = true
	_netbar_t -= delta
	if _netbar_t <= 0.0:
		_netbar_t = NETBAR_REFRESH
		_refresh_netbar()
	if redraw:
		_refresh_game()
		_refresh_players()


func _input(event: InputEvent) -> void:
	var me := Net.my_id()
	if event is InputEventKey and not event.echo:
		if not KEYS.has(event.physical_keycode):
			return
		get_viewport().set_input_as_handled()
		var half: String = KEYS[event.physical_keycode][0]
		var action: String = KEYS[event.physical_keycode][1]
		if not event.pressed:
			# A short press of the other half's confirm key: the lone keyboard player's confirm.
			if not _hold.is_empty() and _hold.key == event.physical_keycode:
				_hold = {}
				_act(me, "keys", "confirm")
			return
		var lone := players.has(_key(me, "keys"))
		var device := "keys" if lone else half
		if half == "":
			device = "keys" if lone else "keys_left"
		if action == "confirm" and device == "keys" and half != _home(me) and view == View.PLAYERS:
			_hold = {key = event.physical_keycode, half = half, t = 0.0}
			return
		_act(me, device, action)
	elif event is InputEventJoypadButton and event.pressed:
		if PAD_BUTTONS.has(event.button_index):
			get_viewport().set_input_as_handled()
			_act(me, "pad:%d" % event.device, PAD_BUTTONS[event.button_index])
	elif event is InputEventJoypadMotion and event.axis <= JOY_AXIS_LEFT_Y:
		get_viewport().set_input_as_handled() # all of it: the rows mustn't see the stick
		var action := _sticks.motion(event)
		if action != "":
			_act(me, "pad:%d" % event.device, action)


## `device` on computer `peer` pressed `action`. Another computer's copy
## looks around by itself and sends the rest to the host.
func _act(peer: int, device: String, action: String) -> void:
	if Net.is_client():
		_act_client(device, action)
	elif view == View.GAME and peer == Net.my_id():
		_act_game(action)
	else:
		_act_players(peer, device if action == "join_second" else _resolve(peer, device), action)
	_changed()


## GAME: anyone moves through the list and changes it.
func _act_game(action: String) -> void:
	var list := _focusables()
	match action:
		"up", "down":
			_row = posmod(_row + (1 if action == "down" else -1), list.size())
			Sfx.play("pop", 1.4)
		"left", "right":
			var step := 1 if action == "right" else -1
			if list[_row] == tabs:
				_pick_game(posmod(modes.find(info) + step, modes.size()))
			elif list[_row] is OptionRow:
				(list[_row] as OptionRow).step(step) # _on_row_changed does the rest
		"confirm":
			_show(View.PLAYERS)
		"rules":
			_show(View.PLAYERS)
		"back":
			if Net.is_host() and not _has_players(Net.my_id()):
				_back_out()
			elif not players.is_empty():
				_show(View.PLAYERS)
			else:
				get_tree().change_scene_to_file(main_menu_path)
		"start":
			_start()


## PLAYERS: people join, and change only their own panel. `peer` is the
## computer the press came from: only this one's own presses change the view.
func _act_players(peer: int, device: String, action: String) -> void:
	var local := peer == Net.my_id()
	match action:
		"start":
			if local or _can_start():
				_start()
			else:
				_say("The host starts the game")
			return
		"rules":
			if local:
				_show(View.GAME)
			return
		"join_second":
			_join_second_keyboard(peer, device)
			return
	var key := _key(peer, device)
	if not players.has(key):
		match action:
			"confirm":
				_join(peer, device)
			"back":
				if local:
					_show(View.GAME)
		return
	var p: Dictionary = players[key]
	match action:
		"left", "right":
			if p.ready:
				_toast(p.panel, "Ready! Press %s to change" % _key_text(peer, device, "back"))
			else:
				_step_choice(p.slot, 1 if action == "right" else -1)
				Sfx.play("pop", 1.2)
		"confirm":
			if _how_to_up() or (not local and _can_start()):
				_start()
			elif not p.ready:
				p.ready = true
				_ripple(p.panel, 1.0)
				Sfx.play("pop", 1.3)
			elif _problem() != "":
				_toast(p.panel, _problem())
		"back":
			if p.ready:
				p.ready = false
				Sfx.play("pop", 0.9)
			else:
				_leave(key)
		"leave":
			_leave(key)


## On another computer's copy: looking around (the views, the GAME list)
## happens here; joining, a player's own panel and starting go to the host.
func _act_client(device: String, action: String) -> void:
	var me := Net.my_id()
	if view == View.GAME:
		match action:
			"up", "down":
				_row = posmod(_row + (1 if action == "down" else -1), _focusables().size())
				Sfx.play("pop", 1.4)
			"left", "right":
				_say("Only the host changes the game")
			"back":
				if _has_players(me):
					_show(View.PLAYERS)
				else:
					_back_out()
			"confirm", "rules":
				_show(View.PLAYERS)
			"start":
				_say("The host starts the game")
		return
	var joined := players.has(_key(me, device))
	match action:
		"rules":
			_show(View.GAME)
			return
		"back":
			if not joined:
				_show(View.GAME)
				return
	if Net.host_status != "":
		_say("%s is playing %s: wait for them to come back" % [Net.host_name, Net.host_status])
		return
	if joined or action in ["confirm", "start", "join_second"]:
		Net.send(1, "lobby_act", [device, action])
		Sfx.play("pop", 1.1)


func _show(next: View) -> void:
	view = next
	Sfx.play("pop", 1.0)


## Online, back with nobody joined: once to be sure, twice to stop hosting or leave.
func _back_out() -> void:
	if _leave_t <= 0.0:
		_leave_t = MESSAGE_TIME
		_say("Press back again to %s" % ("leave %s's game" % Net.host_name if Net.is_client() else "stop hosting"))
		Sfx.play("pop", 0.7)
		return
	if Net.is_client():
		Net.leave()
		get_tree().change_scene_to_file(Net.online_menu_path)
	else:
		Net.leave("%s stopped hosting" % Net.host_name)
		get_tree().change_scene_to_file(main_menu_path)


func _join(peer: int, device: String) -> void:
	if players.size() >= info.max_humans:
		_say("%s takes %d player%s" % [info.title, info.max_humans, "" if info.max_humans == 1 else "s"])
		return
	var panel := _free_panel()
	if panel < 0:
		_say("All seats are taken")
		return
	if device.begins_with("keys") and not _has_keyboard_player(peer):
		_keyboard_home[peer] = device if device != "keys" else "keys_left"
		device = "keys"
	var pad := int(device.get_slice(":", 1)) if device.begins_with("pad:") else -1
	var slot := PlayerSlot.make_human(panel + 1, PlayerSlot.PAD_ONLY, pad)
	slot.device = device
	slot.peer = peer
	_joins += 1
	players[_key(peer, device)] = {peer = peer, device = device, panel = panel, slot = slot, ready = false, order = _joins}
	_place(slot)
	_ripple(panel, 1.6)
	Sfx.play("pop", 1.1)


## Computer `peer`'s lone keyboard player keeps their half, the new one takes `half`.
func _join_second_keyboard(peer: int, half: String) -> void:
	var lone := _key(peer, "keys")
	if not players.has(lone) or not half in ["keys_left", "keys_right"]:
		return
	if players.size() >= info.max_humans or _free_panel() < 0:
		_say("All seats are taken")
		return
	var home := "keys_left" if half == "keys_right" else "keys_right"
	var first: Dictionary = players[lone]
	players.erase(lone)
	players[_key(peer, home)] = first
	first.device = home
	first.slot.device = home
	_keyboard_home[peer] = home
	_join(peer, half)


func _leave(key: String) -> void:
	var peer: int = players[key].peer
	players.erase(key)
	_fix_keyboard(peer)
	Sfx.play("pop", 0.7)


## One keyboard player of two left on computer `peer`: they get the whole keyboard again.
func _fix_keyboard(peer: int) -> void:
	var halves: Array[String] = []
	for k: String in players:
		if players[k].peer == peer and players[k].device.begins_with("keys_"):
			halves.append(k)
	if halves.size() == 1 and not players.has(_key(peer, "keys")):
		var p: Dictionary = players[halves[0]]
		_keyboard_home[peer] = p.device
		players.erase(halves[0])
		players[_key(peer, "keys")] = p
		p.device = "keys"
		p.slot.device = "keys"


## A press from another computer can cross a change it hasn't seen yet: half
## a keyboard when it has one keyboard player, or the whole keyboard when it
## just got a second. Point it at the player who has that key now.
func _resolve(peer: int, device: String) -> String:
	if device.begins_with("keys_") and players.has(_key(peer, "keys")):
		return "keys"
	if device == "keys" and not players.has(_key(peer, "keys")) and _has_keyboard_player(peer):
		return _home(peer)
	return device


func _key(peer: int, device: String) -> String:
	return "%d/%s" % [peer, device]


## The half computer `peer`'s lone keyboard player joined with (their confirm and back keys).
func _home(peer: int) -> String:
	return _keyboard_home.get(peer, "keys_left")


func _has_keyboard_player(peer: int) -> bool:
	for k: String in players:
		if players[k].peer == peer and players[k].device.begins_with("keys"):
			return true
	return false


func _has_players(peer: int) -> bool:
	for k: String in players:
		if players[k].peer == peer:
			return true
	return false


## The computers that have players here.
func _player_peers() -> Array[int]:
	var out: Array[int] = []
	for k: String in players:
		if not out.has(players[k].peer):
			out.append(players[k].peer)
	return out


## The lowest panel no player has, or -1.
func _free_panel() -> int:
	var taken := {}
	for d in players:
		taken[players[d].panel] = true
	for i in info.max_slots:
		if not taken.has(i):
			return i
	return -1


## A new player's (or a player's in a new game) team or colour: the smaller
## team, or the first colour from their seat's that no other player has.
func _place(slot: PlayerSlot) -> void:
	slot.number = _panel_of(slot) + 1
	if info.teams.is_empty():
		slot.team = -1
		slot.color_index = slot.number - 1
		if _color_taken(slot):
			_step_color(slot, 1)
		return
	var counts := _team_counts(slot)
	slot.team = counts.find(counts.min())


func _panel_of(slot: PlayerSlot) -> int:
	for d in players:
		if players[d].slot == slot:
			return players[d].panel
	return 0


## How many players are on each team, not counting `except`.
func _team_counts(except: PlayerSlot = null) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(info.teams.size())
	counts.fill(0)
	for d in players:
		var s: PlayerSlot = players[d].slot
		if s != except and s.team >= 0 and s.team < counts.size():
			counts[s.team] += 1
	return counts


func _step_choice(slot: PlayerSlot, step: int) -> void:
	if info.teams.is_empty():
		_step_color(slot, step)
	else:
		slot.team = posmod(slot.team + step, info.teams.size())


func _step_color(slot: PlayerSlot, step: int) -> void:
	var count := GameTheme.current().palette().size()
	for _i in count:
		slot.color_index = posmod(slot.color_index + step, count)
		if not _color_taken(slot):
			return


func _color_taken(slot: PlayerSlot) -> bool:
	for d in players:
		var s: PlayerSlot = players[d].slot
		if s != slot and s.color_index == slot.color_index:
			return true
	return false


## Who plays where: each player in their panel, then (in a game with
## computers) computers in the lowest free panels until PLAYERS are seated,
## spread to even out the teams, plus one for a team nobody is on.
func _make_lineup() -> Array:
	var out: Array = []
	out.resize(cards.size())
	for d in players:
		var p: Dictionary = players[d]
		p.slot.number = p.panel + 1
		out[p.panel] = p.slot
	if info.bots:
		var cpus := maxi(_seats() - players.size(), 0)
		for i in info.max_slots:
			if cpus > 0 and out[i] == null:
				out[i] = PlayerSlot.make_bot(i + 1, _cpu_level())
				cpus -= 1
	if info.teams.is_empty():
		PlayerSlot.recolor_bots(out.filter(func(s): return s != null))
		return out
	var counts := _team_counts()
	for s: PlayerSlot in out:
		if s != null and not s.human:
			s.team = counts.find(counts.min())
			counts[s.team] += 1
	for t in counts.size():
		var free := out.find(null)
		if counts[t] == 0 and info.bots and free >= 0 and free < info.max_slots:
			out[free] = PlayerSlot.make_bot(free + 1, _cpu_level())
			out[free].team = t
			counts[t] += 1
	var seen := {}
	for s: PlayerSlot in out:
		if s != null:
			s.team_second = seen.has(s.team)
			seen[s.team] = true
	return out


## What stops the game from starting, or "".
func _problem() -> String:
	if not info.bots and players.is_empty():
		return "Join first: %s has no computer players" % info.title
	if not info.teams.is_empty():
		var counts: Array[int] = []
		counts.resize(info.teams.size())
		counts.fill(0)
		for s: PlayerSlot in lineup:
			if s != null and s.team >= 0 and s.team < counts.size():
				counts[s.team] += 1
		for t in counts.size():
			if counts[t] == 0:
				return "%s needs a player" % info.teams[t]
	return ""


func _all_ready() -> bool:
	if players.is_empty():
		return false
	for d in players:
		if not players[d].ready:
			return false
	return true


## Everyone who joined is ready and nothing's missing: the next confirm starts.
func _can_start() -> bool:
	return _all_ready() and _problem() == ""


## Everyone's ready: the HOW TO PLAY page is up, and the next confirm starts.
func _how_to_up() -> bool:
	return view == View.PLAYERS and _can_start()


func _seats() -> int:
	return clampi(Session.lobby_seats.get(info.resource_path, info.default_slots), info.min_slots, info.max_slots)


func _cpu_level() -> BotLevel:
	var id := GameSettings.choice("cpu_level")
	for l in bot_levels:
		if l.display_name.to_lower() == id:
			return l
	return PlayerSlot.NORMAL


## Switch to another game. Players keep their panels where the new one has
## them (or move to a free one); the last to join leave if it takes fewer.
func _set_mode(next: ModeInfo) -> void:
	info = next
	Session.next_mode = info
	var order: Array = players.keys()
	order.sort_custom(func(a, b): return players[a].order < players[b].order)
	for j in order.size():
		if j >= info.max_humans:
			players.erase(order[j])
	var taken := {}
	for d in order:
		if not players.has(d):
			continue
		var p: Dictionary = players[d]
		p.ready = false
		if p.panel >= info.max_slots or taken.has(p.panel):
			p.panel = -1
		else:
			taken[p.panel] = true
	for d in order:
		if players.has(d) and players[d].panel < 0:
			var free := _free_panel()
			if free < 0:
				players.erase(d)
			else:
				players[d].panel = free
	for peer in _player_peers():
		_fix_keyboard(peer)
	for d in players:
		var s: PlayerSlot = players[d].slot
		s.number = players[d].panel + 1
		if info.teams.is_empty():
			s.team = -1
		elif s.team < 0 or s.team >= info.teams.size():
			_place(s)


## The GAME list: the game, its options, then PLAYERS and CPU LEVEL in a game with computers.
func _build_rows() -> void:
	for r in rows.get_children():
		rows.remove_child(r)
		r.queue_free()
	for o: Array in _row_options():
		_add_row(o[0], o[1])
	_row = clampi(_row, 0, _focusables().size() - 1)
	_changed()


## The GAME list's rows: [option, chosen id] each.
func _row_options() -> Array:
	var out: Array = []
	for key in info.options:
		out.append([GameSettings.option(key), GameSettings.choice(key)])
	if info.bots:
		if info.min_slots < info.max_slots:
			var counts: Array = []
			for n in range(info.min_slots, info.max_slots + 1):
				counts.append([str(n), str(n), "%d blobs play: computers take the seats nobody joins." % n])
			out.append([{key = "seats", label = "PLAYERS", choices = counts}, str(_seats())])
		out.append([GameSettings.option("cpu_level"), GameSettings.choice("cpu_level")])
	return out


## Show the current choices in the rows there are; a different set of rows is built anew.
func _update_rows() -> void:
	var options := _row_options()
	var current := rows.get_children().filter(func(r: Node) -> bool: return not r.is_queued_for_deletion())
	if current.size() != options.size():
		_build_rows()
		return
	for i in options.size():
		var row: OptionRow = current[i]
		if row.key() != options[i][0].key:
			_build_rows()
			return
		row.setup(options[i][0], options[i][1])


func _add_row(option: Dictionary, current: String) -> void:
	var row: OptionRow = row_scene.instantiate()
	row.setup(option, current)
	row.changed.connect(_on_row_changed)
	row.focus_mode = Control.FOCUS_ALL
	rows.add_child(row)


func _on_row_changed(row: OptionRow) -> void:
	if Net.is_client():
		_say("Only the host changes the game")
		_update_rows()
		_changed()
		return
	match row.key():
		"seats":
			Session.lobby_seats[info.resource_path] = int(row.id())
		_:
			GameSettings.set_choice(row.key(), row.id())
	for d in players:
		players[d].ready = false # the rules changed: everyone confirms again
	Sfx.play("pop", 1.2)
	_changed()


## Pick the game `modes[index]` (the tiles' left/right, or a click on one).
func _pick_game(index: int) -> void:
	if modes[index] == info:
		return
	if Net.is_client():
		_say("Only the host changes the game")
		_changed()
		return
	_set_mode(modes[index])
	_build_rows()
	Sfx.play("pop", 1.0)


func _focusables() -> Array[Control]:
	var out: Array[Control] = [tabs]
	for r in rows.get_children():
		if not r.is_queued_for_deletion():
			out.append(r)
	out.append(%ChooseButton)
	return out


## A ripple in the menu's backdrop (the neon grid) under panel `panel`.
func _ripple(panel: int, strength: float) -> void:
	%MenuFrame.ripple(cards[panel].get_global_rect().get_center(), strength)


func _say(text: String) -> void:
	_message = text
	_message_time = MESSAGE_TIME


func _toast(panel: int, text: String) -> void:
	_toasts[panel] = [text, TOAST_TIME]
	Sfx.play("pop", 0.6)


## After any change: the lineup, then both views. Hosting, the others get the new state.
func _changed() -> void:
	if not Net.is_client():
		lineup = _make_lineup()
	_refresh_game()
	_refresh_players()
	if Net.is_host():
		Net.send(0, "lobby_state", _state())


func _refresh_game() -> void:
	%Game.visible = view == View.GAME
	%Players.visible = view == View.PLAYERS
	%GameTitle.text = info.title
	%GameSubtitle.text = info.subtitle
	%Facts.text = _facts()
	var list := _focusables()
	_row = clampi(_row, 0, list.size() - 1)
	var focused := list[_row]
	if view == View.GAME and is_inside_tree():
		focused.grab_focus()
	tabs.index = modes.find(info)
	if _message != "":
		%Help.text = _message
	elif focused is OptionRow:
		%Help.text = (focused as OptionRow).help_text()
	elif focused == tabs:
		%Help.text = "The host picks the game." if Net.is_client() else "Left and right pick the game."
	else:
		%Help.text = "Join, pick your %s, and get ready." % ("team" if not info.teams.is_empty() else "colour")
	var mine := _has_players(Net.my_id())
	var back := "Back to players" if not players.is_empty() else "Main menu"
	if Net.is_client() and not mine:
		back = "Leave game"
	elif Net.is_host() and not mine:
		back = "Stop hosting"
	var legend: Array = [[["ud"], "Move"]]
	if not Net.is_client():
		legend.append([["lr"], "Change"])
	legend.append([JOIN_GLYPHS, "Choose players"])
	legend.append([["b", "key:ESC"], back])
	%GameLegend.prompts = legend


## The GAME view's line about who plays.
func _facts() -> String:
	var parts: Array[String] = []
	parts.append("%d player%s" % [info.max_slots, "" if info.max_slots == 1 else "s"] if info.min_slots == info.max_slots \
		else "%d to %d players" % [info.min_slots, info.max_slots])
	if not info.teams.is_empty():
		parts.append(" vs ".join(info.teams))
	parts.append("computers fill empty seats" if info.bots else "together, no computers")
	return "   ·   ".join(parts)


func _refresh_players() -> void:
	%GameName.text = info.title
	var rules: Array[String] = []
	for key in info.options:
		var o := GameSettings.option(key)
		if o.default_id != "normal": # the game's main choice (track, time, level): its value says it all
			rules.append(GameSettings.choice_label(key))
		elif GameSettings.choice(key) != "normal": # a tuning knob: only when changed, with its name
			rules.append("%s %s" % [o.label, GameSettings.choice_label(key)])
	if info.bots:
		rules.append("CPU " + GameSettings.choice_label("cpu_level"))
	%Rules.text = "   ·   ".join(rules)
	%RulesPrompt.prompts = [[["y", "key:R"], "Game & rules"]]
	_refresh_cards()
	var all_ready := _all_ready()
	var how_to: HowToPlay = %HowTo
	how_to.visible = _how_to_up()
	if how_to.visible:
		how_to.show_game(info, info.move_rules(), _my_keyboards())
		how_to.prompts = [[_my_glyphs("confirm") + ["pill:START"], "Play"], [_my_glyphs("back"), "Not ready"]]
	var status := _message if not how_to.visible else ""
	if status == "" and Net.is_client() and not _synced:
		status = "Getting the lobby from %s..." % Net.host_name
	if status == "" and Net.is_client() and Net.host_status != "":
		status = "%s is playing %s. Join a seat when they're back." % [Net.host_name, Net.host_status]
	if status == "" and all_ready:
		status = _problem()
	if status == "" and not players.is_empty() and not all_ready:
		status = "Waiting for everyone to get ready"
	%Status.text = status
	var legend: Array = [[_join_glyphs(), "Join"], [["y", "key:R"], "Game & rules"]]
	if not Net.is_client() and (info.bots or not players.is_empty()):
		legend.append([["pill:START", "key:TAB"], "Let the computers play" if players.is_empty() else "Play now"])
	legend.append([["b"] if _has_keyboard_player(Net.my_id()) else ["b", "key:ESC"], "Back to game"])
	%Legend.prompts = legend
	_refresh_netbar()


## The strip at the top, online: hosting, the addresses to tell the others
## and who's in; joined, whose game it is and the ping.
func _refresh_netbar() -> void:
	%NetBar.visible = Net.is_online()
	if Net.is_host():
		var names := PackedStringArray()
		for id: int in Net.peers:
			names.append(Net.peers[id].name)
		var where := "  /  ".join(_addresses) if not _addresses.is_empty() else "no network found"
		if Net.port != Net.PORT:
			where += "  port %d" % Net.port
		%NetBar.text = "HOSTING   %s   ·   %s" % [where, "with " + ", ".join(names) if not names.is_empty() else "waiting for others to join"]
	elif Net.is_client():
		%NetBar.text = "ONLINE   ·   %s's game   ·   %d ms" % [Net.host_name, roundi(Net.ping_ms)]


func _refresh_cards() -> void:
	var theme := GameTheme.current()
	var me := Net.my_id()
	var next_free := _free_panel()
	var hold_panel := next_free if not _hold.is_empty() else -1
	for i in cards.size():
		var card: LobbyCard = cards[i]
		card.visible = i < info.max_slots
		var s: PlayerSlot = lineup[i]
		var team := s.team_in(info) if s != null else -1
		card.team_name = info.teams[team] if team >= 0 else ""
		card.team_color = theme.team_color(team) if team >= 0 else Color.WHITE
		card.color = s.color_in(info) if s != null else Color.WHITE
		card.toast = _toasts[i][0] if _toasts.has(i) else ""
		card.hold = _hold.t / HOLD_TO_JOIN if i == hold_panel else 0.0
		card.hold_text = "Keep holding %s" % ("SPACE" if _hold.get("half", "") == "keys_left" else "ENTER")
		card.player_ready = false
		var join: Array = [[_join_glyphs(), "Join"]]
		if players.has(_key(me, "keys")) and i == next_free:
			join.append([["key:ENTER" if _home(me) == "keys_left" else "key:SPACE"], "hold: 2nd keyboard"])
		if s == null:
			card.kind = LobbyCard.Kind.OPEN
			card.title = "JOIN"
			card.detail = ""
			card.prompts = join
		elif not s.human:
			card.kind = LobbyCard.Kind.CPU
			card.title = "CPU"
			card.detail = s.bot_level.display_name
			card.prompts = join
		else:
			var p: Dictionary = players.get(_key(s.peer, s.device), {ready = false})
			card.kind = LobbyCard.Kind.HUMAN
			card.title = "P%d" % s.number
			card.detail = s.describe() if not Net.is_online() else "%s  ·  %s" % [Net.peer_name(s.peer), s.describe()]
			card.player_ready = p.ready
			card.choice_label = "COLOUR" if team < 0 else "TEAM"
			card.choice_value = "" if team < 0 else info.teams[team]
			if p.ready:
				card.prompts = [[_glyphs(s.peer, s.device, "back"), "Not ready"]]
			else:
				card.prompts = [
					[_glyphs(s.peer, s.device, "lr"), "Team" if team >= 0 else "Colour"],
					[_glyphs(s.peer, s.device, "confirm"), "Ready"],
					[_glyphs(s.peer, s.device, "back"), "Leave"],
				]
		card.queue_redraw()


## The glyphs for `action` on `device`'s buttons (on computer `peer`).
func _glyphs(peer: int, device: String, action: String) -> Array:
	if device.begins_with("pad:"):
		return [{"confirm": "a", "back": "b", "lr": "lr"}[action]]
	var left := (_home(peer) if device == "keys" else device) == "keys_left"
	match action:
		"confirm":
			return ["key:SPACE" if left else "key:ENTER"]
		"back":
			return ["key:ESC" if left else "key:BKSP"]
	return ["key:A", "key:D"] if left else ["lr"]


func _key_text(peer: int, device: String, action: String) -> String:
	var g: String = _glyphs(peer, device, action)[0]
	return g.get_slice(":", 1) if g.contains(":") else g.to_upper()


## What joins: A, plus the keyboard's keys while nobody plays on this computer's.
func _join_glyphs() -> Array:
	return ["a"] if _has_keyboard_player(Net.my_id()) else JOIN_GLYPHS


## The keys of this computer's keyboard players, for HOW TO PLAY (none: the page shows the whole keyboard's).
func _my_keyboards() -> Array[InputProfile]:
	var out: Array[InputProfile] = []
	for half: String in ["keys", "keys_left", "keys_right"]:
		for p: Dictionary in players.values():
			if p.peer == Net.my_id() and p.device == half:
				out.append({"keys": PlayerSlot.KEYS_ALL, "keys_left": PlayerSlot.KEYS_LEFT}.get(half, PlayerSlot.KEYS_RIGHT))
				break
	return out


## What does `action` ("confirm", "back") for everyone who joined here (HOW TO PLAY's prompts); everyone's if nobody did.
func _my_glyphs(action: String) -> Array:
	var out: Array = []
	var mine := _has_players(Net.my_id())
	for d: String in players:
		var p: Dictionary = players[d]
		if mine and p.peer != Net.my_id():
			continue
		for g in _glyphs(p.peer, p.device, action):
			if not out.has(g):
				out.append(g)
	out.sort()
	return out


func _start() -> void:
	if not is_inside_tree() or _starting:
		return # online, two START presses can arrive together
	lineup = _make_lineup()
	var problem := _problem()
	if problem != "":
		_say(problem)
		if view == View.GAME:
			_show(View.PLAYERS)
		_changed()
		return
	var out: Array = []
	for s: PlayerSlot in lineup:
		if s == null:
			continue
		if s.human:
			s.fit_profile()
		out.append(s)
	Session.lineup = out
	Session.lineup_mode = info.resource_path
	Session.next_mode = info
	_starting = true
	Net.set_status(info.title)
	get_tree().change_scene_to_file(info.scene)


## Back from a game: the same players, if their device (or their computer) is still here.
func _restore() -> bool:
	if Session.lineup.is_empty() or Session.lineup_mode != info.resource_path:
		return false
	var me := Net.my_id()
	var pads := Input.get_connected_joypads()
	for s: PlayerSlot in Session.lineup:
		if not s.human or s.device == "" or s.number < 1 or s.number > info.max_slots:
			continue
		if s.peer != me and not Net.peers.has(s.peer):
			continue
		if s.peer == me and s.pad_device >= 0 and not pads.has(s.pad_device):
			continue
		_joins += 1
		players[_key(s.peer, s.device)] = {peer = s.peer, device = s.device, panel = s.number - 1, slot = s, ready = false, order = _joins}
	for peer in _player_peers():
		_fix_keyboard(peer)
	return true


## What another computer's copy needs to show the lobby (_apply_state()).
func _state() -> Dictionary:
	var seated: Array = []
	for d: String in players:
		seated.append({panel = players[d].panel, ready = players[d].ready, order = players[d].order})
	var seats: Array = []
	for s: PlayerSlot in lineup:
		seats.append(s.to_net() if s != null else null)
	return {
		mode = modes.find(info),
		settings = GameSettings.shared_choices(),
		seats = _seats(),
		lineup = seats,
		players = seated,
		homes = _keyboard_home,
		message = [_message, _message_time],
		toasts = _toasts,
		view = view,
	}


## Another computer's copy: show the host's lobby (_state()). When the host
## switches between GAME and PLAYERS, this copy goes along.
func _apply_state(state: Dictionary) -> void:
	var index := int(state.get("mode", 0))
	if index < 0 or index >= modes.size():
		return
	var new_mode := modes[index] != info or not _synced
	info = modes[index]
	Session.next_mode = info
	GameSettings.use_host_settings(state.get("settings", {}))
	Session.lobby_seats[info.resource_path] = int(state.get("seats", info.default_slots))
	lineup = []
	lineup.resize(cards.size())
	var seats: Array = state.get("lineup", [])
	for i in mini(seats.size(), cards.size()):
		if seats[i] is Dictionary:
			lineup[i] = PlayerSlot.from_net(seats[i], bot_levels)
	players = {}
	for p: Variant in state.get("players", []):
		var panel := int(p.get("panel", -1)) if p is Dictionary else -1
		if panel < 0 or panel >= lineup.size() or lineup[panel] == null:
			continue
		var s: PlayerSlot = lineup[panel]
		players[_key(s.peer, s.device)] = {peer = s.peer, device = s.device, panel = panel, slot = s,
			ready = bool(p.get("ready", false)), order = int(p.get("order", 0))}
	_keyboard_home = state.get("homes", {})
	var message: Array = state.get("message", ["", 0.0])
	if message.size() == 2:
		_message = str(message[0])
		_message_time = float(message[1])
	_toasts = state.get("toasts", {})
	var host_view := int(state.get("view", View.GAME))
	if host_view != _host_view:
		_host_view = host_view
		view = View.PLAYERS if host_view == View.PLAYERS else View.GAME
	_synced = true
	if new_mode:
		_build_rows()
	else:
		_update_rows()
		_changed()


func _on_net_message(from: int, type: String, data: Variant) -> void:
	if not is_inside_tree():
		return # on the way out (the game is loading)
	match type:
		"lobby_hello":
			if Net.is_host():
				Net.send(from, "lobby_state", _state())
		"lobby_act":
			if Net.is_host() and data is Array and data.size() == 2 and data[0] is String and data[1] is String \
					and data[1] in NET_ACTIONS and (data[0].begins_with("keys") or data[0].begins_with("pad:")):
				_act(from, data[0], data[1])
		"lobby_state":
			if Net.is_client() and data is Dictionary:
				_apply_state(data)


## Hosting: a computer left (its players go with it) or joined (it gets the lobby).
func _on_peers_changed() -> void:
	if not Net.is_host():
		_refresh_players()
		return
	for k: String in players.keys():
		var peer: int = players[k].peer
		if peer != Net.my_id() and not Net.peers.has(peer):
			players.erase(k)
	_changed()


func _on_choose_button_pressed() -> void:
	_show(View.PLAYERS)
	_changed()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	var pad := "pad:%d" % device
	if connected or not players.has(_key(Net.my_id(), pad)):
		return
	if Net.is_client():
		Net.send(1, "lobby_act", [pad, "leave"])
	else:
		_leave(_key(Net.my_id(), pad))
		_changed()
