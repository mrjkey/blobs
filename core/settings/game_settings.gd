class_name GameSettings
extends RefCounted
## The options players can change: the look (theme, glow) and the gameplay
## (the dash, the slash, spit and shield, energy, the energy bar, mass loss,
## food, and the treadmill's view and speeds). The main menu's SETTINGS screen and the
## sandbox lab (Tab) list them. Gameplay picks are saved in Session.settings,
## the look in Session.theme_name / Session.glow; everything reads them
## through here, so a change applies at once, mid-game too.
##
## To add an option: an entry in OPTIONS, then read it with choice("key")
## where it's used, or in _sync() if it's a MoveRules field. `only = "lab"`
## shows it only in the sandbox lab, `only = "menu"` only on the SETTINGS screen,
## `only = "lobby"` only in the lobby, for the modes that list it in
## ModeInfo.options (match rules like football's time and goals, the
## treadmill's rules), plus CPU LEVEL for every mode with computers.
## `group` puts a heading over the SETTINGS rows that share it.
##
## In someone else's online game the host's choices decide the game's rules
## (use_host_settings()): every option except the menu's and lab's own and
## those marked `local` (how things look on this screen, like the energy bar).

const OPTIONS := [
	{key = "theme", label = "THEME", default_id = "neon", only = "menu", group = "LOOK", choices = [
		["neon", "NEON", "Glowing colours on a dark grid that pulses with the music."],
		["classic", "CLASSIC", "Plain, solid colours with drop shadows."],
	]},
	{key = "glow", label = "GLOW", default_id = "off", only = "menu", group = "LOOK", choices = [
		["off", "OFF", "No bloom. Scenes load quickly."],
		["on", "ON", "Bloom on glowing themes (neon). The first game with it loads slowly while shaders compile."],
	]},
	{key = "dash", label = "DASH", default_id = "ghost", group = "MOVES", choices = [
		["ghost", "GHOST", "A quick ethereal burst. Passes through blobs, pushes and lasers."],
		["bump", "BUMP", "A quick solid burst. Rams whatever is in the way and stuns the blob it hits."],
		["off", "OFF", "No dash."],
	]},
	{key = "ghost_through", label = "GHOST PASSES", default_id = "obstacles", group = "MOVES", choices = [
		["obstacles", "BLOBS + OBSTACLES", "A ghost dash also passes through walls and bumpers (never the arena's own walls)."],
		["blobs", "BLOBS", "A ghost dash passes through blobs, pushes and lasers, but not walls or bumpers."],
	]},
	{key = "energy", label = "ENERGY", default_id = "all", group = "MOVES", choices = [
		["all", "ALL MOVES", "Every move costs energy: two segments for a push, one for the dash and shield, half one for a slash or spit. Only short cooldowns."],
		["dash", "DASH ONLY", "The dash costs a segment, the other moves keep their normal cooldowns."],
		["off", "OFF", "No bar: every move has its own cooldown."],
	]},
	{key = "slash", label = "SLASH", default_id = "on", group = "MOVES", choices = [
		["on", "ON", "A quick blade swing the way you face. Short reach, no windup, knocks back whoever it cuts."],
		["off", "OFF", "No slash."],
	]},
	{key = "spit", label = "SPIT", default_id = "on", group = "MOVES", choices = [
		["on", "ON", "A glob fired the way you face. Flies far and slimes the first blob it hits: knocked back, slippery for a moment, and drained of energy (never the last segment)."],
		["off", "OFF", "No spit."],
	]},
	{key = "shield", label = "SHIELD", default_id = "on", group = "MOVES", choices = [
		["on", "ON", "A short bubble that slows you down. Blocks pushes and slashes; spit that touches it flies back at whoever fired it."],
		["off", "OFF", "No shield."],
	]},
	{key = "shrink", label = "SHRINKING", default_id = "normal", only = "lobby", choices = [
		["normal", "NORMAL", "In the treadmill, blobs slowly lose mass all the time: keep eating. Too small and they pop."],
		["slow", "SLOW", "Blobs lose mass slowly. Food is a nice extra."],
		["fast", "FAST", "Blobs lose mass fast. Always be hunting food."],
		["off", "OFF", "Blobs only lose mass by spitting and getting lasered."],
	]},
	{key = "spit_mass", label = "SPIT COST", default_id = "normal", only = "lobby", choices = [
		["normal", "NORMAL", "In the treadmill, each spit costs a little mass: a way to slim down and squeeze through gaps."],
		["small", "SMALL", "Each spit costs a tiny bit of mass."],
		["big", "BIG", "Each spit costs a lot of mass."],
		["off", "OFF", "Spitting is free."],
	]},
	{key = "laser_mass", label = "LASER BURN", default_id = "normal", only = "lobby", choices = [
		["normal", "NORMAL", "In the treadmill, a laser hit stuns you and burns off some mass."],
		["small", "SMALL", "A laser hit stuns you and burns off a little mass."],
		["big", "BIG", "A laser hit stuns you and burns off a lot of mass."],
		["off", "OFF", "A laser hit only stuns you."],
	]},
	{key = "food", label = "FOOD", default_id = "normal", only = "lobby", choices = [
		["normal", "NORMAL", "How much food the treadmill lays out: enough to keep up if you go looking."],
		["less", "LESS", "Scarce food: blobs fight over every pellet."],
		["more", "MORE", "Plenty of food: easy to grow big (and get stuck)."],
	]},
	{key = "track_view", label = "TRACK VIEW", default_id = "normal", only = "lobby", choices = [
		["normal", "NORMAL", "The treadmill always shows the whole belt between the kill lasers. A medium belt."],
		["near", "CLOSE", "A shorter belt, seen up close: less room to run, bigger blobs."],
		["far", "FAR", "A tall belt, seen from further away: lots of room, smaller blobs."],
	]},
	{key = "track_speed", label = "TRACK SPEED", default_id = "normal", only = "lobby", choices = [
		["normal", "NORMAL", "How fast the treadmill's belt climbs. It speeds up as the round goes on."],
		["slow", "SLOW", "A relaxed climb."],
		["fast", "FAST", "A hurried climb: keep moving."],
	]},
	{key = "blob_speed", label = "BLOB SPEED", default_id = "normal", only = "lobby", choices = [
		["normal", "NORMAL", "How fast blobs run in the treadmill: a little quicker than in the other modes."],
		["slow", "SLOW", "The same speed as in the other modes."],
		["fast", "FAST", "Quick blobs: dodging is easy, stopping isn't."],
	]},
	{key = "meter", label = "BAR", default_id = "above", group = "ENERGY BAR", local = true, choices = [
		["above", "ABOVE BLOB", "Pips over the blob's head."],
		["below", "BELOW BLOB", "Pips under the blob."],
		["ring", "RING", "Arcs around the blob, outside the push-cooldown ring."],
		["corners", "HUD CORNERS", "Big bars in the screen corners: P1 left, P2 right."],
		["top", "HUD TOP", "Big bars at the top centre of the screen."],
		["bottom", "HUD BOTTOM", "Big bars at the bottom centre of the screen."],
	]},
	{key = "meter_bots", label = "BAR ON BOTS", default_id = "yes", group = "ENERGY BAR", local = true, choices = [
		["yes", "YES", "Bots show their bar too (above, below and ring only)."],
		["no", "NO", "Only players show a bar."],
	]},
	{key = "bots_dash", label = "BOTS DASH", default_id = "yes", group = "COMPUTERS", choices = [
		["yes", "YES", "Bots dodge-dash out of pushes, ram with a bump dash, phase through with a ghost dash."],
		["no", "NO", "Bots never dash."],
	]},
	{key = "football_time", label = "TIME", default_id = "5", only = "lobby", choices = [
		["5", "5 MIN", "The team ahead after 5 minutes wins. A draw goes to a golden goal."],
		["3", "3 MIN", "The team ahead after 3 minutes wins. A draw goes to a golden goal."],
		["10", "10 MIN", "The team ahead after 10 minutes wins. A draw goes to a golden goal."],
		["0", "NO LIMIT", "No clock: play to the goal count (or forever, if that's off too)."],
	]},
	{key = "football_goals", label = "GOALS", default_id = "5", only = "lobby", choices = [
		["5", "FIRST TO 5", "The first team to score 5 wins, even before the time is up."],
		["3", "FIRST TO 3", "The first team to score 3 wins, even before the time is up."],
		["7", "FIRST TO 7", "The first team to score 7 wins, even before the time is up."],
		["10", "FIRST TO 10", "The first team to score 10 wins, even before the time is up."],
		["0", "NO LIMIT", "No goal count: the clock decides."],
	]},
	{key = "track_map", label = "TRACK", default_id = "generated", only = "lobby", choices = [
		["generated", "ENDLESS", "A new random track every run, for as long as you last."],
		["course_1", "COURSE 1", "A hand-made course with a finish line: the first blob across wins."],
	]},
	{key = "fat_level", label = "LEVEL", default_id = "run", only = "lobby", choices = [
		["run", "THE RUN", "Levels 1 to 5 in a row. Stars earn upgrade picks between levels; fail a level and the run is over."],
		["fat_0", "WARM-UP", "Level 0: learn the ropes. Catch food, dodge treats, land in the window."],
		["fat_1", "LEVEL 1", "Breakfast: the plate. Fill all three thirds, dodge the walls, stop in the window."],
		["fat_2", "LEVEL 2", "Lunch rush: walls split the belt into lanes. Pick the right one."],
		["fat_3", "LEVEL 3", "Snack attack: power-up bubbles, good and bad."],
		["fat_4", "LEVEL 4", "Dinner: pairs of walls that slide together and close in."],
		["fat_5", "LEVEL 5", "Dessert: the belt surges in rush sections."],
	]},
	{key = "cpu_level", label = "CPU LEVEL", default_id = "normal", only = "lobby", choices = [
		["idle", "IDLE", "Computers stand still: training dummies."],
		["passive", "PASSIVE", "Computers run around but never push."],
		["easy", "EASY", "Slow, forgiving computers that react late."],
		["normal", "NORMAL", "Computers that play properly: they push, dash and shield."],
		["aggressive", "AGGRESSIVE", "Computers that come for you, and react fast."],
	]},
	{key = "net_lag", label = "PRETEND LAG", default_id = "0", only = "menu", group = "NETWORK TEST", choices = [
		["0", "OFF", "Online games go as fast as the network allows."],
		["50", "50 MS", "Online, this copy holds every message back: 50 ms there and back, like a busy home network."],
		["100", "100 MS", "Online, this copy holds every message back: 100 ms there and back, like playing across a country."],
		["150", "150 MS", "Online, this copy holds every message back: 150 ms there and back."],
		["250", "250 MS", "Online, this copy holds every message back: 250 ms there and back, a bad connection."],
	]},
	{key = "net_jitter", label = "PRETEND JITTER", default_id = "0", only = "menu", group = "NETWORK TEST", choices = [
		["0", "OFF", "Every message takes the same time."],
		["10", "10 MS", "Messages take up to 10 ms longer, at random."],
		["30", "30 MS", "Messages take up to 30 ms longer, at random: Wi-Fi on a bad day."],
		["60", "60 MS", "Messages take up to 60 ms longer, at random."],
	]},
	{key = "net_loss", label = "PRETEND LOSS", default_id = "0", only = "menu", group = "NETWORK TEST", choices = [
		["0", "OFF", "No messages lost (beyond what the network loses)."],
		["2", "2%", "2% of the frequent updates get lost on the way, each way."],
		["5", "5%", "5% of the frequent updates get lost on the way, each way."],
		["15", "15%", "15% of the frequent updates get lost on the way, each way: a very bad connection."],
	]},
	{key = "props", label = "PROPS", default_id = "walls", only = "lab", choices = [
		["walls", "WALLS + BUMPERS", "A wall, a kicker wall and two bumpers to dash into (or through)."],
		["none", "EMPTY ROOM", "Just the room."],
	]},
]

