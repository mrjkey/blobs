# Bumper Blobs

Top-down sumo with jelly blobs. Knock everyone out of the ring and be the last blob standing.
Made for Godot 4.7. Open `project.godot` in the editor and press F5.

## Controls
| Action  | Keyboard        | Gamepad     |
|---------|-----------------|-------------|
| Move    | WASD / arrows   | Left stick  |
| Push    | Space / J       | A           |
| Restart | R               | Start       |
| Quit    | Esc             |             |

## Rules
- Leave the bright ring and a red timer starts. If you stay out for 0.8 s, you're eliminated.
  The dark area outside the ring is slow "mud", and the outer wall bounces you back.
- Yellow pellets are food. Each one makes you bigger and heavier: your pushes hit harder and
  you're harder to move, but you're slower.
- Push has a short cooldown. The ring around your blob fills up as it recharges.

## Files
- `scripts/tuning.gd`: **every feel number lives here.** Each line has a comment.
- `scripts/game.gd`: arena, physics step, collisions, push, food, round flow, HUD.
- `scripts/blob.gd`: one blob's state, movement, push timing, jelly deformation and drawing.
- `scripts/ai_brain.gd`: bot behaviour (choose a target, flank, push, eat, avoid the edge).
- `scripts/fx.gd` / `scripts/sfx.gd`: particles/shockwaves and synthesised sounds (no asset files).

## Tuning cheat sheet (all in `tuning.gd`)
- Not bouncy enough → raise `BLOB_RESTITUTION`, `BUMP_POP`, `WALL_RESTITUTION`.
- Too wobbly or jelly-like → raise `JELLY_DAMPING`, lower `SQUASH_KICK`.
- Pushes too weak or too strong → `PUSH_IMPULSE`, `PUSH_RANGE`, `PUSH_STUN`.
- Hit blobs slide too far → raise `DRAG` or `KNOCKBACK_CONTROL`.
- Too hard to knock people out → raise `OUTSIDE_DRAG`, lower `RING_OUT_TIME` or `WALL_RESTITUTION`.
- Bots too mean → raise `BOT_REACTION`, lower `BOT_PLAYER_BIAS`.
- Food too strong → lower `FOOD_MASS` or `MAX_MASS`.
- Hits feel too sticky or too shaky → `HITSTOP_*`, `SHAKE_*`.

## Neon night-club variant (`neon.tscn`)
Same game, Geometry Wars look: glowing outlines, a warping background grid, motion trails,
a synthesised 128 BPM techno loop, and laser turrets that fire on the beat.
Open `neon.tscn` and press **F6** (Run Current Scene). To make it the default, right-click it
in the FileSystem dock > Set as Main Scene.

- Lasers: a thin line tracks a blob for 2 beats, blinks when the aim locks, then fires on the
  next downbeat. Get out of the line before then.
- How the glow works: the scene turns on HDR 2D and adds a WorldEnvironment with glow.
  Anything drawn with colour values above 1.0 blooms (see `hdr()` in `neon_game.gd`).
  Needs the Forward+ or Mobile renderer (the default).
- Knobs: `scripts/neon/neon_tuning.gd` (glow, grid, music volume/BPM, laser timing and
  strength, colours). Gameplay numbers still come from `scripts/tuning.gd`.
