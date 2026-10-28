extends GameMode
## Don't Get Fat!: co-op for 1 to 4 players, no computers. The blobs are the
## helpers of the buddy, who walks along at the bottom of the screen. The belt
## scrolls up a hand-made level (a Map) and its HealthItems come down at the
## blobs. Whatever they catch flies to the buddy: all food adds weight
## (treats a lot), activity burns it off, and the plate's food fills the
## plate. PowerUps work the moment they're caught. At the end the buddy
## reaches the level's Gate: its weight has to be in the level's window
## (FatRules): too heavy and it doesn't fit, too light and it can't push the
## door open. The buddy burns a little weight all the time (FatSettings.burn).
## Then the report card (FatBreak) gives the level's stars.
##
## The lobby's LEVEL option plays a run (FatRun: levels 1 to 5 in a row, with
## upgrade picks between them; failing a level ends it) or one level on its
## own. What a catch does is up to the buddy's FatBody (workouts build muscle,
## beds give rest); its muscle, leftovers and the run's upgrades
## (FatRun.CARDS) are applied here, on the body and on the blobs. The feeder
## (FatRules) drops workouts, beds, water, food and treats onto the belt at a
## steady pace, and some cards drop more. While the buddy is in the Bull's-eye
## the blobs are faster (in the zone).
## Blobs can move, dash and swat (the ModeInfo's `moves`); a swat knocks junk off the
## belt. They stay in the helpers' zone (BeltBounds), whose bottom edge is a
## laser while the belt runs: running into it just bumps a blob back, but a
## wall that shoves one through it pops it, and it comes back RESPAWN_TIME
## later near the top of the zone. The numbers are in
## FatSettings and each map's FatRules. What players read during play is in
## FatHud, beside the belt.
##
## Classic theme only for now (ModeInfo.theme): the items, the buddy and the
## gate are drawn for the classic look, and nothing here is tuned for neon.
##
## Online, a joined computer plays the host's run and level (net_match_info())
## and shows the host's FatHud and screens between levels (net_state()). A
## player there picks upgrade cards with their own controls, through the host.

## Team power-ups the buddy holds, as shown beside the plate.
const BOOSTS := {"golden": PowerUp.Kind.GOLDEN, "sneakers": PowerUp.Kind.SNEAKERS, "sugar_crash": PowerUp.Kind.SUGAR_CRASH}
const ITEM_SCENE := preload("res://level/pickups/health/health_item.tscn")
## Plate food the feeder can drop, by plate third (HealthItem.Group).
const HELPINGS := [[HealthItem.Kind.EGG, HealthItem.Kind.FISH, HealthItem.Kind.DRUMSTICK],
	[HealthItem.Kind.BREAD, HealthItem.Kind.RICE, HealthItem.Kind.CORN],
	[HealthItem.Kind.APPLE, HealthItem.Kind.CARROT, HealthItem.Kind.BROCCOLI, HealthItem.Kind.BANANA]]
const TREATS := [HealthItem.Kind.BURGER, HealthItem.Kind.FRIES, HealthItem.Kind.CAKE, HealthItem.Kind.DONUT, HealthItem.Kind.SODA]
const ZONE_SPEED := 1.1 # blobs' speed, times this, while the buddy is in the Bull's-eye
const RESPAWN_TIME := 3.0 # seconds a zapped blob is gone
const SPAWN_GRACE := 1.5 # seconds a blob that's just back is safe from the laser
const CLEAR_COLOR := Color(0.3, 0.85, 0.4)
const FAIL_COLOR := Color(1.0, 0.35, 0.3)

@export var settings: FatSettings = preload("res://modes/dont_get_fat/fat_settings.tres")
@export var track: TrackSettings = preload("res://level/arenas/track/track_settings.tres")
@export var camera: GameCamera
@export var bounds: BeltBounds
@export var buddy: Buddy
@export_file("*.tscn") var map_path := "" # a level to play on its own instead of the lobby's LEVEL pick

