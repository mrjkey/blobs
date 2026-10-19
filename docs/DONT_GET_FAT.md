# Don't Get Fat!

A co-op version of the treadmill (written 2026-10-18). 1 to 4 players, no
computer players. Code in `modes/dont_get_fat/`.

**Classic theme only for now.** The mode always plays in the classic look
(`ModeInfo.theme = "classic"`), whatever THEME the player picked. The items,
the buddy and the gate are drawn for classic and nothing has been tuned for
neon. Don't spend time on neon for this mode until we decide to.

## How it plays

- The belt scrolls up a hand-made level, so the items on it come down the
  screen at the players. It goes a bit faster than the treadmill.
- At the bottom of the screen walks the **buddy**, the character the players
  look after. Its weight is shown beside it and at the top of the screen.
- The players' blobs are its helpers. They only move: no push, dash or attacks.
  They stay in the helpers' zone, above the dashed line.
- Whatever a blob catches flies to the buddy:
  - **Junk** (red spot) makes it heavier: burger, fries, cake, donut, soda,
    a lie-in in bed, a night in front of the TV.
  - **The good stuff** (green spot) slims it down: apple, carrot, broccoli,
    water, dumbbell, football.
  - Anything nobody catches fades away at the dashed line and does nothing.
- **Power-ups** work as soon as they're caught:

  | Power-up | | What it does |
  |---|---|---|
  | MAGNET | mixed | That blob pulls in everything near it, good and bad, for 6 s |
  | GOLDEN APPLE | good | Everything caught counts as good for 5 s |
  | SNEAKERS | good | Every blob runs faster for 6 s |
  | SUGAR CRASH | bad | Every blob is sluggish for 5 s |

- At the end the buddy reaches the **gate**. Its opening fits the buddy at
  the level's weight limit, which is also written on the sign. If the buddy
  is under the limit it walks through: LEVEL CLEAR. If it's over, it doesn't
  fit: LEVEL FAILED.

## The pieces

| Piece | Where | What it is |
|---|---|---|
| `dont_get_fat_game.gd` | `modes/dont_get_fat/` | The mode: scrolls the belt, loads the level, stops at the gate |
| `FatSettings` (`fat_settings.tres`) | `modes/dont_get_fat/` | Numbers shared by every level: the view, the buddy's size, each item's kg, power-up times |
| `FatRules` | `level/maps/<level>/<level>_rules.tres` | One level's numbers: start weight, the limit, belt speed, drift |
| `move_only.tres` | `modes/dont_get_fat/` | The blobs' `MoveRules`: no moves at all |
| `Buddy` | `entities/buddy/` | The character: weight, size, face, the team's power-ups |
| `BeltPickup` | `level/pickups/health/` | Base of anything blobs catch on the belt: sway, magnets, fading out |
| `HealthItem`, `PowerUp`, `Magnet` | `level/pickups/health/` | The items, the power-ups, the magnet on a blob |
| `BeltBounds` | `level/arenas/track/` | Keeps blobs in the helpers' zone, draws the dashed line |
| `Gate` | `level/maps/` | The end of a level (a `FinishLine`) |

Tuning while the game runs: `fat_settings.tres` and a level's
`_rules.tres` apply at once. A change to the level's `.tscn` shows the next
time the level loads (R).

## Making a level

A level is a map scene (`Map` root) like the treadmill's courses:
`level/maps/fat_1/fat_1.tscn`, with its rules in `fat_1_rules.tres` (the map's
`rules`). Children:

- `Items`: `HealthItem` nodes (`health_item.tscn`). Pick the `kind`. Set
  `sway` (px, negative = starts the other way) and `sway_time` to make one
  slide side to side.
- `PowerUps`: `PowerUp` nodes (`power_up.tscn`).
- `Obstacles`: `Bumper`s and `WallBlock`s with `kicker` on (the bouncy walls).
- `Spawns`: `SpawnPoint` P1..P4.
- `Gate`: the end. A level is about 100 px per 1 m on the HUD.

New level: copy the `fat_1` folder, rename it, and add a choice to the
`fat_level` option in `GameSettings.OPTIONS`. It then shows in the lobby
(LEVEL).

Level 1 (1200 m, about a minute) was laid out by a script, section by
section, and is meant to be edited by hand from here: a warm-up line of
apples, single junk items, rows of junk with one gap, diagonals and bumpers,
a magnet before a field of good stuff, the lazy zone (beds and TVs) with a
sugar crash, kicker walls, a golden apple followed by a pile of junk to
feast on, swaying rows with a magnet in a junk patch, final rows, and a
cool-down line of good stuff before the gate. Start 80 kg, limit 90 kg, belt
210 to 260 px/s.

## Ideas for later levels

- Raise `scroll_start` / `scroll_end`, tighten `max_weight`, start closer to
  the limit, or turn on `drift` so the buddy gains weight on its own and the
  good stuff becomes a must.
- More `sway`, rows that close in from both sides, narrower gaps.
- Moving walls or traps, junk that chases the nearest blob, a bad magnet that
  only pulls junk.
- Score: time, kg under the limit, stars per level; unlock the next level.
