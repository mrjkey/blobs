# Architecture

How the project is put together, and the rules that keep it easy to extend and
hot-reloadable while the game runs. Read this before adding a component or a mode.

## Folders

Folders are grouped by concept, then by feature: a feature's scenes, scripts
and resources sit together in its folder. How things *look* lives separately,
in `themes/` (see Themes below).

| Folder | What goes there |
|---|---|
| `autoload/` | Global singletons: `Session` (choices that survive scene changes, saved settings and gameplay settings, the chosen theme), `Juice` (shake, hitstop, sparks, the `impact` signal) + its settings `.tres`, `Sfx` (synthesised sound kit) |
| `core/` | Machinery every mode composes: `settings/` (`GameSettings`: the player's gameplay options), `physics/` (`BlobPhysics`, `PhysicsFeel`), `camera/` (`GameCamera`), `fx/` (`FxLayer`), `audio/` (`Techno`: music + beat clock) |
| `entities/` | Things that act. `blob/` (`Blob`, `BlobBody`, `BlobTrail`, `EnergyMeter`, `BlobStats` + `stats/`, `MoveRules`), `ball/` (`Ball`, `BallBody`: the football, a Blob with no moves), `controllers/` (`PlayerInput` + `profiles/`, `BotBrain` and its subclasses, `BotLevel` + `levels/`), `enemies/` (`lasers/`: `LaserEmitter`, `LaserTurret`, `LaserShip`, `LaserDirector`, `LaserSettings`) |
| `level/` | What the level is made of. `arenas/` (`box_room/`, `ring/`, `track/`, `pitch/`: the floors and walls a mode plays on, with their own rules like ring-out, the kill lasers or goals), `obstacles/` (`WallBlock`, `Bumper`), `pickups/` (`food/`: `Food`, `FoodSpawner`) |
| `themes/` | `GameTheme`, `ThemeStyle`, `ThemeBackdrop`, `ThemeSkin` (rare overrides); one folder per theme (`classic/`, `neon/`) with its `.tres`, HUD style and backdrop |
| `modes/` | One folder per game mode (`treadmill/`, `ring/`, `football/`): the scene that composes components, the round rules (`GameMode` subclasses) and its `ModeInfo`. Also `PlayerSlot` (one seat of a lineup) |
| `ui/` | `menus/` (main menu, `lobby/` (game and player select), settings; `options/`: `OptionList`, `OptionRow`, shared by the settings screen and the lab), `hud/` (`Hud`, `EnergyHud`, `ScoreBar`), `themes/menu_theme.tres` |
| `sandbox/` | Test bench scene for trying components, its props, and `lab/` (the Tab menu) |
| `docs/` | This file |
| `addons/`, `tools/` | Live-reload plumbing (see CLAUDE.md) |

Where a new thing goes: something that acts on its own (an enemy, a new kind of
blob) under `entities/`; something placed in a level under `level/`: a solid
or trap blobs bump into in `obstacles/`, something they collect in `pickups/`,
a whole new floor in `arenas/`. It draws itself (see Themes).

## Scenes, scripts, resources

- **Scenes** (`.tscn`) hold structure: which nodes exist and how they're arranged.
  Anything you can point at in the game is a scene, or a node with a `class_name`
  script that you can add from the editor's Create Node dialog.
- **Scripts** (`.gd`) hold behaviour. Spawning instances of scenes at runtime is
  fine; building a node tree by hand in `_ready()` is not (put it in a scene).
- **Resources** (`.tres`) hold numbers you tune: `BlobStats`, `PhysicsFeel`,
  `JuiceSettings`, `InputProfile`, `TrackSettings`, `LaserSettings`, and the
  themes' colours and styles. Many nodes can share one.
- Structural one-offs (a room's size, a spawn position) are `@export`s on the
  node in the scene.

## How components talk

A component never holds a reference to "the game". It works on its own and
finds what it needs:

- **Groups** for finding things. Contract groups are joined in the script's
  `_enter_tree()`, so a node can't be placed without them:
  - `blobs`: every `Blob`. Dead blobs stay in the group with `alive == false` until they free themselves.
  - `blob_colliders`: anything blobs bounce off. Implements `collide(blob: Blob, feel: PhysicsFeel)`.
  - `arena`: at most one. Optional `is_in_mud(pos) -> bool`, and `ring_radius` for ring bots and the food spawner. The football `Pitch` is one too (`own_goal(team)`, `target_goal(team)`).
  - `balls`: every `Ball` (also in `blobs`). The pitch watches it for goals; football bots chase it.
  - `food`: pellets bots look for.
  - `fx`: the `FxLayer` that `Juice.burst()` / `Juice.shockwave()` draw on.
  - `music`: at most one `Techno`. `Techno.current_beat()` / `Techno.current_kick()` read it (a steady 128 BPM / no kick without it).
  - `lasers`: every `LaserEmitter`; the `LaserDirector` schedules them.
  - `grid`: the neon backdrop's `NeonGrid`; call `impulse(world_pos, strength, radius)` on the group to ripple it, `follow_y(y)` to scroll it.
  - `kill_lasers`: at most one `KillLasers`; `kill_top()` / `kill_bottom()` for treadmill bots.
- **Signals** for reporting upward: `Blob.pushed`, `Blob.dashed`, `Blob.ate_food`, `Blob.died`,
  `BlobPhysics.blob_contact`, `RingArena.blob_ringed_out`, `Pitch.goal_scored`, `Juice.impact`. The
  mode script connects to them. Anything that knocks a blob out calls
  `blob.die()`; the mode only listens to `Blob.died`.
- **Autoloads** for feedback anything can trigger: `Juice.shake()`,
  `Juice.hitstop()`, `Juice.burst()`, `Juice.impact_at()`, `Sfx.play()`.
- **Missing collaborators are fine.** No `FxLayer`? No sparks. No arena? No mud,
  and ring bots assume a ring at the origin. Never crash because a scene is
  missing something.

### Who steers a blob

`Blob` only moves where `move_dir` says, pushes when `request_push()` is
called and dashes on `request_dash()`. A controller child sets those: `PlayerInput` (keys from an
`InputProfile` resource, plus one gamepad) or a `BotBrain` subclass. The
controller registers itself as `blob.controller`, so `blob.is_human()` works.
`blob.active = false` makes controllers leave the blob alone (countdowns).

### Who plays: lineups

A game's players are its lineup: up to 4 `PlayerSlot`s (`ModeInfo.MAX_SLOTS`).
A slot is a human (an `InputProfile` for keys and pad buttons, plus a gamepad
by device id) or a computer at a `BotLevel` (`entities/controllers/levels/`:
idle, passive, easy, normal, aggressive), and has a seat number (P1..P4) and
a colour index into `GameTheme.palette()`.

- **Main menu → lobby → mode.** PLAY opens the lobby (`ui/menus/lobby/`).
  Its top picks the game, one of the lobby's `modes` (each a `ModeInfo`:
  title, scene path, min/max/default seats, max humans, teams, options), and
  that game's options; the last game picked is kept in `Session.next_mode`.
  Players join from any device, pick a colour, take a seat (which also picks
  their team), set the CPUs' levels and open or close seats; the lobby writes
  `Session.lineup` + `Session.lineup_mode` and starts the mode. Esc in the game
  goes back to the lobby with the same seats.
- **Started on its own (F6).** `GameMode.lineup()` makes
  `PlayerSlot.default_lineup(info)`: P1 on the keyboard, each connected
  gamepad takes the next seat, CPUs (normal) fill the rest. With one human
  seat, P1 uses the keyboard and the first gamepad.
- **In the mode.** `GameMode` resolves `slots` before `_spawn_blobs()`; the
  mode places a blob per slot with `spawn_slot(i, pos)`, which makes the
  `PlayerInput` or the mode's `_new_brain()` with the slot's level. Humans are
  tagged P1..P4 when there's more than one.
- **Teams.** A `ModeInfo` with `teams` (e.g. `["BLUE", "RED"]`) is a team
  mode: seats alternate between the teams (`team_of()`: P1 and P3 against P2
  and P4). `spawn_slot()` sets `blob.team`. Each seat plays in its team's
  colours, the first seat in the team colour, the second in its partner colour
  (blue + purple, red + orange: `GameTheme.team_member_color()`, theme values
  `team.0`, `team.1`, `team.0.second`, `team.1.second`), unless the player
  picked their own (`PlayerSlot.color_in()`). `BlobBody` draws a
  team-coloured spot under a blob with a team.
- **Mode options.** `ModeInfo.options` lists `GameSettings` options (marked
  `only = "lobby"`) that the lobby shows under the game's name, like
  football's TIME and GOALS. The mode reads them with `GameSettings.choice()`.

### Moves and energy

Which moves a blob has comes from `blob.rules`, a `MoveRules`: the dash
(`NONE`, `BUMP`: solid, stuns what it hits; `GHOST`: passes through blobs,
pushes and lasers, and with `ghost_obstacles` walls and bumpers too) and
whether moves cost energy (`OFF`: cooldowns, `DASH`, `ALL`). Every blob
shares `GameSettings.rules()`, built from the player's settings, so a change
in a menu applies at once. The numbers
(dash speed and time, bar size, regen, costs) are in `BlobStats`. Anything
that hits blobs skips `blob.is_ghost()`; obstacles skip
`blob.phases_obstacles()`; the arena's own walls never do. The bar is drawn
by the blob's `EnergyMeter` child (above, below, ring) or the `EnergyHud` in
the HUD, whichever the "meter" setting picks.

### Settings

`GameSettings.OPTIONS` lists the options (key, label, choices with help
text, default): the look (theme, glow) and the gameplay ones. Gameplay picks
are saved in `Session.settings`, the look in `Session.theme_name` /
`Session.glow`; read any of them with `GameSettings.choice("key")`, change
them with `set_choice()`. The main menu's SETTINGS screen and the sandbox lab
list them; `only = "menu"` / `only = "lab"` keeps an option to one of the two,
and `only = "lobby"` marks a mode's match option (see Mode options above).
New option: add an entry, then read it where it's used (or in
`GameSettings._sync()` for a `MoveRules` field).

