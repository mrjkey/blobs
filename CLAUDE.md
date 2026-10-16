# example_game

Godot 4.7.2 game. The editor runs on Windows; the project lives in WSL. The user usually has the editor and the game open while we work, so changes can be checked live.

- Never make git commits. The user commits.

## Live reload

- Saves in VS Code reach Godot through `tools/godot_lsp_relay.py` (port 6010, started by the VS Code task), which fixes the WSL/Windows paths.
- Claude's edits reach Godot through hooks in `.claude/settings.json` (`tools/claude_godot_sync.py`): when a turn ends, every changed `.gd`, `.tscn` and `.tres` file is pushed in one batch.
  - `.gd` scripts go through the language server and reload in the running game.
  - `.tscn` scenes and `.tres` resources go to the Claude Sync editor plugin (`addons/claude_sync`, port 6011). It reloads scenes that are open in the editor, and refreshes resources in the running game through the `ClaudeSyncGame` autoload.
- What the user sees after a push (tell them which applies):
  - `.gd` and `.tres` changes (e.g. theme colors): live, no action needed.
  - `.tscn` changes: only after the scene loads again. The user has to navigate away from the scene and back. A scene that isn't open in the editor needs a game restart.
- Don't make scene edits apply by restarting the current scene automatically: the user doesn't want game state reset on every change.
- To push files by hand: `python3 tools/claude_godot_sync.py push <files> ...`
- If a push fails, the relay task, the Godot editor or the Claude Sync plugin isn't running.