static var _rules: MoveRules


## The chosen id for option `key` (its default until the player picks one).
static func choice(key: String) -> String:
	match key:
		"theme":
			return Session.theme_name
		"glow":
			return "on" if Session.glow else "off"
	var o := option(key)
	if o.is_empty():
		return ""
	if Session.host_settings.has(key):
		return Session.host_settings[key]
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


## The choices the host's copy sends to the others in an online game: the
## game's rules, option key -> id (see use_host_settings()).
static func shared_choices() -> Dictionary:
	var out := {}
	for o: Dictionary in OPTIONS:
		if _shared(o):
			out[o.key] = choice(o.key)
	return out


## In someone else's online game: play by the host's `choices` (from
## shared_choices()) instead of this player's own; {} goes back to them.
static func use_host_settings(choices: Dictionary) -> void:
	var kept := {}
	for key: Variant in choices:
		var o := option(str(key))
		if _shared(o) and o.choices.any(func(c: Array) -> bool: return c[0] == choices[key]):
			kept[o.key] = choices[key]
	Session.host_settings = kept
	if _rules != null:
		_sync()


## Whether option `o` is one the host decides in an online game.
static func _shared(o: Dictionary) -> bool:
	return not o.is_empty() and not o.get("only", "") in ["menu", "lab"] and not o.get("local", false)


