class_name RemoteInput
extends PlayerInput
## Online, on the host: steers the blob of a player on another computer.
## GameMode gives a seat this instead of reading keys when the seat's player
## isn't on this computer (PlayerSlot.peer). NetGame feeds it what that
## computer sends: where its player steers, and how many times each button
## (PlayerInput.ACTIONS) has been pressed so far. A press is a count going up,
## so a lost packet never loses one. Anything that reads a PlayerInput (the
## blob, Don't Get Fat!'s upgrade cards) reads this the same way.

const MENU_BUTTONS := {"menu_ok": "push", "menu_alt": "dash"} # PlayerInput's menu reads -> the button behind them

var seat := 0 # the PlayerSlot.number it plays
var peer := 0 # the computer its player is on

var _steer := Vector2.ZERO
var _counts := {} # button -> presses so far, on the player's computer
var _seen := {} # what was asked (a button, or a menu read) -> the count it last saw
var _seq := -1 # the newest input taken


static func of(slot: PlayerSlot) -> RemoteInput:
	var input := RemoteInput.new()
	input.seat = slot.number
	input.peer = slot.peer
	return input


func _enter_tree() -> void:
	add_to_group("remote_inputs")


## The player's computer says: input number `seq`, steering `move`, `counts` presses so far per ACTIONS button.
func feed(seq: int, move: Vector2, counts: Variant) -> void:
	if seq <= _seq:
		return # older than one already taken (unreliable messages can swap places)
	_seq = seq
	_steer = move.limit_length(1.0)
	if counts is PackedInt32Array or counts is Array:
		for i in mini(counts.size(), ACTIONS.size()):
			_counts[ACTIONS[i]] = int(counts[i])


## Its computer left: let go of everything.
func release() -> void:
	_steer = Vector2.ZERO


func _menu_open() -> bool:
	return false # the host's menu isn't this player's


func _move() -> Vector2:
	return _steer


func _just_pressed(action: String, _keys: Array[Key], _buttons: Array[JoyButton]) -> bool:
	var n: int = _counts.get(MENU_BUTTONS.get(action, action), 0)
	var pressed: bool = _seen.has(action) and n > _seen[action]
	_seen[action] = n
	return pressed