var map: Map
var gate: Gate
var rules: FatRules
var run: FatRun # the run being played, or null for a level on its own
var low := 72.0 # this level's window: the map's FatRules, widened by the run's upgrades (the
var high := 78.0 # buddy's muscle raises the top further: Buddy.top())
var target := 4 # servings that fill each third of the plate (FatRules, less Smaller plate)
var treat_slots := 5 # treats the Light on treats star allows (FatRules, plus Sweet tooth)
var belt_y := 0.0 # world y of the screen's centre
var distance := 0.0
var fat_hud: FatHud
var between: FatBreak
var _play_time := 0.0
var _walk_left := 0.0 # px the belt still goes once the buddy is through the gate
var _hint_left := 0.0 # seconds until the hint goes (it sits over the buddy)
var _rush := 1.0 # the belt's speed, times this: eases up to rush_speed in a RushZone and back
var _rushing := false
var _cleared := false
var _rng := RandomNumberGenerator.new()
var _slot_of := {} # blob -> its index in `slots`
var _respawns: Array = [] # [slot index, seconds left] for each zapped blob
var _feed_in := {} # what the feeder drops -> seconds to the next one
var _last_catch := [null, -10.0] # the blob that last caught plate food, and when (Teamwork)


func _ready() -> void:
	process_physics_priority = -8 # scroll before BlobPhysics and the pickups look at the view
	_rng.randomize()
	if Net.is_client(): # a copy of the host's game: its run and level
		var played := NetGame.match_info
		run = FatRun.from_net(played.run) if played.get("run") is Dictionary else null
		FatRun.current = run
		map_path = str(played.get("map", ""))
	elif GameSettings.choice("fat_level") == "run" and map_path == "":
		run = FatRun.current if FatRun.current != null else FatRun.start()
	else:
		FatRun.stop()
	_load_map()
	low = rules.window_low - FatRun.count("room_to_shrink")
	high = rules.window_high + FatRun.count("room_to_grow")
	if run != null and FatRun.count("compound_interest") > 0:
		high += minf(0.2 * run.stars(), 3.0)
	target = maxi(rules.plate_target - FatRun.count("smaller_plate"), 1)
	treat_slots = rules.treat_slots + 2 * FatRun.count("sweet_tooth")
	buddy.weight = rules.start_weight
	buddy.shown = rules.start_weight
	buddy.low = low
	buddy.high = high
	buddy.body = _make_body()
	if gate != null:
		gate.low = low
		gate.high = high
	_make_screens()
	_follow_belt()
	super._ready()


## The buddy's body for this level: the run's muscle, leftovers and upgrades.
func _make_body() -> FatBody:
	var body := FatBody.new()
	var left: Dictionary = run.leftovers if run != null else {}
	body.target = target
	if run != null:
		body.muscle = run.muscle
		body.plate = run.prepped.duplicate()
	body.muscle_start = body.muscle
	body.free_treats = FatRun.count("iron_stomach")
	var clean := run.clean_levels * FatRun.count("clean_streak") if run != null else 0
	body.treat_scale = maxf(pow(0.8, FatRun.count("insulin")) * pow(0.9, clean) * (1.0 - 0.03 * left.get("fibre", 0)), 0.3)
	body.reps_floor = FatRun.count("healthy_reps") > 0
	body.muscle_per_rep = 1.0 + FatRun.count("gym_membership")
	body.rest_per_bed = 1 + FatRun.count("deep_sleep")
	body.protein_muscle = 0.5 * FatRun.count("protein_shake")
	body.recovery = left.get("recovery", 0)
	body.sleepwalker = FatRun.count("sleepwalker") > 0
	body.power_nap = FatRun.count("power_nap") > 0
	body.tv_workouts = FatRun.count("workout_videos") > 0
	body.balanced_bonus = FatRun.count("balanced_bonus") > 0
	body.water_chaser = FatRun.count("water_chaser") > 0
	body.runners_high = FatRun.count("runners_high") > 0
	return body


