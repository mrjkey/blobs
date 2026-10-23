class_name LanDiscovery
extends RefCounted
## Finds games hosted on the local network, and answers for a hosted one.
## A copy looking for games (search()) sends a small question, QUERY, to the
## discovery port every ASK_EVERY seconds; a hosting copy (listen()) answers
## with what it is: one JSON object with its name, port, how many computers
## are in and what it's doing. The question goes to the whole network
## (255.255.255.255), to each local subnet's own broadcast address (Windows
## sends the plain one out of one adapter only; subnets are taken as /24)
## and to this computer (127.0.0.1: a second copy of the game). Net owns one.

const QUERY := "BUMPERBLOBS?"
const GAME_ID := "bumper_blobs"
const ASK_EVERY := 1.0
const FORGET_AFTER := 3.5 # seconds without an answer before a game drops off the list
const MAX_PACKET := 1024
## Adapters that aren't the real network (their names, lower case, contain one of these).
const VIRTUAL_HINTS := ["vethernet", "wsl", "hyper-v", "virtualbox", "vmware", "docker", "loopback", "virbr", "veth", "br-"]

## Searching: the games that answered, "name:port" -> {address, port, name, computers, status, protocol, seen (msec)}.
var found := {}
var searching := false

var _socket: PacketPeerUDP
var _port := 0 # searching: the discovery port to ask
var _ask_t := 0.0


## Hosting: answer questions arriving on `port`. Returns the bind error, if any.
func listen(port: int, bind := "*") -> Error:
	stop()
	_socket = PacketPeerUDP.new()
	var err := _socket.bind(port, bind)
	if err != OK:
		_socket = null
	return err


## Look for games answering on `port`; they collect in `found`.
func search(port: int) -> Error:
	stop()
	_socket = PacketPeerUDP.new()
	_socket.set_broadcast_enabled(true)
	var err := _socket.bind(0)
	if err != OK:
		_socket = null
		return err
	_port = port
	_ask_t = 0.0
	searching = true
	return OK


func stop() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	searching = false
	found.clear()


## Once a frame. Hosting: answers with `info` (a Dictionary). Searching: asks, and reads the answers.
func poll(delta: float, info := {}) -> void:
	if _socket == null:
		return
	if searching:
		_ask_t -= delta
		if _ask_t <= 0.0:
			_ask_t = ASK_EVERY
			_ask()
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		var ip := _socket.get_packet_ip()
		var port := _socket.get_packet_port()
		if packet.size() > MAX_PACKET or ip == "":
			continue
		var text := packet.get_string_from_utf8()
		if searching:
			_heard(ip, text)
		elif text == QUERY:
			_socket.set_dest_address(ip, port)
			_socket.put_packet(JSON.stringify(info).to_utf8_buffer())
	var now := Time.get_ticks_msec()
	for key: String in found.keys():
		if now - int(found[key].seen) > FORGET_AFTER * 1000.0:
			found.erase(key)


func _ask() -> void:
	for target in _targets():
		_socket.set_dest_address(target, _port)
		_socket.put_packet(QUERY.to_utf8_buffer())


func _heard(ip: String, text: String) -> void:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or data.get("game", "") != GAME_ID:
		return
	var port := int(data.get("port", 0))
	if port <= 0 or port > 65535:
		return
	# The same game answers on every address it was asked on: one entry, the LAN address over 127.0.0.1.
	var game_name := str(data.get("name", "?")).left(24)
	var key := "%s:%d" % [game_name, port]
	var address := ip
	if found.has(key) and ip.begins_with("127.") and not str(found[key].address).begins_with("127."):
		address = found[key].address
	found[key] = {
		address = address,
		port = port,
		name = game_name,
		computers = int(data.get("computers", 1)),
		status = str(data.get("status", "")).left(32),
		protocol = int(data.get("protocol", 0)),
		seen = Time.get_ticks_msec(),
	}


static func _targets() -> PackedStringArray:
	var out := PackedStringArray(["255.255.255.255", "127.0.0.1"])
	for a in lan_addresses(true):
		var parts := a.split(".")
		var b := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		if not out.has(b):
			out.append(b)
	return out


## This computer's addresses on local networks (IPv4, private ranges): what
## others type to join. Virtual adapters (WSL, Hyper-V, VirtualBox, Docker)
## only with `virtual`.
static func lan_addresses(virtual := false) -> PackedStringArray:
	var out := PackedStringArray()
	for iface: Dictionary in IP.get_local_interfaces():
		var label := ("%s %s" % [iface.get("friendly", ""), iface.get("name", "")]).to_lower()
		var is_virtual := false
		for hint: String in VIRTUAL_HINTS:
			is_virtual = is_virtual or label.contains(hint)
		if is_virtual and not virtual:
			continue
		for a: String in iface.get("addresses", []):
			if _is_lan(a) and not out.has(a):
				out.append(a)
	return out


## A private IPv4 address: 10.x, 172.16-31.x, 192.168.x, and 100.64-127.x (Tailscale).
static func _is_lan(a: String) -> bool:
	if not a.is_valid_ip_address() or a.contains(":"):
		return false
	var p := a.split(".")
	var b := int(p[1])
	return p[0] == "10" or (p[0] == "192" and b == 168) or (p[0] == "172" and b >= 16 and b <= 31) \
		or (p[0] == "100" and b >= 64 and b <= 127)
