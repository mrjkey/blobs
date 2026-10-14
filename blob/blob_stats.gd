class_name BlobStats
extends Resource

@export_group("Movement")
@export var base_radius := 22.0
@export var base_speed := 330.0   # top speed at mass 1
@export var base_accel := 3200.0  # how snappy steering is at mass 1 (was 1400: ~0.27s to top speed felt like sludge)
@export var turn_accel_mult := 1.6 # extra accel when steering against your current motion
@export var drag := 1.6 # damping during normal movement
@export var knockback_drag := 4.0 # damping while launched faster than top speed (was effectively 1.6: long floaty glide)
@export_range(0.0, 1.0) var knockback_control := 0.3 # steering multiplier while flying faster than your top speed

@export_group("Push")
@export var push_impulse := 1050.0 # speed given to a mass-1 target by a mass-1 pusher, point blank
@export var push_range := 70.0
@export var push_cooldown := 0.9
@export var push_stun := 0.35

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
