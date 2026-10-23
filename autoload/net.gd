extends Node
## Autoload "Net" (autoload/net.tscn): playing over the network. One copy
## hosts (an ENet server, UDP) and the others join it. The host runs the
## lobby and the games; the others send what their players press and show
## what the host sends back. Everything travels as messages: send() a type
## and some data to a peer (1 is the host, 0 everyone), and listen to
## `message`. Reliable messages arrive in order; unreliable ones may not
## arrive at all (for things sent every frame).
##
## Net does the handshake (names, PROTOCOL), keeps who's connected (`peers`),
## pings the host and learns its clock (host_time_usec()), finds games on the
## local network (LanDiscovery) and can pretend the network is slow (NetLag:
## the NETWORK TEST settings). F3 shows the network overlay. When the host
## goes away, a joined copy goes back to the online screen with the reason.
## When the host loads a game (or loads it again), its NetGame sends "match"
## and a joined copy follows it there, whatever screen it's on.
##
## Command line (also the editor's Customize Run Instances), after `--`:
##   --host                  host, and open the lobby
##   --join=ADDRESS[:PORT]   join, and open the lobby
##   --name=NAME             this copy's player name (not saved)
##   --lag=MS --jitter=MS --loss=PERCENT   pretend lag (instead of the settings)
##   --bind=IP               host on this address only (127.0.0.1: no firewall prompt)

signal message(from: int, type: String, data: Variant) # a message for the game arrived
signal peers_changed # someone joined or left (host), or the list of who's in changed (client)
signal joined # joining: the host let us in
signal left(reason: String) # the session ended without us asking (the host left, or joining failed)
signal status_changed # the host started a game or came back to the lobby (host_status)

enum Role { OFFLINE, HOST, JOINING, CLIENT }

const PORT := 24680
const DISCOVERY_PORT := 24681
const PROTOCOL := 2 # bump when messages change: copies on another version are turned away
const MAX_CLIENTS := 7
const CHANNELS := 2 # 0: reliable, 1: unreliable (so frequent updates never wait behind a resend)
const JOIN_TIMEOUT := 6.0
const PING_EVERY := 0.5
const PING_SAMPLES := 5 # ping_ms is the median of this many: one hitch (a scene loading) doesn't show
const KICK_DELAY := 0.5 # seconds between telling a peer why and closing on it
## ENet throttling: (interval ms, acceleration, deceleration). ENet drops
## unreliable packets for a while after it sees the round trip jump (a scene
## loading on the other side); the game sends a little every frame and would
## rather have all of it, so the throttle never comes down.
const THROTTLE := [5000, 32, 0]

@export_file("*.tscn") var online_menu_path := "res://ui/menus/online/online_menu.tscn"
@export_file("*.tscn") var lobby_path := "res://ui/menus/lobby/lobby.tscn"
@export var overlay_scene: PackedScene # the F3 overlay

var role := Role.OFFLINE
## Who else is in, peer id -> {name, ping (ms)}. Host: every client the
## handshake let in. Client: everyone else, the host (1) included.
var peers := {}
var host_name := ""
var host_status := "" # what the host is doing: "" in the lobby, else the title of the game it's playing
var ping_ms := 0.0 # client: the round trip to the host (the median of the last few)
var last_error := "" # why the last session ended, for the online screen
var port := PORT
var discovery := LanDiscovery.new()

var _lag_out := NetLag.new()
var _lag_in := NetLag.new()
var _join_t := 0.0
var _ping_t := 0.0
var _clock_offset := 0 # usec: the host's clock minus ours, from the quickest ping
var _best_rtt := -1
var _rtts: Array[float] = [] # the last few round trips, ms
var _address := "" # joining: what was typed or picked (remembered once we're in)
var _bye := "" # the reason the host gave as it closed
var _args := {} # the command line's --key=value options
var _overlay: Node
var _last_usec := 0
var _rate_t := 0.0
var _counted := {sent = 0, received = 0} # messages since the last second
var rates := {sent = 0, received = 0} # messages in the last second


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS # pings and the overlay go on while a game is paused
	multiplayer.server_relay = false # clients only ever talk to the host
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: _drop("Couldn't connect to %s" % _address))
	multiplayer.server_disconnected.connect(func() -> void: _drop(_bye if _bye != "" else "Lost the connection to the host"))
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			_args[arg.trim_prefix("--").get_slice("=", 0)] = arg.get_slice("=", 1) if arg.contains("=") else ""
	_last_usec = Time.get_ticks_usec()
	_start_from_args.call_deferred()


