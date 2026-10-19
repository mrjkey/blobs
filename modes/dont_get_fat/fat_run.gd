class_name FatRun
extends RefCounted
## A run of Don't Get Fat!: LEVELS in a row with the same team. After each
## level the report card gives stars, and every star is an extra upgrade pick
## (1 pick for clearing it, +1 per star); the players take the picks in turns,
## one card from a hand of three. Upgrades last until the run ends. Failing a
## level ends the run, unless the team took Second helping, which spends one
## to try that level again. What each upgrade does is up to the code that
## reads count(): the mode, the Buddy, the items. `current` holds the run
## being played, so it lives on while the mode's scene reloads for the next
## level; null means a single level is being played on its own (no upgrades).

## The levels of a run, in order (map ids: res://level/maps/<id>/<id>.tscn).
const LEVELS := ["fat_1", "fat_2", "fat_3", "fat_4", "fat_5"]

## Every upgrade: [title, kind, what it does, how many times it can be taken (0 = no limit)].
## All of them help; most stack.
const CARDS := {
	"insulin": ["INSULIN BOOST", "BUDDY", "Treats add 20% less weight.", 0],
	"metabolism": ["FAST METABOLISM", "BUDDY", "Your buddy burns weight faster: 0.04 kg more every second.", 0],
	"getting_fit": ["GETTING FIT", "BUDDY", "Each workout caught is muscle: the top of the window goes up 0.5 kg (up to 3 kg a level).", 0],
	"healthy_reps": ["HEALTHY REPS", "BUDDY", "Workouts never take your buddy below the window.", 1],
	"iron_stomach": ["IRON STOMACH", "BUDDY", "The first treat each level weighs nothing and doesn't count.", 0],
	"room_to_grow": ["ROOM TO GROW", "WINDOW", "The top of the window goes up 1 kg.", 0],
	"room_to_shrink": ["ROOM TO SHRINK", "WINDOW", "The bottom of the window goes down 1 kg.", 0],
	"smaller_plate": ["SMALLER PLATE", "PLATE", "Each third of the plate needs 1 serving fewer.", 3],
	"sweet_tooth": ["SWEET TOOTH", "PLATE", "The treat meter has 2 more slots.", 0],
	"more_workouts": ["MORE WORKOUTS", "BELT", "Extra dumbbells and footballs come down the belt.", 0],
	"extra_helpings": ["EXTRA HELPINGS", "BELT", "Extra food comes down the belt: whatever the plate is shortest on.", 0],
	"slow_cooker": ["SLOW COOKER", "BELT", "The belt runs 6% slower.", 3],
	"small_blob": ["SMALL BLOB", "BLOB", "Blobs are 15% smaller (and a bit quicker): easier to squeeze past things.", 3],
	"quick_feet": ["QUICK FEET", "BLOB", "Blobs run 10% faster.", 0],
	"quick_dash": ["QUICK DASH", "BLOB", "The dash recharges 30% faster.", 2],
	"golden_hour": ["GOLDEN HOUR", "POWER-UP", "The golden apple lasts 3 s longer.", 0],
	"fresh_sneakers": ["FRESH SNEAKERS", "POWER-UP", "Sneakers last 3 s longer.", 0],
	"sugar_proof": ["SUGAR-PROOF", "POWER-UP", "Sugar crashes last half as long.", 0],
	"second_helping": ["SECOND HELPING", "TEAM", "Fail a level and try it again once, instead of ending the run.", 0],
}

static var current: FatRun

var level := 0 # index into LEVELS
var upgrades := {} # card id -> times taken
var report: Array = [] # one entry per level played: {title, cleared, stars: [plate, bull's-eye, treats]}
var turn := 0 # who picks next, counting round the human players; carries on between levels


## Start a new run at its first level.
static func start() -> FatRun:
	current = FatRun.new()
	return current


static func stop() -> void:
	current = null


## How many times the run has taken upgrade `id` (0 outside a run).
static func count(id: String) -> int:
	return current.upgrades.get(id, 0) if current != null else 0


## The map scene of the run's current level.
func level_path() -> String:
	return "res://level/maps/%s/%s.tscn" % [LEVELS[level], LEVELS[level]]


func last_level() -> bool:
	return level >= LEVELS.size() - 1


func take(id: String) -> void:
	upgrades[id] = upgrades.get(id, 0) + 1


## Three different cards to pick from, leaving out the ones taken as often as they can be.
func hand(rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = []
	for id: String in CARDS:
		var most: int = CARDS[id][3]
		if most == 0 or upgrades.get(id, 0) < most:
			pool.append(id)
	var out: Array[String] = []
	while out.size() < 3 and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


## The run's stars so far.
func stars() -> int:
	var n := 0
	for r: Dictionary in report:
		for s: bool in r.stars:
			n += 1 if s else 0
	return n
