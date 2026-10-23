extends SceneTree
## Online play end to end, without a screen. tools/net_test.sh runs two
## copies on this computer: role=host hosts and opens the lobby, and goes to
## PLAYERS once someone's in; role=client joins, follows the host to PLAYERS,
## takes a seat from the keyboard and readies up. The host sees the player
## arrive ready and that it can't start yet (online matches come in step 2),
## then switches the game; the client sees the switch and that it has to
## ready up again, then leaves; the host sees it go. Each
## copy prints PASS or FAIL and quits. Net's own options work too
## (--lag=200 --jitter=30 --loss=10: a bad connection).
## No project class names in here: see "Checking work without the editor"
## in docs/ARCHITECTURE.md.

const LOBBY := "res://ui/menus/lobby/lobby.tscn"
const TIMEOUT := 30.0

var role := ""
var step := 0
var waited := 0.0
var net: Node
var mode_before := -1
var pressed_at := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("role="):
			role = a.get_slice("=", 1)


func _process(delta: float) -> bool:
	waited += delta
	if waited > TIMEOUT:
		return _done(false, "timed out at step %d" % step)
	if net == null:
		net = root.get_node_or_null("Net")
		if net == null:
			return _done(false, "no Net autoload")
	return _host() if role == "host" else _client()


func _host() -> bool:
	var lobby := current_scene
	match step:
		0:
			var err: int = net.host()
			if err != OK:
				return _done(false, "couldn't host: error %d" % err)
			change_scene_to_file(LOBBY)
			step = 1
		1:
			if lobby == null or not "players" in lobby:
				return false
			if lobby.view == 0 and not net.peers.is_empty():
				lobby._show(1) # PLAYERS: the client should follow
				lobby._changed()
			for p: Dictionary in lobby.players.values():
				if p.peer != 1 and p.ready:
					print("host: %s's player is in seat P%d, ready" % [net.peer_name(p.peer), p.panel + 1])
					if lobby._can_start():
						return _done(false, "the host could start with another computer's player seated")
					print("host: can't start yet: ", lobby._problem())
					mode_before = lobby.modes.find(lobby.info)
					lobby._pick_game((mode_before + 1) % lobby.modes.size())
					print("host: switched the game to ", lobby.info.title)
					step = 2
		2:
			if net.peers.is_empty():
				for p: Dictionary in lobby.players.values():
					if p.peer != 1:
						return _done(false, "the client left but its player is still seated")
				return _done(true, "the client joined, readied, saw the switch and left")
	return false


func _client() -> bool:
	var lobby := current_scene
	var me: int = net.my_id()
	match step:
		0:
			var problem: String = net.join("127.0.0.1")
			if problem != "":
				return _done(false, problem)
			step = 1
		1:
			if net.is_client():
				print("client: in %s's game after %d ms" % [net.host_name, roundi(waited * 1000.0)])
				change_scene_to_file(LOBBY)
				step = 2
		2:
			if lobby != null and "_synced" in lobby and lobby._synced:
				step = 3
		3:
			if lobby.view == 1: # the host went to PLAYERS
				_press(KEY_SPACE) # join
				pressed_at = Time.get_ticks_msec()
				step = 4
		4:
			if _mine(lobby).is_empty():
				return false
			print("client: seated as P%d, seen %d ms after pressing" % [_mine(lobby).panel + 1, Time.get_ticks_msec() - pressed_at])
			_press(KEY_SPACE) # ready
			step = 5
		5:
			if _mine(lobby).get("ready", false):
				mode_before = lobby.modes.find(lobby.info)
				print("client: ready in ", lobby.info.title)
				step = 6
		6:
			var mine := _mine(lobby)
			if lobby.modes.find(lobby.info) != mode_before and not mine.is_empty() and not mine.ready:
				print("client: the host switched to %s, still seated, not ready" % lobby.info.title)
				return _done(true, "joined, readied and followed the host's switch")
	return false


func _mine(lobby: Node) -> Dictionary:
	return lobby.players.get("%d/keys" % net.my_id(), {})


func _press(key: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = key
		e.keycode = key
		e.pressed = down
		root.push_input(e)


func _done(ok: bool, text: String) -> bool:
	print(("PASS %s: " if ok else "FAIL %s: ") % role, text)
	if net != null:
		net.leave()
	quit(0 if ok else 1)
	return true
