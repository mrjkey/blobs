# Refactor plan: composable scenes

Status of the move from code-built prototypes to standalone scenes, and the
remaining work. Rules and conventions are in [ARCHITECTURE.md](ARCHITECTURE.md);
this file is the to-do list. Delete it when Phase 5 is done.

**Goal:** no new gameplay. Port classic, neon and treadmill onto small
standalone scenes, remove duplicated code, put feel numbers in `.tres`
resources (live-tweakable), and make every component work dropped into
`sandbox/sandbox.tscn` (groundwork for an object gallery).

**Constraint:** the feel must not change. Port the math line for line from the
old scripts; default resource values equal the old `const`s.

## Status

| Phase | State |
|---|---|
| 0. Cleanup and moves | done |
| 1. Foundations | done |
| Project move to `C:\dev\example_game` | done |
| 2. Classic ring on scenes | built; waiting on a feel check against "CLASSIC (OLD)" |
| 3. Neon on scenes | to do |
| 4. Treadmill on scenes | to do |
| 5. Delete the old code | to do |

## Moving the project to C:\dev\example_game (done)

Why: Windows Godot reads a project in WSL over the `\\wsl.localhost` share, and
every file open is slow. Measured first scene loads (headless): sandbox 3484 ms
in WSL vs 111 ms on C:; neon 2309 vs 97; treadmill 2200 vs 113. The scene-based
layout means more small files, so this would only get worse.

Steps:

1. Commit, or copy the whole folder including `.git`. A fresh `git clone`
   loses uncommitted work. `.godot/` can be left behind; the editor rebuilds it.
2. From WSL the project becomes `/mnt/c/dev/example_game`. Pick one git (WSL
   or Windows) and keep using it. If using Windows git, set
   `core.autocrlf=false` so line endings don't churn.
3. Fix the live-reload tools. They assume the project is in WSL:
   - `tools/godot_lsp_relay.py`: done. `godot_uris()` sends Godot
     `file:///C:/dev/example_game` and maps its replies (`file:///C%3A/...`,
     checked against the live editor) back to `file:///mnt/c/dev/example_game`.
     The `//wsl.localhost` case still works if the project moves back.
   - Alternative: open the folder in VS Code on Windows directly (not through
     Remote-WSL). Paths then match natively and the relay isn't needed; point
     `godotTools.lsp.serverPort` back at Godot's port and drop the VS Code task.
     `claude_godot_sync.py` still needs a path to the language server (it goes
     through the relay today, via `godot_lsp_save.py`).
   - `tools/godot_lsp_save.py` and `tools/claude_godot_sync.py` find the project
     from their own location (`PROJECT`), so they follow the move.
   - Update CLAUDE.md's live-reload section to match.
4. Claude Code keys its per-project memory and history on the path, so a
   session in the new folder starts fresh: point it at this file.
5. Check: open the project, make sure Claude Sync is enabled, edit a `.gd` file
   in VS Code and see it reload in the running game, then have Claude change a
   `.tres` value and see it live.

## What exists now (Phases 0 and 1)

New, scene-based (use these):

