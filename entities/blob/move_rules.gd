class_name MoveRules
extends Resource
## Which special moves blobs have and what limits them. Blobs share the one
## GameSettings.rules() builds from the player's settings; a mode could give
## its blobs another. The numbers for each move are in BlobStats.

enum Dash {
	NONE,
	BUMP, ## a quick solid burst: hits whatever is in the way
	GHOST, ## a quick ethereal burst: passes through blobs, pushes and lasers
}

enum Energy {
	OFF, ## every move has its own cooldown
	DASH, ## the dash costs energy, pushes keep their cooldown
	ALL, ## the dash and the push both cost energy
}

@export var dash := Dash.NONE
@export var ghost_obstacles := false # a ghost dash also passes through walls and bumpers (not the arena)
@export var energy := Energy.OFF
@export var bots_dash := true


func dash_costs_energy() -> bool:
	return energy != Energy.OFF


func push_costs_energy() -> bool:
	return energy == Energy.ALL
