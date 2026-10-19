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
## nobody joined). Once every player is ready a READY banner shows and the
## next A (or START) starts the game.
##
## Every button means the same thing in both views. The lobby writes
## Session.lineup + Session.lineup_mode and starts the mode; back from the
## game it opens on PLAYERS with the same people.

enum View { GAME, PLAYERS }

const HOLD_TO_JOIN := 0.5 # seconds a second keyboard player holds their confirm key
const MESSAGE_TIME := 2.6
const TOAST_TIME := 2.2
const JOIN_GLYPHS := ["a", "key:SPACE", "key:ENTER"]

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
## The people who joined: device ("keys", "keys_left", "keys_right", "pad:<id>")
## -> {panel: card index, slot: PlayerSlot, ready: bool, order: join count}.
## "keys" is a lone keyboard player, who has every key.
var players := {}
var lineup: Array = [] # per card: the PlayerSlot that plays there, or null (free); from _make_lineup()
var _row := 0 # the focused row in GAME
var _came_from_players := false # PLAYERS was shown: B in GAME goes back there
var _joins := 0
var _keyboard_home := "keys_left" # the half a lone keyboard player joined with
var _hold := {} # {key, half, t} while a second keyboard player holds their confirm key
var _sticks := StickRepeat.new() # one step per push of a stick, like the d-pad
var _message := "" # a short note under the panels
var _message_time := 0.0
var _toasts := {} # card index -> [text, seconds left]

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
	if _restore():
		view = View.PLAYERS
		_came_from_players = true
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_build_rows()


func _process(delta: float) -> void:
	for r: Array in _sticks.repeats(delta):
		_act("pad:%d" % r[0], r[1])
	var redraw := false
	if not _hold.is_empty():
		_hold.t += delta
		if _hold.t >= HOLD_TO_JOIN:
			var half: String = _hold.half
			_hold = {}
			_join_second_keyboard(half)
			_changed()
			return
		redraw = true
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message = ""
			redraw = true
	for i: int in _toasts.keys():
		_toasts[i][1] -= delta
		if _toasts[i][1] <= 0.0:
			_toasts.erase(i)
			redraw = true
	if redraw:
		_refresh_players()


func _input(event: InputEvent) -> void:
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
				_act("keys", "confirm")
			return
		var device := "keys" if players.has("keys") else half
		if half == "":
			device = "keys" if players.has("keys") else "keys_left"
		if action == "confirm" and device == "keys" and half != _keyboard_home and view == View.PLAYERS:
			_hold = {key = event.physical_keycode, half = half, t = 0.0}
			return
		_act(device, action)
	elif event is InputEventJoypadButton and event.pressed:
		if PAD_BUTTONS.has(event.button_index):
			get_viewport().set_input_as_handled()
			_act("pad:%d" % event.device, PAD_BUTTONS[event.button_index])
	elif event is InputEventJoypadMotion and event.axis <= JOY_AXIS_LEFT_Y:
		get_viewport().set_input_as_handled() # all of it: the rows mustn't see the stick
		var action := _sticks.motion(event)
		if action != "":
			_act("pad:%d" % event.device, action)


func _act(device: String, action: String) -> void:
	if view == View.GAME:
		_act_game(action)
	else:
		_act_players(device, action)
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
		"back", "rules":
			if _came_from_players or not players.is_empty():
				_show(View.PLAYERS)
			else:
				get_tree().change_scene_to_file(main_menu_path)
		"start":
			_start()


## PLAYERS: people join, and change only their own panel.
func _act_players(device: String, action: String) -> void:
	match action:
		"start":
			_start()
			return
		"rules":
			_show(View.GAME)
			return
	if not players.has(device):
		match action:
			"confirm":
				_join(device)
			"back":
				_show(View.GAME)
		return
	var p: Dictionary = players[device]
	match action:
		"left", "right":
			if p.ready:
				_toast(p.panel, "Ready! Press %s to change" % _key_text(device, "back"))
			else:
				_step_choice(p.slot, 1 if action == "right" else -1)
				Sfx.play("pop", 1.2)
		"confirm":
			if _banner_up():
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
				_leave(device)