func _load_map() -> void:
	rules = FatRules.new()
	var path := map_path
	if path == "":
		path = run.level_path() if run != null else GameSettings.fat_level()
	if not ResourceLoader.exists(path):
		push_warning("Don't Get Fat!: no level at %s" % path)
		return
	map = (load(path) as PackedScene).instantiate()
	add_child(map)
	move_child(map, bounds.get_index())
	if map.rules is FatRules:
		rules = map.rules
	gate = map.finish() as Gate
	for p: PowerUp in map.find_children("*", "PowerUp", true, false):
		p.collected.connect(_on_power_up)
	for h: HealthItem in map.find_children("*", "HealthItem", true, false):
		h.caught.connect(_on_caught)


func _make_screens() -> void:
	var frame := hud.get_node("Frame")
	fat_hud = FatHud.new()
	fat_hud.buddy = buddy
	fat_hud.track_half = track.track_width * 0.5
	frame.add_child(fat_hud)
	between = FatBreak.new()
	between.mirror = Net.is_client()
	frame.add_child(between)
	hud.set_score([])


## "LEVEL 1 · BREAKFAST": the level's number from its map's name (fat_1), and its title.
func level_name() -> String:
	var n := map.scene_file_path.get_file().get_basename().trim_prefix("fat_") if map != null else "?"
	return "LEVEL %s · %s" % [n, rules.title] if rules.title != "" else "LEVEL %s" % n


func _spawn_blobs() -> void:
	var points: Array[SpawnPoint] = map.spawn_points() if map != null else []
	var total := slots.size()
	for i in total:
		var at := Vector2(lerpf(-track.track_width * 0.3, track.track_width * 0.3, (i + 0.5) / total), belt_y + 150.0)
		if i < points.size():
			at = points[i].global_position
		_add_blob(i, at)
	var goal := "Fill the plate and get your buddy through the door at %d–%d kg" % [roundi(low), roundi(high)] if rules.plate \
		else "Catch food to get your buddy to %d–%d kg: too light or too heavy and the door won't let it through" % [roundi(low), roundi(high)]
	hud.set_hint(goal + "\nDASH: B / Shift   ·   SWAT junk: X / J   ·   Don't get pushed into the laser   ·   Start or Esc: pause")


## The blob for `slots[i]` at `at`, with this mode's moves and the run's blob upgrades.
func _add_blob(i: int, at: Vector2) -> Blob:
	var b := spawn_slot(i, at)
	_slot_of[b] = i
	b.rules = info.move_rules()
	b.body.look = Vector2.UP
	b.slashed.connect(_on_slash)
	if FatRun.count("small_blob") > 0:
		b.set_mass(b.mass * pow(0.72, FatRun.count("small_blob"))) # radius about 15% smaller each
	if FatRun.count("quick_dash") > 0:
		b.stats = b.stats.duplicate()
		b.stats.dash_cooldown *= pow(0.7, FatRun.count("quick_dash"))
	return b


## Zapped by the laser: back in RESPAWN_TIME.
func _on_blob_died(b: Blob) -> void:
	if not _slot_of.has(b):
		return
	_respawns.append([_slot_of[b], RESPAWN_TIME])
	_slot_of.erase(b)
	hud.show_banner("ZAPPED!" if b.tag == "" else "%s ZAPPED!" % b.tag, b.color if b.tag != "" else KillLasers.COLOR, 1.2)


func _tick_respawns(delta: float) -> void:
	for r: Array in _respawns:
		r[1] -= delta
	for r: Array in _respawns.filter(func(e: Array) -> bool: return e[1] <= 0.0):
		_respawns.erase(r)
		_respawn(r[0])


## Slot `i`'s blob back near the top of the zone, clear of walls and blobs,
## safe from the laser for a moment.
func _respawn(i: int) -> void:
	var y := belt_y - 150.0
	var at := Vector2(0.0, y)
	for x: float in [0.0, -150.0, 150.0, -260.0, 260.0]:
		var p := Vector2(x, y)
		var clear := true
		for w in get_tree().get_nodes_in_group("blob_colliders"):
			if w is WallBlock and (w as WallBlock).rect().grow(70.0).has_point(p):
				clear = false
		for other in living_blobs():
			if other.global_position.distance_to(p) < 70.0:
				clear = false
		if clear:
			at = p
			break
	var b := _add_blob(i, at)
	b.active = state == State.PLAYING
	bounds.spare(b, SPAWN_GRACE)
	Juice.shockwave(at, 10.0, 90.0, b.color.lightened(0.4), 0.3)
	Sfx.play("pop", 1.2)


