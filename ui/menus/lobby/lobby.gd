extends Control
## The lobby (game and player select), between the main menu's PLAY and a
## mode. At the top: the game (one of `modes`) and its options (ModeInfo.options,
## e.g. football's time and goals). Below: the mode's seats as cards. It builds
## the lineup (Session.lineup) and starts the mode.
##
## The top: before joining, left/right changes the game and up/down picks a
## row (the game or one of its options) to change. Once joined, LB/RB on a
## controller or Q/E on the keyboard change the picked row, Y or R picks the row.
##
## Anyone joins by pressing A on a controller, SPACE (WASD keys) or ENTER
## (arrow keys) on the keyboard, and takes the first seat that isn't a
## player's. Seats nobody joined are computers. Each player has a hand, a
## marker under one card, that they move with left/right:
##   own card:     up/down colour, A ready, B leave
##   a CPU card:   up/down its level, A take its seat (to change team), B close the seat
##   empty seat:   A open it as a CPU
## Once every player is ready the game starts. START (or TAB) starts it right
## away; with nobody joined, the computers play on their own. B / ESC with
## nobody joined goes back to the main menu.

const READY_DELAY := 0.7 # seconds between everyone being ready and the game starting
const STICK_ON := 0.6
const STICK_OFF := 0.35

@export var modes: Array[ModeInfo] = [] # the games, in the order they cycle; the first is the default
@export var bot_levels: Array[BotLevel] = [] # the order a CPU's level cycles through
@export var default_level := 3 # index into bot_levels for new CPUs
@export_file("*.tscn") var main_menu_path := "res://ui/menus/main_menu.tscn"

var info: ModeInfo
var row := 0 # the top row being changed: 0 = the game, 1.. = info.options
var seats: Array = [] # one per card: a PlayerSlot, or null for an empty seat
var players := {} # device -> {seat: card index, hand: card index, ready: bool}
var _keyboard_order: Array[String] = [] # keyboard devices in the order they joined (ESC leaves the last)
var _stick := {} # "pad:axis" -> -1, 0 or 1, so a held stick moves once
var _start_in := -1.0
var _message := "" # a short note in the status line (e.g. "All seats are taken")

@onready var cards: Array[Node] = %Cards.get_children()
@onready var status: Label = %Status
@onready var options_label: RichTextLabel = %Options


func _ready() -> void:
	info = Session.next_mode if Session.next_mode is ModeInfo else modes[0]
	seats.resize(cards.size())
	for i in cards.size():
		cards[i].seat = i + 1
	if not _restore():
		for i in info.default_slots:
			seats[i] = _new_bot(i)
	_fix_teams()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_changed()


func _process(delta: float) -> void:
	if _start_in > 0.0:
		_start_in -= delta
		if _start_in <= 0.0:
			_start()


func _input(event: InputEvent) -> void:
	var device := ""
	var action := ""
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: device = "keys_left"; action = "confirm"
			KEY_W: device = "keys_left"; action = "up"
			KEY_S: device = "keys_left"; action = "down"
			KEY_A: device = "keys_left"; action = "left"
			KEY_D: device = "keys_left"; action = "right"
			KEY_ENTER, KEY_KP_ENTER: device = "keys_right"; action = "confirm"
			KEY_UP: device = "keys_right"; action = "up"
			KEY_DOWN: device = "keys_right"; action = "down"
			KEY_LEFT: device = "keys_right"; action = "left"
			KEY_RIGHT: device = "keys_right"; action = "right"
			KEY_ESCAPE:
				device = _keyboard_order.back() if not _keyboard_order.is_empty() else "keys_left"
				action = "back"
			KEY_TAB: device = "keys_left"; action = "start"
			KEY_Q: device = "keys"; action = "prev"
			KEY_E: device = "keys"; action = "next"
			KEY_R: device = "keys"; action = "row"
	elif event is InputEventJoypadButton and event.pressed:
		device = "pad:%d" % event.device
		match event.button_index:
			JOY_BUTTON_A: action = "confirm"
			JOY_BUTTON_B: action = "back"
			JOY_BUTTON_START: action = "start"
			JOY_BUTTON_LEFT_SHOULDER: action = "prev"
			JOY_BUTTON_RIGHT_SHOULDER: action = "next"
			JOY_BUTTON_Y: action = "row"
			JOY_BUTTON_DPAD_UP: action = "up"
			JOY_BUTTON_DPAD_DOWN: action = "down"
			JOY_BUTTON_DPAD_LEFT: action = "left"
			JOY_BUTTON_DPAD_RIGHT: action = "right"
	elif event is InputEventJoypadMotion and event.axis <= JOY_AXIS_LEFT_Y:
		device = "pad:%d" % event.device
		action = _stick_action(event)
	if action != "":
		get_viewport().set_input_as_handled()
		_act(device, action)