## Pick `id` for option `key`, save it, and apply it.
static func set_choice(key: String, id: String) -> void:
	match key:
		"theme":
			Session.theme_name = id
			return
		"glow":
			Session.glow = id == "on"
			return
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
	_rules.slash = choice("slash") == "on"
	_rules.spit = choice("spit") == "on"
	_rules.shield = choice("shield") == "on"
	_rules.mass_decay = {"slow": 0.01, "normal": 0.02, "fast": 0.04}.get(choice("shrink"), 0.0)
	_rules.spit_mass = {"small": 0.04, "normal": 0.08, "big": 0.16}.get(choice("spit_mass"), 0.0)
	_rules.laser_mass = {"small": 0.1, "normal": 0.2, "big": 0.35}.get(choice("laser_mass"), 0.0)


## How much food levels lay out, as a multiplier (the FOOD setting).
static func food_amount() -> float:
	return {"less": 0.6, "more": 1.7}.get(choice("food"), 1.0)


## The treadmill map the lobby's TRACK option picked (a scene path), or "" to generate the track.
## A map with id `x` lives at res://level/maps/x/x.tscn.
static func track_map() -> String:
	var id := choice("track_map")
	return "" if id == "generated" or id == "" else "res://level/maps/%s/%s.tscn" % [id, id]


## The Don't Get Fat! level the lobby's LEVEL option picked (a map's scene path, like track_map()).
## THE RUN starts at level 1 (FatRun takes it from there).
static func fat_level() -> String:
	var id := choice("fat_level")
	if id == "run":
		id = "fat_1"
	return "res://level/maps/%s/%s.tscn" % [id, id]


## The treadmill's belt height, as a multiple of TrackSettings.belt_height (TRACK VIEW).
static func track_view() -> float:
	return {"near": 0.68, "far": 1.0}.get(choice("track_view"), 0.82)


## The treadmill's scroll speed, as a multiplier (TRACK SPEED).
static func track_speed() -> float:
	return {"slow": 0.75, "fast": 1.3}.get(choice("track_speed"), 1.0)


## Blobs' top speed and acceleration in the treadmill, as a multiplier (BLOB SPEED).
static func blob_speed() -> float:
	return {"slow": 1.0, "fast": 1.35}.get(choice("blob_speed"), 1.18)