## Nobody gets knocked out: the gate decides.
func _check_round_over() -> void:
	pass


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	var moving := state == State.PLAYING or _walk_left > 0.0
	if moving:
		_play_time += delta
		_update_rush(delta)
		var length := -gate.global_position.y if gate != null else 10000.0
		var speed := lerpf(rules.scroll_start, rules.scroll_end, clampf(distance / maxf(length, 1.0), 0.0, 1.0)) \
			* clampf(_play_time / maxf(settings.start_ramp, 0.01), 0.0, 1.0) * _rush * pow(0.94, FatRun.count("slow_cooker"))
		var step := speed * delta
		if state == State.PLAYING and gate != null:
			step = minf(step, maxf(_gap_to_gate(), 0.0))
		elif _walk_left > 0.0:
			step = minf(step, _walk_left)
			_walk_left -= step
		belt_y -= step
		distance += step
		if state == State.PLAYING:
			_tick_respawns(delta)
			var gain := rules.drift - settings.burn - 0.04 * FatRun.count("metabolism") - buddy.body.muscle_burn()
			buddy.weight = clampf(buddy.weight + gain * delta, settings.min_weight, settings.max_weight)
			_feeder(delta, length)
			if gate != null and _gap_to_gate() <= 0.5:
				_reach_gate()
	buddy.walking = moving
	var energy: int = run.leftovers.get("energy", 0) if run != null else 0
	var speed := settings.blob_speed * (1.0 + 0.1 * FatRun.count("quick_feet")) * buddy.speed_factor() \
		* (1.0 + 0.02 * energy) * (1.0 + 0.03 * buddy.body.rest * FatRun.count("well_rested")) \
		* (ZONE_SPEED if in_the_zone() else 1.0)
	for b in living_blobs():
		b.speed_scale = speed
	_follow_belt()


## In a RushZone (where the blobs are) the belt eases up to the level's rush_speed, and back down after.
func _update_rush(delta: float) -> void:
	var inside := false
	for z: RushZone in get_tree().get_nodes_in_group("rush_zones"):
		inside = inside or z.covers(belt_y + 100.0)
	if inside and not _rushing and state == State.PLAYING:
		hud.show_banner("RUSH!", RushZone.COLOR, 0.8)
		Sfx.play("warn", 1.2)
	_rushing = inside
	_rush = move_toward(_rush, rules.rush_speed if inside else 1.0, delta * 1.2)


## The buddy is in the Bull's-eye, the middle third of the window, while the belt runs.
func in_the_zone() -> bool:
	var third := (buddy.top() - low) / 3.0
	return state == State.PLAYING and buddy.weight >= low + third and buddy.weight <= buddy.top() - third


## How far the gate's hedges still are from the top of the buddy's head.
func _gap_to_gate() -> float:
	return belt_y + settings.buddy_y - buddy.radius - (gate.global_position.y + 20.0)


## A swat knocks junk in front of the blob off the belt.
func _on_slash(b: Blob) -> void:
	var reach := b.radius + b.stats.slash_range + settings.item_size
	var cone := deg_to_rad(b.stats.slash_angle + 15.0)
	for item in get_tree().get_nodes_in_group("on_belt"):
		var h := item as HealthItem
		if h == null or not h.is_junk():
			continue
		var rel := h.global_position - b.global_position
		if rel.length() < reach and absf(rel.angle_to(b.body.look)) < cone:
			h.swat(rel)