## Turns stick motion into one move per push of the stick.
func _stick_action(event: InputEventJoypadMotion) -> String:
	var key := "%d:%d" % [event.device, event.axis]
	var was: int = _stick.get(key, 0)
	var now := was
	if absf(event.axis_value) >= STICK_ON:
		now = 1 if event.axis_value > 0.0 else -1
	elif absf(event.axis_value) <= STICK_OFF:
		now = 0
	_stick[key] = now
	if now == 0 or now == was:
		return ""
	if event.axis == JOY_AXIS_LEFT_X:
		return "right" if now > 0 else "left"
	return "down" if now > 0 else "up"


func _act(device: String, action: String) -> void:
	_message = ""
	if action == "start":
		_start()
		return
	if not players.has(device):
		# Not joined: the arrows change the game and its options.
		action = {"left": "prev", "right": "next", "up": "row_up", "down": "row"}.get(action, action)
	match action:
		"prev", "next":
			_change_row(-1 if action == "prev" else 1)
			_changed()
			return
		"row", "row_up":
			row = posmod(row + (-1 if action == "row_up" else 1), info.options.size() + 1)
			_changed()
			return
	if not players.has(device):
		if action == "confirm":
			_join(device)
		elif action == "back":
			get_tree().change_scene_to_file(main_menu_path)
			return
		_changed()
		return
	var p: Dictionary = players[device]
	var own: int = p.seat
	var at: PlayerSlot = seats[p.hand]
	var on_cpu := at != null and not at.human
	match action:
		"left", "right":
			p.hand = posmod(p.hand + (1 if action == "right" else -1), info.max_slots)
		"up", "down":
			var step := -1 if action == "up" else 1
			if p.hand == own:
				_step_color(own, step)
				p.ready = false
			elif on_cpu:
				_step_level(p.hand, step)
		"confirm":
			if p.hand == own:
				p.ready = not p.ready
				Sfx.play("pop", 1.3 if p.ready else 0.9)
			elif at == null:
				seats[p.hand] = _new_bot(p.hand)
			elif on_cpu:
				_swap(device, p.hand)
		"back":
			if p.hand == own:
				if p.ready:
					p.ready = false
				else:
					_leave(device)
			elif on_cpu and _can_close(p.hand):
				seats[p.hand] = null
			else:
				p.hand = own
	_changed()


func _join(device: String) -> void:
	var humans := 0
	for s: PlayerSlot in seats:
		if s != null and s.human:
			humans += 1
	if humans >= info.max_humans:
		_message = "This mode takes %d player%s" % [info.max_humans, "" if info.max_humans == 1 else "s"]
		return
	var target := _first_seat(func(s: PlayerSlot) -> bool: return s != null and not s.human) # a CPU's seat
	if target < 0:
		target = _first_seat(func(s: PlayerSlot) -> bool: return s == null) # else an empty one
	if target < 0:
		_message = "All seats are taken"
		return
	var pad := int(device.get_slice(":", 1)) if device.begins_with("pad:") else -1
	var keys: InputProfile = PlayerSlot.PAD_ONLY
	if device == "keys_left":
		keys = PlayerSlot.KEYS_LEFT
	elif device == "keys_right":
		keys = PlayerSlot.KEYS_RIGHT
	var slot := PlayerSlot.make_human(target + 1, keys, pad)
	slot.device = device
	slot.color_index = seats[target].color_index if seats[target] != null else 0
	if _color_taken(slot.color_index, target):
		_step_color_of(slot, target, 1)
	seats[target] = slot
	players[device] = {seat = target, hand = target, ready = false}
	if device.begins_with("keys"):
		_keyboard_order.append(device)
	Sfx.play("pop", 1.1)


