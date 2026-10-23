extends SceneTree
## Online play end to end, without a screen. tools/net_test.sh runs two
## copies on this computer:
## - role=host hosts and opens the lobby, goes to PLAYERS once someone's in,
##   picks the game (RING) once their player is ready (which un-readies them) and starts
##   when they're ready again. In the game it watches the client's blob, and
##   two seconds after it has moved right, goes back to the lobby; it passes
##   when the client has left.
## - role=client joins, follows the host to PLAYERS, takes a seat from the
##   keyboard and readies up (again after the switch). It follows the host
##   into the game, holds right once the countdown is over, sees its own blob
##   move there (and says how long the first response took: a round trip,
##   plus how late it shows the game), follows the host back to the lobby
##   and leaves.
## game=TITLE plays another game than RING (FOOTBALL, TREADMILL, "DON'T GET
## FAT!"); give it to both. In DON'T GET FAT! the host then sends the buddy
## to the gate in the window: the client goes on from the report card and
## picks an upgrade with its own keys, and both go on to level 2 before
## going back to the lobby. With shots=DIR (and without --headless), each copy
## saves a screenshot of the game there, half a second after the client's
## blob has moved.
## - role=late (with late=1 on the host: tools/net_test.sh does both with
##   LATE=1) joins while the game is on: it should land in the game and
##   watch, then follow the host back to the lobby. The host waits for it.
## Each copy prints PASS or FAIL and quits. Net's own options work too
## (--lag=200 --jitter=30 --loss=10: a bad connection).
## No project class names in here: see "Checking work without the editor"
## in docs/ARCHITECTURE.md.

const LOBBY := "res://ui/menus/lobby/lobby.tscn"
const TIMEOUT := 45.0
const MOVE := 60.0 # px the client's blob has to go right

var role := ""
var step := 0
var waited := 0.0
var net: Node
var pressed_at := 0
var seat := 0
var start_x := 0.0
var shots := ""
var game := "RING"
var late := false # host: someone joins during the game; stay in it until they're watching
var first_response := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("role="):
			role = a.get_slice("=", 1)
		elif a.begins_with("shots="):
			shots = a.get_slice("=", 1)
		elif a.begins_with("game="):
			game = a.get_slice("=", 1)
		elif a == "late=1":
			late = true


func _process(delta: float) -> bool:
	waited += delta
	if waited > TIMEOUT:
		return _done(false, "timed out at step %d" % step)
	if net == null:
		net = root.get_node_or_null("Net")
		if net == null:
			return _done(false, "no Net autoload")
	match role:
		"host":
			return _host()
		"late":
			return _late()
	return _client()


func _host() -> bool:
	var scene := current_scene
	match step:
		0:
			var err: int = net.host()
			if err != OK:
				return _done(false, "couldn't host: error %d" % err)
			root.get_node("Session").settings["cpu_level"] = "idle" # computers that stand still
			change_scene_to_file(LOBBY)
			step = 1
		1:
			if scene == null or not "players" in scene:
				return false
			if scene.view == 0 and not net.peers.is_empty():
				scene._show(1) # PLAYERS: the client should follow
				scene._changed()
			var p := _remote_player(scene)
			if p.get("ready", false):
				seat = p.panel + 1
				print("host: %s's player is in seat P%d, ready" % [net.peer_name(p.peer), seat])
				for i in scene.modes.size():
					if scene.modes[i].title == game:
						scene._pick_game(i)
				print("host: switched the game to ", scene.info.title)
				step = 2
		2:
			var p := _remote_player(scene)
			if p.is_empty():
				return _done(false, "the switch lost the client's player")
			if p.ready and scene._can_start():
				print("host: everyone's ready again, starting")
				scene._start()
				step = 3
		3:
			var b := _blob(seat)
			if b == null:
				return false
			if not b.active:
				start_x = b.global_position.x
				return false
			if b.global_position.x > start_x + MOVE:
				print("host: the client's blob went right %d px (%d fps here)" % [roundi(b.global_position.x - start_x), Engine.get_frames_per_second()])
				pressed_at = Time.get_ticks_msec()
				step = 4
		4:
			if shots != "" and Time.get_ticks_msec() - pressed_at > 500 and step == 4 and not has_meta("shot"):
				set_meta("shot", true)
				_shot()
			if late and scene.net._ready_peers.size() < 2:
				pressed_at = Time.get_ticks_msec() # the late one isn't watching yet: then give it a moment
				return false
			if Time.get_ticks_msec() - pressed_at > 2000: # the client sees it too, a moment later
				if game == "DON'T GET FAT!":
					scene.buddy.weight = (scene.low + scene.high) * 0.5
					scene._reach_gate()
					set_meta("level_1", scene)
					print("host: the buddy's at the gate, in the window")
					step = 20
					return false
				scene.leave()
				step = 5
		20:
			if scene != get_meta("level_1") and "run" in scene and scene.run != null and scene.run.level == 1:
				print("host: the client went on and picked %s; on to level 2" % ", ".join(scene.run.upgrades.keys()))
				pressed_at = Time.get_ticks_msec()
				step = 21
		21:
			if Time.get_ticks_msec() - pressed_at > 1500:
				scene.leave()
				step = 5
		5:
			if net.peers.is_empty():
				if scene != null and "players" in scene:
					for p: Dictionary in scene.players.values():
						if p.peer != 1:
							return _done(false, "the client left but its player is still seated")
				return _done(true, "started %s with the client, it played, everyone came back and it left" % game)
	return false