func _start_from_args() -> void:
	if _args.has("host"):
		if host() == OK:
			get_tree().change_scene_to_file(lobby_path)
	elif _args.get("join", "") != "":
		joined.connect(func() -> void: get_tree().change_scene_to_file(lobby_path), CONNECT_ONE_SHOT)
		join(_args["join"])


func is_online() -> bool:
	return role == Role.HOST or role == Role.CLIENT


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


## This copy's peer id: 1 when hosting or offline.
func my_id() -> int:
	return multiplayer.get_unique_id()


## The name the others see for this copy.
func my_name() -> String:
	return clean_name(_args.get("name", Session.player_name))


func peer_name(id: int) -> String:
	if id == my_id():
		return my_name()
	return peers[id].name if peers.has(id) else "?"


## A player name as the others will see it: trimmed, at most 16 characters.
static func clean_name(text: String) -> String:
	var n := text.strip_edges().left(16)
	return n if n != "" else "PLAYER"


## The host's clock (Time.get_ticks_usec() on the host), as best we know it.
func host_time_usec() -> int:
	return Time.get_ticks_usec() + (_clock_offset if is_client() else 0)


## Start hosting on `at_port`. Returns the error if the port is taken.
func host(at_port := PORT) -> Error:
	leave()
	var bind: String = _args.get("bind", "*")
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind)
	var err := peer.create_server(at_port, MAX_CLIENTS, CHANNELS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	port = at_port
	host_name = my_name()
	host_status = ""
	discovery.listen(DISCOVERY_PORT, bind) # without it, games can still be joined by address
	print("Net: hosting as %s on port %d" % [host_name, port])
	peers_changed.emit()
	return OK


## Start joining the game at `address` ("192.168.1.20", "laptop" or "host:port").
## `joined` or `left` follows. Returns why it can't even try, or "".
func join(address: String) -> String:
	leave()
	last_error = ""
	address = address.strip_edges()
	var host_part := address
	var at_port := PORT
	if address.count(":") == 1:
		host_part = address.get_slice(":", 0)
		at_port = int(address.get_slice(":", 1))
	if at_port <= 0 or at_port > 65535:
		return "That port isn't right: %s" % address
	var ip := host_part if host_part.is_valid_ip_address() else IP.resolve_hostname(host_part, IP.TYPE_IPV4)
	if ip == "":
		return "Can't find %s on the network" % host_part
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, at_port, CHANNELS)
	if err != OK:
		return "Couldn't start connecting (error %d)" % err
	multiplayer.multiplayer_peer = peer
	role = Role.JOINING
	port = at_port
	_address = address
	_join_t = JOIN_TIMEOUT
	_bye = ""
	_best_rtt = -1
	return ""


## End the session: stop hosting (telling everyone `reason`) or leave the host's game.
func leave(reason := "") -> void:
	if role == Role.OFFLINE:
		return
	if role == Role.HOST and reason != "":
		for id: int in peers:
			_send_now(id, "bye", reason, true)
		_flush()
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.OFFLINE
	peers.clear()
	host_name = ""
	host_status = ""
	ping_ms = 0.0
	_rtts.clear()
	_clock_offset = 0
	_lag_out.clear()
	_lag_in.clear()
	if not discovery.searching:
		discovery.stop()
	GameSettings.use_host_settings({})
	peers_changed.emit()


## Look for games on the local network (LanDiscovery.found), or stop looking.
func search_lan(on: bool) -> void:
	if on and role != Role.HOST:
		discovery.search(DISCOVERY_PORT)
	elif not on and discovery.searching:
		discovery.stop()


## Host: tell everyone what it's doing ("" = in the lobby, else a game's title).
func set_status(text: String) -> void:
	if role != Role.HOST or text == host_status:
		return
	host_status = text
	send(0, "status", text)


## Send a message: `to` a peer id (1 = the host), or 0 for everyone (a client: the host).
func send(to: int, type: String, data: Variant = null, reliable := true) -> void:
	if not is_online():
		return
	if to == 0:
		for id: int in (peers.keys() if is_host() else [1]):
			_post(id, type, data, reliable)
	else:
		_post(to, type, data, reliable)


func _post(to: int, type: String, data: Variant, reliable: bool) -> void:
	_counted.sent += 1
	if _lag_out.active() or not _lag_out.empty():
		_lag_out.push([to, type, data, reliable], reliable, to)
	else:
		_send_now(to, type, data, reliable)


func _send_now(to: int, type: String, data: Variant, reliable: bool) -> void:
	if not multiplayer.get_peers().has(to):
		return
	if reliable:
		_rpc_reliable.rpc_id(to, type, data)
	else:
		_rpc_unreliable.rpc_id(to, type, data)


func _flush() -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer != null and peer.host != null:
		peer.host.flush()


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_reliable(type: String, data: Variant) -> void:
	_arrive(multiplayer.get_remote_sender_id(), type, data, true)