## The player on `device` moves to the CPU's seat `seat`, the CPU to theirs.
func _swap(device: String, seat: int) -> void:
	var p: Dictionary = players[device]
	var me: PlayerSlot = seats[p.seat]
	var cpu: PlayerSlot = seats[seat]
	seats[seat] = me
	seats[p.seat] = cpu
	cpu.number = p.seat + 1
	me.number = seat + 1
	p.seat = seat
	p.ready = false
	Sfx.play("pop", 1.0)


## A seat can close if enough stay open and, in a team mode, its team keeps someone.
func _can_close(seat: int) -> bool:
	if _open_count() <= info.min_slots:
		return false
	var team := info.team_of(seat)
	if team < 0:
		return true
	for i in info.max_slots:
		if i != seat and seats[i] != null and info.team_of(i) == team:
			return true
	return false


## In a team mode, a CPU for any team that has nobody.
func _fix_teams() -> void:
	for team in info.teams.size():
		var free := -1
		var has_one := false
		for i in info.max_slots:
			if info.team_of(i) != team:
				continue
			if seats[i] != null:
				has_one = true
			elif free < 0:
				free = i
		if not has_one and free >= 0:
			seats[free] = _new_bot(free)


## Change the picked top row: the game, or one of its options.
func _change_row(step: int) -> void:
	if row == 0:
		if modes.size() > 1:
			var i := modes.find(info)
			_set_mode(modes[posmod(i + step, modes.size())])
			Sfx.play("pop", 1.0)
		return
	var key := info.options[row - 1]
	var choices: Array = GameSettings.option(key).get("choices", [])
	var ids := choices.map(func(c: Array) -> String: return c[0])
	var i := ids.find(GameSettings.choice(key))
	GameSettings.set_choice(key, ids[posmod(i + step, ids.size())])
	Sfx.play("pop", 1.2)


## Switch to another game. Players keep their seats where the new one has
## them (or move to a free one); CPUs fill seats up to its usual count.
func _set_mode(next: ModeInfo) -> void:
	info = next
	Session.next_mode = info
	row = 0
	var old := seats.duplicate()
	seats.fill(null)
	# Players whose seat the new game has stay put; the others take free seats.
	var movers: Array[String] = []
	for d: String in players.keys():
		var p: Dictionary = players[d]
		if p.seat < info.max_slots:
			seats[p.seat] = old[p.seat]
		else:
			movers.append(d)
	for d in movers:
		var p: Dictionary = players[d]
		var target := _first_seat(func(x: PlayerSlot) -> bool: return x == null)
		if target < 0:
			players.erase(d)
			_keyboard_order.erase(d)
			continue
		seats[target] = old[p.seat]
		p.seat = target
	# More players than the new game takes: the last ones to sit leave.
	var humans: Array[String] = []
	humans.assign(players.keys())
	humans.sort_custom(func(a: String, b: String) -> bool: return players[a].seat < players[b].seat)
	for j in range(info.max_humans, humans.size()):
		seats[players[humans[j]].seat] = null
		players.erase(humans[j])
		_keyboard_order.erase(humans[j])
	for d: String in players:
		var p: Dictionary = players[d]
		seats[p.seat].number = p.seat + 1
		p.hand = p.seat
		p.ready = false
	var want := maxi(info.default_slots, info.min_slots)
	for i in info.max_slots:
		if seats[i] == null and _open_count() < want:
			var cpu: PlayerSlot = old[i]
			seats[i] = cpu if cpu != null and not cpu.human else _new_bot(i)
	_fix_teams()


