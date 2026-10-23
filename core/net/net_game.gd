class_name NetGame
extends Node
## Online, one per game (GameMode adds it): keeps the joined computers'
## copies of the game in step with the host's. The host runs the game as
## always. The others run none of it (every node's _physics_process is off
## there, except in group "net_local": things that only animate, like the
## neon grid) and show what the host sends:
##
## - What's in the game. A node with a net_state() method is an entity. Ones
##   from a scene file (the mode, the HUD, the ring's lasers) are known by
##   their path. Ones made during the game (blobs, slashes, spit, food) get a
##   number, and the others make their own copy from the same scene file,
##   where the host's is, with net_spawn() -> net_setup() for what the copy
##   needs (a blob's colour, a slash's aim). A joined computer frees any it
##   makes by itself (food a map lays out in _ready(), say).
## - How things are, every physics frame: each entity's net_state(), an
##   Array, unreliable; only what changed, and everything every REFRESH
##   frames (in case an update was lost). A busy frame goes in several
##   packets of up to PACKET_BYTES, so a lost one loses only its part. The
##   others show the game `_delay` in the past (just long enough for the
##   updates to be there, given the connection) and blend the two updates
##   either side of that moment: numbers, vectors and colours blend, anything
##   else switches. net_apply() takes the result. The host's player colours
##   become this computer's (its theme can differ: a shot, slime, a banner).
## - What happens: Juice and Sfx calls, and a node's methods named "fx_..."
##   that it passes to relay() (a wall flashing where it was hit). The others
##   play them at the same moment of the game.
## - Who plays: a joined computer reads its own players' keys and
##   controllers and sends them every physics frame; on the host a
##   RemoteInput steers each of those seats' blobs. Presses are counted, not
##   sent as they happen, so a lost packet never loses one.
## - The music: the others count beats from the host's start, so the
##   beat-timed lasers fire at the same moment everywhere.
##
## Messages: "match" (the game to load: Net follows it), "nr" (a joined
## computer's copy is ready: it gets everything made so far), "nq" (it
## closed: its players let go), "nw" (made,
## happened, gone: reliable), "ns" (states), "ni" (inputs), "nc" (the music's
## start). See docs/ONLINE.md.

const EVENT_TOO_LATE := 500000 # usec: effects older than this when they'd play are skipped
const SNAP_USEC := 16667.0 # between the host's updates (one per physics frame)
const MIN_DELAY := 20000.0 # usec: the least the others show the game in the past
const AUTOLOADS := ["/root/Juice", "/root/Sfx"] # what relay()ed calls may reach besides fx_ methods
const REFRESH := 30 # physics frames: every entity's state goes out at least this often, changed or not
const PACKET_BYTES := 1000 # a frame's states go in packets of about this much (under the ~1400 a network packet holds)

## The game's NetGame, while one runs (hosting, relay() records into it).
static var current: NetGame
## A joined computer: what the host's mode said about the game it loaded (GameMode.net_match_info()).
static var match_info := {}

var mode: GameMode
var _entities := {} # id -> entity (dynamic: int; from a scene file: its path from the mode)
var _next_id := 1

# Hosting
var _new: Array = [] # entities made since the last send (untyped: some are freed by then)
var _events: Array = [] # relay()ed calls since the last send: [where (_ref()), method, args]
var _gone_static: Array = [] # scene entities freed so far, for computers that get ready later
var _ready_peers: Array[int] = []
var _sent := {} # id -> the state last sent
var _frame := 0
var _told: Array[int] = [] # peers sent "match" for this game
var _size := [0, 0] # the latest frame's states: bytes, packets (for the overlay)
var _size_peak := 0

# Joined
var _spawning := false
var _world: Array = [] # "nw" messages waiting to be played: [time, spawns, events, gone]
var _snaps: Array = [] # [time, {id: state}], oldest first
var _delay := 60000.0 # usec
var _lat := -INF # usec: how old updates are when they arrive (smoothed)
var _dev := 0.0 # how much that varies
var _readers: Array = [] # [seat, PlayerInput (outside the tree, only read), press counts]
var _seq := 0
var _last_usec := 0
var _colors := {} # the host's player colours -> this computer's (its theme can differ)