### Update order

Set with `process_physics_priority` in each script's `_ready()`:

1. `-10` controllers (`PlayerInput`, `BotBrain`) set `move_dir` / request pushes
   - `-8` the treadmill mode scrolls the camera, `-7` `TrackGenerator` builds ahead
   - `-6` `LaserDirector`, `-5` `LaserEmitter`s (dodging overrides the bots' `move_dir`)
2. `0` `BlobPhysics`: substeps of motion, blob-vs-blob, then every `blob_colliders` node
3. `10` `Blob`: cooldowns, energy, push windup and release, starting a dash
4. `20` rules that look at where blobs ended up: `RingArena` ring-out, `KillLasers`, `Food` eating

Drawing runs in `_process` / `_draw`, painted in the theme's style.

### Hitstop

`Juice.hitstop()` sets `Engine.time_scale` to 0 for a moment of real time. Every
`delta` is then 0, so movement, timers, particles and jelly freeze together
without anyone checking a flag. Code that must keep running (Juice itself) uses
real time.

## Hot-reload rules

What reaches the running game (see CLAUDE.md for the plumbing):

| You change | When the game sees it |
|---|---|
| a `.tres` (stats, settings, theme, environment) | immediately |
| a `.gd` method body | immediately; node state is kept, `_ready()` does not run again |
| a `.tscn` (nodes, exported values on nodes) | when that scene loads again (Esc to the menu and back) |

So:

1. **Numbers you iterate on go in a resource**, not in `const`s or scene
   overrides. A `.tres` only stores values that differ from the script's
   defaults; to tune one, set it in the Inspector or add the line to the `.tres`.
2. **Read values when you use them.** Don't copy a resource value into a
   variable in `_ready()`: that copy won't update. Derive things on the fly
   (`Blob.radius` is a getter over `stats` for this reason).
3. **Keep `_ready()` small.** It only runs once, so a fix there needs a scene
   reload. Logic in `_physics_process` / `_process` / `_draw` updates live.
4. **Don't build node trees in code.** Put them in a `.tscn`; spawn scenes.
5. **Use `class_name`** for types other scripts refer to, instead of
   `preload("res://path")`, so moving a file doesn't break its users. Scene
   paths go in `@export_file` vars.
6. **`@tool` + setters that `queue_redraw()`** for anything worth previewing in
   the editor (see `BoxRoom`). Keep `@tool` scripts free of game-time side effects.
7. **Don't make edits apply by restarting the scene for the user.** Game state
   should survive changes.

## Themes

The player picks a theme in SETTINGS (THEME: NEON / CLASSIC; neon by
default). `Session.theme_name` saves it; `GameTheme.current()` returns its
`GameTheme` resource (`themes/<name>/<name>.tres`; in the editor the default
one, so `@tool` previews draw too). Switching never changes a scene.

**Every element has one default drawing, in its own `_draw()`.** Themes only
adjust it, so a new element works in every theme as soon as it draws itself:

- **`ThemeStyle`** (the theme's `style`) is how things are painted: plain or
  glowing colours (`glow`, `brightness`), solid or dark-glass bodies (`fill`),
  darker or bright edges (`edge`, `edge_flash`), and on/off features:
  `shadows`, `highlights` (shine), `halos`, `trail_frames` (0 = no trails),
  `spark_streak` (0 = round sparks), `pulse` (reacting to the music's kick),
  `bold` (arena wall thickness). Draw with its primitives so the theme applies:
  `style.body()` / `disc()` / `box()` for solid shapes (shadow, halo, fill,
  edge), `line()`, `ring()`, `dot()`, `outline()` for strokes, `color(c, k)`
  for a colour at glow intensity `k`, `kick(node)` for the beat. A theme is
  numbers and flags in its `.tres`; no theme has code.
- **Values** (`theme.value("wall.color", COLOR)`): an element's colours and
  options by name, each with the element's own default (a `const` in the
  element; the defaults are the classic look). A theme's `values` only lists
  what differs. Effect colours (sparks, bursts) use the same names. Options are
  values too: `"food.shape"` is `"round"` or `"diamond"`.
- **Overrides** (rare): a `ThemeSkin` in the theme's `overrides` under an
  element's name replaces that element's whole drawing. Every element's
  `_draw()` starts with `if theme.draw_override("name", self): return`.
  None are used yet.
- **The rest of a `GameTheme`:** `hud` (the HUD's UI theme), `backdrop` (a scene
  drawn behind everything, e.g. the neon grid), `glow` (a bloom scene, used when
  `Session.glow` is on), `clear_color`, `beat_zoom` (camera thump on the kick),
  and the player, P2 and bot colours. `ThemeBackdrop`, near the top of every
  game scene, adds the backdrop and glow and sets the clear colour.

Draw order in a game scene: backdrop z -10, arena z -1, then trails (z -1,
later in the tree), obstacles, food and blobs at 0, lasers and kill lasers z 5,
`FxLayer` z 10.

## The standalone rule

Every component scene works when dropped into `sandbox/sandbox.tscn` (a room,
`BlobPhysics`, a player and two bots), without a mode script. If it needs
something, it finds it through a group and copes when it isn't there. This is
what makes a gallery of objects possible.

**The lab** (`sandbox/lab/`, Tab in the sandbox) is a pause menu with every
setting plus the sandbox-only ones (props), changed live. `sandbox.gd`
`_apply_lab()` handles the sandbox-only ones. To try a new idea: add a
`only = "lab"` option to `GameSettings.OPTIONS` and read it there.

## Recipes

**New obstacle or trap** (bumper, wall, spikes...): a scene in `level/obstacles/`
whose root script joins `blob_colliders` in `_enter_tree()` and implements
`collide(blob, feel)`. Use `BlobPhysics.bounce()` for solid surfaces and
`BlobPhysics.wall_feedback()` for the hit effects. Put tunables in exports or a
resource. Draw it (next recipe). Try it in the sandbox.

**Drawing a new element:** in its `_draw()`, `var theme := GameTheme.current()`,
`if theme.draw_override("spikes", self): return`, then draw with
`theme.style` primitives and `theme.value("spikes.color", COLOR)`. That's all:
it works in every theme. Later, a theme can set `"spikes.color"` (or a new
option) in its `values`.

**New pickup or power-up:** like `Food` in `level/pickups/`: join a group bots
can look for, check overlap with living blobs in `_physics_process`, apply the
effect to the blob, `queue_free()`.

**New enemy:** under `entities/enemies/`. Beat-driven ones can extend
`LaserEmitter` (see `LaserTurret`, `LaserShip`: they only give their shape).

**New theme:** a folder under `themes/` with a `<name>.tres` (a `GameTheme`
with a `ThemeStyle` and the `values` that differ), a HUD theme, optionally a
backdrop, and an entry in `Session.THEMES`.

**New controller:** a node script that sets `blob.controller = self` in
`_ready()`, runs at physics priority -10, and writes `move_dir` /
`request_push()` while `blob.alive and blob.active`. Bots extend `BotBrain` and
override `_decide()`, `_target_score()`, `_food_ok()`.

**New tuning knob:** add an `@export` with a comment to the right resource class
(`BlobStats`, `PhysicsFeel`, `JuiceSettings`...), read it where it's used.

**New mode:** a folder under `modes/` with a scene that places the components
(`ThemeBackdrop`, camera, arena, `BlobPhysics`, `FxLayer`, `Hud`, a `Blobs` node) and a script
that extends `GameMode`: place one blob per slot in `_spawn_blobs()` with
`spawn_slot()`, return the mode's bot brain from `_new_brain()`, switch
hazards on in `_on_play_started()` and off in `_on_round_over()`, override
`_check_round_over()` for other win rules. Add a `ModeInfo` `.tres` (set it as
the scene's `info`) and add it to the lobby's `modes` (`ui/menus/lobby/lobby.tscn`).
Team modes set `teams` in it; match rules go in `options`. See `modes/ring/`
(every blob for itself) and `modes/football/` (teams, a ball, a clock).

## Working with the editor open

- The editor holds open scenes in memory and saves them on F5. Close the editor
  (or at least the affected scene tabs, choosing "Don't Save") before files are
  moved, renamed or deleted, or before `project.godot` is edited, or it writes
  the old versions back.
- After new `class_name` scripts appear, a game that was already running doesn't
  know them: restart it. Clicking into the editor lets it rescan the files.
- Easier in the editor than in code: AnimationPlayer keyframes, tuning the glow
  Environment with live preview, arranging spawn points and sandbox props.

## Checking work without the editor

Godot's Windows console binary works headless from WSL:

```sh
GD=/mnt/c/godot/Godot_v4.7.2-stable_win64_console.exe
W=$(wslpath -w .)
"$GD" --headless --path "$W" --import                          # rescan: class cache, .uid files
"$GD" --headless --path "$W" res://modes/ring/ring.tscn --quit-after 400   # run a scene, print errors
```

- `--import` is needed after adding `class_name` scripts or moving files, or
  scenes fail with stale UID paths. While the editor is open, run it on a copy
  of the project (e.g. in a temp folder, without `.godot/`) so the two don't
  fight over `.godot/`.
- For a scripted test (`--script some_test.gd` extending `SceneTree`),
  autoloads aren't compile-time identifiers yet. Don't name project classes
  in the test script at all (no `var b: Blob`, no `x is WallBlock`): that
  compiles them before `Juice` exists, and every script that depends on them
  fails. Use untyped variables and duck typing (`"kicker" in node`), and reach
  autoloads with `root.get_node("Juice")`.
- A test copy should get its own `config/name` in `project.godot`, so its
  `user://settings.cfg` (theme, glow) isn't the real game's.
- Screenshots: the same `--script` approach without `--headless` opens a window
  and can save `root.get_viewport().get_texture().get_image()` as PNG.
- Check new `class_name`s against Godot's built-in classes (`Skin` is one):
  shadowing a native class is a compile error.