@rpc("any_peer", "call_remote", "unreliable", 1)
func _rpc_unreliable(type: String, data: Variant) -> void:
	_arrive(multiplayer.get_remote_sender_id(), type, data, false)


func _arrive(from: int, type: String, data: Variant, reliable: bool) -> void:
	_counted.received += 1
	if _lag_in.active() or not _lag_in.empty():
		_lag_in.push([from, type, data], reliable, from)
	else:
		_handle(from, type, data)


func _handle(from: int, type: String, data: Variant) -> void:
	match role:
		Role.HOST:
			if type == "hello":
				_on_hello(from, data)
				return
			if not peers.has(from):
				return
		Role.JOINING, Role.CLIENT:
			if from != 1:
				return
		_:
			return
	match type:
		"ping":
			if data is Array and data.size() == 2:
				peers[from].ping = float(data[1])
				_post(from, "pong", [data[0], Time.get_ticks_usec()], false)
		"pong":
			if data is Array and data.size() == 2:
				_on_pong(int(data[0]), int(data[1]))
		"welcome":
			if role == Role.JOINING and data is Dictionary:
				_on_welcome(data)
		"reject", "bye":
			if data is String:
				if role == Role.JOINING:
					_drop(data)
				else:
					_bye = data
		"roster":
			if role == Role.CLIENT and data is Dictionary:
				_on_roster(data)
		"status":
			if data is String:
				host_status = data
				status_changed.emit()
		"match":
			if role == Role.CLIENT and data is Dictionary:
				_follow_match(data)
		_:
			if role == Role.HOST or role == Role.CLIENT:
				message.emit(from, type, data)


func _on_connected() -> void:
	_no_throttle(1)
	_post(1, "hello", {name = my_name(), protocol = PROTOCOL}, true)


func _on_peer_connected(id: int) -> void:
	_no_throttle(id) # and nothing else until its hello


func _no_throttle(id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var link := enet.get_peer(id) if enet != null else null
	if link != null:
		link.throttle_configure(THROTTLE[0], THROTTLE[1], THROTTLE[2])


func _on_peer_disconnected(id: int) -> void:
	if role == Role.HOST and peers.has(id):
		print("Net: %s left (#%d)" % [peers[id].name, id])
		peers.erase(id)
		_send_roster()
		peers_changed.emit()


## Host: a new copy says who it is. In, or turned away with the reason.
func _on_hello(from: int, data: Variant) -> void:
	if peers.has(from):
		return
	if not data is Dictionary or int(data.get("protocol", 0)) != PROTOCOL:
		_send_now(from, "reject", "Your copy of the game is a different version from the host's. Use the same build on both computers.", true)
		_flush()
		get_tree().create_timer(KICK_DELAY, true, false, true).timeout.connect(_kick.bind(from))
		return
	peers[from] = {name = clean_name(str(data.get("name", ""))), ping = 0.0}
	print("Net: %s joined (#%d)" % [peers[from].name, from])
	_post(from, "welcome", {name = host_name, status = host_status}, true)
	_send_roster()
	peers_changed.emit()


func _kick(id: int) -> void:
	if role == Role.HOST and multiplayer.get_peers().has(id):
		multiplayer.multiplayer_peer.disconnect_peer(id)


func _send_roster() -> void:
	var names := {1: host_name}
	for id: int in peers:
		names[id] = peers[id].name
	send(0, "roster", names)


func _on_welcome(data: Dictionary) -> void:
	role = Role.CLIENT
	host_name = clean_name(str(data.get("name", "")))
	host_status = str(data.get("status", ""))
	peers = {1: {name = host_name, ping = 0.0}}
	Session.remember_host(_address, host_name)
	print("Net: in %s's game at %s, as #%d" % [host_name, _address, my_id()])
	_ping_t = 0.0
	joined.emit()
	peers_changed.emit()


func _on_roster(names: Dictionary) -> void:
	peers.clear()
	for id: Variant in names:
		if int(id) != my_id():
			peers[int(id)] = {name = clean_name(str(names[id])), ping = 0.0}
	if peers.has(1):
		host_name = peers[1].name
	peers_changed.emit()


func _on_pong(sent_usec: int, host_usec: int) -> void:
	var now := Time.get_ticks_usec()
	var rtt := now - sent_usec
	if rtt < 0:
		return
	_rtts.append(rtt / 1000.0)
	if _rtts.size() > PING_SAMPLES:
		_rtts.pop_front()
	var sorted := _rtts.duplicate()
	sorted.sort()
	ping_ms = sorted[floori(sorted.size() / 2.0)]
	# The quickest round trips say the most about the clock (least time spent waiting in queues).
	if _best_rtt < 0 or rtt <= _best_rtt * 1.25:
		_best_rtt = rtt if _best_rtt < 0 else mini(_best_rtt, rtt)
		_clock_offset = host_usec + int(rtt * 0.5) - now


## The host loaded a game (NetGame._match_data()): load it too, with the same lineup.
func _follow_match(data: Dictionary) -> void:
	var scene := str(data.get("scene", ""))
	var info_path := str(data.get("info", ""))
	if not scene.begins_with("res://") or not ResourceLoader.exists(scene):
		push_warning("Net: the host's game isn't in this copy: %s" % scene)
		return
	var lineup: Array = []
	for d: Variant in data.get("lineup", []):
		if d is Dictionary:
			var s := PlayerSlot.from_net(d, [])
			if s.human:
				s.fit_profile()
			lineup.append(s)
	Session.lineup = lineup
	Session.lineup_mode = info_path
	if info_path.begins_with("res://") and ResourceLoader.exists(info_path):
		Session.next_mode = load(info_path)
	var extra: Variant = data.get("extra", {})
	NetGame.match_info = extra if extra is Dictionary else {}
	get_tree().change_scene_to_file(scene)


## The session ended without us asking: back to the online screen, saying why.
func _drop(reason: String) -> void:
	print("Net: dropped: ", reason)
	leave()
	last_error = reason
	left.emit(reason)
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path != online_menu_path:
		get_tree().change_scene_to_file(online_menu_path)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - _last_usec) / 1000000.0 # real time: hitstop stops the game's delta
	_last_usec = now
	_apply_lag()
	for item: Array in _lag_out.pop_due():
		_send_now(item[0], item[1], item[2], item[3])
	for item: Array in _lag_in.pop_due():
		_handle(item[0], item[1], item[2])
	match role:
		Role.JOINING:
			_join_t -= dt
			if _join_t <= 0.0:
				_drop("No answer from %s. Is the game hosting, and the firewall letting it through?" % _address)
		Role.CLIENT:
			_ping_t -= dt
			if _ping_t <= 0.0:
				_ping_t = PING_EVERY
				_post(1, "ping", [Time.get_ticks_usec(), ping_ms], false)
	if role == Role.HOST:
		discovery.poll(dt, {game = LanDiscovery.GAME_ID, protocol = PROTOCOL, name = host_name, port = port,
			computers = peers.size() + 1, status = host_status})
	else:
		discovery.poll(dt)
	_rate_t += dt
	if _rate_t >= 1.0:
		_rate_t = 0.0
		rates = _counted.duplicate()
		_counted = {sent = 0, received = 0}