func _ready() -> void:
	mode = get_parent()
	process_priority = -100 # show the host's state before anything draws
	process_physics_priority = 100 if Net.is_host() else -20 # host: send after everything moved
	Net.message.connect(_on_message)
	get_tree().node_added.connect(_on_node_added)
	_last_usec = Time.get_ticks_usec()
	current = self
	if Net.is_host():
		Net.peers_changed.connect(_on_peers_changed)
		_walk(mode, _register)
		_on_peers_changed()
	else:
		Net.status_changed.connect(_on_status_changed)
		_walk(mode, _take_over)
		_make_readers()
		Net.send(1, "nr", mode.scene_file_path)


func _exit_tree() -> void:
	if current == self:
		current = null
	if Net.is_client():
		Net.send(1, "nq")
	# Leaving the game: nothing more to do here (the node goes after the scene change).
	Net.message.disconnect(_on_message)
	get_tree().node_added.disconnect(_on_node_added)
	if Net.peers_changed.is_connected(_on_peers_changed):
		Net.peers_changed.disconnect(_on_peers_changed)
	if Net.status_changed.is_connected(_on_status_changed):
		Net.status_changed.disconnect(_on_status_changed)
	for r: Array in _readers:
		r[1].free()
	_readers.clear()


## Hosting: send `node`'s call of `method` with `args` to the others, which
## make the same call on their copy at the same moment of the game. For Juice,
## Sfx and methods named "fx_...". Does nothing when not hosting a game.
static func relay(node: Node, method: String, args: Array) -> void:
	if current != null and Net.is_host():
		current._events.append([current._ref(node), method, args])


func _physics_process(_delta: float) -> void:
	if Net.is_host():
		_send()
	elif Net.is_client():
		_send_inputs()


func _process(_delta: float) -> void:
	if not Net.is_client():
		return
	var now_usec := Time.get_ticks_usec()
	var dt := (now_usec - _last_usec) / 1000000.0 # real time: hitstop stops delta
	_last_usec = now_usec
	if _lat > -INF:
		_delay = lerpf(_delay, _target_delay(), 1.0 - exp(-dt * 2.0))
	var now: int = Net.host_time_usec() - int(_delay)
	while not _world.is_empty() and _world[0][0] <= now:
		_play(_world.pop_front(), now)
	_show(now)
	mode.net_mirror(dt)


func _on_message(from: int, type: String, data: Variant) -> void:
	if Net.is_host():
		match type:
			"nr":
				if data == mode.scene_file_path and not _ready_peers.has(from):
					_ready_peers.append(from)
					_catch_up(from)
			"ni":
				if data is Array and data.size() == 2:
					_take_inputs(from, int(data[0]), data[1])
			"nq": # its copy closed (back to the lobby on its own, or loading the next game)
				_ready_peers.erase(from)
				for input: RemoteInput in get_tree().get_nodes_in_group("remote_inputs"):
					if input.peer == from:
						input.release()
		return
	if from != 1:
		return
	match type:
		"nw":
			if data is Array and data.size() == 4:
				_world.append(data)
		"ns":
			if data is Array and data.size() == 2:
				_take_snapshot(int(data[0]), data[1])
		"nc":
			var music := Techno.find(get_tree())
			if music != null and data is int:
				# The host's clock to ours, and back by what the game is shown late.
				music.sync_start(data - (Net.host_time_usec() - Time.get_ticks_usec()) + int(_delay))


# --- Hosting ------------------------------------------------------------------

func _register(node: Node) -> void:
	if not node.has_method("net_state") or node.has_meta("net_id"):
		return
	var id: Variant = String(mode.get_path_to(node))
	if not _from_scene(node):
		id = _next_id
		_next_id += 1
		_new.append(node)
	node.set_meta("net_id", id)
	_entities[id] = node


func _on_node_added(node: Node) -> void:
	if not mode.is_ancestor_of(node):
		return
	if Net.is_host():
		_register(node)
	else:
		_take_over(node)


