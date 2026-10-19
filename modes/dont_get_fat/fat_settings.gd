@tool
class_name FatSettings
extends Resource
## Don't Get Fat! knobs shared by every level: the view, the buddy's size,
## what each item does to its weight, and the power-ups. Shared through
## modes/dont_get_fat/fat_settings.tres. What changes from level to level (start
## weight, the gate's limit, the belt's speed) is in each map's FatRules.
## @tool so the Gate can size its opening in the editor.

@export_group("Belt and camera")
@export var view_height := 1150.0 # world height on screen (the track and its side zones always fit across)
@export var top_margin := 30.0 # blobs stay this far below the top of the screen
@export var zone_bottom := 300.0 # the helpers' zone ends this far below the screen's centre (the dashed line)
@export var buddy_y := 445.0 # the buddy walks this far below the screen's centre
@export var blob_speed := 1.0 # blobs' top speed and acceleration, times this
@export var start_ramp := 2.0 # seconds for the belt to get up to speed after GO
@export var finish_walk := 450.0 # px the belt keeps going once the buddy fits through the gate

@export_group("Buddy")
@export var buddy_radius := 62.0 # body radius at base_weight
@export var base_weight := 75.0
@export var size_exp := 1.25 # radius = buddy_radius * (weight / base_weight)^this
@export var min_weight := 50.0 # it never gets lighter than this...
@export var max_weight := 140.0 # ...or heavier than this

@export_group("Items")
@export var item_size := 28.0 # drawing scale of an item (about its radius)
@export var catch_radius := 22.0 # a blob catches an item when their centres are this much closer than the blob's radius
@export var fly_time := 0.4 # a caught item takes this long to reach the buddy
## kg each kind adds to the buddy: + for junk, - for the good stuff.
@export var weights := {
	"burger": 4.0, "fries": 3.0, "cake": 4.0, "donut": 3.0, "soda": 2.0, "bed": 3.0, "tv": 2.0,
	"apple": -2.0, "carrot": -2.0, "broccoli": -2.0, "water": -1.0, "dumbbell": -3.0, "football": -3.0,
}

@export_group("Power-ups")
@export var magnet_time := 6.0
@export var magnet_radius := 300.0 # items this close to the blob with the magnet get pulled in
@export var magnet_pull := 650.0 # px/s at point blank, less further out
@export var golden_time := 5.0 # everything caught counts as good this long
@export var sneakers_time := 6.0
@export var sneakers_speed := 1.35 # blobs' speed, times this
@export var crash_time := 5.0 # sugar crash
@export var crash_speed := 0.55 # blobs' speed, times this


## The buddy's body radius at `weight` kg.
func radius_at(weight: float) -> float:
	return buddy_radius * pow(clampf(weight, min_weight, max_weight) / base_weight, size_exp)


## How chubby the buddy looks at `weight` kg: -0.5 (thin) to 1 (as big as it gets), 0 at base_weight.
func chubby(weight: float) -> float:
	return clampf((weight - base_weight) / 30.0, -0.5, 1.0)


## Half the buddy's body width at `weight` kg: it gets wider than it is tall as it gets heavier.
## The gate's opening is this wide at the level's limit.
func half_width_at(weight: float) -> float:
	return radius_at(weight) * (1.0 + 0.12 * chubby(weight))


## The kg `kind` (e.g. "burger") adds to the buddy; 0 for a kind with no entry.
func weight_of(kind: String) -> float:
	return weights.get(kind, 0.0)
