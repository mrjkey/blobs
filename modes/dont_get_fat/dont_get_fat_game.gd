extends GameMode
## Don't Get Fat!: co-op for 1 to 4 players, no computers. The blobs are the
## helpers of the buddy, who walks along at the bottom of the screen. The belt
## scrolls up a hand-made level (a Map, picked with the lobby's LEVEL option)
## and its HealthItems come down at the blobs: catch the good stuff, dodge the
## junk. Whatever they catch flies to the buddy and changes its weight;
## PowerUps work the moment they're caught. At the end the buddy reaches the
## level's Gate: under the limit it walks through and the level is cleared,
## over it, it doesn't fit and the level is failed. Blobs only move (no push,
## dash or attacks: `move_rules`) and stay in the helpers' zone (BeltBounds).
## The numbers are in FatSettings and each map's FatRules.
##
## Classic theme only for now (ModeInfo.theme): the items, the buddy and the
## gate are drawn for the classic look, and nothing here is tuned for neon.

## Team power-ups the buddy holds, as shown in the score bar.
const BOOSTS := {"golden": PowerUp.Kind.GOLDEN, "sneakers": PowerUp.Kind.SNEAKERS, "sugar_crash": PowerUp.Kind.SUGAR_CRASH}

@export var settings: FatSettings = preload("res://modes/dont_get_fat/fat_settings.tres")
@export var track: TrackSettings = preload("res://level/arenas/track/track_settings.tres")
@export var camera: GameCamera
@export var bounds: BeltBounds
@export var buddy: Buddy
@export var move_rules: MoveRules = preload("res://modes/dont_get_fat/move_only.tres")
@export_file("*.tscn") var map_path := "" # a level to play instead of the lobby's LEVEL pick

var map: Map
var gate: Gate
var rules: FatRules
var belt_y := 0.0 # world y of the screen's centre
var distance := 0.0
var _play_time := 0.0
var _walk_left := 0.0 # px the belt still goes once the buddy fits through the gate
var _hint_left := 0.0 # seconds until the controls hint goes (it sits over the buddy)


func _ready() -> void:
	process_physics_priority = -8 # scroll before BlobPhysics and the pickups look at the view
	_load_map()
	buddy.weight = rules.start_weight
	buddy.shown = rules.start_weight
	buddy.limit = rules.max_weight
	_follow_belt()
	super._ready()


func _load_map() -> void:
	rules = FatRules.new()
	var path := map_path if map_path != "" else GameSettings.fat_level()
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


func _spawn_blobs() -> void:
	var points: Array[SpawnPoint] = map.spawn_points() if map != null else []
	var total := slots.size()
	for i in total:
		var at := Vector2(lerpf(-track.track_width * 0.3, track.track_width * 0.3, (i + 0.5) / total), belt_y + 150.0)
		if i < points.size():
			at = points[i].global_position
		var b := spawn_slot(i, at)
		b.rules = move_rules
		b.body.look = Vector2.UP
	hud.set_hint("Catch the good stuff, dodge the junk: get your buddy through the gate under %d kg  ·  R restart  ·  Esc back"
		% roundi(rules.max_weight))


## Nobody gets knocked out: the gate decides.
func _check_round_over() -> void:
	pass


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	var moving := state == State.PLAYING or _walk_left > 0.0
	if moving:
		_play_time += delta
		var length := -gate.global_position.y if gate != null else 10000.0
		var speed := lerpf(rules.scroll_start, rules.scroll_end, clampf(distance / maxf(length, 1.0), 0.0, 1.0)) \
			* clampf(_play_time / maxf(settings.start_ramp, 0.01), 0.0, 1.0)
		var step := speed * delta
		if state == State.PLAYING and gate != null:
			step = minf(step, maxf(_gap_to_gate(), 0.0))
		elif _walk_left > 0.0:
			step = minf(step, _walk_left)
			_walk_left -= step
		belt_y -= step
		distance += step
		if state == State.PLAYING:
			buddy.weight = clampf(buddy.weight + rules.drift * delta, settings.min_weight, settings.max_weight)
			if gate != null and _gap_to_gate() <= 0.5:
				_reach_gate()
	buddy.walking = moving
	for b in living_blobs():
		b.speed_scale = settings.blob_speed * buddy.speed_factor()
	_follow_belt()


## How far the gate's hedges still are from the top of the buddy's head.
func _gap_to_gate() -> float:
	return belt_y + settings.buddy_y - buddy.radius - (gate.global_position.y + 20.0)


## The buddy fits through, or it doesn't.
func _reach_gate() -> void:
	state = State.OVER
	_on_round_over()
	var fits := buddy.weight <= rules.max_weight
	if fits:
		_walk_left = settings.finish_walk
		gate.cheer = 1.0
		Juice.burst(gate.global_position, Gate.GOOD_COLOR, 40, 520.0)
		Juice.burst(gate.global_position, Color(1.0, 0.85, 0.3), 30, 380.0)
		Sfx.play("power", 1.3)
		hud.show_banner("LEVEL CLEAR!", Gate.GOOD_COLOR)
	else:
		buddy.stick()
		Juice.shake(Juice.settings.shake_elimination)
		Juice.burst(buddy.global_position + Vector2(0.0, -buddy.radius), Gate.BAD_COLOR, 24, 380.0)
		Sfx.play("out", 0.7)
		hud.show_banner("TOO BIG!\nLEVEL FAILED", Gate.BAD_COLOR)
	hud.set_hint("%d kg, limit %d kg   ·   R or Start: play again   ·   Esc or Back: menu"
		% [roundi(buddy.weight), roundi(rules.max_weight)])


func _on_play_started() -> void:
	_hint_left = 5.0


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
	var of := " / %d m" % int(-gate.global_position.y / 10.0) if gate != null else ""
	hud.set_status("%s     %d m%s" % [GameSettings.choice_label("fat_level"), int(distance / 10.0), of])
	var over := buddy.weight > rules.max_weight
	var near := buddy.weight > rules.max_weight - 3.0
	var pieces: Array = [["%d kg" % roundi(buddy.weight), Gate.BAD_COLOR if over else (Color(1.0, 0.8, 0.2) if near else Gate.GOOD_COLOR)],
		["MAX %d kg" % roundi(rules.max_weight), Color(0.75, 0.75, 0.8)]]
	for key: String in BOOSTS:
		if buddy.boosted(key):
			var kind: int = BOOSTS[key]
			pieces.append(["%s %d" % [PowerUp.NAMES[kind], ceili(buddy.boosts[key])], PowerUp.COLORS[kind]])
	hud.set_score(pieces)