## Everyone who joined and didn't get "match" for this game yet gets it; whoever left is forgotten.
func _on_peers_changed() -> void:
	for id: int in Net.peers:
		if not _told.has(id):
			_told.append(id)
			Net.send(id, "match", _match_data())
	for id: int in _told.duplicate():
		if not Net.peers.has(id):
			_told.erase(id)
			_ready_peers.erase(id)
			for input: RemoteInput in get_tree().get_nodes_in_group("remote_inputs"):
				if input.peer == id:
					input.release()


func _match_data() -> Dictionary:
	var seats := []
	for s: PlayerSlot in mode.slots:
		seats.append(s.to_net())
	return {scene = mode.scene_file_path, info = mode.info.resource_path if mode.info != null else "",
		lineup = seats, extra = mode.net_match_info()}


## A computer whose copy is ready: the music's start, everything made so far, the scene's entities already gone.
func _catch_up(peer: int) -> void:
	var music := Techno.find(get_tree())
	if music != null:
		Net.send(peer, "nc", music.started_at())
	var spawns := []
	_walk(mode, func(node: Node) -> void:
		if node.get_meta("net_id", "") is int and _alive(node):
			spawns.append(_spawn_of(node)))
	Net.send(peer, "nw", [Time.get_ticks_usec(), spawns, [], _gone_static.duplicate()])


func _send() -> void:
	var t := Time.get_ticks_usec()
	var spawns := []
	for node: Variant in _new:
		if _alive(node):
			spawns.append(_spawn_of(node))
	_new.clear()
	var gone := []
	var packets := [[]] # each [id, state, id, state...]
	var room := PACKET_BYTES
	var bytes := 0
	_frame += 1
	for id: Variant in _entities.keys():
		var node: Variant = _entities[id]
		if not _alive(node):
			_entities.erase(id)
			_sent.erase(id)
			gone.append(id)
			if id is String:
				_gone_static.append(id)
			continue
		var s: Array = node.net_state()
		if not s.is_empty() and (s != _sent.get(id) or (_frame + hash(id)) % REFRESH == 0):
			_sent[id] = s
			var size := var_to_bytes([id, s]).size()
			if size > room and not packets[-1].is_empty():
				packets.append([])
				room = PACKET_BYTES
			room -= size
			bytes += size
			packets[-1].append(id)
			packets[-1].append(s)
	var events := _events
	_events = []
	_size = [bytes, packets.size()]
	_size_peak = maxi(_size_peak, bytes)
	for peer in _ready_peers:
		if not spawns.is_empty() or not events.is_empty() or not gone.is_empty():
			Net.send(peer, "nw", [t, spawns, events, gone])
		for states: Array in packets:
			Net.send(peer, "ns", [t, states], false)


## [id, scene, where it goes, position, net_spawn(), net_state()]: what a joined computer needs to make its copy.
func _spawn_of(node: Node) -> Array:
	var path := node.scene_file_path
	if path == "" and node.get_script() != null:
		path = node.get_script().resource_path
	var setup: Array = node.net_spawn() if node.has_method("net_spawn") else []
	return [node.get_meta("net_id"), path, _ref(node.get_parent()), node.position if node is Node2D else null,
		setup, node.net_state()]


func _take_inputs(peer: int, seq: int, list: Variant) -> void:
	if not list is Array:
		return
	for entry: Variant in list:
		if not entry is Array or entry.size() != 3 or not entry[1] is Vector2:
			continue
		for input: RemoteInput in get_tree().get_nodes_in_group("remote_inputs"):
			if input.peer == peer and input.seat == int(entry[0]):
				input.feed(seq, entry[1], entry[2])


## Where `node` is, the same on every computer: [the nearest made-during-the-game
## entity it's in (0: none), the path from there (or from the mode, or absolute
## outside the game)].
func _ref(node: Node) -> Array:
	var at := node
	while at != null and at != mode:
		if at.get_meta("net_id", "") is int:
			return [at.get_meta("net_id"), String(at.get_path_to(node))]
		at = at.get_parent()
	if at == mode:
		return [0, String(mode.get_path_to(node))]
	return [0, String(node.get_path())]


func _from_scene(node: Node) -> bool:
	return node == mode or node.owner != null


func _alive(node: Variant) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()


# --- Joined -------------------------------------------------------------------

