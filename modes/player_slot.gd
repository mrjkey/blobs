class_name PlayerSlot
extends Resource
## One seat in a game's lineup: a human on the keyboard and/or a gamepad, or a
## computer at some BotLevel, with its colour and, in a team mode, its team. The lobby builds the lineup
## (Session.lineup); a mode started on its own uses default_lineup(). GameMode
## turns each slot into a blob with a PlayerInput or a BotBrain.

const KEYS_ALL := preload("res://entities/controllers/profiles/solo.tres")
const KEYS_LEFT := preload("res://entities/controllers/profiles/p1.tres")
const KEYS_RIGHT := preload("res://entities/controllers/profiles/p2.tres")
const PAD_ONLY := preload("res://entities/controllers/profiles/pad.tres")
const NORMAL := preload("res://entities/controllers/levels/normal.tres")

@export var number := 1 # the seat, 1..4: P1..P4
@export var human := false
@export var color_index := 0 # into GameTheme.palette(); not used in a team mode
## In a team mode, the team (0, 1): players pick theirs in the lobby, which
## spreads the computers to even the teams out. -1 = from the seat (ModeInfo.team_of).
@export var team := -1
@export var team_second := false # with `team` set: the team's second member, in the team's second colour
@export var peer := 1 # the computer this seat's player is on, online (Net peer id); 1 = the host, or this one offline

@export_group("Human")
@export var profile: InputProfile = KEYS_ALL # keys and gamepad buttons
@export var pad_device := -1 # the gamepad it plays with (device id), -1 = none
@export var any_pad := false # also the first gamepad, whichever it is (when one player is all there is)
@export var device := "" # what joined in the lobby: "keys_left", "keys_right" or "pad:<id>"

@export_group("Computer")
@export var bot_level: BotLevel = NORMAL


static func make_bot(seat: int, level: BotLevel = NORMAL) -> PlayerSlot:
	var s := PlayerSlot.new()
	s.number = seat
	s.bot_level = level
	return s


static func make_human(seat: int, keys: InputProfile, pad := -1) -> PlayerSlot:
	var s := PlayerSlot.new()
	s.number = seat
	s.human = true
	s.profile = keys
	s.pad_device = pad
	return s


## The lineup for a mode started on its own, with no lobby: P1 on the
## keyboard, each connected gamepad takes the next seat (as many as the mode
## allows humans), computers fill the rest (unless the mode has no `bots`).
## With only one human seat, P1 plays with the keyboard and the first gamepad.
static func default_lineup(info: ModeInfo) -> Array[PlayerSlot]:
	var count := info.default_slots if info != null else 2
	var max_humans := mini(info.max_humans if info != null else ModeInfo.MAX_SLOTS, count)
	var out: Array[PlayerSlot] = []
	var p1 := make_human(1, KEYS_ALL)
	p1.any_pad = max_humans == 1
	out.append(p1)
	if not p1.any_pad:
		for id in Input.get_connected_joypads():
			if out.size() >= max_humans:
				break
			var p := make_human(out.size() + 1, PAD_ONLY, id)
			p.color_index = out.size()
			out.append(p)
	while out.size() < count and (info == null or info.bots):
		out.append(make_bot(out.size() + 1))
	recolor_bots(out)
	return out


## Gives the computers the first palette colours no human has.
static func recolor_bots(slots: Array) -> void:
	var taken := {}
	for s: PlayerSlot in slots:
		if s.human:
			taken[s.color_index] = true
	var next := 0
	var colors := GameTheme.current().palette().size()
	for s: PlayerSlot in slots:
		if s.human:
			continue
		while taken.has(next) and next < colors:
			next += 1
		s.color_index = next % colors
		taken[next] = true


## This seat as plain data, for the network (the lobby's copies on the other computers).
func to_net() -> Dictionary:
	return {number = number, human = human, color = color_index, team = team, second = team_second,
		device = device, peer = peer, pad = pad_device, bot = bot_level.display_name if bot_level != null else ""}


## A seat from to_net(). A computer's level is looked up by name in `levels` (BotLevels).
static func from_net(d: Dictionary, levels: Array) -> PlayerSlot:
	var s := PlayerSlot.new()
	s.number = clampi(int(d.get("number", 1)), 1, ModeInfo.MAX_SLOTS)
	s.human = bool(d.get("human", false))
	s.color_index = int(d.get("color", 0))
	s.team = int(d.get("team", -1))
	s.team_second = bool(d.get("second", false))
	s.device = str(d.get("device", ""))
	s.peer = int(d.get("peer", 1))
	s.pad_device = int(d.get("pad", -1))
	for level: BotLevel in levels:
		if level.display_name == str(d.get("bot", "")):
			s.bot_level = level
	return s


## The team this slot plays for in mode `info` (team_in), -1 without teams.
func team_in(info: ModeInfo) -> int:
	if info == null or info.teams.is_empty():
		return -1
	return team if team >= 0 else info.team_of(number - 1)


## The colour this slot plays in, in mode `info`: its team's colour in a team
## mode (the second colour for a team's second member), else its palette colour.
func color_in(info: ModeInfo) -> Color:
	var theme := GameTheme.current()
	var t := team_in(info)
	if t >= 0:
		return theme.team_member_color(t, team_second if team >= 0 else number > 2)
	return theme.palette_color(color_index)


## The keys that go with what joined in the lobby (`device`): all of them, one half, or none (a gamepad).
func fit_profile() -> void:
	match device:
		"keys":
			profile = KEYS_ALL
		"keys_left":
			profile = KEYS_LEFT
		"keys_right":
			profile = KEYS_RIGHT
		_:
			profile = PAD_ONLY


## Who this is in a menu: "KEYBOARD  WASD", "CONTROLLER 2", "CPU  NORMAL".
func describe() -> String:
	if not human:
		return "CPU  " + bot_level.display_name
	if pad_device >= 0:
		if peer != Net.my_id():
			return "CONTROLLER" # on another computer: its number there isn't known here
		var n := Input.get_connected_joypads().find(pad_device) + 1
		return "CONTROLLER %d" % n if n > 0 else "CONTROLLER"
	match device:
		"keys":
			return "KEYBOARD"
		"keys_left":
			return "KEYBOARD  WASD"
		"keys_right":
			return "KEYBOARD  ARROWS"
	return "KEYBOARD" + ("  +  CONTROLLER" if any_pad else "")
