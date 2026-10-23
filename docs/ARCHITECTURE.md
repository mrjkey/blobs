# Architecture

How the project is put together, and the rules that keep it easy to extend and
hot-reloadable while the game runs. Read this before adding a component or a mode.

## Folders

Folders are grouped by concept, then by feature: a feature's scenes, scripts
and resources sit together in its folder. How things *look* lives separately,
in `themes/` (see Themes below).

| Folder | What goes there |
|---|---|
| `autoload/` | Global singletons: `Session` (choices that survive scene changes, saved settings and gameplay settings, the chosen theme), `Juice` (shake, hitstop, sparks, the `impact` signal) + its settings `.tres`, `Sfx` (synthesised sound kit), `Net` (online play: hosting, joining, messages; see `docs/ONLINE.md`) |
| `core/` | Machinery every mode composes: `settings/` (`GameSettings`: the player's gameplay options), `physics/` (`BlobPhysics`, `PhysicsFeel`), `camera/` (`GameCamera`), `fx/` (`FxLayer`), `audio/` (`Techno`: music + beat clock), `net/` (`LanDiscovery`: finding hosted games; `NetLag`: pretend lag for testing) |
| `entities/` | Things that act. `blob/` (`Blob`, `BlobBody`, `BlobTrail`, `EnergyMeter`, `BlobStats` + `stats/`, `MoveRules`), `ball/` (`Ball`, `BallBody`: the football, a Blob with no moves), `slash/` (`Slash`: one blade swing, spawned on the blob), `shots/` (`Shot`, `Spit`: things blobs fire that fly on their own), `controllers/` (`PlayerInput` + `profiles/`, `BotBrain` and its subclasses, `BotLevel` + `levels/`), `enemies/` (`lasers/`: `LaserEmitter`, `LaserTurret`, `LaserShip`, `LaserDirector`, `LaserSettings`), `buddy/` (`Buddy`: the character Don't Get Fat!'s blobs look after) |
| `level/` | What the level is made of. `arenas/` (`box_room/`, `ring/`, `track/`, `pitch/`: the floors and walls a mode plays on, with their own rules like ring-out, the kill lasers or goals), `obstacles/` (`WallBlock`, `Bumper`), `pickups/` (`food/`: `Food`, `FoodSpawner`; `health/`: `BeltPickup`, `HealthItem`, `PowerUp` for Don't Get Fat!), `maps/` (hand-made levels: `Map`, `SpawnPoint`, `FoodSpot`, `FinishLine`, `Gate`, `BeltSign`, `RushZone`, and one folder per map) |
| `themes/` | `GameTheme`, `ThemeStyle`, `ThemeBackdrop`, `ThemeSkin` (rare overrides); one folder per theme (`classic/`, `neon/`) with its `.tres`, HUD style, menu style and backdrop |
| `modes/` | One folder per game mode (`treadmill/`, `ring/`, `football/`, `dont_get_fat/`): the scene that composes components, the round rules (`GameMode` subclasses) and its `ModeInfo`. Also `PlayerSlot` (one seat of a lineup) |
| `ui/` | `menus/` (`MenuFrame`: the theme's menu look, background and stick steps, first in every menu; `StickRepeat`; main menu, `lobby/` (game and player select, `GameTabs`, `LobbyCard`), settings, `online/` (PLAY ONLINE: host, join, recent games), `pause/` (`PauseMenu`); `options/`: `OptionList`, `OptionRow`, shared by the settings screen, the lobby's GAME list and the lab; `prompts/`: `ButtonGlyph`, `PromptBar`, button prompts drawn as glyphs), `hud/` (`Hud`, `EnergyHud`, `ScoreBar`, the F3 network overlay) |
| `sandbox/` | Test bench scene for trying components, its props, and `lab/` (the Tab menu) |
| `docs/` | This file; `ONLINE.md` (playing on several computers), `STATIC_LEVELS.md` (maps), `DONT_GET_FAT.md` (the co-op mode), `IDEAS.md` |
| `addons/`, `tools/` | Live-reload plumbing (see CLAUDE.md); `tools/export_builds.sh` builds the Windows and Linux versions; `tools/net_test.sh` tests online play headless; `tools/bake_track.gd` bakes a generated treadmill track into a map; `tools/make_fat_levels.py` lays out Don't Get Fat!'s levels (DONT_GET_FAT.md) |

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
  - `shots`: every `Shot` in flight; bots watch them to raise their shields.
  - `grid`: the neon backdrop's `NeonGrid`; call `impulse(world_pos, strength, radius)` on the group to ripple it, `follow_y(y)` to scroll it.
  - `kill_lasers`: at most one `KillLasers` (the treadmill's belt: two lines `belt_height()` apart, centred on the node); `kill_top()` / `kill_bottom()` for treadmill bots and the generator.
  - `finish`: a map's `FinishLine`; treadmill bots race for it once it's inside the belt.
  - `buddy`: at most one `Buddy` (Don't Get Fat!). `HealthItem`s fly to it and `feed()` it; `PowerUp`s `boost()` it.
  - `on_belt`: every `BeltPickup` not yet caught (a swat looks through them).
  - `belt_bounds`: at most one `BeltBounds`; pickups fade out past its `bottom_y()`.
  - `rush_zones`: a Don't Get Fat! map's `RushZone`s; the mode speeds the belt up inside them.
- **Signals** for reporting upward: `Blob.pushed`, `Blob.dashed`, `Blob.slashed`, `Blob.spat`,
  `Blob.blocked`, `Blob.reflected`, `Blob.ate_food`, `Blob.died`,
  `BlobPhysics.blob_contact`, `RingArena.blob_ringed_out`, `Pitch.goal_scored`, `HealthItem.caught`, `PowerUp.collected`, `Juice.impact`. The
  mode script connects to them. Anything that knocks a blob out calls
  `blob.die()`; the mode only listens to `Blob.died`.
- **Autoloads** for feedback anything can trigger: `Juice.shake()`,
  `Juice.hitstop()`, `Juice.burst()`, `Juice.impact_at()`, `Sfx.play()`.
- **Missing collaborators are fine.** No `FxLayer`? No sparks. No arena? No mud,
  and ring bots assume a ring at the origin. Never crash because a scene is
  missing something.

### Who steers a blob

`Blob` only moves where `move_dir` says, pushes when `request_push()` is
called, dashes on `request_dash()`, and slashes, spits and shields on
`request_slash()`, `request_spit()`, `request_shield()`. A controller child sets those: `PlayerInput` (keys from an
`InputProfile` resource, plus one gamepad) or a `BotBrain` subclass. The
controller registers itself as `blob.controller`, so `blob.is_human()` works.
`blob.active = false` makes controllers leave the blob alone (countdowns).

### Who plays: lineups

A game's players are its lineup: up to 4 `PlayerSlot`s (`ModeInfo.MAX_SLOTS`).
A slot is a human (an `InputProfile` for keys and pad buttons, plus a gamepad
by device id) or a computer at a `BotLevel` (`entities/controllers/levels/`:
idle, passive, easy, normal, aggressive), and has a seat number (P1..P4) and
a colour index into `GameTheme.palette()`.

- **Main menu → lobby → mode.** PLAY opens the lobby (`ui/menus/lobby/`),
  which has two views. GAME is one list, like SETTINGS: the game (one of
  the lobby's `modes`, each a `ModeInfo`: title, scene path, min/max/default
  seats, max humans, teams, options), its options, PLAYERS (how many play;
  kept per game in `Session.lobby_seats`) and CPU LEVEL (the `cpu_level`
  setting, one level for every computer). PLAYERS has a panel per seat:
  players join from any device into the lowest free panel (P1, P2...) and
  only ever change their own panel (their team in a team mode, else their
  colour; ready; leave). Computers fill the seats nobody joined up to
  PLAYERS (not in a mode whose `ModeInfo` has `bots` off: someone has to
  join). Once everyone is ready a READY banner shows and the next confirm
  starts. The last game picked is kept in `Session.next_mode`; the lobby
  writes `Session.lineup` + `Session.lineup_mode` and starts the mode.
  Quitting from the game's pause menu comes back to PLAYERS with the same people.
- **Online.** PLAY ONLINE hosts or joins (`Net`); the host's lobby is the
  real one and the others show a copy, sending their presses to it. Players
  are keyed by computer and device; `PlayerSlot.peer` is the computer. Only
  the host picks the game and starts. Details in `docs/ONLINE.md`.
- **Menu buttons mean one thing everywhere.** Up/down moves between rows,
  left/right changes the focused value, A / SPACE / ENTER confirms, B / ESC
  goes back one step, Y / R opens the game and rules, START / TAB plays (in a
  game: pauses). Prompts show the glyph of the device that will press it
  (`ButtonGlyph`, `PromptBar`). A lone keyboard player has every key; a
  second one joins by holding the other half's confirm key.
- **Started on its own (F6).** `GameMode.lineup()` makes
  `PlayerSlot.default_lineup(info)`: P1 on the keyboard, each connected
  gamepad takes the next seat, CPUs (normal) fill the rest (not without `bots`). With one human
  seat, P1 uses the keyboard and the first gamepad.
- **In the mode.** `GameMode` resolves `slots` before `_spawn_blobs()`; the
  mode places a blob per slot with `spawn_slot(i, pos)`, which makes the
  `PlayerInput` or the mode's `_new_brain()` with the slot's level. Humans are
  tagged P1..P4 when there's more than one.
- **Teams.** A `ModeInfo` with `teams` (e.g. `["BLUE", "RED"]`) is a team
  mode: players pick their team in the lobby (`PlayerSlot.team`) and the
  lobby spreads the computers to even the teams out, adding one for a team
  nobody is on. Started on its own, seats alternate (`team_of()`: P1 and P3
  against P2 and P4). `PlayerSlot.team_in()` gives a slot's team and
  `spawn_slot()` sets `blob.team`. Each team member plays in the team's
  colours, the first in the team colour, the second in its partner colour
  (`team_second`; blue + purple, red + orange: `GameTheme.team_member_color()`, theme values
  `team.0`, `team.1`, `team.0.second`, `team.1.second`). `BlobBody` draws a
  team-coloured spot under a blob with a team.
- **Mode options.** `ModeInfo.options` lists `GameSettings` options (marked
  `only = "lobby"`) that the lobby's GAME list shows for the game, like
  football's TIME and GOALS or the treadmill's track and mass rules. The
  mode reads them with `GameSettings.choice()`.
- **Pausing.** START or ESC in a game opens the `PauseMenu` (resume,
  restart, quit to the lobby or menu) and pauses the tree; R restarts at
  once on the keyboard.

### Moves and energy

Which moves a blob has comes from `blob.rules`, a `MoveRules`: the push (on
unless a mode turns it off), the dash
(`NONE`, `BUMP`: solid, stuns what it hits; `GHOST`: passes through blobs,
pushes and lasers, and with `ghost_obstacles` walls and bumpers too) and
whether moves cost energy (`OFF`: cooldowns, `DASH`, `ALL`), plus on/off
for the slash, the spit and the shield. The shield blocks pushes, slashes
and dash stuns (`Blob.try_block()`) and sends shots back
(`Blob.try_reflect()`); anything new that hits blobs should ask one of the two.
A spit hit slimes the blob (`Blob.slime()`): for `stats.slime_time` it has
little grip, takes a bit more knockback and loses energy, but never below
`stats.slime_drain_floor`, so it can still shield. The slime numbers are in
`BlobStats`, with the spit's.

### Mass

Food makes blobs bigger, heavier, slower and stronger, up to
`BlobStats.max_mass`. A mode whose `ModeInfo` has `mass_loss` (the
treadmill) spawns blobs with `Blob.loses_mass`: they shrink all the time and
pay mass for spit and laser hits (`MoveRules.mass_decay`, `spit_mass`,
`laser_mass`, from the SHRINKING, SPIT COST and LASER BURN settings). Below
`stats.low_mass` the blob flashes red and players hear a warning beep; below
`stats.min_mass` it pops (`die(true)`). Anything that takes mass calls
`blob.lose_mass(amount)`, which does nothing where mass loss is off (football,
the ring). The FOOD setting scales how much food levels lay out
(`GameSettings.food_amount()`). Every blob
shares `GameSettings.rules()`, built from the player's settings, so a change
in a menu applies at once, unless its mode gives it its own (Don't Get Fat!'s
blobs get `fat_moves.tres`: dash and swat only). The numbers
(dash speed and time, bar size, regen, costs) are in `BlobStats`. Anything
that hits blobs skips `blob.is_ghost()`; obstacles skip
`blob.phases_obstacles()`; the arena's own walls never do, nor does a
`WallBlock` with `ghost_proof` (drawn hatched: some pieces of the treadmill's wall rows). The bar is drawn
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
`group` puts the SETTINGS rows under headings (LOOK, MOVES...).
New option: add an entry, then read it where it's used (or in
`GameSettings._sync()` for a `MoveRules` field).

### Update order

Set with `process_physics_priority` in each script's `_ready()`:

1. `-10` controllers (`PlayerInput`, `BotBrain`) set `move_dir` / request pushes
   - `-8` the treadmill mode scrolls the camera, `-7` `TrackGenerator` builds ahead
   - `-6` `LaserDirector`, `-5` `LaserEmitter`s (dodging overrides the bots' `move_dir`)
2. `0` `BlobPhysics`: substeps of motion, blob-vs-blob, then every `blob_colliders` node
3. `10` `Blob`: cooldowns, energy, push windup and release, starting a dash
4. `20` rules that look at where blobs ended up: `RingArena` ring-out, `KillLasers`, `Food` eating, `BeltPickup` catching

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
| a `.tscn` (nodes, exported values on nodes) | when that scene loads again (quit to the lobby or menu and back) |

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
`GameTheme` resource. A mode with `ModeInfo.theme` set always plays in that
theme instead (`Session.theme_override`, set by `GameMode` while it's in the
tree): Don't Get Fat! is classic only for now. Otherwise `current()` returns
the player's (`themes/<name>/<name>.tres`; in the editor the default
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
- **The rest of a `GameTheme`:** `hud` (the HUD's UI theme), `menu` (the
  menus' UI theme, see Menus below), `backdrop` (a scene
  drawn behind everything, e.g. the neon grid), `glow` (a bloom scene, used when
  `Session.glow` is on), `clear_color`, `beat_zoom` (camera thump on the kick),
  and the player, P2 and bot colours. `ThemeBackdrop`, near the top of every
  game scene, adds the backdrop and glow and sets the clear colour.

Draw order in a game scene: backdrop z -10, arena z -1, then trails (z -1,
later in the tree), obstacles, food and blobs at 0, lasers and kill lasers z 5,
`FxLayer` z 10.

**Menus** follow the theme too. Every menu scene starts with a `MenuFrame`,
which gives the menu the theme's `menu` (a UI `Theme` in the theme's folder,
`menu_theme.tres`) and paints its background: the `MenuFrame` colours
(`background`, `stripes`) and the theme's `backdrop` scene (neon: the grid,
tinted by `backdrop_tint`, rippling where the focus moves). The menu theme
holds every menu colour and style: buttons and labels (`TitleLabel`,
`SubtitleLabel`, `HintLabel`, `AccentLabel`, `HeadingLabel`, `DimLabel`,
`PrimaryButton`, `MenuPanel`, `BannerPanel`) and the drawn parts (`LobbyCard`,
`ButtonGlyph`, `PromptBar`, `GameTabs`), which read them with
`get_theme_color(name, "<Type>")`. Switching THEME restyles an open menu at
once (`Session.theme_changed`). `MenuFrame` also turns stick pushes into
single `ui_*` steps (`StickRepeat`: one per push, repeating while held); the
lobby reads the stick itself, per player, with its own `StickRepeat`.

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

**New map:** a scene under `level/maps/<name>/` with a `Map` root (see
`docs/STATIC_LEVELS.md`). To start from a generated track, bake one:
`godot --headless --path <project> -s tools/bake_track.gd -- name=<name> seed=<n> length=<px>`.
Add a choice for it to the `track_map` option in `GameSettings.OPTIONS` and
it shows up in the treadmill's lobby (TRACK). New pieces for maps are `@tool`
scripts whose `_draw()` returns early in the game when only the editor needs
to see them (`SpawnPoint`), or draw in both (`FinishLine`, `WallBlock`).

**New enemy:** under `entities/enemies/`. Beat-driven ones can extend
`LaserEmitter` (see `LaserTurret`, `LaserShip`: they only give their shape).

**New theme:** a folder under `themes/` with a `<name>.tres` (a `GameTheme`
with a `ThemeStyle` and the `values` that differ), a HUD theme, a menu theme
(copy one and change its colours and styles), optionally a backdrop, and an
entry in `Session.THEMES`.

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
- Online play: `tools/net_test.sh` runs a host and a client headless and
  prints PASS or FAIL (`--lag=200 --loss=15` after it for a bad connection).
- Check new `class_name`s against Godot's built-in classes (`Skin` is one):
  shadowing a native class is a compile error.