## A node in this copy of the game: it doesn't play (the host does), and a
## made-during-the-game entity that NetGame didn't make goes.
func _take_over(node: Node) -> void:
	if node == self:
		return
	if node.has_method("net_state") and not _from_scene(node) and not _spawning:
		node.queue_free()
		return
	if node.is_in_group("net_local"):
		return
	if node.is_node_ready():
		_mute(node)
	else:
		node.ready.connect(_mute.bind(node), CONNECT_ONE_SHOT)


func _mute(node: Node) -> void:
	node.set_physics_process(false)
	if node == mode:
		node.set_process(false) # the mode's _process keeps its own state: the host's comes in instead


## The players on this computer: their keys and controllers, read every physics frame.
func _make_readers() -> void:
	for s: PlayerSlot in mode.slots:
		if s.human and s.peer == Net.my_id():
			var input := PlayerInput.new()
			input.profile = s.profile
			input.pad_device = s.pad_device
			input.pad_slot = 0 if s.any_pad else -1
			var counts := PackedInt32Array()
			counts.resize(PlayerInput.ACTIONS.size())
			_readers.append([s.number, input, counts])


func _send_inputs() -> void:
	if _readers.is_empty():
		return
	_seq += 1
	var menu := get_tree().get_node_count_in_group("pause_menu") > 0 # this computer's menu is open
	var out := []
	for r: Array in _readers:
		var input: PlayerInput = r[1]
		var counts: PackedInt32Array = r[2]
		var move := Vector2.ZERO if menu else input.steer()
		for i in PlayerInput.ACTIONS.size():
			if input.just_pressed(PlayerInput.ACTIONS[i]) and not menu:
				counts[i] += 1
		out.append([r[0], move, counts.duplicate()])
	Net.send(1, "ni", [_seq, out], false)


func _take_snapshot(t: int, flat: Variant) -> void:
	if not flat is Array:
		return
	var lat := float(Net.host_time_usec() - t)
	if _lat == -INF:
		_lat = lat
		_delay = _target_delay()
	else:
		# A hitch (a scene loading, a burst of new things) only nudges it: one late batch shouldn't slow the game down.
		var off := clampf(lat - _lat, -(_dev * 3.0 + 10000.0), _dev * 3.0 + 10000.0)
		_lat += off * 0.05
		_dev = lerpf(_dev, absf(off), 0.05)
	if not _snaps.is_empty() and t < _snaps[0][0]:
		return # older than what's already shown
	var states := {}
	for i in range(0, flat.size() - 1, 2):
		if flat[i + 1] is Array:
			states[flat[i]] = _recolor(flat[i + 1])
	var at := _snaps.size()
	while at > 0 and _snaps[at - 1][0] > t:
		at -= 1
	if at > 0 and _snaps[at - 1][0] == t: # another packet of the same frame
		_snaps[at - 1][1].merge(states, true)
		return
	_snaps.insert(at, [t, states])


## Far enough in the past that the next update has nearly always arrived.
func _target_delay() -> float:
	return maxf(_lat + SNAP_USEC * 1.5 + _dev * 3.0 + 3000.0, MIN_DELAY)


func _play(w: Array, now: int) -> void:
	if w[1] is Array:
		for s: Variant in w[1]:
			if s is Array and s.size() == 6:
				_make(s)
	if w[2] is Array and now - int(w[0]) < EVENT_TOO_LATE:
		for e: Variant in w[2]:
			if e is Array and e.size() == 3 and e[2] is Array:
				_call(e[0], str(e[1]), _recolor(e[2]))
	if w[3] is Array:
		for id: Variant in w[3]:
			var node := _find(id)
			if node != null:
				node.queue_free()
			_entities.erase(id)