## The NETWORK TEST settings, or the command line's --lag / --jitter / --loss.
func _apply_lag() -> void:
	var lag := float(_args.get("lag", GameSettings.choice("net_lag")))
	var jitter := float(_args.get("jitter", GameSettings.choice("net_jitter")))
	var loss := float(_args.get("loss", GameSettings.choice("net_loss"))) / 100.0
	for l: NetLag in [_lag_out, _lag_in]:
		l.lag_ms = lag
		l.jitter_ms = jitter
		l.loss = loss


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		if _overlay == null:
			_overlay = overlay_scene.instantiate()
			add_child(_overlay)
		else:
			_overlay.visible = not _overlay.visible


## What the F3 overlay shows.
func overlay_text() -> String:
	var lines := PackedStringArray()
	match role:
		Role.OFFLINE:
			lines.append("OFFLINE")
		Role.JOINING:
			lines.append("JOINING %s..." % _address)
		Role.HOST:
			var addresses := LanDiscovery.lan_addresses()
			lines.append("HOSTING as %s   port %d   %s" % [host_name, port, " / ".join(addresses)])
			if host_status != "":
				lines.append("playing %s" % host_status)
			for id: int in peers:
				lines.append("  %s  (#%d)   %d ms" % [peers[id].name, id, roundi(peers[id].ping)])
		Role.CLIENT:
			lines.append("IN %s's GAME as %s (#%d)   ping %d ms" % [host_name, my_name(), my_id(), roundi(ping_ms)])
			lines.append("host clock %+.1f ms from ours" % (_clock_offset / 1000.0))
	if _lag_out.active():
		lines.append("PRETEND LAG  %d ms round trip  + up to %d jitter   loss %d%% each way" % [
			roundi(_lag_out.lag_ms), roundi(_lag_out.jitter_ms), roundi(_lag_out.loss * 100.0)])
	if NetGame.current != null:
		lines.append(NetGame.current.describe())
	lines.append("messages/s   out %d   in %d" % [rates.sent, rates.received])
	return "\n".join(lines)
