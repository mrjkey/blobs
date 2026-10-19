@tool
class_name FatRules
extends Resource
## One Don't Get Fat! level's numbers, in its map's `rules` (a .tres next to
## the map, so it can be tuned while the game runs). Raise the speeds or
## tighten the limit for harder levels.

@export var start_weight := 80.0 # kg when the level starts
@export var max_weight := 90.0 # the gate's limit: heavier than this when the buddy reaches it fails the level
@export var drift := 0.0 # kg the buddy gains every second on its own (0 = none)
@export var scroll_start := 210.0 # belt speed (px/s) at the start...
@export var scroll_end := 260.0 # ...rising evenly to this at the gate