## A copy of a host's entity: [id, scene, where, position, setup, state] (_spawn_of()).
func _make(s: Array) -> void:
	var id: Variant = s[0]
	if _find(id) != null:
		return
	var path := str(s[1])
	var parent := _resolve(s[2])
	if parent == null or not path.begins_with("res://") or not ResourceLoader.exists(path):
		return
	var res := load(path)
	var node: Node = null
	if res is PackedScene:
		node = res.instantiate()
	elif res is Script and res.can_instantiate():
		node = res.new()
	if node == null:
		return
	node.set_meta("net_id", id)
	if node is Node2D and s[3] is Vector2:
		node.position = s[3]
	_spawning = true
	parent.add_child(node)
	_spawning = false
	_entities[id] = node
	if node.has_method("net_setup") and s[4] is Array:
		node.net_setup(s[4])
	if s[5] is Array and not s[5].is_empty() and node.has_method("net_apply"):
		node.net_apply(_recolor(s[5]))
	var was: Variant = node.get("color")
	mode.net_made(node)
	if was is Color and node.get("color") is Color and node.get("color") != was:
		_colors[was] = node.get("color")


## `values` with the host's player colours swapped for this computer's (a shot, slime, an effect in a blob's colour).
func _recolor(values: Array) -> Array:
	if _colors.is_empty():
		return values
	var out := values
	var copied := false
	for i in values.size():
		if values[i] is Color and _colors.has(values[i]):
			if not copied:
				out = values.duplicate()
				copied = true
			out[i] = _colors[values[i]]
	return out


func _call(where: Variant, method: String, args: Variant) -> void:
	var node := _resolve(where)
	if node == null or not args is Array or not node.has_method(method):
		return
	if method.begins_with("fx_") or (where is Array and AUTOLOADS.has(where[1])):
		node.callv(method, args)


func _resolve(ref: Variant) -> Node:
	if not ref is Array or ref.size() != 2:
		return null
	var base: Node = mode if ref[0] is int and ref[0] == 0 else _find(ref[0])
	return base.get_node_or_null(NodePath(str(ref[1]))) if base != null else null


func _find(id: Variant) -> Node:
	var node: Variant = _entities.get(id)
	if not is_instance_valid(node) and id is String:
		node = mode.get_node_or_null(NodePath(id))
		if node != null:
			_entities[id] = node
	return node if _alive(node) else null


## The host's game at `now` (its clock): each entity blended between the updates either side.
func _show(now: int) -> void:
	while _snaps.size() > 1 and _snaps[1][0] <= now:
		_snaps.pop_front()
	if _snaps.is_empty():
		return
	var a: Array = _snaps[0]
	var b: Array = _snaps[1] if _snaps.size() > 1 and a[0] <= now else a
	var k := clampf(float(now - a[0]) / maxf(b[0] - a[0], 1.0), 0.0, 1.0) if b != a else 0.0
	for id: Variant in a[1]:
		if b == a or not b[1].has(id): # it stopped changing: as it ended up
			var node := _find(id)
			if node != null:
				node.net_apply(a[1][id])
	if b == a:
		return
	for id: Variant in b[1]:
		var node := _find(id)
		if node == null:
			continue
		var to: Array = b[1][id]
		node.net_apply(_blend(a[1][id], to, k) if a[1].has(id) else to)


## `a` toward `b` by `k`: numbers, vectors and colours in between, anything else as in `a` until it's `b`'s turn.
static func _blend(a: Array, b: Array, k: float) -> Array:
	if a.size() != b.size() or k <= 0.0:
		return a
	if k >= 1.0:
		return b
	var out := []
	out.resize(a.size())
	for i in a.size():
		var x: Variant = a[i]
		var y: Variant = b[i]
		match typeof(x):
			TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR:
				out[i] = lerp(x, y, k) if typeof(y) == typeof(x) else x
			_:
				out[i] = x
	return out


## For the network overlay (F3).
func describe() -> String:
	if Net.is_host():
		return "game: %d things, sending to %d of %d computers; updates %d bytes in %d packets (at most %d)" % [
			_entities.size(), _ready_peers.size(), Net.peers.size(), _size[0], _size[1], _size_peak]
	return "game shown %d ms late   (updates %d ms old when they arrive, give or take %d)" % [
		roundi(_delay / 1000.0), roundi(_lat / 1000.0), roundi(_dev / 1000.0)]


## Back to the lobby when the host is.
func _on_status_changed() -> void:
	if Net.host_status == "":
		get_tree().change_scene_to_file(Net.lobby_path)


static func _walk(node: Node, f: Callable) -> void:
	f.call(node)
	for c in node.get_children():
		_walk(c, f)
