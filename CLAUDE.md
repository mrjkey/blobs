# example_game

Godot 4.7.2 game. The editor runs on Windows; the project lives in WSL. The user usually has the editor and the game open while we work, so changes can be checked live.

## Live reload

- Saves in VS Code reach Godot through `tools/godot_lsp_relay.py` (port 6010, started by the VS Code task), which fixes the WSL/Windows paths.
- Claude's edits reach Godot through hooks in `.claude/settings.json` (`tools/claude_godot_sync.py`): when a turn ends, every changed `.gd`, `.tscn` and `.tres` file is pushed in one batch.
  - `.gd` scripts go through the language server and reload in the running game.
  - `.tscn` scenes and `.tres` resources go to the Claude Sync editor plugin (`addons/claude_sync`, port 6011). It reloads scenes that are open in the editor, and refreshes resources in the running game through the `ClaudeSyncGame` autoload.
- Resource changes (e.g. theme colors) show up live. Scene changes show up the next time the scene loads (leave it and come back); a scene that isn't open in the editor needs a game restart. Tell the user which applies.
- To push files by hand: `python3 tools/claude_godot_sync.py push <files> ...`
- If a push fails, the relay task, the Godot editor or the Claude Sync plugin isn't running.
