# Bumper Blobs

Top-down sumo with jelly blobs. Knock everyone out and be the last blob standing.
Made for Godot 4.7. Open `project.godot` in the editor and press F5. The main menu has the
three modes, a SANDBOX test room and a GLOW switch for the neon bloom.

## Controls
| Action  | Keyboard               | Gamepad          |
|---------|------------------------|------------------|
| Move    | WASD / arrows          | Left stick, D-pad |
| Push    | Space / J / Enter      | A, X or RB       |
| Restart | R                      | Start            |
| Menu    | Esc                    | Back             |

Two players (treadmill): P1 is WASD + Space, P2 is arrows + Enter. With one controller P2
gets it; with two, one each.

## Modes
- **Classic ring** (`modes/ring/ring.tscn`): leave the bright ring and a red timer starts;
  stay out for 1 s and you're eliminated. Outside the ring is slow "mud", and the outer wall
  bounces you back. Yellow pellets make you bigger and heavier: your pushes hit harder and
  you're harder to move, but you're slower. The ring around your blob fills as your push
  recharges.
- **Neon** (`modes/ring/neon.tscn`): the same game with a Geometry Wars look (glowing
  outlines, a warping grid, motion trails), a synthesised 128 BPM techno loop, and laser
  turrets that fire on the beat. A thin line tracks a blob for 2 beats, blinks when the aim
  locks, then fires on the next downbeat: get out of the line. Glow needs the Forward+ or
  Mobile renderer; anything drawn brighter than 1.0 blooms (see `NeonLook.hdr()`).
- **Treadmill** (`modes/treadmill/treadmill.tscn`): the camera scrolls up through a still
  world. Fall behind the red laser at the bottom (or get launched past the top one) and you're
  out. The track is generated ahead: purple walls, pink kicker walls and gold bumpers that fling
  you, plus food, denser the further you go. Laser ships beside the track fire across it on the
  beat. Modes: 1 player vs computer, 2 players versus, 2 players + computer, watch.
  Skip the menu: `godot modes/treadmill/treadmill.tscn -- --mode=0` (0-3 = menu order).

Any scene runs on its own with F6. `sandbox/sandbox.tscn` is a walled room with you and two
bots, for trying components.

## Where things live
Everything is built from small scenes; see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for
the folders, how components find each other, and the hot-reload rules.

Feel numbers live in resources (`.tres`). Edit them in the Inspector or in a text editor and
the running game picks them up straight away:

| Resource | What |
|---|---|
| `blob/stats/default.tres` (`heavy.tres`) | Blob movement, size growth, push, jelly (`BlobStats`) |
| `physics/default_feel.tres` | Bounciness of blob hits and walls (`PhysicsFeel`) |
| `autoload/juice_settings.tres` | Hitstop, screen shake, sparks, sound volume |
| `neon/neon_palette.tres` | Neon brightness, blob glow, trail length, ring colours |
| `lasers/turret_laser.tres`, `ship_laser.tres` | Laser timing in beats, width, knockback, colours |
| `track/track_settings.tres` | Treadmill: scrolling, obstacles, kick strength, ships, bots per mode, colours |

Per-scene settings are exports on the nodes (ring size and ring-out time on `RingArena`,
food timing on `FoodSpawner`, grid springs on `NeonGrid`, BPM on `Techno`, laser start delay
on `LaserDirector`); those apply when the scene loads again. Bot behaviour is in
`blob/control/` (`BotBrain` defaults, `RingBotBrain`, `TrackBotBrain`).

## Tuning cheat sheet
- Not bouncy enough → `blob_restitution`, `bump_pop`, `wall_restitution` (PhysicsFeel).
- Too wobbly or jelly-like → raise `jelly_damping`, lower `squash_kick` (BlobStats).
- Pushes too weak or too strong → `push_impulse`, `push_range`, `push_stun` (BlobStats).
- Hit blobs slide too far → raise `drag` or `knockback_control` (BlobStats).
- Too hard to knock people out → raise `outside_drag` (BlobStats), lower `ring_out_time`
  (RingArena) or `wall_restitution` (PhysicsFeel).
- Bots too mean → raise `reaction`, lower `player_bias` (`blob/control/bot_brain.gd`).
- Food too strong → lower `food_mass` or `max_mass` (BlobStats).
- Hits feel too sticky or too shaky → `hitstop_*`, `shake_*` (juice_settings.tres).
