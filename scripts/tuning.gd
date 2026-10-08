extends RefCounted
## Every "feel" knob in one place. Change a number, save, press F5.
## Speeds are pixels/second, times are seconds. Mass starts at 1.0.

# --- Arena -------------------------------------------------------------------
const WALL_RADIUS := 380.0        # bouncy outer wall (keeps blobs on screen)
const RING_RADIUS := 270.0        # the sumo ring; leave it and the clock starts
const RING_OUT_TIME := 0.8        # how long you can be outside the ring before you're out
const OUTSIDE_DRAG := 4.0         # extra drag in the out-of-bounds "mud"
const OUTSIDE_CONTROL := 0.5      # steering multiplier while in the mud

# --- Blob movement -----------------------------------------------------------
const BASE_RADIUS := 22.0
const BASE_SPEED := 230.0         # top speed at mass 1
const BASE_ACCEL := 1400.0        # how snappy steering is at mass 1
const DRAG := 1.6                 # general damping; higher = slides less after a hit
const KNOCKBACK_CONTROL := 0.2    # steering multiplier while flying faster than your top speed
const STUN_CONTROL := 0.05        # steering multiplier right after being pushed
const MAX_MASS := 4.0
const SIZE_RADIUS_EXP := 0.45     # radius = BASE_RADIUS * mass^this
const SIZE_SPEED_EXP := 0.35      # top speed = BASE_SPEED / mass^this
const SIZE_ACCEL_EXP := 0.45      # accel = BASE_ACCEL / mass^this (big = sluggish)
const SUBSTEPS := 2               # physics substeps per frame (stops fast blobs tunnelling)

# --- Bouncing ----------------------------------------------------------------
const BLOB_RESTITUTION := 0.9     # 0 = dead thud, 1 = perfect bounce
const BUMP_POP := 70.0            # extra separation speed on every real contact (the "boing")
const BUMP_POP_MIN_IMPACT := 40.0
const WALL_RESTITUTION := 0.7

# --- Push ability ------------------------------------------------------------
const PUSH_WINDUP := 0.07         # tiny tense-up before the blast
const PUSH_COOLDOWN := 0.9
const PUSH_BUFFER := 0.15         # pressing slightly early still counts
const PUSH_RANGE := 70.0          # reach beyond your own edge
const PUSH_RANGE_MASS_EXP := 0.3  # bigger blobs reach a bit further
const PUSH_IMPULSE := 650.0       # speed given to a mass-1 target by a mass-1 pusher, point blank
const PUSH_FALLOFF := 0.45        # impulse multiplier at the very edge of the reach
const PUSH_MASS_EXP := 0.7        # pusher strength = mass^this
const PUSH_RESIST_EXP := 0.85     # target resistance = mass^this
const PUSH_RECOIL := 0.12         # how much the pusher gets shoved back
const PUSH_STUN := 0.35           # how long the victim loses control
const PUSH_SWELL := 0.45          # how much the pusher visually puffs up

# --- Jelly (squash & stretch) ------------------------------------------------
const JELLY_STIFFNESS := 380.0    # higher = faster wobble
const JELLY_DAMPING := 9.0        # lower = wobbles longer
const JELLY_BULGE := 0.7          # sideways bulge when squashed (keeps it looking like jelly)
const SQUASH_KICK := 0.011        # squash per px/s of impact
const SQUASH_KICK_MAX := 9.0
const SQUASH_MAX := 0.5
const MOVE_STRETCH := 0.0004      # stretch along velocity per px/s
const MOVE_STRETCH_MAX := 0.2
const SWELL_STIFFNESS := 300.0
const SWELL_DAMPING := 10.0

# --- Juice -------------------------------------------------------------------
const HITSTOP_PUSH := 0.06        # freeze frames when a push connects
const HITSTOP_BUMP := 0.03
const HITSTOP_MIN_IMPACT := 500.0
const SHAKE_PUSH := 7.0
const SHAKE_WHIFF := 1.5
const SHAKE_PER_IMPACT := 0.012
const SHAKE_MIN_IMPACT := 250.0
const SHAKE_MAX := 18.0
const SHAKE_DECAY := 9.0
const SPARK_MIN_IMPACT := 150.0
const SFX_VOLUME_DB := -8.0

# --- Food --------------------------------------------------------------------
const FOOD_MAX := 6
const FOOD_SPAWN_INTERVAL := 2.0
const FOOD_MASS := 0.25           # mass gained per pellet
const FOOD_RADIUS := 7.0

# --- Bots --------------------------------------------------------------------
const BOT_COUNT := 4
const BOT_THINK_TIME := 0.15      # seconds between decisions
const BOT_REACTION := 0.18        # delay before they actually push
const BOT_TURN_RATE := 7.0        # how fast their steering follows their intent
const BOT_WOBBLE := 0.25          # random wiggle so they don't look robotic
const BOT_LEAD := 0.25            # how far ahead they aim at a moving target (s)
const BOT_PLAYER_BIAS := 60.0     # how much more they like picking on you

# --- Round -------------------------------------------------------------------
const COUNTDOWN := 2.4

# --- Colours -----------------------------------------------------------------
const PLAYER_COLOR := Color(0.3, 0.85, 1.0)
const FLOOR_COLOR := Color(0.19, 0.22, 0.31)
const MOAT_COLOR := Color(0.14, 0.08, 0.11)
const RING_EDGE_COLOR := Color(1.0, 0.85, 0.55)
const WALL_COLOR := Color(0.55, 0.6, 0.8)
const FOOD_COLOR := Color(1.0, 0.9, 0.35)
