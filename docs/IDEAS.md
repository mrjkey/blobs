# Feature ideas

A backlog of ideas, not a plan (written 2026-10-17). Most of them build on
something the game already has; that's noted where it matters.

## RPG direction

A **roguelite room run** (like Hades) rather than a story RPG: the game's
strength is short physics fights in arenas, and a run of rooms keeps that
while adding progression.

- **Damage from physics, not from hits.** Blobs get HP, but a push alone does
  little. Slamming an enemy into a wall, a bumper or another blob hurts in
  proportion to the impact speed (BlobPhysics already works it out). Knocking
  enemies around becomes the combat.
- **Room loop.** Clear a room of bots, the doors open, pick 1 of 3 upgrades.
  Upgrades change your blob's numbers and moves: push reach, dash distance, a
  4th energy segment, faster refill, a bump dash that also stuns, a ghost dash
  that leaves a damaging trail.
- **Enemies as blob types** (a `BlobStats` file plus a bot brain each):
  - Tank: the heavy blob that already exists.
  - Spiky: touching it hurts you.
  - Splitter: breaks into two small blobs when slammed.
  - Ghost: dashes through you.
  - Eater: grows by eating food (the mass system).
  - Laser turrets and ships as room hazards.
- **XP as mass.** Food already makes blobs bigger and heavier; in a run it
  could also be the currency spent between rooms.
- **Bosses.** A huge blob with its own move pattern, or a laser ship that
  fires on the beat.
- **Later:** an overworld hub with NPC blobs, a shop, unlocks between runs.

**How to prototype it:** HP and wall-slam damage as a sandbox lab option
(off / wall slams / every hit) to find out whether the combat feels good. If
it does, a small three-room run as a new mode.

## More moves for the energy bar

- **Charged push:** hold to charge; each segment spent pushes harder and farther.
- **Parry:** a push timed just as an enemy's push lands throws it back at
  them. The skill counterpart to the ghost dodge.
- **Pull / magnet:** the opposite of a push, to drag someone off a ledge.
- **Ground pound:** a short hop, then a stomp that pushes in every direction.
  Costs 2 segments.
- **Spit:** shoot a small piece of yourself as a projectile. Costs mass, so
  you get lighter and faster but easier to knock out.
- **Grab and throw:** hold a blob, then fling it.

## Use the music

The game already keeps a 128 BPM beat clock (`Techno`).

- **On-beat bonus:** pushes or dashes timed to the kick drum hit harder or
  cost less energy. A light rhythm-game layer.
- **Beat-driven arenas:** walls move, the ring shrinks a step, or bumpers
  pulse on the beat.

## New modes

- **King of the hill:** score by holding a zone that moves around.
- **Sumo shrinking ring:** the ring gets smaller on the beat.
- **Football** (built: `modes/football/`). Next for it: a kick-off where
  one team starts with the ball, a charged shot, a goalkeeper role for bots,
  other pitch shapes, and other balls (heavy, bouncy, more than one at a time).
- **Infection / tag:** a pushed blob switches teams; the round ends when one
  colour is left.
- **Paint:** the neon trails paint the floor; whoever covers the most wins.
- **Co-op waves:** survive waves of bots and lasers together. Also a way to
  test the RPG enemy types early.

## Smaller polish

- Character select: light, standard and heavy blobs (just different stats files).
- A slow-motion zoom on the knockout that ends a round.
- Hats, eye styles and colour unlocks.
