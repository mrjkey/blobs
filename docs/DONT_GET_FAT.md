# Don't Get Fat!

A co-op version of the treadmill (written 2026-10-18, reworked 2026-10-19
into the run, the window and the plate). 1 to 4 players, no computer
players. Code in `modes/dont_get_fat/`. The design discussion behind it is
the "Don't Get Fat! Depth & Progression" doc.

**Classic theme only for now.** The mode always plays in the classic look
(`ModeInfo.theme = "classic"`), whatever THEME the player picked. The items,
the buddy and the gate are drawn for classic and nothing has been tuned for
neon. Don't spend time on neon for this mode until we decide to.

## How it plays

- The belt scrolls up a hand-made level, so the items on it come down the
  screen at the players. A level lasts 45 to 60 s.
- At the bottom of the screen walks the **buddy**, the character the players
  look after. It burns a little weight all the time (`FatSettings.burn`,
  0.08 kg/s), so it has to keep eating. The players' blobs are its helpers.
  They stay in the helpers' zone; the belt carries everything else past
  them, so a blob left alone drifts back to the zone's bottom edge. That edge
  is a laser while the belt runs: running into it only bumps a blob back up,
  but a wall that shoves a blob through it pops the blob, which comes back
  3 s later near the top of the zone, safe from the laser for 1.5 s.
  They can move, dash (B / Shift) and swat (X / J): a swat knocks junk
  (treats, lazing) off the belt. Walls, sliding walls, kickers and bumpers
  are in the way from level 1.
- Whatever a blob catches flies to the buddy. Every item has a group, shown
  by the colour of the spot it sits on:

  | Group | Spot | Items | Does |
  |---|---|---|---|
  | Protein | orange | egg, fish, drumstick | +0.5 to 0.6 kg, fills the plate |
  | Grains | yellow | bread, rice, corn | +0.4 to 0.5 kg, fills the plate |
  | Fruit and veg | green | apple, carrot, broccoli, banana | +0.3 to 0.4 kg, fills the plate |
  | Treats | red | burger, fries, cake, donut, soda | +2 to 3 kg, fills the treat meter |
  | Lazing about | grey | bed, TV | +1.5 kg; a bed also gives rest (below) |
  | Activity (workouts) | blue | dumbbell, football | −2.5 kg at the middle of the window (scaled, below); builds muscle |
  | Water | light blue | water | −0.5 kg |

  Anything nobody catches fades away at the laser and does nothing.
- **The feeder.** On top of a level's own layout, its `FatRules` drop
  workouts, beds, water, plate food and treats onto the belt at a steady
  pace (`feed_*`: seconds between drops, give or take a third; 0 = none),
  just above the screen and clear of walls. Turn one up or down in the
  level's `_rules.tres` while the game runs for more or less of it.