func _show(next: View) -> void:
	view = next
	if next == View.PLAYERS:
		_came_from_players = true
	Sfx.play("pop", 1.0)


func _join(device: String) -> void:
	if players.size() >= info.max_humans:
		_say("%s takes %d player%s" % [info.title, info.max_humans, "" if info.max_humans == 1 else "s"])
		return
	var panel := _free_panel()
	if panel < 0:
		_say("All seats are taken")
		return
	if device.begins_with("keys") and not _has_keyboard_player():
		_keyboard_home = device
		device = "keys"
	var pad := int(device.get_slice(":", 1)) if device.begins_with("pad:") else -1
	var slot := PlayerSlot.make_human(panel + 1, PlayerSlot.PAD_ONLY, pad)
	slot.device = device
	_joins += 1
	players[device] = {panel = panel, slot = slot, ready = false, order = _joins}
	_place(slot)
	_ripple(panel, 1.6)
	Sfx.play("pop", 1.1)


## The lone keyboard player keeps their half, the new one takes `half`.
func _join_second_keyboard(half: String) -> void:
	if players.size() >= info.max_humans or _free_panel() < 0:
		_say("All seats are taken")
		return
	var first: Dictionary = players["keys"]
	players.erase("keys")
	players[_keyboard_home] = first
	first.slot.device = _keyboard_home
	_join(half)


func _leave(device: String) -> void:
	players.erase(device)
	_fix_keyboard()
	Sfx.play("pop", 0.7)


## One keyboard player left of two: they get the whole keyboard again.
func _fix_keyboard() -> void:
	var halves: Array[String] = []
	for d: String in players:
		if d.begins_with("keys_"):
			halves.append(d)
	if halves.size() == 1 and not players.has("keys"):
		_keyboard_home = halves[0]
		var p: Dictionary = players[halves[0]]
		players.erase(halves[0])
		players["keys"] = p
		p.slot.device = "keys"


func _has_keyboard_player() -> bool:
	for d: String in players:
		if d.begins_with("keys"):
			return true
	return false


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
			if s != null:
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


func _banner_up() -> bool:
	return view == View.PLAYERS and _all_ready() and _problem() == ""


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
	_fix_keyboard()
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
	for key in info.options:
		_add_row(GameSettings.option(key), GameSettings.choice(key))
	if info.bots:
		if info.min_slots < info.max_slots:
			var counts: Array = []
			for n in range(info.min_slots, info.max_slots + 1):
				counts.append([str(n), str(n), "%d blobs play: computers take the seats nobody joins." % n])
			_add_row({key = "seats", label = "PLAYERS", choices = counts}, str(_seats()))
		_add_row(GameSettings.option("cpu_level"), GameSettings.choice("cpu_level"))
	_row = clampi(_row, 0, _focusables().size() - 1)
	_changed()


func _add_row(option: Dictionary, current: String) -> void:
	var row: OptionRow = row_scene.instantiate()
	row.setup(option, current)
	row.changed.connect(_on_row_changed)
	row.focus_mode = Control.FOCUS_ALL
	rows.add_child(row)


func _on_row_changed(row: OptionRow) -> void:
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


## After any change: the lineup, then both views.
func _changed() -> void:
	lineup = _make_lineup()
	_refresh_game()
	_refresh_players()


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
	if focused is OptionRow:
		%Help.text = (focused as OptionRow).help_text()
	elif focused == tabs:
		%Help.text = "Left and right pick the game."
	else:
		%Help.text = "Join, pick your %s, and get ready." % ("team" if not info.teams.is_empty() else "colour")
	%GameLegend.prompts = [
		[["ud"], "Move"],
		[["lr"], "Change"],
		[JOIN_GLYPHS, "Choose players"],
		[["b", "key:ESC"], "Back to players" if _came_from_players or not players.is_empty() else "Main menu"],
	]


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
		rules.append(GameSettings.choice_label(key))
	if info.bots:
		rules.append("CPU " + GameSettings.choice_label("cpu_level"))
	%Rules.text = "   ·   ".join(rules)
	%RulesPrompt.prompts = [[["y", "key:R"], "Game & rules"]]
	_refresh_cards()
	var all_ready := _all_ready()
	%Banner.visible = _banner_up()
	%BannerPrompt.prompts = [[_confirm_glyphs() + ["pill:START"], "to play"]]
	var status := _message if not %Banner.visible else ""
	if status == "" and all_ready:
		status = _problem()
	if status == "" and not players.is_empty() and not all_ready:
		status = "Waiting for everyone to get ready"
	%Status.text = status
	var legend: Array = [[_join_glyphs(), "Join"], [["y", "key:R"], "Game & rules"]]
	if info.bots or not players.is_empty():
		legend.append([["pill:START", "key:TAB"], "Let the computers play" if players.is_empty() else "Play now"])
	legend.append([["b"] if _has_keyboard_player() else ["b", "key:ESC"], "Back to game"])
	%Legend.prompts = legend