## The feeder: workouts, beds, water, food and treats dropped onto the belt
## every so often (FatRules), plus Personal trainer's workouts (sooner the
## stronger the buddy) and Extra helpings (what the plate is shortest on),
## until near the gate.
func _feeder(delta: float, length: float) -> void:
	if distance > length - 1500.0:
		return
	var trainer := FatRun.count("personal_trainer")
	var helpings := FatRun.count("extra_helpings")
	var plan := [
		["workout", rules.feed_workouts], ["bed", rules.feed_beds], ["water", rules.feed_water],
		["food", rules.feed_food], ["treat", rules.feed_treats],
		["trainer", 7.0 / trainer / (1.0 + buddy.body.muscle / 30.0) if trainer > 0 else 0.0],
		["helping", 4.0 / helpings if helpings > 0 and rules.plate else 0.0],
	]
	for p: Array in plan:
		var what: String = p[0]
		var every: float = p[1]
		if every <= 0.0:
			continue
		_feed_in[what] = _feed_in.get(what, every * _rng.randf_range(0.3, 1.0)) - delta
		if _feed_in[what] <= 0.0:
			_feed_in[what] = every * _rng.randf_range(0.67, 1.33)
			_drop(_feed_kind(what))


## What the feeder drops for `what`.
func _feed_kind(what: String) -> HealthItem.Kind:
	match what:
		"workout", "trainer":
			return [HealthItem.Kind.DUMBBELL, HealthItem.Kind.FOOTBALL][_rng.randi() % 2]
		"bed":
			return HealthItem.Kind.BED
		"water":
			return HealthItem.Kind.WATER
		"treat":
			return TREATS[_rng.randi() % TREATS.size()]
		"helping":
			var short := 0
			for i in 3:
				if buddy.body.plate[i] < buddy.body.plate[short]:
					short = i
			return HELPINGS[short][_rng.randi() % HELPINGS[short].size()]
	var kinds: Array = HELPINGS[_rng.randi() % 3]
	return kinds[_rng.randi() % kinds.size()]


## Teamwork: plate food caught within 1 s of another blob's catch fills the plate twice.
func _on_caught(item: HealthItem, b: Blob) -> void:
	if item.group() > HealthItem.Group.VEG:
		return
	var now := _play_time
	if FatRun.count("teamwork") > 0 and is_instance_valid(_last_catch[0]) and _last_catch[0] != b and now - _last_catch[1] <= 1.0:
		item.servings = 2
	_last_catch = [b, now]


## A `kind` item on the belt just above the screen, clear of the walls there.
func _drop(kind: HealthItem.Kind) -> void:
	var y := belt_y - settings.view_height * 0.5 - 80.0
	var x := 0.0
	for attempt in 10:
		x = _rng.randf_range(-280.0, 280.0)
		var clear := true
		for w in get_tree().get_nodes_in_group("blob_colliders"):
			if w is WallBlock and (w as WallBlock).rect().grow(50.0).has_point(Vector2(x, y)):
				clear = false
		if clear:
			break
	var item: HealthItem = ITEM_SCENE.instantiate()
	item.kind = kind
	item.position = Vector2(x, y) - map.global_position
	item.caught.connect(_on_caught)
	map.add_child(item)


## The buddy reaches the door: in the window it swings open; too heavy, it doesn't fit; too light, it won't budge.
func _reach_gate() -> void:
	state = State.OVER
	_on_round_over()
	bounds.lethal = false
	for r: Array in _respawns: # everyone back for the report card and the picks
		_respawn(r[0])
	_respawns.clear()
	for b in living_blobs():
		b.active = false
	var w := buddy.weight
	var top := buddy.top()
	var why := ""
	_cleared = w >= low and w <= top
	hud.set_hint("")
	if _cleared:
		_walk_left = settings.finish_walk
		gate.cheer = 1.0
		Juice.burst(gate.global_position, CLEAR_COLOR, 40, 520.0)
		Juice.burst(gate.global_position, Color(1.0, 0.85, 0.3), 30, 380.0)
		Sfx.play("power", 1.3)
		hud.show_banner("LEVEL CLEAR!", CLEAR_COLOR)
		why = "%.1f kg: in the window, and through the door!" % w
	elif w > top:
		buddy.stick()
		Juice.shake(Juice.settings.shake_elimination)
		Juice.burst(buddy.global_position + Vector2(0.0, -buddy.radius), FAIL_COLOR, 24, 380.0)
		Sfx.play("out", 0.7)
		hud.show_banner("TOO HEAVY!", FAIL_COLOR)
		why = "%.1f kg: too heavy to fit through the door (%.1f kg at most)" % [w, top]
	else:
		buddy.stick()
		gate.thud = 1.0
		Juice.shake(Juice.settings.shake_elimination * 0.6)
		Sfx.play("wall", 0.6)
		hud.show_banner("TOO LIGHT!", Buddy.LIGHT_COLOR)
		why = "%.1f kg: too light to push the door open (%d kg at least)" % [w, roundi(low)]
	await get_tree().create_timer(1.8, false).timeout
	hud.show_banner("", Color.WHITE)
	_after_level(_grade(why))