- **The body** (`FatBody`, the buddy's): what a catch really does.
  - Workouts scale with weight: 12% weaker per kg under the middle of the
    window, 12% stronger per kg over it, from 0.35× to 1.8×. Early on, when
    the buddy is light, a workout trims about 1 kg instead of 2.5.
  - Each workout builds 1 **muscle**, plus 0.25 for each point of **rest**.
    Muscle is kept for the whole run and never fades. Each point raises the
    top of the window by 0.05 kg (up to +4 kg at 80) and the burn by
    0.0005 kg/s, so a strong buddy has more room but needs more food. The
    buddy's arms grow and its headband changes colour at 10, 30 and 60.
  - Each bed caught gives 1 rest for the rest of the level (z's over the
    buddy). Beds still add 1.5 kg: rest is what they're worth.
  - **Leftovers:** in a run, servings over the plate's target carry into the
    next level: extra protein (recovery: that many workouts build double
    muscle), grains (energy: blobs 2% faster each) and veg (fibre: treats 3%
    lighter each), up to 10 each.
- **In the zone.** While the buddy is in the Bull's-eye, the blobs are 10%
  faster and the yellow on the scale glows.
- **Training montage.** Levels 1 to 5 each have one stretch, under a
  WORKOUT! sign, of workouts and water and nothing else.
- **The window.** Each level has a target weight window (e.g. 72–78 kg) and
  the buddy starts below it, hungry. At the end it reaches the **gate**, a
  heavy door: too heavy and it doesn't fit through, too light and it can't
  push the door open. In the window, the door swings open: LEVEL CLEAR.
- **The plate.** Each food group fills a third of the plate. A level says how
  many servings fill a third to its line (`plate_target`). The **treat meter**
  has one slot per treat the level allows (`treat_slots`); its star goes dark
  once it overflows. Neither has any effect during play: they only decide
  stars on the report card.
- **Power-ups** are glowing bubbles that chime as they come on screen and
  float: they come down slower than the food (`power_float`), so they stand
  out. They work as soon as they're caught:

  | Power-up | | What it does |
  |---|---|---|
  | GOLDEN APPLE | good | Everything caught takes weight off, and treats don't count, for 5 s |
  | SNEAKERS | good | Every blob runs faster for 6 s |
  | SUGAR CRASH | bad | Every blob is sluggish for 5 s |

- **What players read during play** (`FatHud`, right of the track): the
  scale (the weight, the window in green with muscle's part in darker green,
  its middle third in yellow: the Bull's-eye), the plate with a tick on each
  full third and its servings, the treat meter with its star, muscle and
  rest, and the running power-ups. In the last fifth of a level, a third
  that's still short pulses.

## Report card, the run, upgrades

- At the gate, the **report card** (`FatBreak`) shows: in the window or not,
  then three stars: **Balanced plate** (every third full), **Bull's-eye**
  (stopped in the middle third of the window), **Light on treats** (the meter
  never overflowed). Then the body: muscle (and how much this level), rest,
  and the leftovers going into the next level.
- The lobby's LEVEL option plays **THE RUN** (`FatRun`: levels 1 to 5 in a
  row) or one level on its own (WARM-UP is level 0, then LEVEL 1 to 5).
- In a run, a cleared level is worth 1 upgrade pick plus 1 per star. The
  players take the picks in turns (P1, P2, ..., carrying on between levels),
  each one card from a hand of three, chosen with left and right and taken
  with A (or their push key); with Ask the chef, B swaps the hand. There's no
  limit: most upgrades stack, and a snowball card shows how strong it is now.
- Failing a level ends the run, unless the team has **Second helping**: that
  spends one and plays the level again. The run's report card lists every
  level with its stars, the upgrades and the total stars. Restarting (R, or
  RESTART in the pause menu) starts a new run.
- The upgrades (`FatRun.CARDS`) all help; most stack. The snowball ones grow
  with what the team does:

  | Upgrade | Kind | What it does |
  |---|---|---|
  | INSULIN BOOST | buddy | Treats add 20% less weight |
  | FAST METABOLISM | buddy | Burns 0.04 kg/s more |
  | HEALTHY REPS | buddy | Workouts never take the buddy below the window |
  | IRON STOMACH | buddy | The first treat each level weighs nothing and doesn't count |
  | ROOM TO GROW / ROOM TO SHRINK | window | The top 1 kg higher / the bottom 1 kg lower |
  | COMPOUND INTEREST | window | The top 0.2 kg higher for every star this run (up to 3 kg) |
  | SMALLER PLATE | plate | Each third needs 1 serving fewer (up to 3) |
  | SWEET TOOTH | plate | 2 more treat slots |
  | MEAL PREP | plate | Servings over the target start the next level's plate (up to 2 per third) |
  | BALANCED BONUS | plate | A full third's food weighs 25% less |
  | CHEF'S SPECIAL | plate | The golden apple adds a serving to every third |
  | CLEAN STREAK | treats | Treats 10% lighter per level with the Light on treats star |
  | WATER CHASER | treats | Water takes a treat back off the meter |
  | GYM MEMBERSHIP | muscle | Each workout builds 1 more muscle |
  | PROTEIN SHAKE | muscle | Each protein serving builds half a muscle |
  | PERSONAL TRAINER | muscle | An extra workout every 7 s, sooner the more muscle |
  | RUNNER'S HIGH | muscle | A workout makes every blob 25% faster for 3 s |
  | DEEP SLEEP | rest | A bed gives 2 rest |
  | WELL RESTED | rest | Blobs 3% faster per point of rest |
  | POWER NAP | rest | Beds weigh nothing and give sneakers for 3 s |
  | OLYMPIC SLEEPWALKER | rest | A bed is a workout too |
  | WORKOUT VIDEOS | rest | A TV is a workout instead of lazing |
  | EXTRA HELPINGS | belt | Extra food every 4 s, of whatever the plate is shortest on |
  | SLOW COOKER | belt | The belt 6% slower (up to 3) |
  | SMALL BLOB | blob | Blobs about 15% smaller and a bit quicker (up to 3) |
  | QUICK FEET | blob | Blobs 10% faster |
  | QUICK DASH | blob | The dash recharges 30% faster (up to 2) |
  | TEAMWORK | blob | Food caught within 1 s of another player's catch counts double on the plate |
  | GOLDEN HOUR, FRESH SNEAKERS | power-up | Golden apple / sneakers 3 s longer |
  | SUGAR-PROOF | power-up | Sugar crashes half as long |
  | GOLD STAR | picks | A Bull's-eye star is worth 2 picks |
  | BIGGER MENU | picks | One more card per pick (up to 2) |
  | ASK THE CHEF | picks | One new hand after each level, per card |
  | SECOND HELPING | team | One retry of a failed level |

## The levels

Each level adds one idea and remixes the earlier ones. Numbers are first
guesses, to tune live in each level's `_rules.tres`.

| Level | Title | New idea | Belt (px/s) | Window (kg) | Start | Plate | Treats |
|---|---|---|---|---|---|---|---|
| 0 | WARM-UP | Signs on the belt teach each idea: catch, treats, activity, lanes, bubbles, the window. No plate | 210–250 | 66–76 | 66.5 | – | 3 |
| 1 | BREAKFAST | The plate; sliding walls, splitters, slaloms, bumpers | 280–330 | 72–78 | 71 | 4 | 5 |
| 2 | LUNCH RUSH | Lanes: dividers and three-lane walls; funnels | 300–360 | 72–78 | 71 | 5 | 5 |
| 3 | SNACK ATTACK | Power-up bubbles, good and bad; kickers | 320–380 | 73–77 | 70 | 6 | 5 |
| 4 | DINNER | Pairs of walls that slide together and close in | 330–390 | 73–77 | 68.5 | 7 | 5 |
| 5 | DESSERT | Rush sections (the belt surges ×1.45); an obstacle between every section | 320–380 | 74–76 | 68 | 8 | 5 |

Every level starts the buddy just under the window, hungry. The plate's
target goes up each level, and with the burn a full plate alone lands about
2 kg under the middle of the window. The plate's food is plentiful (15 to
30 servings of each group per level): catching everything makes the buddy
far too heavy, so the choice is what to catch.

