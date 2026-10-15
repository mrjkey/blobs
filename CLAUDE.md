# example_game

Godot 4.7.2 game. The editor runs on Windows; the project lives in WSL. The user usually has the editor and the game open while we work, so changes can be checked live.

## Live reload

- Saves in VS Code reach Godot through `tools/godot_lsp_relay.py` (port 6010, started by the VS Code task), which fixes the WSL/Windows paths.
- Claude's edits reach Godot through hooks in `.claude/settings.json`: when a turn ends, every `.gd` file changed during it is sent to Godot in one batch, and the running game reloads those scripts.
- Only `.gd` scripts hot-reload. Changes to `.tscn` and `.tres` files need Godot to notice them (clicking into the editor) or a restart of the game. Say so when a change needs that.
- To send scripts by hand: `python3 tools/godot_lsp_save.py <file.gd> ...`
- If a send fails, the relay task or the Godot editor isn't running.