## The level's report card line: whether it was cleared and its three stars.
func _grade(why: String) -> Dictionary:
	var w := buddy.weight
	var top := buddy.top()
	var mid := (low + top) * 0.5
	var bull := (top - low) / 6.0 # the middle third of the window
	var body := buddy.body
	var plate_ok := rules.plate
	for i in 3:
		plate_ok = plate_ok and body.plate[i] >= target
	var over := func(i: int) -> int: return clampi(body.plate[i] - target, 0, FatRun.LEFTOVER_MAX) if rules.plate else 0
	return {
		title = level_name(), cleared = _cleared, why = why, weight = w, low = low, high = top, mid = mid, bull = bull,
		plate = body.plate.duplicate(), target = target, has_plate = rules.plate,
		treats = body.treats, slots = treat_slots,
		stars = [plate_ok, _cleared and absf(w - mid) <= bull, body.treats <= treat_slots],
		muscle = body.muscle, muscle_gained = body.muscle - body.muscle_start, workouts = body.workouts, rest = body.rest,
		leftovers = [over.call(0), over.call(1), over.call(2)],
	}


## After the report card: picks and the next level, a retry (Second helping),
## the run's report card, or (a level on its own) the same level again.
func _after_level(entry: Dictionary) -> void:
	between.inputs = _human_inputs()
	if run == null:
		await between.report(entry, -1)
		super.restart()
		return
	var more: bool = entry.cleared and not run.last_level()
	var picks := 1
	for s: bool in entry.stars:
		picks += 1 if s else 0
	if entry.stars[1]:
		picks += FatRun.count("gold_star")
	await between.report(entry, picks if more else -1)
	if entry.cleared:
		run.report.append(entry)
		run.carry(buddy.body, target, entry)
		if more:
			await _picks(picks)
			run.level += 1
			get_tree().reload_current_scene()
			return
		await between.run_report(run, true)
	elif FatRun.count("second_helping") > 0:
		run.upgrades["second_helping"] -= 1
		if run.upgrades["second_helping"] <= 0:
			run.upgrades.erase("second_helping")
		hud.show_banner("SECOND HELPING!\nTRY AGAIN", Color(0.4, 0.9, 0.6))
		Sfx.play("power", 1.0)
		await get_tree().create_timer(1.6, false).timeout
		get_tree().reload_current_scene()
		return
	else:
		run.report.append(entry)
		await between.run_report(run, false)
	restart()


## `n` upgrade picks, taken in turns round the human players.
func _picks(n: int) -> void:
	var pickers := _human_blobs()
	var swaps := FatRun.count("ask_the_chef") # Ask the chef: new hands, once per level each
	var i := 0
	var left := n
	while left > 0 and not pickers.is_empty():
		var b: Blob = pickers[run.turn % pickers.size()]
		var who := b.tag # "" with one player
		var hand := run.hand(_rng)
		var id := ""
		while id == "":
			id = await between.pick(hand, who, b.color, b.controller as PlayerInput, i + 1, i + left, run, swaps)
			if id == "": # asked the chef
				swaps -= 1
				hand = run.hand(_rng)
		run.turn += 1
		run.take(id)
		left -= 1
		i += 1


