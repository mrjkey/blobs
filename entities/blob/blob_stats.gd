class_name BlobStats
extends Resource
## How one kind of blob moves, pushes and wobbles. Shared by every blob that
## uses the same .tres, so edits apply to all of them (live, while the game runs).
## Speeds are pixels/second, times are seconds. Mass starts at 1.0.

@export_group("Movement")
@export var base_radius := 22.0
@export var base_speed := 330.0   # top speed at mass 1
@export var base_accel := 3200.0  # how snappy steering is at mass 1 (was 1400: ~0.27s to top speed felt like sludge)
@export var turn_accel_mult := 1.6 # extra accel when steering against your current motion
@export var drag := 1.6 # damping during normal movement
@export var knockback_drag := 4.0 # damping while launched faster than top speed (was effectively 1.6: long floaty glide)
@export_range(0.0, 1.0) var knockback_control := 0.3 # steering multiplier while flying faster than your top speed
@export_range(0.0, 1.0) var stun_control := 0.05 # steering multiplier right after being pushed
@export var outside_drag := 4.0 # extra drag in the out-of-bounds "mud"
@export_range(0.0, 1.0) var outside_control := 0.5 # steering multiplier while in the mud

@export_group("Size")
@export var max_mass := 10.0
@export var food_mass := 0.25       # mass gained per pellet
@export var low_mass := 0.6         # where blobs lose mass: below this it flashes a warning...
@export var min_mass := 0.35        # ...and below this it pops
@export var size_radius_exp := 0.45 # radius = base_radius * mass^this
@export var size_speed_exp := 0.35  # top speed = base_speed / mass^this
@export var size_accel_exp := 0.45  # accel = base_accel / mass^this (big = sluggish)

@export_group("Push")
@export var push_impulse := 1350.0 # speed given to a mass-1 target by a mass-1 pusher, point blank
@export var push_range := 90.0     # reach beyond your own edge
@export var push_range_mass_exp := 0.3 # bigger blobs reach a bit further
@export var push_falloff := 0.45   # impulse multiplier at the very edge of the reach
@export var push_mass_exp := 0.7   # pusher strength = mass^this
@export var push_resist_exp := 0.85 # how hard this blob is to shove: resistance = mass^this
@export var push_recoil := 0.12    # how much the pusher gets shoved back
@export var push_windup := 0.07    # tiny tense-up before the blast
@export var push_cooldown := 0.9
@export var push_buffer := 0.15    # pressing slightly early still counts
@export var push_stun := 0.35      # how long this blob loses control after being pushed
@export var push_swell := 0.45     # how much the pusher visually puffs up
@export var push_energy_cooldown := 0.3 # replaces push_cooldown when pushes cost energy

@export_group("Dash")
@export var dash_speed := 1150.0   # launch speed at mass 1 (scaled like top speed)
@export var dash_time := 0.16      # seconds of flight: distance is about speed * time
@export var dash_exit_speed := 1.0 # speed when the dash runs out, as a multiple of top speed
@export var dash_cooldown := 1.1   # used when energy is off
@export var dash_hit_stun := 0.3   # a solid dash knocks the blob it hits out of control this long

@export_group("Slash")
@export var slash_impulse := 820.0 # speed given to a mass-1 target, along the swing
@export var slash_range := 62.0    # how far the blade reaches beyond your own edge
@export var slash_angle := 65.0    # half the arc's width, in degrees
@export var slash_active := 0.07   # the blade cuts for this long (it fires the frame you press)
@export var slash_cooldown := 0.3  # between swings, whatever the energy rules
@export var slash_lunge := 110.0   # a small step into each swing (px/s)
@export var slash_recoil := 280.0  # the slasher bounces back off what it hits (px/s)
@export var slash_stun := 0.22
@export var slash_blocked_recoil := 560.0 # slashing a shield throws you back this hard...
@export var slash_blocked_stun := 0.35    # ...and staggers you this long

@export_group("Spit")
@export var spit_impulse := 650.0  # speed given to a mass-1 target
@export var spit_speed := 620.0
@export var spit_range := 520.0    # distance it flies before it fizzles
@export var spit_radius := 8.0
@export var spit_recoil := 90.0    # the spitter is nudged back this much (px/s)
@export var spit_cooldown := 0.6
@export var spit_energy_cooldown := 0.25 # replaces spit_cooldown when it costs energy
@export var spit_stun := 0.25

@export_group("Shield")
@export var shield_time := 0.4     # how long it stays up: pushes and slashes are blocked, spit flies back
@export var shield_move := 0.55    # top speed multiplier while it's up
@export var shield_absorb := 0.12  # share of a blocked hit's knockback that still gets through
@export var shield_cooldown := 1.2 # used when it doesn't cost energy
@export var shield_energy_cooldown := 0.3 # between shields when it costs energy
@export var reflect_speedup := 1.15 # each reflection flies this much faster...
@export var reflect_boost := 1.15   # ...and hits this much harder
@export var shot_max_speed := 1500.0 # rallies speed up to this, no further

@export_group("Energy")
@export var energy_segments := 4   # size of the bar
@export var energy_regen := 0.85   # segments refilled per second
@export var energy_regen_delay := 0.35 # refilling pauses this long after spending
@export var dash_cost := 1.0
@export var push_cost := 2.0
@export var slash_cost := 0.5
@export var spit_cost := 1.0
@export var shield_cost := 1.0

@export_group("Jelly")
@export var jelly_stiffness := 380.0
@export var jelly_damping := 9.0
@export var jelly_bulge := 0.7 # sideways bulge when squashed (keeps it looking like jelly)
@export var squash_kick := 0.11 # squash per px/s of impact
@export var squash_kick_max := 9.0
@export var squash_max := 0.5
@export var move_stretch := 0.0004 # stretch along velocity per px/s
@export var move_stretch_max := 0.2
@export var swell_stiffness := 300.0
@export var swell_damping := 10.0
