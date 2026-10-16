# Architecture

How the project is put together, and the rules that keep it easy to extend and
hot-reloadable while the game runs. Read this before adding a component or a mode.

The project is mid-migration: `scripts/` holds the old code-built prototypes
(classic, neon, treadmill extend `scripts/game.gd`). Each mode is being rebuilt
from the components below; `scripts/` is deleted once all three are ported.
Don't add to `scripts/`.

## Folders

Group by feature, not by file type: a feature's scenes, scripts and resources
sit together.

| Folder | What goes there |
|---|---|
| `autoload/` | Global singletons: `Session` (choices that survive scene changes, saved settings), `Juice` (shake, hitstop, sparks, the `impact` signal) + its settings `.tres` |
| `audio/` | `Sfx` autoload (synthesised sound kit); music |
| `blob/` | `blob.tscn` and its script, `BlobStats` + `stats/*.tres` |
| `blob/body/` | How a blob is drawn (jelly spring, eyes, status rings); other looks subclass `BlobBody` |
| `blob/control/` | Controllers that steer a blob: `PlayerInput` + `InputProfile`s, `BotBrain` and its subclasses |
| `physics/` | `BlobPhysics` (moves and collides blobs) and `PhysicsFeel` |
| `arena/` | Floors and walls blobs play on (`BoxRoom`, `RingArena`) |
| `food/` | `Food` pellets and the `FoodSpawner` |
| `fx/` | Visual-only nodes: `FxLayer` (sparks, shockwaves), `GameCamera` |
| `neon/` | The neon look: `hdr()` colours, the optional glow |
| `ui/` | `menus/`, `hud/`, `themes/` |
| `modes/` | One folder per game mode: the scene that composes components plus the round rules |
| `sandbox/` | Test bench scene for trying components |
| `docs/` | This file |
| `addons/`, `tools/` | Live-reload plumbing (see CLAUDE.md) |

## Scenes, scripts, resources

- **Scenes** (`.tscn`) hold structure: which nodes exist and how they're arranged.
  Anything you can point at in the game is a scene, or a node with a `class_name`
  script that you can add from the editor's Create Node dialog.
- **Scripts** (`.gd`) hold behaviour. Spawning instances of scenes at runtime is
  fine; building a node tree by hand in `_ready()` is not (put it in a scene).
- **Resources** (`.tres`) hold numbers you tune: `BlobStats`, `PhysicsFeel`,
  `JuiceSettings`, `InputProfile`, the glow `Environment`. Many nodes can share one.
- Structural one-offs (a room's size, a spawn position) are `@export`s on the
  node in the scene.

## How components talk

A component never holds a reference to "the game". It works on its own and
finds what it needs:

- **Groups** for finding things. Contract groups are joined in the script's
  `_enter_tree()`, so a node can't be placed without them:
  - `blobs`: every `Blob`. Dead blobs stay in the group with `alive == false` until they free themselves.
  - `blob_colliders`: anything blobs bounce off. Implements `collide(blob: Blob, feel: PhysicsFeel)`.
  - `arena`: at most one. Optional `is_in_mud(pos) -> bool`, and `ring_radius` for ring bots and the food spawner.
  - `food`: pellets bots look for.
  - `fx`: the `FxLayer` that `Juice.burst()` / `Juice.shockwave()` draw on.
- **Signals** for reporting upward: `Blob.pushed`, `Blob.ate_food`, `Blob.died`,
  `BlobPhysics.blob_contact`, `RingArena.blob_ringed_out`, `Juice.impact`. The
  mode script connects to them. Anything that knocks a blob out calls
  `blob.die()`; the mode only listens to `Blob.died`.
- **Autoloads** for feedback anything can trigger: `Juice.shake()`,
  `Juice.hitstop()`, `Juice.burst()`, `Juice.impact_at()`, `Sfx.play()`.
- **Missing collaborators are fine.** No `FxLayer`? No sparks. No arena? No mud,
  and ring bots assume a ring at the origin. Never crash because a scene is
  missing something.

### Who steers a blob

`Blob` only moves where `move_dir` says and pushes when `request_push()` is
called. A controller child sets those: `PlayerInput` (keys from an
`InputProfile` resource, plus one gamepad) or a `BotBrain` subclass. The
controller registers itself as `blob.controller`, so `blob.is_human()` works.
`blob.active = false` makes controllers leave the blob alone (countdowns).

### Update order

Set with `process_physics_priority` in each script's `_ready()`:

1. `-10` controllers (`PlayerInput`, `BotBrain`) set `move_dir` / request pushes
2. `0` `BlobPhysics`: substeps of motion, blob-vs-blob, then every `blob_colliders` node
3. `10` `Blob`: push cooldown, windup and release
4. `20` rules that look at where blobs ended up: `RingArena` ring-out, `Food` eating

Drawing (`BlobBody`, `FxLayer`) runs in `_process`.

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

## The standalone rule

Every component scene works when dropped into `sandbox/sandbox.tscn` (a room,
`BlobPhysics`, a player and two bots), without a mode script. If it needs
something, it finds it through a group and copes when it isn't there. This is
what makes a gallery of objects possible.

## Recipes

**New obstacle** (bumper, wall, spikes...): a scene whose root script joins
`blob_colliders` in `_enter_tree()` and implements `collide(blob, feel)`. Use
`BlobPhysics.bounce()` for solid surfaces and `BlobPhysics.wall_feedback()` for
the hit effects. Draw it in `_draw()`. Put tunables in exports or a resource.
Try it in the sandbox.

**New look for blobs:** a script that `extends BlobBody` and overrides `_draw()`;
an inherited scene of `blob.tscn` with that script on `Body`.

**New controller:** a node script that sets `blob.controller = self` in
`_ready()`, runs at physics priority -10, and writes `move_dir` /
`request_push()` while `blob.alive and blob.active`. Bots extend `BotBrain` and
override `_decide()`, `_target_score()`, `_food_ok()`.

**New tuning knob:** add an `@export` with a comment to the right resource class
(`BlobStats`, `PhysicsFeel`, `JuiceSettings`...), read it where it's used.

**New mode:** a folder under `modes/` with a scene that places the components
(camera, arena, `BlobPhysics`, `FxLayer`, `Hud`, a `Blobs` node) and a script
that extends `GameMode`: spawn in `_spawn_blobs()` with `spawn_player()` /
`spawn_bot()`, switch hazards on in `_on_play_started()` and off in
`_on_round_over()`, override `_check_round_over()` for other win rules. See
`modes/ring/`. Add a menu button.