func _first_seat(test: Callable) -> int:
	for i in info.max_slots:
		if test.call(seats[i]):
			return i
	return -1


func _leave(device: String) -> void:
	var seat: int = players[device].seat
	seats[seat] = _new_bot(seat)
	players.erase(device)
	_keyboard_order.erase(device)
	Sfx.play("pop", 0.7)


func _new_bot(seat: int) -> PlayerSlot:
	return PlayerSlot.make_bot(seat + 1, bot_levels[default_level] if default_level < bot_levels.size() else PlayerSlot.NORMAL)


func _open_count() -> int:
	var n := 0
	for s in seats:
		if s != null:
			n += 1
	return n


## True if another player (not the one in `seat`) already has colour `index`.
func _color_taken(index: int, seat: int) -> bool:
	for i in seats.size():
		var s: PlayerSlot = seats[i]
		if i != seat and s != null and s.human and s.color_index == index:
			return true
	return false


func _step_color(seat: int, step: int) -> void:
	var slot: PlayerSlot = seats[seat]
	if slot.team_color and info.team_of(seat) >= 0:
		slot.team_color = false # first press in a team mode: leave the team colour
		if not _color_taken(slot.color_index, seat):
			return
	_step_color_of(slot, seat, step)


func _step_color_of(slot: PlayerSlot, seat: int, step: int) -> void:
	var count := GameTheme.current().palette().size()
	for _i in count:
		slot.color_index = posmod(slot.color_index + step, count)
		if not _color_taken(slot.color_index, seat):
			return


func _step_level(seat: int, step: int) -> void:
	var slot: PlayerSlot = seats[seat]
	var i := bot_levels.find(slot.bot_level)
	slot.bot_level = bot_levels[posmod(i + step, bot_levels.size())]


## After any change: bots' colours, the cards, the status line, and the start
## countdown once everyone is ready.
func _changed() -> void:
	var open: Array = seats.filter(func(s): return s != null)
	PlayerSlot.recolor_bots(open)
	var all_ready := not players.is_empty()
	for d in players:
		all_ready = all_ready and players[d].ready
	if all_ready and _start_in <= 0.0:
		_start_in = READY_DELAY
	elif not all_ready:
		_start_in = -1.0
	_refresh_top()
	_refresh_cards()
	_refresh_status(all_ready)


func _refresh_cards() -> void:
	var theme := GameTheme.current()
	for i in cards.size():
		var card: LobbyCard = cards[i]
		card.visible = i < info.max_slots
		card.slot = seats[i]
		card.player_ready = false
		card.hint = ""
		card.hands = []
		var team := info.team_of(i)
		card.team_name = info.teams[team] if team >= 0 else ""
		card.team_color = theme.team_color(team) if team >= 0 else Color.WHITE
		if seats[i] != null:
			card.color = seats[i].color_in(info)
	for d: String in players:
		var p: Dictionary = players[d]
		var own: PlayerSlot = seats[p.seat]
		var card: LobbyCard = cards[p.hand]
		card.hands.append(["P%d" % own.number, own.color_in(info)])
		if card.hint == "":
			card.hint = _hint_for(d, p)
		cards[p.seat].player_ready = p.ready
	for c in cards:
		c.queue_redraw()


## What the player using `device` can do where their hand is.
func _hint_for(device: String, p: Dictionary) -> String:
	var k := _key_names(device)
	var at: PlayerSlot = seats[p.hand]
	if p.hand == p.seat:
		return "%s: colour\n%s: %s   %s: leave" % [k.ud, k.ok, "not ready" if p.ready else "ready", k.back]
	if at == null:
		return "%s: add a CPU" % k.ok
	if not at.human:
		var close := "   %s: remove" % k.back if _can_close(p.hand) else ""
		return "%s: level\n%s: sit here%s" % [k.ud, k.ok, close]
	return ""


