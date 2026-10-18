# Static levels: a plan

How we get hand-made maps you can see and edit in the Godot editor, next to
(not instead of) the generated treadmill. Written 2026-10-18.

## Status (2026-10-18)

Built so far (most of phase 1 and part of phase 2):
- `Map`, `SpawnPoint`, `FoodSpot` and `FinishLine` in `level/maps/`. In the
  editor, `Map` draws the track bed and a ruler in metres. `FoodSpot` draws
  its pellet (`Food` itself isn't `@tool`).
- `tools/bake_track.gd` bakes a generated track into a map. One baked map is
  checked in: `level/maps/course_1/course_1.tscn` (seed 1, 8000 px, 800 m).
- The treadmill plays a map instead of the generated track when you pick it
  in the lobby (TRACK: COURSE 1) or set `map_path` on the treadmill scene.
  Blobs start on the spawn points, the belt stops just past the finish line,
  and the first blob across it wins.

Not built yet: `FoodZone`, practice mode (no scroll, dev keys), the preview
renderer, and editor drawing for the kill lasers.

## The goal

- Open a map scene in the editor and see it the way it looks in the game:
  floor, walls, bumpers, food spots, spawn points, the finish.
- Place and resize walls and obstacles by hand, mark where food appears.
- Run through a map at your own pace to test things: no scrolling, no lasers,
  no starving, unless you want them.
- The same setup later carries an RPG: rooms and an overworld are just
  bigger maps with doors.

## Why the editor shows nothing today

- The treadmill's track is built at runtime by `TrackGenerator`, so the
  `treadmill.tscn` scene holds no walls at all.
- Some pieces only draw while the game runs. `WallBlock` and `Bumper` are
  `@tool` and already draw in the editor. `Food`, the track bed (`SideWalls`)
  and `KillLasers` don't.
- There's nothing to mark a spawn point, a food spot or a finish line.

None of this needs a new engine feature. The fix is: **a map is a scene made
of the same pieces the generator uses, every piece draws itself in the
editor, and a mode can load a map instead of generating one.**

## The approach

### 1. A map is a scene

Maps live in `level/maps/<name>/<name>.tscn`. A treadmill map looks like this:

```
Map (Map: the map's size and kind, draws the floor and side walls in the editor)
├── Walls        (WallBlock nodes: drag them around, set size in the Inspector)
├── Obstacles    (Bumper, kicker walls, later spikes, turrets...)
├── Food         (FoodSpot and FoodZone markers)
├── Spawns       (SpawnPoint x4, numbered P1..P4)
└── Finish       (FinishLine at the top)
```

The pieces are the ones the game already uses, so a map plays exactly like
the generated track. The generator only decides *where* things go. A map
fixes that by hand.

### 2. New pieces (all `@tool`, all drawn in the editor)

| Piece | What it does | In the editor |
|---|---|---|
| `Map` | Root of a map: `size` (width x length), `kind` (treadmill, arena, room), the floor colour | Draws the floor, the side walls and a ruler every 500 px, so you know how far up you are |
| `SpawnPoint` | Where seat N starts | A ghost blob with "P1".."P4" on it |
| `FoodSpot` | A pellet that appears here, and comes back `respawn` seconds after it's eaten (0 = never) | A pellet with a small clock if it respawns |
| `FoodZone` | A rectangle that keeps up to `count` pellets scattered inside it | A dashed rectangle with the count |
| `FinishLine` | Reaching it wins a treadmill run | A chequered line across the track |

`Food`, `SideWalls` and `KillLasers` get `@tool` drawing too. Their game logic
stays behind `if Engine.is_editor_hint(): return`, as `BoxRoom` already does.

### 3. Modes load a map

- **Treadmill:** an `@export_file var map` on `TreadmillGame` (and a choice
  of map in the lobby, as a mode option). Empty means generate, as now. With a
  map, the `TrackGenerator` is left out, blobs start at the map's
  `SpawnPoint`s, and the belt scrolls from the bottom of the map to its
  `FinishLine`.
- **Practice / explore:** a lab-style toggle for any map. It turns off the
  scroll, the lasers and mass loss, and adds a few dev keys:
  - F1 shows every collider's outline.
  - Click teleports your blob to the mouse.
  - Mouse wheel zooms the camera out to see the whole map.

  This is the "run through it at my own pace" mode.
- **Other kinds later:** an arena map for the ring or a room for the RPG uses
  the same `Map` root with a different `kind`. The mode reads what it needs.

### 4. Getting a first map without starting from scratch

A small tool script, `tools/bake_track.gd`, runs the generator headless with
a seed and saves what it builds as a map scene. You get a full treadmill
map in seconds, then move, delete and add things by hand in the editor.
"Bake me 3 maps of 8000 px, seeds 1..3" is a one-line request.

## How we collaborate on a map

Scenes are text files (`.tscn`), so we can both work on the same map. Each of
us does what we're best at.

**You, in the editor:** layout and feel. Drag walls, resize them (the `size`
field in the Inspector, with grid snap on), drop food spots, play-test with
F6 (run current scene) in practice mode.

**Me, in the files:**
- Read the `.tscn` to see what you built.
- Make bulk or precise changes: "add a zig-zag corridor at 3000-4000", "make
  every gap in the second half 20% narrower", "mirror this section".
- Bake new maps, write the new pieces, wire maps into modes.
- **Render a preview.** A headless script saves a PNG of the whole map
  zoomed out (the same trick I used for the screenshots in this session),
  so I can look at your layout before changing it, and show you mine.

**Rules so we don't overwrite each other:**
1. One of us edits a given map at a time. Save it in the editor (Ctrl+S)
   before asking me to change it.
2. My edits to a `.tscn` reach the editor through the Claude Sync plugin
   when the turn ends. It reloads scenes that are open, so you see the
   change in the editor tab. In the running game, the map shows the change
   the next time it loads (Esc and back, or R).
3. When I add new pieces (new `class_name` scripts), click into the editor so
   it rescans, then restart the game.
4. You commit; I never do. Commit a map before asking for a big change to
   it, so it's easy to undo.

## Walls at RPG scale: tiles later

Placing `WallBlock` nodes one by one is right for a treadmill map (dozens of
walls). An RPG overworld or a dungeon wants hundreds, painted like tiles.
Godot's `TileMapLayer` is the editor tool for that. Blobs don't use Godot's
physics, though: they collide through the `blob_colliders` group. So:

- A `TileWalls` node points at a `TileMapLayer`. It joins `blob_colliders`
  and collides blobs against the solid cells near them. Looking up only the
  few cells around a blob keeps it cheap however big the map is.
- Tile custom data says what a cell is: wall, kicker, ghost-proof, mud,
  spikes. You paint with them like any tile set.
- Nodes and tiles mix: paint the walls, place bumpers, spawns and food as
  nodes on top.

This is phase 3, not needed for the first maps.

## Phases

| Phase | What you get | Who |
|---|---|---|
| 1. Pieces | `Map`, `SpawnPoint`, `FoodSpot`, `FoodZone`, `FinishLine`; `@tool` drawing for `Food`, the track bed and the kill lasers; one hand-placed sample map | me, then you look at it in the editor |
| 2. Play it | Treadmill loads a map (and the lobby can pick one), practice mode with the dev keys, the bake tool, the preview renderer | me; you build or edit the first real map |
| 3. Tiles | `TileWalls` + a tile set for walls, kickers and mud; a sample room painted with it | me for the code, you for the painting |
| 4. RPG rooms | `Door` (target map + spawn point), a room mode that moves between maps and keeps your blob's state, the first enemies placed by hand | together, after the RPG idea in `IDEAS.md` is settled |

Phase 1 is about a session. After it, you can open a map in the editor and
see everything.

## Open questions

- **Treadmill maps:** should a map still scroll (a laser chasing you up a
  fixed course, with a finish), or be free to explore (no scroll, reach the
  top)? Both are a setting on the map. Which matters first?
- **Map size:** a treadmill map of 8000-10000 px long is about 1.5-2 minutes at the
  current scroll speed. Is that the right length for a run?
- **Grid:** do you want walls snapped to a grid (e.g. 24 px, the wall
  thickness), so maps look tidy and line up with tiles later?
