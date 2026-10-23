class_name FatRun
extends RefCounted
## A run of Don't Get Fat!: LEVELS in a row with the same team. After each
## level the report card gives stars, and every star is an extra upgrade pick
## (1 pick for clearing it, +1 per star); the players take the picks in turns,
## one card from a hand of three. Upgrades last until the run ends. Failing a
## level ends the run, unless the team took Second helping, which spends one
## to try that level again. The run also carries the buddy's muscle (never
## lost), the leftovers of a level's plate into the next, and the clean
## streak. What each upgrade does is up to the code that reads count(): the
## mode, the FatBody, the items. `current` holds the run
## being played, so it lives on while the mode's scene reloads for the next
## level; null means a single level is being played on its own (no upgrades).

## The levels of a run, in order (map ids: res://level/maps/<id>/<id>.tscn).
const LEVELS := ["fat_1", "fat_2", "fat_3", "fat_4", "fat_5"]

## Every upgrade: [title, kind, what it does, how many times it can be taken (0 = no limit)].
## All of them help; most stack, and the snowball ones grow with what the team does.
const CARDS := {
	"insulin": ["INSULIN BOOST", "BUDDY", "Treats add 20% less weight.", 0],
	"metabolism": ["FAST METABOLISM", "BUDDY", "Your buddy burns weight faster: 0.04 kg more every second.", 0],
	"healthy_reps": ["HEALTHY REPS", "BUDDY", "Workouts never take your buddy below the window.", 1],
	"iron_stomach": ["IRON STOMACH", "BUDDY", "The first treat each level weighs nothing and doesn't count.", 0],
	"room_to_grow": ["ROOM TO GROW", "WINDOW", "The top of the window goes up 1 kg.", 0],
	"room_to_shrink": ["ROOM TO SHRINK", "WINDOW", "The bottom of the window goes down 1 kg.", 0],
	"compound_interest": ["COMPOUND INTEREST", "WINDOW", "The top of the window goes up 0.2 kg for every star this run (up to 3 kg).", 1],
	"smaller_plate": ["SMALLER PLATE", "PLATE", "Each third of the plate needs 1 serving fewer.", 3],
	"sweet_tooth": ["SWEET TOOTH", "PLATE", "The treat meter has 2 more slots.", 0],
	"meal_prep": ["MEAL PREP", "PLATE", "Servings over the target carry to the next level's plate (up to 2 per third).", 0],
	"balanced_bonus": ["BALANCED BONUS", "PLATE", "Once a third is full, that group's food weighs 25% less.", 1],
	"chefs_special": ["CHEF'S SPECIAL", "PLATE", "The golden apple also adds a serving to every third.", 0],
	"clean_streak": ["CLEAN STREAK", "TREATS", "Treats get 10% lighter for every level with the Light on treats star.", 0],
	"water_chaser": ["WATER CHASER", "TREATS", "Each water caught takes a treat back off the meter.", 1],
	"gym_membership": ["GYM MEMBERSHIP", "MUSCLE", "Each workout builds 1 more muscle.", 0],
	"protein_shake": ["PROTEIN SHAKE", "MUSCLE", "Each protein serving builds half a muscle.", 0],
	"personal_trainer": ["PERSONAL TRAINER", "MUSCLE", "Extra workouts come down the belt, more as your buddy gets stronger.", 0],
	"runners_high": ["RUNNER'S HIGH", "MUSCLE", "Each workout makes every blob 25% faster for 3 s.", 1],
	"deep_sleep": ["DEEP SLEEP", "REST", "Each bed gives 2 rest instead of 1.", 0],
	"well_rested": ["WELL RESTED", "REST", "Blobs are 3% faster for each point of rest.", 0],
	"power_nap": ["POWER NAP", "REST", "Beds weigh nothing, and give the blobs sneakers for 3 s.", 1],
	"sleepwalker": ["OLYMPIC SLEEPWALKER", "REST", "Each bed is a workout too: it burns weight and builds muscle.", 1],
	"workout_videos": ["WORKOUT VIDEOS", "REST", "TVs are workouts: they burn weight and build muscle.", 1],
	"extra_helpings": ["EXTRA HELPINGS", "BELT", "Extra food comes down the belt: whatever the plate is shortest on.", 0],
	"slow_cooker": ["SLOW COOKER", "BELT", "The belt runs 6% slower.", 3],
	"small_blob": ["SMALL BLOB", "BLOB", "Blobs are 15% smaller (and a bit quicker): easier to squeeze past things.", 3],
	"quick_feet": ["QUICK FEET", "BLOB", "Blobs run 10% faster.", 0],
	"quick_dash": ["QUICK DASH", "BLOB", "The dash recharges 30% faster.", 2],
	"teamwork": ["TEAMWORK", "BLOB", "Food caught within 1 s of another player's catch counts double on the plate.", 1],
	"golden_hour": ["GOLDEN HOUR", "POWER-UP", "The golden apple lasts 3 s longer.", 0],
	"fresh_sneakers": ["FRESH SNEAKERS", "POWER-UP", "Sneakers last 3 s longer.", 0],
	"sugar_proof": ["SUGAR-PROOF", "POWER-UP", "Sugar crashes last half as long.", 0],
	"gold_star": ["GOLD STAR", "PICKS", "A Bull's-eye star is worth 2 picks.", 1],
	"bigger_menu": ["BIGGER MENU", "PICKS", "Every pick shows one more card.", 2],
	"ask_the_chef": ["ASK THE CHEF", "PICKS", "Once after each level, swap your hand for a new one.", 0],
	"second_helping": ["SECOND HELPING", "TEAM", "Fail a level and try it again once, instead of ending the run.", 0],
}
## Leftovers: plate servings over the target in one level that help in the next.
const LEFTOVER_MAX := 10

