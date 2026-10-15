@tool
extends EditorPlugin
## Reloads scenes and resources that changed on disk outside the editor, so edits from
## Claude Code show up without clicking into Godot or restarting the game.
##
## tools/claude_godot_sync.py connects to 127.0.0.1:PORT and sends one JSON line:
##     {"scenes": ["res://..."], "resources": ["res://..."]}
## Open scenes are reloaded in the editor, which also updates them in the running game.
## Resources are refreshed in the editor and passed to the game's ClaudeSyncGame autoload
## (game_sync.gd) over the debugger connection. The reply is one JSON line saying what happened.

const PORT := 6011
const AUTOLOAD_NAME := "ClaudeSyncGame"
const AUTOLOAD_PATH := "res://addons/claude_sync/game_sync.gd"

var _server := TCPServer.new()
var _buffers := {}  # StreamPeerTCP -> String received so far
var _debugger := GameLink.new()


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


func _enter_tree() -> void:
	add_debugger_plugin(_debugger)
	var err := _server.listen(PORT, "127.0.0.1")
	if err != OK:
		push_warning("Claude Sync: can't listen on port %d (error %d)" % [PORT, err])


func _exit_tree() -> void:
	_server.stop()
	_buffers.clear()
	remove_debugger_plugin(_debugger)


func _process(_delta: float) -> void:
	while _server.is_connection_available():
		_buffers[_server.take_connection()] = ""
	for client: StreamPeerTCP in _buffers.keys():
		client.poll()
		if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_buffers.erase(client)
			continue
		var available := client.get_available_bytes()
		if available == 0:
			continue
		var chunk: Array = client.get_data(available)
		_buffers[client] += (chunk[1] as PackedByteArray).get_string_from_utf8()
		var newline: int = _buffers[client].find("\n")
		if newline >= 0:
			var reply := _handle(JSON.parse_string(_buffers[client].substr(0, newline)))
			client.put_data((JSON.stringify(reply) + "\n").to_utf8_buffer())
			_buffers[client] = ""


func _handle(request: Variant) -> Dictionary:
	if typeof(request) != TYPE_DICTIONARY:
		return {"error": "expected a JSON object"}
	var scenes: Array = request.get("scenes", [])
	var resources: Array = request.get("resources", [])

	var filesystem := EditorInterface.get_resource_filesystem()
	for path: String in scenes + resources:
		filesystem.update_file(path)

	var open_scenes := EditorInterface.get_open_scenes()
	var reloaded := []
	var not_open := []
	for path: String in scenes:
		if path in open_scenes:
			EditorInterface.reload_scene_from_path(path)
			reloaded.append(path)
		else:
			not_open.append(path)

	for path: String in resources:
		# Refresh the editor's copy too, so saving in the editor can't write back the old one.
		if ResourceLoader.has_cached(path):
			ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	var games := 0
	if resources:
		games = _debugger.reload_resources(resources)

	return {"reloaded_scenes": reloaded, "scenes_not_open": not_open, "games_sent_resources": games}


## Passes resource reloads to the running game, where game_sync.gd picks them up.
class GameLink extends EditorDebuggerPlugin:
	func reload_resources(paths: Array) -> int:
		var sent := 0
		for session: EditorDebuggerSession in get_sessions():
			if session.is_active():
				session.send_message("claude_sync:reload_resources", [paths])
				sent += 1
		return sent
