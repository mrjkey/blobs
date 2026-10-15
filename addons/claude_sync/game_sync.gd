extends Node
## Autoload "ClaudeSyncGame", added by the Claude Sync plugin (plugin.gd).
## When the editor says resources changed on disk, reloads them in place so everything
## already using them (themes, materials, ...) updates without restarting the game.
## Does nothing unless the game was started from the editor with the debugger attached.


func _ready() -> void:
	if EngineDebugger.is_active():
		EngineDebugger.register_message_capture("claude_sync", _on_editor_message)


func _on_editor_message(message: String, data: Array) -> bool:
	if not message.ends_with("reload_resources"):
		return false
	for path: String in data[0]:
		# Only resources already in use need refreshing; anything else loads fresh when needed.
		if ResourceLoader.has_cached(path):
			ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
			print("Claude Sync: reloaded ", path)
	return true