static var current: FatRun

var level := 0 # index into LEVELS
var upgrades := {} # card id -> times taken
var report: Array = [] # one entry per level played: {title, cleared, stars: [plate, bull's-eye, treats]}
var turn := 0 # who picks next, counting round the human players; carries on between levels
var muscle := 0.0 # the buddy's muscle: built by workouts, kept for the whole run (FatBody)
var clean_levels := 0 # levels with the Light on treats star (Clean streak)
var leftovers := {} # for the next level: "energy" (grains), "fibre" (veg), "recovery" (protein) over the target
var prepped: Array[int] = [0, 0, 0] # servings that start the next level's plate (Meal prep)


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


## Online: the run as plain data, so a joined computer can show the same one (from_net()).
func to_net() -> Dictionary:
	return {level = level, upgrades = upgrades, report = report, turn = turn, muscle = muscle,
		clean_levels = clean_levels, leftovers = leftovers, prepped = prepped}


static func from_net(d: Dictionary) -> FatRun:
	var r := FatRun.new()
	r.level = clampi(int(d.get("level", 0)), 0, LEVELS.size() - 1)
	r.upgrades = d.get("upgrades", {}) if d.get("upgrades") is Dictionary else {}
	r.report = d.get("report", []) if d.get("report") is Array else []
	r.turn = int(d.get("turn", 0))
	r.muscle = float(d.get("muscle", 0.0))
	r.clean_levels = int(d.get("clean_levels", 0))
	r.leftovers = d.get("leftovers", {}) if d.get("leftovers") is Dictionary else {}
	if d.get("prepped") is Array and d.prepped.size() == 3:
		r.prepped.assign(d.prepped)
	return r


func take(id: String) -> void:
	upgrades[id] = upgrades.get(id, 0) + 1


## Different cards to pick from (three, more with Bigger menu), leaving out the ones taken as often as they can be.
func hand(rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = []
	for id: String in CARDS:
		var most: int = CARDS[id][3]
		if most == 0 or upgrades.get(id, 0) < most:
			pool.append(id)
	var out: Array[String] = []
	while out.size() < 3 + count("bigger_menu") and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


## The run's stars so far.
func stars() -> int:
	var n := 0
	for r: Dictionary in report:
		for s: bool in r.stars:
			n += 1 if s else 0
	return n


## How strong a snowball card is right now, for the card ("" for the others).
func note(id: String) -> String:
	match id:
		"clean_streak":
			return "%d clean level%s so far" % [clean_levels, "" if clean_levels == 1 else "s"]
		"compound_interest":
			return "%d stars so far: +%.1f kg" % [stars(), minf(0.2 * stars(), 3.0)]
		"personal_trainer":
			return "muscle %d" % roundi(muscle)
	return ""


## What a cleared level leaves for the next: muscle, leftovers (servings
## over `target` in each third), Meal prep, the clean streak.
func carry(body: FatBody, target: int, entry: Dictionary) -> void:
	muscle = body.muscle
	var over := func(i: int) -> int: return clampi(body.plate[i] - target, 0, LEFTOVER_MAX)
	leftovers = {"recovery": over.call(0), "energy": over.call(1), "fibre": over.call(2)}
	for i in 3:
		prepped[i] = mini(over.call(i), 2 * count("meal_prep"))
	if entry.stars[2]:
		clean_levels += 1