func _refresh_cards() -> void:
	var theme := GameTheme.current()
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
		if players.has("keys") and i == next_free:
			join.append([["key:ENTER" if _keyboard_home == "keys_left" else "key:SPACE"], "hold: 2nd keyboard"])
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
			var p: Dictionary = players[s.device]
			card.kind = LobbyCard.Kind.HUMAN
			card.title = "P%d" % s.number
			card.detail = s.describe()
			card.player_ready = p.ready
			card.choice_label = "COLOUR" if team < 0 else "TEAM"
			card.choice_value = "" if team < 0 else info.teams[team]
			if p.ready:
				card.prompts = [[_glyphs(s.device, "back"), "Not ready"]]
			else:
				card.prompts = [
					[_glyphs(s.device, "lr"), "Team" if team >= 0 else "Colour"],
					[_glyphs(s.device, "confirm"), "Ready"],
					[_glyphs(s.device, "back"), "Leave"],
				]
		card.queue_redraw()


## The glyphs for `action` on `device`'s buttons.
func _glyphs(device: String, action: String) -> Array:
	if device.begins_with("pad:"):
		return [{"confirm": "a", "back": "b", "lr": "lr"}[action]]
	var left := (_keyboard_home if device == "keys" else device) == "keys_left"
	match action:
		"confirm":
			return ["key:SPACE" if left else "key:ENTER"]
		"back":
			return ["key:ESC" if left else "key:BKSP"]
	return ["key:A", "key:D"] if left else ["lr"]


func _key_text(device: String, action: String) -> String:
	var g: String = _glyphs(device, action)[0]
	return g.get_slice(":", 1) if g.contains(":") else g.to_upper()


## What joins: A, plus the keyboard's keys while nobody plays on it.
func _join_glyphs() -> Array:
	return ["a"] if _has_keyboard_player() else JOIN_GLYPHS


## What confirms for everyone who joined (the READY banner).
func _confirm_glyphs() -> Array:
	var out: Array = []
	for d: String in players:
		for g in _glyphs(d, "confirm"):
			if not out.has(g):
				out.append(g)
	out.sort()
	return out


func _start() -> void:
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
			match s.device:
				"keys":
					s.profile = PlayerSlot.KEYS_ALL
				"keys_left":
					s.profile = PlayerSlot.KEYS_LEFT
				"keys_right":
					s.profile = PlayerSlot.KEYS_RIGHT
				_:
					s.profile = PlayerSlot.PAD_ONLY
		out.append(s)
	Session.lineup = out
	Session.lineup_mode = info.resource_path
	Session.next_mode = info
	get_tree().change_scene_to_file(info.scene)


## Back from a game: the same players, if their device is still here.
func _restore() -> bool:
	if Session.lineup.is_empty() or Session.lineup_mode != info.resource_path:
		return false
	var pads := Input.get_connected_joypads()
	for s: PlayerSlot in Session.lineup:
		if not s.human or s.device == "" or s.number < 1 or s.number > info.max_slots:
			continue
		if s.pad_device >= 0 and not pads.has(s.pad_device):
			continue
		_joins += 1
		players[s.device] = {panel = s.number - 1, slot = s, ready = false, order = _joins}
	if players.has("keys_left") != players.has("keys_right"):
		_fix_keyboard()
	return true


func _on_choose_button_pressed() -> void:
	_show(View.PLAYERS)
	_changed()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	var key := "pad:%d" % device
	if not connected and players.has(key):
		_leave(key)
		_changed()