func _client() -> bool:
	var scene := current_scene
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
			if scene != null and "_synced" in scene and scene._synced:
				step = 3
		3:
			if scene.view == 1: # the host went to PLAYERS
				_press(KEY_SPACE) # join
				pressed_at = Time.get_ticks_msec()
				step = 4
		4:
			if _mine(scene).is_empty():
				return false
			seat = _mine(scene).panel + 1
			print("client: seated as P%d, seen %d ms after pressing" % [seat, Time.get_ticks_msec() - pressed_at])
			_press(KEY_SPACE) # ready
			step = 5
		5:
			if _mine(scene).get("ready", false) or scene.info.title == game: # with lag the switch can come in the same frame
				print("client: ready in ", scene.info.title)
				step = 6
		6:
			if "net" in scene: # it was the game already: no switch, and the host started
				step = 7
			elif scene.info.title == game and not _mine(scene).is_empty() and not _mine(scene).ready:
				print("client: the host switched to %s, ready again" % game)
				seat = _mine(scene).panel + 1
				_press(KEY_SPACE)
				step = 7
		7:
			if scene == null or not "net" in scene:
				return false
			print("client: followed the host into ", scene.scene_file_path)
			step = 8
		8:
			var b := _blob(seat)
			if b == null or scene.state != 1: # PLAYING: the countdown is over
				pressed_at = Time.get_ticks_msec()
				return false
			if Time.get_ticks_msec() - pressed_at < (500 if game == "TREADMILL" else 2000): # things settle (the music is made at the start), unless the belt's coming
				return false
			start_x = b.global_position.x
			print("client: %d blobs here, mine (P%d) at x %d" % [root.get_tree().get_nodes_in_group("blobs").size(), seat, roundi(start_x)])
			_hold(KEY_D, true)
			if game == "TREADMILL":
				_hold(KEY_W, true) # keep ahead of the belt's laser
			pressed_at = Time.get_ticks_msec()
			step = 9
		9:
			var b := _blob(seat)
			if b == null:
				return false
			if first_response == 0 and b.global_position.x > start_x + 2.0:
				first_response = Time.get_ticks_msec() - pressed_at
				print("client: my blob answered right here %d ms after pressing (ping %d ms, %d fps; %s)" % [first_response, roundi(net.ping_ms), Engine.get_frames_per_second(), scene.net.describe()]); print("client: pings ", net._rtts, " messages/s ", net.rates)
			if b.global_position.x > start_x + MOVE:
				print("client: and went right %d px" % roundi(b.global_position.x - start_x))
				pressed_at = Time.get_ticks_msec()
				step = 10
		10:
			if shots != "" and Time.get_ticks_msec() - pressed_at > 500:
				_shot()
				shots = ""
			if Time.get_ticks_msec() - pressed_at > 600:
				_hold(KEY_D, false)
				_hold(KEY_W, false)
				step = 11
				if game == "DON'T GET FAT!":
					set_meta("level_1", scene)
					step = 20
		20:
			# Go on from the report card and take a card: tap the push key (space) until level 2 is here.
			if scene != get_meta("level_1") and "run" in scene and scene.run != null and scene.run.level == 1:
				_hold(KEY_SPACE, false)
				print("client: followed the host into level 2 (%s)" % scene.map.scene_file_path.get_file())
				step = 11
			elif "between" in scene and scene.between.visible and Engine.get_process_frames() % 20 == 0:
				var down := not Input.is_physical_key_pressed(KEY_SPACE)
				if down and not has_meta("seen_screen"):
					set_meta("seen_screen", true)
					print("client: the host's screen is up here: ", scene.between._mode)
				_hold(KEY_SPACE, down)
		11:
			if scene != null and "players" in scene:
				return _done(true, "played %s on the host and came back to the lobby with it" % game)
	return false


func _late() -> bool:
	var scene := current_scene
	match step:
		0:
			var problem: String = net.join("127.0.0.1")
			if problem != "":
				return _done(false, problem)
			step = 1
		1:
			if scene != null and "net" in scene and not root.get_tree().get_nodes_in_group("blobs").is_empty():
				print("late: joined during the game and watching %s, %d blobs here" % [scene.scene_file_path.get_file(),
					root.get_tree().get_nodes_in_group("blobs").size()])
				step = 2
		2:
			if scene != null and "players" in scene:
				return _done(true, "watched the game and came back to the lobby with the host")
	return false


func _remote_player(lobby: Node) -> Dictionary:
	for p: Dictionary in lobby.players.values():
		if p.peer != 1:
			return p
	return {}


func _mine(lobby: Node) -> Dictionary:
	return lobby.players.get("%d/keys" % net.my_id(), {})


func _blob(number: int) -> Node:
	for b in root.get_tree().get_nodes_in_group("blobs"):
		if b.seat == number and b.alive:
			return b
	return null


func _press(key: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = key
		e.keycode = key
		e.pressed = down
		root.push_input(e)


## Held keys reach the game's polling (Input.is_physical_key_pressed), not just its events.
func _hold(key: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.keycode = key
	e.pressed = down
	Input.parse_input_event(e)


func _shot() -> void:
	var path := shots.path_join("%s.png" % role)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("%s: screenshot %s" % [role, path])


func _done(ok: bool, text: String) -> bool:
	print(("PASS %s: " if ok else "FAIL %s: ") % role, text)
	if not ok and current_scene != null:
		print("%s: in %s, state %s" % [role, current_scene.scene_file_path, current_scene.get("state")])
		if current_scene.get("hud") != null:
			print("%s:   banner %s, status %s" % [role, current_scene.hud.banner.text, current_scene.hud.status.text])
		for b in root.get_tree().get_nodes_in_group("blobs"):
			print("%s:   blob seat %d alive %s at %s" % [role, b.seat, b.alive, b.global_position])
	if net != null:
		net.leave()
	quit(0 if ok else 1)
	return true
