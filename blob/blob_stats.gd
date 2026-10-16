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
@export var max_mass := 4.0
@export var food_mass := 0.25       # mass gained per pellet
@export var size_radius_exp := 0.45 # radius = base_radius * mass^this
@export var size_speed_exp := 0.35  # top speed = base_speed / mass^this
@export var size_accel_exp := 0.45  # accel = base_accel / mass^this (big = sluggish)

@export_group("Push")
@export var push_impulse := 1050.0 # speed given to a mass-1 target by a mass-1 pusher, point blank
@export var push_range := 70.0     # reach beyond your own edge
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
