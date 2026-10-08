extends RefCounted
## Knobs for the neon night-club variant. Gameplay numbers still come from
## scripts/tuning.gd; these only cover the look, the music and the lasers.

# --- Glow --------------------------------------------------------------------
# Anything drawn brighter than GLOW_THRESHOLD blooms. Neon colours are drawn at
# 1.5x-3x brightness on purpose; see hdr() in neon_game.gd.
const GLOW_INTENSITY := 0.9
const GLOW_STRENGTH := 1.0
const GLOW_THRESHOLD := 0.95
const BLOB_GLOW := 2.4             # brightness of blob outlines
const TRAIL_FRAMES := 12           # trail length in frames

# --- Grid --------------------------------------------------------------------
const GRID_SPACING := 40.0
const GRID_HALF_SIZE := Vector2(760, 460)
const GRID_STIFFNESS := 70.0       # pull back to rest
const GRID_DAMPING := 5.0
const GRID_COUPLING := 45.0        # how much ripples spread to neighbours
const GRID_COLOR := Color(0.25, 0.2, 1.0)
const GRID_IMPACT_SCALE := 0.35    # impact speed -> grid kick

# --- Music -------------------------------------------------------------------
const BPM := 128.0
const MUSIC_DB := -9.0
const BEAT_PULSE := 0.008          # camera zoom thump on every kick

# --- Lasers ------------------------------------------------------------------
const TURRET_COUNT := 6
const TURRET_ORBIT_SPEED := 0.12   # radians/second while idle
const TURRET_DISTANCE := 50.0      # outside the wall
const LASER_START_DELAY := 4.0     # seconds of peace after "BUMP!"
const LASER_CHARGE_BEATS := 2.0    # telegraph length
const LASER_LOCK_BEATS := 0.75     # aim freezes this many beats before firing
const LASER_FIRE_BEATS := 0.5      # how long the beam stays visible
const LASER_WIDTH := 20.0          # hit width
const LASER_IMPULSE := 700.0       # knockback on a mass-1 blob
const LASER_COLOR := Color(1.0, 0.15, 0.6)
const TURRET_COLOR := Color(1.0, 0.3, 0.7)

# --- Colours -----------------------------------------------------------------
const FLOOR_COLOR := Color(0.03, 0.0, 0.09, 0.6)
const MOAT_COLOR := Color(0.1, 0.0, 0.04, 0.55)
const RING_COLOR := Color(1.0, 0.6, 0.15)
const WALL_COLOR := Color(0.5, 0.3, 1.0)
const FOOD_COLOR := Color(0.9, 1.0, 0.3)
