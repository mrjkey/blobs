@tool
class_name FatRules
extends Resource
## One Don't Get Fat! level's numbers, in its map's `rules` (a .tres next to
## the map, so it can be tuned while the game runs). Harder levels: a faster
## belt, a narrower window, a fuller plate, fewer treat slots.

@export var title := "" # shown in the status line and on the report card, e.g. "BREAKFAST"
@export var start_weight := 64.0 # kg when the level starts (below the window: the buddy is hungry)
@export var window_low := 72.0 # the gate's door only opens for a buddy at least this heavy...
@export var window_high := 78.0 # ...and its opening only fits one at most this heavy
@export var drift := 0.0 # kg the buddy gains every second on its own (< 0: it burns weight)
@export var scroll_start := 280.0 # belt speed (px/s) at the start...
@export var scroll_end := 330.0 # ...rising evenly to this at the gate
@export var rush_speed := 1.5 # the belt's speed, times this, in a RushZone

@export_group("The plate")
@export var plate := true # false: no plate or treat meter (the warm-up level)
@export var plate_target := 4 # servings of each food group that fill its third to the line
@export var treat_slots := 3 # treats the Light on treats star allows


## The middle of the window: dead centre for the Bull's-eye star.
func window_mid() -> float:
	return (window_low + window_high) * 0.5
