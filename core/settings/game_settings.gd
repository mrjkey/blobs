class_name GameSettings
extends RefCounted
## The gameplay options players can change: the dash, energy, the energy bar.
## The main menu's SETTINGS screen lists them; the sandbox lab (Tab) lists
## them plus the sandbox-only ones. Picks are saved in Session.settings, and
## everything reads them through here, so a change applies at once, mid-game too.
##
## To add an option: an entry in OPTIONS (`sandbox = true` to show it only in
## the lab), then read it with choice("key") where it's used, or in _sync()
## if it's a MoveRules field.

const OPTIONS := [
	{key = "dash", label = "DASH", default_id = "ghost", choices = [
		["ghost", "GHOST", "A quick ethereal burst. Passes through blobs, pushes and lasers."],
		["bump", "BUMP", "A quick solid burst. Rams whatever is in the way and stuns the blob it hits."],
		["off", "OFF", "No dash."],
	]},
	{key = "ghost_through", label = "GHOST PASSES", default_id = "obstacles", choices = [
		["obstacles", "BLOBS + OBSTACLES", "A ghost dash also passes through walls and bumpers (never the arena's own walls)."],
		["blobs", "BLOBS", "A ghost dash passes through blobs, pushes and lasers, but not walls or bumpers."],
	]},
	{key = "energy", label = "ENERGY", default_id = "all", choices = [
		["all", "DASH + PUSH", "Dash and push each cost a segment of the bar. The push keeps only a short cooldown."],
		["dash", "DASH ONLY", "The dash costs a segment, the push keeps its normal cooldown."],
		["off", "OFF", "No bar: the push and the dash each have their own cooldown."],
	]},
	{key = "meter", label = "BAR", default_id = "above", choices = [
		["above", "ABOVE BLOB", "Pips over the blob's head."],
		["below", "BELOW BLOB", "Pips under the blob."],
		["ring", "RING", "Arcs around the blob, outside the push-cooldown ring."],
		["corners", "HUD CORNERS", "Big bars in the screen corners: P1 left, P2 right."],
		["top", "HUD TOP", "Big bars at the top centre of the screen."],
		["bottom", "HUD BOTTOM", "Big bars at the bottom centre of the screen."],
	]},
	{key = "meter_bots", label = "BAR ON BOTS", default_id = "yes", choices = [
		["yes", "YES", "Bots show their bar too (above, below and ring only)."],
		["no", "NO", "Only players show a bar."],
	]},
	{key = "bots_dash", label = "BOTS DASH", default_id = "yes", choices = [
		["yes", "YES", "Bots dodge-dash out of pushes, ram with a bump dash, phase through with a ghost dash."],
		["no", "NO", "Bots never dash."],
	]},
	{key = "props", label = "PROPS", default_id = "walls", sandbox = true, choices = [
		["walls", "WALLS + BUMPERS", "A wall, a kicker wall and two bumpers to dash into (or through)."],
		["none", "EMPTY ROOM", "Just the room."],
	]},
]

static var _rules: MoveRules


## The chosen id for option `key` (its default until the player picks one).
static func choice(key: String) -> String:
	var o := option(key)
	if o.is_empty():
		return ""
	return Session.settings.get(key, o.default_id)


## The on-screen name of the chosen value for option `key`.
static func choice_label(key: String) -> String:
	var id := choice(key)
	for c: Array in option(key).get("choices", []):
		if c[0] == id:
			return c[1]
	return id


static func option(key: String) -> Dictionary:
	for o: Dictionary in OPTIONS:
		if o.key == key:
			return o
	return {}


## Pick `id` for option `key`, save it, and apply it.
static func set_choice(key: String, id: String) -> void:
	Session.set_setting(key, id)
	if _rules != null:
		_sync()


## The MoveRules the settings describe. One shared instance: every blob uses
## it (Blob.rules), so a change in a menu reaches them all at once.
static func rules() -> MoveRules:
	if _rules == null:
		_rules = MoveRules.new()
		_sync()
	return _rules


static func _sync() -> void:
	_rules.dash = {"bump": MoveRules.Dash.BUMP, "ghost": MoveRules.Dash.GHOST}.get(choice("dash"), MoveRules.Dash.NONE)
	_rules.ghost_obstacles = choice("ghost_through") == "obstacles"
	_rules.energy = {"all": MoveRules.Energy.ALL, "dash": MoveRules.Energy.DASH}.get(choice("energy"), MoveRules.Energy.OFF)
	_rules.bots_dash = choice("bots_dash") == "yes"