| Path | What |
|---|---|
| `autoload/juice.gd` (+ `juice_settings.gd/.tres`) | Autoload `Juice`: `shake()`, `hitstop()` (Engine.time_scale = 0 for real-time seconds), `burst()`, `shockwave()`, `impact_at()` + `impact` signal |
| `audio/sfx.gd` | Autoload `Sfx`: synthesised sounds, all tones including `zap`, `charge`, `bumper` |
| `autoload/session.gd` | Autoload `Session`: `treadmill_mode`, `glow` (saved to `user://settings.cfg`) |
| `blob/blob.tscn`, `blob/blob.gd` | `Blob`: movement, push (`_release_push`, ported from `game.gd::do_push`), `take_hit()`, `bump()`, `eat()`, `die()` (with elimination effects), signals `pushed`, `ate_food`, `died`; `active` flag for countdowns; `radius` is a getter over `stats` |
| `blob/blob_stats.gd`, `blob/stats/{default,heavy}.tres` | `BlobStats`: every per-blob number from `tuning.gd` |
| `blob/body/blob_body.gd` | `BlobBody`: jelly spring + classic drawing, `swell_kick()` |
| `blob/control/` | `PlayerInput` + `InputProfile` (`profiles/solo,p1,p2.tres`), `BotBrain` (base), `RingBotBrain` |
| `physics/blob_physics.gd`, `physics_feel.gd`, `default_feel.tres` | `BlobPhysics`: substeps, blob-vs-blob with feedback, calls `collide(blob, feel)` on group `blob_colliders`; statics `bounce()` and `wall_feedback()` for colliders |
| `arena/box_room.gd` | `BoxRoom` (@tool): rectangular walled floor, a `blob_colliders` example |
| `fx/fx_layer.gd/.tscn`, `fx/game_camera.gd` | `FxLayer` (group `fx`), `GameCamera` (fits `view_size`, shakes by `Juice.shake_amount`, `zoom_pulse`) |
| `neon/neon_glow.gd/.tscn`, `neon_glow_env.tres` | Optional bloom; only on when `Session.glow`; HDR 2D on while in the tree |
| `sandbox/sandbox.tscn` | Test bench: room, player, a bot, a heavy bot |
| `ui/menus/`, `ui/themes/menu_theme.tres` | Menus (main menu has SANDBOX and GLOW buttons) |
| `arena/ring_arena.gd` | `RingArena` (@tool): ring, mud, circular wall with hit flashes; ring-out timer sets `blob.ring_danger` and calls `blob.die()` while `counting` |
| `food/food.gd/.tscn`, `food/food_spawner.gd` | `Food` (eaten on touch), `FoodSpawner` (timer, max, free spot inside the arena's ring; `enabled`) |
| `ui/hud/hud.gd/.tscn`, `ui/themes/hud_theme.tres` | `Hud`: `set_status()`, `set_hint()`, `show_banner()`, `await play_countdown()` |
| `modes/game_mode.gd` | `GameMode`: spawning, countdown, `Blob.died` → banner + last-standing win check; hooks `_spawn_blobs()`, `_on_play_started()`, `_on_round_over()` |
| `modes/ring/ring.tscn`, `ring_game.gd` | Classic ring on the components (menu: CLASSIC RING; old one is CLASSIC (OLD)) |

Old, still running classic/neon/treadmill (don't extend; delete in Phase 5):
`scripts/` (`game.gd`, `blob.gd`, `ai_brain.gd`, `fx.gd`, `sfx.gd`, `tuning.gd`,
`neon/*`, `treadmill/*`), root `main.tscn`, `neon.tscn`, `treadmill.tscn`.
`game.gd` preloads its sound kit as `OldSfx` so it doesn't shadow the `Sfx` autoload.

## Phase 2: classic ring

Built as below, except: the arena knocks blobs out itself (`blob.die()`), and
`GameMode` reacts to `Blob.died` from any cause, so treadmill's kill lasers can
just call `die()` too. Left to do: the user's feel check, then remove the
CLASSIC (OLD) button (the old `main.tscn` goes in Phase 5).

Source: `scripts/game.gd` (and `tuning.gd` arena/food/round consts).

- `arena/ring_arena.gd` + `ring_arena.tscn` (`RingArena`, `@tool`):
  - Joins groups `arena` and `blob_colliders`. Exports `ring_radius` (300), `wall_radius` (380), `ring_out_time` (1.0), colours (setters `queue_redraw()`).
  - `is_in_mud(pos)`: outside the ring.
  - `collide(blob, feel)`: circular wall. Port `game.gd::_collide_walls` using `BlobPhysics.bounce()` / `wall_feedback()`, plus the wall-hit flash list.
  - Ring-out: per-blob outside timer (port `_check_ring`), sets `blob.ring_danger` (0..1, already drawn by `BlobBody`), emits `blob_ringed_out(blob)`. Only counts while a `counting` flag is on, so the mode can keep it off during the countdown.
  - `_draw()`: port the arena part of `game.gd::_draw` (mud stripes, floor, pulsing edge, wall flashes).
  - Runs at physics priority 20 (after blob abilities).
- `food/food.gd` + `food.tscn` (`Food`, group `food`): pop-in and bob drawing (from `game.gd::_draw`), checks overlap with living blobs, then `blob.eat()`, burst, `Sfx.play("pop")`, `queue_free()`. Radius and colour as exports.
- `food/food_spawner.gd` (`FoodSpawner`): timer (interval 2.0 ±30%), max 6, random point inside `ring_radius * 0.8` away from blobs (port `_spawn_food`), only while `enabled`. Exports `food_scene: PackedScene`.
- `ui/hud/hud.tscn` + `hud.gd` (`Hud`, a CanvasLayer): Status, Hint and Banner labels with anchors; `ui/themes/hud_theme.tres` (outlined text). API: `set_status(text)`, `set_hint(text)`, `show_banner(text, color, life := -1.0)`, `play_countdown(seconds)` (await-able, plays the "pop" sounds like `_tick_countdown`). Banner fade like `_banner_life`.
- `modes/game_mode.gd` (`GameMode`, shared by ring and treadmill):
  - Exports `blob_scene`, the player/bot colours and names (the `bot_looks` lists), and the countdown time.
  - Spawning helper: instantiate, set color/name/stats, add a controller node, set `active = false`, add to the `Blobs` node.
  - Countdown via HUD, then `active = true` for everyone.
  - `eliminate(blob)` calls `blob.die()` and shows a banner if it was human.
  - Round-over check and banners (YOU WIN / X WINS / DRAW).
  - `restart` reloads the scene; `quit` goes to the menu (`@export_file`).
  - States: countdown, playing, over.
- `modes/ring/ring_game.gd` (extends `GameMode`):
  - Spawns on a circle at `ring_radius * 0.6`, facing the centre.
  - Connects `RingArena.blob_ringed_out`, turns on the arena counting and the food spawner when play starts.
  - Status text: "Blobs left: N  Your size: 1.25x".
- `modes/ring/ring.tscn`: GameCamera (view 820x820), RingArena, BlobPhysics, Blobs, FoodSpawner, FxLayer, Hud. Script `ring_game.gd`.
- Main menu: CLASSIC RING → `ring.tscn`; add a temporary "CLASSIC (old)" → `main.tscn` for side-by-side comparison; remove it once they match.
- Optional: add `start_mass` to `BlobStats` so `heavy.tres` is also harder to push (resistance comes from mass, and everyone starts at 1).

Check: countdown, push, food growth, mud, ring-out timer ring, wall flashes, win banner, R, Esc; compare against "CLASSIC (old)".

## Phase 3: neon

Sources: `scripts/neon/*`.

- `neon/neon_look.gd`: move `hdr()` here (from `scripts/neon/neon_look.gd`) with `BRIGHTNESS` as an export on a small `NeonPalette` resource (`neon/neon_palette.tres`), along with the neon colours from `neon_tuning.gd`.
- `blob/body/neon_blob_body.gd` (extends `BlobBody`, overrides `_draw`, `_draw_eyes`, `_draw_status`): port from `scripts/neon/neon_blob.gd`. Draws `blob.tag`.
- `blob/body/blob_trail.gd`: motion trail node (port `_record_trails` and the trail drawing; it's currently duplicated in `neon_game.gd` and `treadmill_game.gd`). Child of the blob, drawn in world space (`top_level`) under the body.
- `blob/neon_blob.tscn`: inherited from `blob.tscn`, Body script swapped to `neon_blob_body.gd`, plus a Trail node.
- `arena/neon_ring_arena.gd` (extends `RingArena`, overrides `_draw`; pulses with the music's kick).
- `food/neon_food.gd/.tscn` (spinning diamond drawing; currently duplicated in neon and treadmill).
- `fx/neon_fx_layer.gd` (extends `FxLayer`, glowing streaks; port `scripts/neon/neon_fx.gd`).
- `neon/neon_grid.gd/.tscn`: port; listens to `Juice.impact` (replaces `_on_impact`); reads the beat pulse from group `music`. Knobs as exports or a resource.
- `audio/techno.gd/.tscn` (group `music`): port; `beat()`, `kick_env()`; BPM and volume exports. Renders on a thread at startup (keep it).
- `lasers/`:
  - `laser_emitter.gd`: the shared charge → lock → fire state machine, target tracking, bot dodging (uses `controller.skill` of `BotBrain`s), hit test, `take_hit(d, dv, stun, clean_hit = false)`, grid ripple via `Juice.impact_at` along the beam, telegraph and beam drawing. Virtual `beam_length(from, dir)`. Port from `neon_game.gd::_update_turret/_dodge/_fire/_draw_overlay` (the treadmill ship version is the same with small differences).
  - `laser_settings.gd` + `.tres`: charge/lock/fire beats, width, impulse, start delay, colours.
  - `laser_turret.gd/.tscn`: orbits outside the ring wall; beam length to the far side of the circle.
  - `laser_director.gd`: once per bar picks idle emitters (in group `lasers`) to fire on the next downbeat, ramping up after 30 s and 60 s of play (port `_schedule_lasers`). Needs `enabled` (on when play starts).
  - Physics priority -5 so dodging overrides bot steering after the brain runs (the old code did this in `_before_simulate`).
- `modes/ring/neon.tscn`: same `ring_game.gd`; places NeonRingArena, neon_blob as `blob_scene`, NeonFxLayer, NeonGrid, Techno, NeonGlow, six LaserTurrets, LaserDirector, Hud with `ui/themes/neon_hud_theme.tres`. GameCamera view grows to fit the turrets; `zoom_pulse` from the kick (small node or GameCamera export reading group `music`).
- Menu NEON → `modes/ring/neon.tscn`.

Check: lasers telegraph and fire on the beat, bots dodge, grid ripples on hits, trails, glow on/off.

## Phase 4: treadmill

Sources: `scripts/treadmill/*`.

- `track/track_settings.gd` + `.tres`: from `treadmill_tuning.gd` (scroll speeds, chunk sizes, gaps, kicker/bumper strength, colours, bots per mode).
- `track/wall_block.gd/.tscn` (`blob_colliders`): rectangle with a `kicker` flag; port the rect branch of `treadmill_game.gd::_collide_walls`, `_hit_flat_wall`, `_kick`, plus the drawing.
- `track/bumper.gd/.tscn` (`blob_colliders`): pinball bumper (port the bumper branch and `_kick`; flash; drawing).
- `track/side_walls.gd/.tscn` (`blob_colliders`): the two long walls, drawn for the visible span.
- `track/kill_lasers.gd/.tscn`: top and bottom lasers that follow the camera; eliminate blobs past them (emit a signal; the mode eliminates). Port `_check_edges` and the overlay drawing.
- `track/track_generator.gd`: generates chunks ahead of the camera by spawning `wall_block`, `bumper` and `neon_food` scenes; culls behind (port `_generate_ahead`, `_gen_chunk`, `_random_wall_rect`, `_blocked`, `_cull_behind`). Difficulty by distance.
- `lasers/laser_ship.gd/.tscn`: uses `laser_emitter.gd`; cruises beside the track, pins while charging, never aims along the wall, beam length to the far side wall.
- `blob/control/track_bot_brain.gd` (extends `BotBrain`): port `scripts/treadmill/treadmill_brain.gd` (`_decide`, `_attack_dir`, `_avoid_obstacles`, `_go_around`; `_target_score` and `_food_ok` from its `_pick_target` / `_best_food`). Reads the kill lines from `KillLasers` (group) and obstacles from `blob_colliders`.
- `modes/treadmill/treadmill_game.gd` (extends `GameMode`): modes from `Session.treadmill_mode` (and `--mode=` on the command line), players with `PlayerInput` (`p1`/`p2`/`solo` profiles, `pad_slot` per the old pad assignment: two pads one each, one pad to P2), scrolling camera (`GameCamera` gets a position; view height 820), distance, round-over rules (GAME OVER / YOU WIN / P1 WINS / THE BOTS WIN), R/Start rematch and Esc/Back to the treadmill menu (the old one used raw key and button checks).
- `modes/treadmill/treadmill.tscn`; the treadmill menu points at it.

Check: all 4 menu modes, keyboard sharing and controllers, kickers, bumpers, ships, edge lasers, rematch, Esc.

## Phase 5: delete the old code

- Delete `scripts/`, root `main.tscn`, `neon.tscn`, `treadmill.tscn`, `SCENES_GUIDE.md`, and this file.
- `grep -r "scripts/" --include=*.gd --include=*.tscn` returns nothing.
- Update `README.md` (controls, modes, where tuning lives now) and CLAUDE.md (pointer to ARCHITECTURE.md, paths).
- Make sure every menu entry launches.

## Things the user does in the editor

- After each phase: open the new scenes and check for errors, play the new mode next to the old one, report feel differences. Check Claude Sync is still enabled.
- Close the editor before Claude moves files or edits `project.godot`, and choose "Don't Save" if asked.
- Optional, easier in the editor: AnimationPlayer keyframes (banner pop, food pop-in; code tweens by default), tuning the glow Environment with live preview, arranging spawn points and sandbox props.

## How to check work without the editor

Godot's Windows console binary works headless from WSL:

```sh
GD=/mnt/c/godot/Godot_v4.7.2-stable_win64_console.exe
W=$(wslpath -w .)
"$GD" --headless --path "$W" --import                          # rescan: class cache, .uid files (editor closed)
"$GD" --headless --path "$W" res://modes/ring/ring.tscn --quit-after 400   # run a scene, print errors
```

- `--import` is needed after adding `class_name` scripts or moving files, or
  scenes fail with stale UID paths.
- For a scripted test (`--script some_test.gd` extending `SceneTree`),
  autoloads aren't compile-time identifiers: don't type variables as `Blob`
  etc. in the test script (it compiles `blob.gd` before `Juice` exists), and
  reach autoloads with `root.get_node("Juice")`.