## The pieces

| Piece | Where | What it is |
|---|---|---|
| `dont_get_fat_game.gd` | `modes/dont_get_fat/` | The mode: scrolls the belt, loads the level, the burn, rushes, swats, the upgrades, the gate, the report card, the run |
| `FatRun` | `modes/dont_get_fat/` | The run: its levels, upgrades (`CARDS`), report, whose pick it is, the muscle and leftovers it carries. `FatRun.current` lives on while the scene reloads for the next level |
| `FatHud` | `modes/dont_get_fat/` | The scale, the plate, the treat meter, the power-ups |
| `FatBreak` | `modes/dont_get_fat/` | The report card, the upgrade picks, the run's report card |
| `FatSettings` (`fat_settings.tres`) | `modes/dont_get_fat/` | Numbers shared by every level: the view, the buddy's size, each item's kg, power-up times |
| `FatRules` | `level/maps/<level>/<level>_rules.tres` | One level's numbers: title, start weight, the window, belt speed, rush speed, drift, the plate's target, treat slots, the feeder |
| `fat_moves.tres` | `modes/dont_get_fat/` | The blobs' `MoveRules`: dash and swat |
| `Buddy` | `entities/buddy/` | The character: weight, window, face, muscle and rest on show, the team's power-ups |
| `FatBody` | `modes/dont_get_fat/` | The buddy's body: the plate, treats, scaled workouts, muscle, rest, and what the upgrades change about eating |
| `BeltPickup` | `level/pickups/health/` | Base of anything blobs catch on the belt: sway, fading out |
| `HealthItem`, `PowerUp` | `level/pickups/health/` | The items (kinds, groups, swat), the power-ups |
| `BeltBounds` | `level/arenas/track/` | Keeps blobs in the helpers' zone; its bottom edge is the laser (`lethal`) |
| `Gate` | `level/maps/` | The end of a level: the heavy door (a `FinishLine`) |
| `BeltSign`, `RushZone` | `level/maps/` | A sign painted across the belt; a stretch where the belt surges |

Tuning while the game runs: `fat_settings.tres` and a level's
`_rules.tres` apply at once. A change to the level's `.tscn` shows the next
time the level loads (R starts a new run).

## Making a level

A level is a map scene (`Map` root) like the treadmill's courses:
`level/maps/fat_1/fat_1.tscn`, with its rules in `fat_1_rules.tres` (the map's
`rules`). Children:

- `Signs`: `BeltSign`s (set `text`).
- `Rushes`: `RushZone`s; each covers `length` px up the belt from where it sits.
- `Items`: `HealthItem` nodes (`health_item.tscn`). Pick the `kind`. Set
  `sway` (px, negative = starts the other way) and `sway_time` to make one
  slide side to side.
- `PowerUps`: `PowerUp` nodes (`power_up.tscn`).
- `Obstacles`: `Bumper`s and `WallBlock`s: plain walls, `kicker` walls (the
  bouncy ones), or sliding ones (`slide` px either way, `slide_time`).
- `Spawns`: `SpawnPoint` P1..P4.
- `Gate`: the end. A level is about 100 px per 1 m on the HUD.

Levels 0 to 5 are laid out by `tools/make_fat_levels.py`, section by
section (snakes of food, good-or-junk pairs, junk rows with gaps, funnels,
splitters, lanes, three lanes, the lazy zone, kickers, bumpers, swaying
rows, bubbles with what they're for, sliding walls, rushes, the training
montage, a final weigh-in of food and activity, with an obstacle between
sections more often each level). It also writes each level's rules,
including the feeder's rates and a start weight worked out from the plate
and the burn. Run it from the project folder (`python3
tools/make_fat_levels.py .`, or add level numbers); it overwrites the
levels, hand edits included. For more or less of something in one level,
change its feeder in the `_rules.tres` instead.

Power-ups float, so one reaches the blobs about 600 px of belt later than
where it sits in the editor. Place them that much nearer the start than the
items they belong with.

New level: copy a level's folder, rename it, and add a choice to the
`fat_level` option in `GameSettings.OPTIONS`; for it to be part of the run,
add it to `FatRun.LEVELS`.

## Not done yet

- The best stars per level aren't saved or shown on the level select.
- Caught food flies to the buddy, not into the plate on the HUD (the plate's
  third flashes when it lands).
- Upgrades with a downside as well as an upside (Cheat day) are left out for now.
