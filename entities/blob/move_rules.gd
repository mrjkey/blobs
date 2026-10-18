class_name MoveRules
extends Resource
## Which special moves blobs have and what limits them, and how fast blobs
## lose mass where they can (Blob.loses_mass: the modes that turn it on in
## their ModeInfo). Blobs share the one GameSettings.rules() builds from the
## player's settings; a mode could give its blobs another. The numbers for
## each move are in BlobStats.

enum Dash {
	NONE,
	BUMP, ## a quick solid burst: hits whatever is in the way
	GHOST, ## a quick ethereal burst: passes through blobs, pushes and lasers
}

enum Energy {
	OFF, ## every move has its own cooldown
	DASH, ## the dash costs energy, the other moves keep their cooldowns
	ALL, ## every move costs energy
}

@export var dash := Dash.NONE
@export var ghost_obstacles := false # a ghost dash also passes through walls and bumpers (not the arena)
@export var energy := Energy.OFF
@export var bots_dash := true
@export var slash := false # a quick blade swing the way the blob faces
@export var spit := false # a glob fired the way the blob faces
@export var shield := false # a short bubble that blocks pushes and slashes and sends spit back

@export_group("Mass loss")
@export var mass_decay := 0.0 # mass lost per second, all the time
@export var spit_mass := 0.0 # mass lost per spit
@export var laser_mass := 0.0 # mass burnt off by a laser hit


func dash_costs_energy() -> bool:
	return energy != Energy.OFF


## The push, the slash and the spit.
func attacks_cost_energy() -> bool:
	return energy == Energy.ALL


func push_costs_energy() -> bool:
	return attacks_cost_energy()


func shield_costs_energy() -> bool:
	return energy == Energy.ALL