## The human players' blobs, in seat order.
func _human_blobs() -> Array[Blob]:
	var out: Array[Blob] = []
	for b in living_blobs():
		if b.controller is PlayerInput and _slot_of.has(b):
			out.append(b)
	out.sort_custom(func(a: Blob, c: Blob) -> bool: return _slot_of[a] < _slot_of[c])
	return out


func _human_inputs() -> Array[PlayerInput]:
	var out: Array[PlayerInput] = []
	for b in _human_blobs():
		out.append(b.controller as PlayerInput)
	return out


## Restarting in a run starts a new run.
func restart() -> void:
	if run != null:
		FatRun.start()
	super.restart()


func leave() -> void:
	FatRun.stop()
	super.leave()


func _on_play_started() -> void:
	_hint_left = 7.0
	bounds.lethal = true


func _on_power_up(p: PowerUp, _b: Blob) -> void:
	if state == State.PLAYING:
		hud.show_banner(p.title() + "!", p.color(), 0.9)


## The camera, the zone's edges and the buddy ride with the belt. The camera
## shows `view_height` of the track (and all of its width, with the side zones).
func _follow_belt() -> void:
	camera.global_position = Vector2(0.0, belt_y)
	camera.view_size = Vector2(track.track_width + track.side_zone * 2.0, settings.view_height)
	bounds.global_position.y = belt_y
	bounds.top = settings.view_height * 0.5 - settings.top_margin
	bounds.bottom = settings.zone_bottom
	buddy.global_position = Vector2(0.0, belt_y + settings.buddy_y)


func _process(delta: float) -> void:
	if _hint_left > 0.0:
		_hint_left -= delta
		if _hint_left <= 0.0 and state == State.PLAYING:
			hud.set_hint("")
	if gate != null:
		gate.high = buddy.top()
		if _cleared:
			gate.open = move_toward(gate.open, 1.0, delta * 2.5)
	var length := -gate.global_position.y if gate != null else 10000.0
	var where := "     %d m / %d m" % [int(minf(distance, length) / 10.0), int(length / 10.0)]
	var run_part := "     RUN ★ %d" % run.stars() if run != null else ""
	hud.set_status(level_name() + where + run_part)
	fat_hud.low = low
	fat_hud.high = buddy.top()
	fat_hud.high_base = high
	fat_hud.in_zone = in_the_zone()
	fat_hud.plate_on = rules.plate
	fat_hud.target = target
	fat_hud.treat_slots = treat_slots
	fat_hud.progress = clampf(distance / maxf(length, 1.0), 0.0, 1.0)
	var pieces: Array = []
	for key: String in BOOSTS:
		if buddy.boosted(key):
			var kind: int = BOOSTS[key]
			pieces.append(["%s %d" % [PowerUp.NAMES[kind], ceili(buddy.boosts[key])], PowerUp.COLORS[kind]])
	fat_hud.boosts = pieces


## Online: the run and the level a joined computer plays (NetGame.match_info there).
func net_match_info() -> Dictionary:
	return {map = map.scene_file_path if map != null else "", run = run.to_net() if run != null else null}


## Online (NetGame): the FatHud's numbers and the screen between levels, for a joined computer.
func net_state() -> Array:
	return super.net_state() + [fat_hud.low, fat_hud.high, fat_hud.high_base, fat_hud.in_zone, fat_hud.plate_on,
		fat_hud.target, fat_hud.treat_slots, fat_hud.progress, fat_hud.boosts, between.net_view() if between.visible else {}]


func net_apply(s: Array) -> void:
	super.net_apply(s)
	fat_hud.low = s[1]
	fat_hud.high = s[2]
	fat_hud.high_base = s[3]
	fat_hud.in_zone = s[4]
	fat_hud.plate_on = s[5]
	fat_hud.target = s[6]
	fat_hud.treat_slots = s[7]
	fat_hud.progress = s[8]
	fat_hud.boosts = s[9]
	between.net_show(s[10])
