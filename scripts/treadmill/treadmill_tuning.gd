extends RefCounted
## Treadmill mode knobs. Blob physics still comes from scripts/tuning.gd and the
## neon look (glow, grid, music, BRIGHTNESS) from scripts/neon/neon_tuning.gd.

# --- Track & camera ----------------------------------------------------------
const TRACK_WIDTH := 700.0         # distance between the side walls
const VIEW_HEIGHT := 820.0         # world units visible top to bottom (16:9 window)
const SIDE_ZONE := 150.0           # space beside the track where the laser ships fly
const SCROLL_START := 55.0         # camera speed (px/s) when the round starts
const SCROLL_MAX := 130.0          # top camera speed
const SCROLL_RAMP_TIME := 90.0     # seconds to go from start speed to top speed
const EDGE_INSET := 26.0           # how far inside the screen edge the kill lasers sit

# --- Obstacles ---------------------------------------------------------------
const CHUNK_HEIGHT := 420.0        # the track is generated in slices this tall
const START_CLEAR := 260.0         # empty floor above the spawn line
const OBSTACLE_GAP := 95.0         # min space between obstacles (a full-size blob is ~80 wide)
const WALL_THICKNESS := 24.0
const KICKER_SPEED := 650.0        # pink walls fling you away at this speed
const BUMPER_KICK := 780.0         # round pinball bumpers fling you at this speed
const BUMPER_STUN := 0.2
const DIFFICULTY_DISTANCE := 6000.0  # px travelled until obstacles are at their densest
const FOOD_PER_CHUNK_MAX := 2

# --- Laser ships -------------------------------------------------------------
const SHIPS_PER_SIDE := 2
const SHIP_SPEED := 0.6            # how fast they cruise up and down
const LASER_START_DELAY := 5.0     # seconds of peace after "BUMP!"
const LASER_CHARGE_BEATS := 2.0
const LASER_LOCK_BEATS := 0.75
const LASER_FIRE_BEATS := 0.5
const LASER_WIDTH := 20.0
const LASER_IMPULSE := 650.0

# --- Players & bots ----------------------------------------------------------
const BOTS_VS_CPU := 3
const BOTS_WITH_TWO_PLAYERS := 2
const JOY_DEADZONE := 0.25

# --- Colours -----------------------------------------------------------------
const P1_COLOR := Color(0.3, 0.85, 1.0)
const P2_COLOR := Color(1.0, 0.5, 0.1)
const SIDE_WALL_COLOR := Color(0.5, 0.3, 1.0)
const WALL_COLOR := Color(0.45, 0.35, 1.0)
const KICKER_COLOR := Color(1.0, 0.3, 0.75)
const BUMPER_COLOR := Color(1.0, 0.8, 0.2)
const EDGE_LASER_COLOR := Color(1.0, 0.12, 0.15)
const SHIP_COLOR := Color(1.0, 0.3, 0.7)
const BEAM_COLOR := Color(1.0, 0.15, 0.6)
const BELT_COLOR := Color(0.35, 0.3, 1.0)