func _key_names(device: String) -> Dictionary:
	match device:
		"keys_left":
			return {ok = "SPACE", back = "ESC", ud = "W/S"}
		"keys_right":
			return {ok = "ENTER", back = "ESC", ud = "UP/DOWN"}
	return {ok = "A", back = "B", ud = "UP/DOWN"}


## The game's name, its line, and its options, with the picked row lit.
func _refresh_top() -> void:
	%Title.text = "<   %s   >" % info.title if modes.size() > 1 else info.title
	%Title.modulate.a = 1.0 if row == 0 else 0.55
	var players_text := "%d players" % info.min_slots if info.min_slots == info.max_slots \
		else "%d to %d players" % [info.min_slots, info.max_slots]
	%Subtitle.text = "%s     %s" % [info.subtitle, players_text]
	var lines: Array[String] = []
	for i in info.options.size():
		var key := info.options[i]
		var o := GameSettings.option(key)
		var text := "%s    <  %s  >" % [o.get("label", key), GameSettings.choice_label(key)]
		lines.append("[color=%s]%s[/color]" % ["#ffe066" if row == i + 1 else "#7c82a8", text])
	if row > 0:
		var key := info.options[row - 1]
		for c: Array in GameSettings.option(key).get("choices", []):
			if c[0] == GameSettings.choice(key):
				lines.append("[font_size=17][color=#9aa0c8]%s[/color][/font_size]" % c[2])
	options_label.text = "[center]%s[/center]" % "\n".join(lines)


func _refresh_status(all_ready: bool) -> void:
	var lines: Array[String] = []
	var rows := "   ·   Options:  UP / DOWN" if not info.options.is_empty() else ""
	if _message != "":
		lines.append(_message)
	if all_ready:
		lines.append("READY!")
	elif players.is_empty():
		lines.append("Game:  LEFT / RIGHT%s" % rows)
		lines.append("Join:  A on a controller   ·   SPACE  (WASD keys)   ·   ENTER  (arrow keys)")
		lines.append("START / TAB:  let the computers play      B / ESC:  back")
	else:
		var top := "Game and options:  LB / RB  or  Q / E,   Y  or  R  next row" if not info.options.is_empty() \
			else "Game:  LB / RB  or  Q / E"
		lines.append("More players:  A   ·   SPACE   ·   ENTER        Move your hand:  left / right")
		lines.append(top)
		lines.append("Everyone ready on their own card to start      START / TAB:  start now")
	status.text = "\n".join(lines)


func _start() -> void:
	var lineup: Array = []
	var keyboards := _keyboard_order.size()
	for s: PlayerSlot in seats:
		if s == null:
			continue
		if s.human and s.device.begins_with("keys"):
			# One keyboard player gets every key; two split it into WASD and arrows.
			if keyboards == 1:
				s.profile = PlayerSlot.KEYS_ALL
			else:
				s.profile = PlayerSlot.KEYS_LEFT if s.device == "keys_left" else PlayerSlot.KEYS_RIGHT
		lineup.append(s)
	Session.lineup = lineup
	Session.lineup_mode = info.resource_path
	get_tree().change_scene_to_file(info.scene)


## Back from a game: the same seats, and the same players if their device is still here.
func _restore() -> bool:
	if Session.lineup.is_empty() or Session.lineup_mode != info.resource_path:
		return false
	var pads := Input.get_connected_joypads()
	for s: PlayerSlot in Session.lineup:
		var i := s.number - 1
		if i < 0 or i >= info.max_slots:
			continue
		var here := s.device.begins_with("keys") or (s.pad_device >= 0 and pads.has(s.pad_device))
		if s.human and (s.device == "" or not here):
			seats[i] = _new_bot(i)
			continue
		seats[i] = s
		if s.human:
			players[s.device] = {seat = i, hand = i, ready = false}
			if s.device.begins_with("keys"):
				_keyboard_order.append(s.device)
	return true


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	var key := "pad:%d" % device
	if not connected and players.has(key):
		_leave(key)
		_changed()
