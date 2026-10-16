extends "res://scripts/game.gd"
## Treadmill mode. The world stands still and the camera scrolls up through it,
## so blob physics stays simple and the floor appears to slide down the screen.
## Fall behind the bottom laser (or fly past the top one) and you're out.
## The track is generated in chunks ahead of the camera: solid walls, pink
## kicker walls, pinball bumpers and food. Laser ships cruise beside the side
## walls and fire across the track on the beat. The mode (1P vs computer,
## 2P versus, 2P + computer, watch) is picked in ui/menus/treadmill_menu.tscn and
## read from Session.treadmill_mode.
##
## Reuses from game.gd: blob-vs-blob collisions, pushes, bump effects, hitstop,
## shake, countdown and the HUD labels. Reuses the neon look from scripts/neon/.

const TT = preload("res://scripts/treadmill/treadmill_tuning.gd")
const NT = preload("res://scripts/neon/neon_tuning.gd")
const NeonLook = preload("res://scripts/neon/neon_look.gd")
const NeonBlob = preload("res://scripts/neon/neon_blob.gd")
const NeonFx = preload("res://scripts/neon/neon_fx.gd")
const NeonGrid = preload("res://scripts/neon/neon_grid.gd")
const Techno = preload("res://scripts/neon/techno.gd")
const TreadmillBrain = preload("res://scripts/treadmill/treadmill_brain.gd")
const PadInput = preload("res://scripts/treadmill/pad_input.gd")

enum Mode { VS_CPU, VERSUS, VERSUS_PLUS_CPU, WATCH }  # same numbers as the menu's buttons

const TREADMILL_MENU := "res://ui/menus/treadmill_menu.tscn"

var mode: int = Mode.VS_CPU
var cam_y := 0.0                    # world y at the centre of the screen
var view_zoom := 1.0
var scroll_speed := 0.0
var distance := 0.0
var walls: Array = []               # {rect: Rect2, kicker: bool, flash: float}
var bumpers: Array = []             # {pos: Vector2, radius: float, flash: float}
var ships: Array = []               # laser ships, see _make_ships()
var players: Array = []             # {blob: OldBlob, input: PadInput}
var trails := {}                    # blob instance id -> recent positions
var grid: NeonGrid
var music: Techno

var _overlay: Node2D                # kill lasers, ships and beams, drawn above the blobs
var _next_chunk_y := 0.0
var _prev_rects: Array[Rect2] = []
var _play_time := 0.0
var _last_bar := -1


func _ready() -> void:
	bot_looks = [
		{"name": "Bonk", "color": Color(1.0, 0.2, 0.25)},
		{"name": "Wobbles", "color": Color(0.2, 1.0, 0.5)},
		{"name": "Gummy", "color": Color(0.65, 0.3, 1.0)},
		{"name": "Blorb", "color": Color(1.0, 0.35, 0.85)},
	]
	add_child(NeonLook.make_world_env(get_viewport()))
	grid = NeonGrid.new()
	grid.z_index = -10
	add_child(grid)
	music = Techno.new()
	add_child(music)
	_overlay = Node2D.new()
	_overlay.z_index = 5
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	super._ready()  # camera, fx, sfx, HUD (blobs spawn in _start())

	sfx.add_tone("zap", 0.4, 1600.0, 90.0, 0.0, 0.3, 3.5)
	sfx.add_tone("charge", 0.9, 180.0, 700.0, 0.05, 0.0, 0.8)
	sfx.add_tone("bumper", 0.22, 700.0, 1400.0, 0.0, 0.0, 5.0)
	for l: Label in [_status, _hint, _banner]:
		l.label_settings.font_color = Color(0.8, 0.95, 1.0)
		l.label_settings.outline_color = Color(0.3, 0.0, 0.4, 0.9)
	_next_chunk_y = -TT.START_CLEAR
	_update_view()
	_generate_ahead()
	_make_ships()
	# Launch option to pick the mode, e.g. "godot treadmill.tscn -- --mode=3".
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode=") and Session.treadmill_mode < 0:
			Session.treadmill_mode = clampi(int(arg.get_slice("=", 1)), 0, Mode.size() - 1)
	# Run on its own (F6) with no mode chosen: default to 1P vs computer.
	_start(Session.treadmill_mode if Session.treadmill_mode >= 0 else Mode.VS_CPU)


func _spawn_blobs() -> void:
	pass  # blobs spawn in _start(), once the mode is known


func _make_blob() -> OldBlob:
	return NeonBlob.new()


func _make_fx() -> Fx:
	return NeonFx.new()


func in_mud(_pos: Vector2) -> bool:
	return false  # no mud on the treadmill


func _on_impact(pos: Vector2, strength: float) -> void:
	if strength >= 120.0:
		grid.impulse(pos, strength * NT.GRID_IMPACT_SCALE, 60.0 + strength * 0.08)


# --- View ---------------------------------------------------------------------

func _update_view() -> void:
	var vp := get_viewport_rect().size
	view_zoom = minf(vp.y / TT.VIEW_HEIGHT, vp.x / (TT.TRACK_WIDTH + 2.0 * TT.SIDE_ZONE))
	camera.position = Vector2(0.0, cam_y)
	grid.follow_y(cam_y)


## The part of the world currently on screen (ignoring shake and beat pulse).
func view_rect() -> Rect2:
	var size := get_viewport_rect().size / view_zoom
	return Rect2(Vector2(-size.x * 0.5, cam_y - size.y * 0.5), size)


func kill_top() -> float:
	return view_rect().position.y + TT.EDGE_INSET


func kill_bottom() -> float:
	return view_rect().end.y - TT.EDGE_INSET


# --- Input ---------------------------------------------------------------------

## R / Start: same mode again (it lives in Session). Esc / Back: treadmill menu.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.physical_keycode == KEY_R:
			get_tree().reload_current_scene()
		elif key.physical_keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file(TREADMILL_MENU)
	var button := event as InputEventJoypadButton
	if button and button.pressed:
		if button.button_index == JOY_BUTTON_START:
			get_tree().reload_current_scene()
		elif button.button_index == JOY_BUTTON_BACK:
			get_tree().change_scene_to_file(TREADMILL_MENU)


# --- Round setup --------------------------------------------------------------

func _start(m: int) -> void:
	mode = m
	var pads := Input.get_connected_joypads()
	var inputs: Array = []
	if m == Mode.WATCH:
		pass  # no humans
	elif m == Mode.VS_CPU:
		var keys := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP],
			"down": [KEY_S, KEY_DOWN], "push": [KEY_SPACE, KEY_J, KEY_ENTER, KEY_KP_ENTER]}
		inputs.append(PadInput.new(keys, pads[0] if pads.size() > 0 else -1))
	else:
		var p1_keys := {"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
			"push": [KEY_SPACE, KEY_J]}
		var p2_keys := {"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
			"push": [KEY_ENTER, KEY_KP_ENTER, KEY_KP_0, KEY_SLASH]}
		# Two pads: one each. One pad: P2 gets it, P1 keeps the keyboard.
		var p1_pad: int = pads[0] if pads.size() >= 2 else -1
		var p2_pad: int = pads[pads.size() - 1] if pads.size() >= 1 else -1
		inputs.append(PadInput.new(p1_keys, p1_pad))
		inputs.append(PadInput.new(p2_keys, p2_pad))

	var bot_count := 0
	if m == Mode.VS_CPU:
		bot_count = TT.BOTS_VS_CPU
	elif m == Mode.VERSUS_PLUS_CPU:
		bot_count = TT.BOTS_WITH_TWO_PLAYERS
	elif m == Mode.WATCH:
		bot_count = bot_looks.size()
	var total := inputs.size() + bot_count
	for i in total:
		var b: OldBlob = _make_blob()
		b.game = self
		var x := lerpf(-TT.TRACK_WIDTH * 0.35, TT.TRACK_WIDTH * 0.35, (i + 0.5) / total)
		b.position = Vector2(x, cam_y + 150.0)
		b.look = Vector2.UP
		if i < inputs.size():
			b.is_player = true
			b.color = TT.P1_COLOR if i == 0 else TT.P2_COLOR
			b.display_name = "Player %d" % (i + 1)
			if inputs.size() > 1:
				b.player_tag = "P%d" % (i + 1)
			players.append({"blob": b, "input": inputs[i]})
		else:
			var looks: Dictionary = bot_looks[(i - inputs.size()) % bot_looks.size()]
			b.display_name = looks["name"]
			b.color = looks["color"]
			b.brain = TreadmillBrain.new(b, self)
		b.set_mass(1.0)
		b.draw_radius = b.radius
		add_child(b)
		blobs.append(b)

	state = "countdown"
	countdown = T.COUNTDOWN
	if inputs.is_empty():
		_hint.text = "Watching the bots  ·  R restart  ·  Esc menu"
	elif inputs.size() == 1:
		_hint.text = "WASD move  ·  SPACE push  ·  stay ahead of the laser  ·  R restart  ·  Esc menu"
	else:
		_hint.text = "P1: WASD + Space    P2: Arrows + Enter    ·    R restart  ·  Esc menu"


# --- Main loop ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	clock += delta
	_read_inputs()
	if hitstop > 0.0:
		hitstop -= delta
		return

	if state == "countdown":
		_tick_countdown(delta)
	else:
		for b in blobs:
			if b.brain:
				b.brain.think(delta)

	if state == "playing":
		_play_time += delta
		scroll_speed = lerpf(TT.SCROLL_START, TT.SCROLL_MAX, clampf(_play_time / TT.SCROLL_RAMP_TIME, 0.0, 1.0))
		cam_y -= scroll_speed * delta
		distance += scroll_speed * delta
	_update_view()
	_generate_ahead()
	_update_ships(delta)

	var h := delta / T.SUBSTEPS
	for _i in T.SUBSTEPS:
		for b in blobs:
			b.step_motion(h)
		_collide_blobs()
		_collide_walls()
	for b in blobs.duplicate():
		b.step_ability(delta)
	_check_edges()
	_update_food(delta)
	for b in blobs:
		b.step_visuals(delta)
	for w in walls:
		w["flash"] = maxf(w["flash"] - delta * 4.0, 0.0)
	for bp in bumpers:
		bp["flash"] = maxf(bp["flash"] - delta * 4.0, 0.0)
	_check_round_over()
	_cull_behind()


func _read_inputs() -> void:
	for p in players:
		var obj = p["blob"]
		if not is_instance_valid(obj) or not obj.alive:
			continue
		var b: OldBlob = obj
		var input = p["input"]
		var pushed: bool = input.push_pressed()
		if state == "countdown":
			b.move_dir = Vector2.ZERO
			continue
		b.move_dir = input.move()
		if pushed:
			b.push_buffer = T.PUSH_BUFFER


func _process(delta: float) -> void:
	var k := music.kick_env()
	camera.position = Vector2(0.0, cam_y)
	camera.zoom = Vector2.ONE * view_zoom * (1.0 + NT.BEAT_PULSE * k)
	shake = minf(shake, T.SHAKE_MAX)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	shake *= exp(-T.SHAKE_DECAY * delta)
	grid.pulse = k
	_record_trails()

	_status.text = "Distance: %d m     Blobs left: %d" % [int(distance / 10.0), blobs.size()]
	if _banner_life > 0.0:
		_banner_life -= delta
		_banner.modulate.a = clampf(_banner_life / 0.4, 0.0, 1.0)
		if _banner_life <= 0.0:
			_banner.text = ""
	queue_redraw()
	_overlay.queue_redraw()


func _record_trails() -> void:
	var seen := {}
	for other in blobs:
		var b: OldBlob = other
		var id := b.get_instance_id()
		seen[id] = true
		if not trails.has(id):
			trails[id] = []
		var pts: Array = trails[id]
		pts.append(b.position)
		while pts.size() > NT.TRAIL_FRAMES:
			pts.pop_front()
	for id in trails.keys():
		if not seen.has(id):
			trails.erase(id)


# --- Collisions ---------------------------------------------------------------

func _collide_walls() -> void:
	var half := TT.TRACK_WIDTH * 0.5
	for other in blobs:
		var b: OldBlob = other
		# Side walls.
		if b.position.x < -half + b.radius:
			_hit_flat_wall(b, Vector2.RIGHT, -half + b.radius - b.position.x)
		elif b.position.x > half - b.radius:
			_hit_flat_wall(b, Vector2.LEFT, b.position.x - (half - b.radius))

		# Rectangular walls and kickers.
		for w in walls:
			var rect: Rect2 = w["rect"]
			var closest := b.position.clamp(rect.position, rect.end)
			var d := b.position - closest
			var dist2 := d.length_squared()
			if dist2 > b.radius * b.radius:
				continue
			var n: Vector2
			var depth: float
			if dist2 > 0.0001:
				var dist := sqrt(dist2)
				n = d / dist
				depth = b.radius - dist
			else:
				# Centre ended up inside the box: leave by the nearest face.
				var to_left := b.position.x - rect.position.x
				var to_right := rect.end.x - b.position.x
				var to_top := b.position.y - rect.position.y
				var to_bottom := rect.end.y - b.position.y
				var nearest := minf(minf(to_left, to_right), minf(to_top, to_bottom))
				if nearest == to_left:
					n = Vector2.LEFT
				elif nearest == to_right:
					n = Vector2.RIGHT
				elif nearest == to_top:
					n = Vector2.UP
				else:
					n = Vector2.DOWN
				depth = nearest + b.radius
			if w["kicker"]:
				_kick(b, n, depth, TT.KICKER_SPEED)
				w["flash"] = 1.0
			else:
				_hit_flat_wall(b, n, depth)

		# Pinball bumpers.
		for bp in bumpers:
			var bpos: Vector2 = bp["pos"]
			var br: float = bp["radius"]
			var d := b.position - bpos
			var dist := d.length()
			if dist >= b.radius + br:
				continue
			var n := d / dist if dist > 0.001 else Vector2.UP
			_kick(b, n, b.radius + br - dist, TT.BUMPER_KICK)
			bp["flash"] = 1.0


## Solid, slightly bouncy surface. n points from the wall toward the blob.
func _hit_flat_wall(b: OldBlob, n: Vector2, depth: float) -> void:
	b.position += n * depth
	var vn := b.vel.dot(n)
	if vn >= 0.0:
		return
	b.vel -= n * vn * (1.0 + T.WALL_RESTITUTION)
	b.bump(n, -vn)
	if -vn > 120.0:
		_on_impact(b.position - n * b.radius, -vn)
		fx.burst(b.position - n * b.radius, TT.WALL_COLOR.lightened(0.4), int(clampf(-vn / 80.0, 3.0, 10.0)), -vn * 0.4)
		sfx.play("wall", randf_range(0.9, 1.1), linear_to_db(clampf(-vn / 500.0, 0.2, 1.0)))
	if -vn > T.SHAKE_MIN_IMPACT:
		add_shake(-vn * T.SHAKE_PER_IMPACT * 0.7)


## Pinball-style: always fling the blob away at `speed`, however softly it touched.
func _kick(b: OldBlob, n: Vector2, depth: float, speed: float) -> void:
	b.position += n * depth
	var vn := b.vel.dot(n)
	if vn < 0.0:
		b.vel -= n * vn
	b.vel += n * speed / sqrt(b.mass)
	b.stun = maxf(b.stun, TT.BUMPER_STUN)
	b.flash = 0.8
	b.bump(n, speed)
	var contact := b.position - n * b.radius
	fx.burst(contact, TT.BUMPER_COLOR, 12, 420.0)
	_on_impact(contact, speed)
	sfx.play("bumper", randf_range(0.95, 1.1), -2.0)
	add_shake(4.0)


# --- Rules --------------------------------------------------------------------

func _check_edges() -> void:
	if state == "countdown":
		return
	var top := kill_top()
	var bottom := kill_bottom()
	for other in blobs.duplicate():
		var b: OldBlob = other
		if b.position.y <= bottom and b.position.y >= top:
			continue
		if state == "playing":
			var edge_y := bottom if b.position.y > bottom else top
			fx.burst(Vector2(b.position.x, edge_y), TT.EDGE_LASER_COLOR, 24, 500.0)
			sfx.play("zap", randf_range(0.9, 1.1), 0.0, 0.0)
			_eliminate(b)
		else:
			b.position.y = clampf(b.position.y, top, bottom)  # round's over: keep the winner on screen


func _eliminate(b: OldBlob) -> void:
	blobs.erase(b)
	b.die()
	_on_impact(b.position, 1500.0)
	fx.burst(b.position, b.color, 28, 380.0)
	fx.shockwave(b.position, b.radius, b.radius * 4.0, b.color, 0.45)
	sfx.play("out", randf_range(0.9, 1.1))
	add_shake(10.0)
	hitstop = maxf(hitstop, 0.08)
	if b.is_player:
		var who := "BUMPED OUT!" if b.player_tag == "" else "%s IS OUT!" % b.player_tag
		_show_banner(who, b.color, 1.6)


func _check_round_over() -> void:
	if state != "playing":
		return
	var humans_alive := 0
	for p in players:
		if is_instance_valid(p["blob"]) and p["blob"].alive:
			humans_alive += 1
	if blobs.size() > 1 and (humans_alive > 0 or players.is_empty()):
		return
	state = "over"
	if players.size() == 1 and humans_alive == 0:
		_show_banner("GAME OVER", Color(1.0, 0.4, 0.4))
	elif blobs.size() == 1 and blobs[0].is_player:
		var winner: OldBlob = blobs[0]
		_show_banner("YOU WIN!" if players.size() == 1 else "%s WINS!" % winner.player_tag, winner.color)
	elif blobs.size() == 1:
		_show_banner("%s WINS" % blobs[0].display_name.to_upper(), blobs[0].color)
	elif humans_alive == 0 and not players.is_empty():
		_show_banner("THE BOTS WIN", Color(1.0, 0.4, 0.4))
	else:
		_show_banner("DRAW!", Color.WHITE)
	_hint.text = "%d m   ·   R or Start: rematch   ·   Esc or Back: menu" % int(distance / 10.0)


func _update_food(delta: float) -> void:
	for f in foods:
		f["age"] += delta
	for f in foods.duplicate():
		var fpos: Vector2 = f["pos"]
		for other in blobs:
			var b: OldBlob = other
			if b.position.distance_to(fpos) < b.radius + T.FOOD_RADIUS:
				foods.erase(f)
				b.eat()
				fx.burst(fpos, NT.FOOD_COLOR, 10, 160.0)
				sfx.play("pop", randf_range(0.95, 1.1), -2.0)
				break


# --- Track generation ---------------------------------------------------------

func _generate_ahead() -> void:
	var want_top := view_rect().position.y - TT.CHUNK_HEIGHT
	while _next_chunk_y > want_top:
		_gen_chunk(_next_chunk_y - TT.CHUNK_HEIGHT, _next_chunk_y)
		_next_chunk_y -= TT.CHUNK_HEIGHT


func _gen_chunk(y0: float, y1: float) -> void:
	var half := TT.TRACK_WIDTH * 0.5
	var difficulty := clampf(-y1 / TT.DIFFICULTY_DISTANCE, 0.0, 1.0)
	var placed: Array[Rect2] = []

	for _i in randi_range(1, 2 + int(difficulty * 1.5)):
		for _try in 15:
			var rect := _random_wall_rect(y0, y1, half)
			if rect.size.x <= 0.0 or _blocked(rect, placed):
				continue
			placed.append(rect)
			walls.append({"rect": rect, "kicker": randf() < 0.15 + 0.25 * difficulty, "flash": 0.0})
			break

	for _i in randi_range(0, 2 + int(difficulty * 2.0)):
		for _try in 15:
			var br := randf_range(22.0, 32.0)
			var p := Vector2(randf_range(-half + 70.0, half - 70.0), randf_range(y0 + 40.0, y1 - 40.0))
			var rect := Rect2(p - Vector2(br, br), Vector2(br, br) * 2.0)
			if _blocked(rect, placed):
				continue
			placed.append(rect)
			bumpers.append({"pos": p, "radius": br, "flash": 0.0})
			break

	for _i in randi_range(0, TT.FOOD_PER_CHUNK_MAX):
		for _try in 10:
			var p := Vector2(randf_range(-half + 40.0, half - 40.0), randf_range(y0 + 20.0, y1 - 20.0))
			var clear := true
			for r: Rect2 in placed:
				if r.grow(30.0).has_point(p):
					clear = false
					break
			if clear:
				foods.append({"pos": p, "age": 0.0, "seed": randf() * TAU})
				break

	_prev_rects = placed


func _random_wall_rect(y0: float, y1: float, half: float) -> Rect2:
	var roll := randf()
	var w: float
	var h: float
	if roll < 0.55:      # horizontal bar
		w = randf_range(120.0, TT.TRACK_WIDTH * 0.42)
		h = TT.WALL_THICKNESS
	elif roll < 0.75:    # vertical bar
		w = TT.WALL_THICKNESS
		h = randf_range(90.0, 170.0)
	else:                # block
		w = randf_range(50.0, 80.0)
		h = w
	var y := randf_range(y0 + 20.0, y1 - 20.0 - h)
	var x: float
	if roll < 0.55 and randf() < 0.5:
		x = -half if randf() < 0.5 else half - w  # bar sticking out of a side wall
	else:
		var lo := -half + TT.OBSTACLE_GAP
		var hi := half - TT.OBSTACLE_GAP - w
		if hi < lo:
			return Rect2()
		x = randf_range(lo, hi)
	return Rect2(x, y, w, h)


## Too close to something already placed (in this chunk or the one below)?
func _blocked(rect: Rect2, placed: Array[Rect2]) -> bool:
	for other: Rect2 in placed + _prev_rects:
		if other.grow(TT.OBSTACLE_GAP).intersects(rect):
			return true
	return false


func _cull_behind() -> void:
	var limit := view_rect().end.y + 300.0
	walls = walls.filter(func(w): return w["rect"].position.y < limit)
	bumpers = bumpers.filter(func(bp): return bp["pos"].y < limit)
	foods = foods.filter(func(f): return f["pos"].y < limit)


# --- Laser ships --------------------------------------------------------------

func _make_ships() -> void:
	var cruise := view_rect().size.y * 0.36
	for side: float in [-1.0, 1.0]:
		for i in TT.SHIPS_PER_SIDE:
			var phase := randf() * TAU + i * PI
			var s := {"side": side, "phase": phase, "rel_y": sin(phase) * cruise, "pinned": false, "pin_y": 0.0,
				"aim": Vector2(-side, 0.0)}
			_reset_ship(s)
			ships.append(s)


func _reset_ship(s: Dictionary) -> void:
	s["fire_beat"] = -1.0
	s["fired"] = false
	s["locked"] = false
	s["charging"] = false
	s["pinned"] = false
	s["target"] = null
	s["dodgers"] = []
	s["length"] = 0.0


func _ship_pos(s: Dictionary) -> Vector2:
	var x: float = s["side"] * (TT.TRACK_WIDTH * 0.5 + TT.SIDE_ZONE * 0.45)
	var y: float = s["pin_y"] if s["pinned"] else cam_y + s["rel_y"]
	return Vector2(x, y)


## Distance from a ship to the far side wall along `aim`.
func _ship_beam_length(from: Vector2, aim: Vector2) -> float:
	if absf(aim.x) < 0.05:
		return 2400.0
	var far_x := -signf(from.x) * TT.TRACK_WIDTH * 0.5
	return clampf((far_x - from.x) / aim.x, 0.0, 2400.0)


func _update_ships(delta: float) -> void:
	var beat := music.beat()
	if state == "playing":
		_schedule_lasers(beat)
	var view := view_rect()
	for s in ships:
		if s["pinned"]:
			s["rel_y"] = s["pin_y"] - cam_y
		else:
			# Cruise up and down beside the track.
			var want: float = sin(clock * TT.SHIP_SPEED + s["phase"]) * view.size.y * 0.36
			s["rel_y"] = lerpf(s["rel_y"], want, 1.0 - exp(-2.0 * delta))
		_update_ship_laser(s, beat, delta)


func _schedule_lasers(beat: float) -> void:
	var bar := int(floorf(beat / 4.0))
	if bar == _last_bar:
		return
	_last_bar = bar
	if _play_time < TT.LASER_START_DELAY:
		return
	var count := 1 if randf() < 0.7 else 0
	if _play_time > 30.0 and randf() < 0.5:
		count += 1
	if _play_time > 60.0 and randf() < 0.5:
		count += 1
	var idle := ships.filter(func(s): return s["fire_beat"] < 0.0)
	idle.shuffle()
	for i in mini(count, idle.size()):
		var s: Dictionary = idle[i]
		s["fire_beat"] = float(bar + 1) * 4.0  # fires on the next downbeat


func _update_ship_laser(s: Dictionary, beat: float, delta: float) -> void:
	var pos := _ship_pos(s)
	var side: float = s["side"]
	var aim: Vector2 = s["aim"]
	var fire_beat: float = s["fire_beat"]
	var to_fire := fire_beat - beat

	if fire_beat < 0.0 or to_fire > TT.LASER_CHARGE_BEATS:
		s["aim"] = aim.slerp(Vector2(-side, 0.0), 1.0 - exp(-3.0 * delta)).normalized()
		return

	if to_fire > TT.LASER_LOCK_BEATS:
		# Charging: stop cruising and track a victim.
		if not s["charging"]:
			s["charging"] = true
			s["pinned"] = true
			s["pin_y"] = pos.y
			s["target"] = blobs.pick_random() if not blobs.is_empty() else null
			sfx.play("charge", randf_range(0.95, 1.05), -12.0, 0.0)
		var target = s["target"]
		if target != null and is_instance_valid(target) and target.alive:
			var want: Vector2 = (target.position + target.vel * 0.15 - pos).normalized()
			if want.x * -side < 0.3:
				want = Vector2(-side * 0.3, signf(want.y) * 0.95).normalized()  # never aim along the wall
			aim = aim.slerp(want, 1.0 - exp(-7.0 * delta)).normalized()
			s["aim"] = aim
		s["length"] = _ship_beam_length(pos, aim)
		return

	if to_fire > 0.0:
		# Locked: aim is frozen. Bots that noticed try to sidestep.
		if not s["locked"]:
			s["locked"] = true
			var dodgers := []
			for other in blobs:
				if other.brain and randf() < 0.35 + 0.5 * other.brain.skill:
					dodgers.append(other)
			s["dodgers"] = dodgers
		_dodge(s, pos)
		return

	if not s["fired"]:
		s["fired"] = true
		_fire(s, pos)
	if to_fire < -TT.LASER_FIRE_BEATS:
		_reset_ship(s)


func _dodge(s: Dictionary, pos: Vector2) -> void:
	var d: Vector2 = s["aim"]
	var length: float = s["length"]
	for other in s["dodgers"]:
		if not is_instance_valid(other) or not other.alive:
			continue
		var b: OldBlob = other
		var rel := b.position - pos
		var off := rel - d * clampf(rel.dot(d), 0.0, length)
		if off.length() > b.radius + TT.LASER_WIDTH + 40.0:
			continue
		var away := Vector2(-d.y, d.x)
		if away.dot(off) < 0.0:
			away = -away
		b.move_dir = away


func _fire(s: Dictionary, pos: Vector2) -> void:
	var d: Vector2 = s["aim"]
	var length := _ship_beam_length(pos, d)
	s["length"] = length
	sfx.play("zap", randf_range(0.95, 1.05), 0.0, 0.0)
	add_shake(5.0)
	var hit_any := false
	for other in blobs:
		var b: OldBlob = other
		var rel := b.position - pos
		var off := rel - d * clampf(rel.dot(d), 0.0, length)
		if off.length() > b.radius + TT.LASER_WIDTH * 0.5:
			continue
		var dv := TT.LASER_IMPULSE / pow(b.mass, T.PUSH_RESIST_EXP)
		b.vel += d * dv
		b.stun = maxf(b.stun, T.PUSH_STUN)
		b.flash = 1.0
		b.bump(d, dv)
		fx.burst(b.position, TT.BEAM_COLOR, 18, 500.0)
		hit_any = true
	if hit_any:
		hitstop = maxf(hitstop, T.HITSTOP_PUSH)
		add_shake(6.0)
	for i in int(length / 70.0) + 1:
		grid.impulse(pos + d * (i * 70.0), 260.0, 90.0)
	fx.burst(pos + d * length, TT.BEAM_COLOR, 12, 350.0)


# --- Drawing ------------------------------------------------------------------

func _draw() -> void:
	var view := view_rect()
	var k := music.kick_env()
	var half := TT.TRACK_WIDTH * 0.5
	var y0 := view.position.y - 60.0
	var y1 := view.end.y + 60.0

	# Off-track zones where the ships fly.
	var shade := Color(0.03, 0.0, 0.06, 0.75)
	draw_rect(Rect2(-half - 800.0, y0, 800.0, y1 - y0), shade)
	draw_rect(Rect2(half, y0, 800.0, y1 - y0), shade)

	# Belt chevrons are fixed in the world, so they slide down the screen.
	var step := 120.0
	var yy := floorf(y0 / step) * step
	while yy < y1:
		for cx: float in [-half * 0.55, 0.0, half * 0.55]:
			var p := Vector2(cx, yy)
			draw_polyline(PackedVector2Array([p + Vector2(-26, -10), p + Vector2(0, 8), p + Vector2(26, -10)]),
				NeonLook.hdr(TT.BELT_COLOR, 0.8, 0.2), 3.0, true)
		yy += step

	# Side walls.
	for sx: float in [-half, half]:
		draw_line(Vector2(sx, y0), Vector2(sx, y1), NeonLook.hdr(TT.SIDE_WALL_COLOR, 1.6 + 0.4 * k), 5.0, true)
		var inner := sx - signf(sx) * 10.0
		draw_line(Vector2(inner, y0), Vector2(inner, y1), NeonLook.hdr(TT.SIDE_WALL_COLOR, 0.7, 0.4), 1.5, true)

	# Motion trails.
	for other in blobs:
		var b: OldBlob = other
		var id := b.get_instance_id()
		if not trails.has(id):
			continue
		var pts: Array = trails[id]
		for i in range(1, pts.size()):
			var f := float(i) / pts.size()
			draw_line(pts[i - 1], pts[i], NeonLook.hdr(b.color, 1.5, 0.35 * f), maxf(b.radius * 1.3 * f, 1.0), true)

	# Walls: dark glass with a neon edge. Kickers are pink and flash when they fire.
	for w in walls:
		var rect: Rect2 = w["rect"]
		if rect.end.y < y0 or rect.position.y > y1:
			continue
		var col: Color = TT.KICKER_COLOR if w["kicker"] else TT.WALL_COLOR
		var fl: float = w["flash"]
		draw_rect(rect, Color(col.r * 0.1, col.g * 0.1, col.b * 0.15, 0.9))
		draw_rect(rect, NeonLook.hdr(col, 1.6 + 2.5 * fl), false, 3.0, true)
		if w["kicker"] and rect.size.x > 14.0 and rect.size.y > 14.0:
			draw_rect(rect.grow(-6.0), NeonLook.hdr(col, 0.9 + fl, 0.6), false, 1.5, true)

	# Pinball bumpers: pop bigger when hit.
	for bp in bumpers:
		var p: Vector2 = bp["pos"]
		if p.y < y0 - 60.0 or p.y > y1 + 60.0:
			continue
		var fl: float = bp["flash"]
		var rr: float = bp["radius"] * (1.0 + 0.25 * fl)
		draw_circle(p, rr, Color(0.08, 0.06, 0.0, 0.9))
		draw_arc(p, rr, 0.0, TAU, 40, NeonLook.hdr(TT.BUMPER_COLOR, 1.8 + 3.0 * fl + 0.4 * k), 4.0, true)
		draw_arc(p, rr * 0.6, 0.0, TAU, 32, NeonLook.hdr(TT.BUMPER_COLOR, 1.2 + 2.0 * fl, 0.7), 2.0, true)
		draw_circle(p, rr * 0.22, NeonLook.hdr(TT.BUMPER_COLOR, 1.5 + 3.0 * fl))

	# Food: spinning neon diamonds.
	for f in foods:
		var fpos: Vector2 = f["pos"]
		if fpos.y < y0 or fpos.y > y1:
			continue
		var age: float = f["age"]
		var fseed: float = f["seed"]
		var pop := minf(age / 0.25, 1.0)
		var r := T.FOOD_RADIUS * (1.0 + 0.4 * sin(pop * PI)) * pop * (1.3 + 0.2 * k)
		var pts := PackedVector2Array()
		for j in 4:
			pts.append(fpos + Vector2.from_angle(clock * 2.0 + fseed + j * PI / 2.0) * r)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_colored_polygon(pts, NeonLook.hdr(NT.FOOD_COLOR, 0.5, 0.5))
		draw_polyline(outline, NeonLook.hdr(NT.FOOD_COLOR, 2.5), 2.0, true)


func _draw_overlay() -> void:
	var beat := music.beat()
	var k := music.kick_env()
	var half := TT.TRACK_WIDTH * 0.5

	# Kill lasers across the top and bottom of the screen.
	for y: float in [kill_top(), kill_bottom()]:
		var flicker := 0.85 + 0.15 * sin(clock * 40.0 + y * 0.1)
		var a := Vector2(-half, y)
		var b := Vector2(half, y)
		_overlay.draw_line(a, b, NeonLook.hdr(TT.EDGE_LASER_COLOR, 0.9, 0.25), 14.0, true)
		_overlay.draw_line(a, b, NeonLook.hdr(TT.EDGE_LASER_COLOR, (2.2 + 0.5 * k) * flicker), 3.0, true)
		for end: Vector2 in [a, b]:
			_overlay.draw_circle(end, 6.0, NeonLook.hdr(TT.EDGE_LASER_COLOR, 2.5))

	# Ships, their telegraphs and beams.
	for s in ships:
		var pos := _ship_pos(s)
		var aim: Vector2 = s["aim"]
		var fire_beat: float = s["fire_beat"]
		var length: float = s["length"]
		var to_fire := fire_beat - beat if fire_beat >= 0.0 else 99.0
		var charge := 0.0
		if to_fire > 0.0 and to_fire <= TT.LASER_CHARGE_BEATS:
			charge = 1.0 - to_fire / TT.LASER_CHARGE_BEATS

		if charge > 0.0:
			var alpha := 0.15 + 0.5 * charge
			var width := 1.5
			if to_fire <= TT.LASER_LOCK_BEATS:
				alpha = 0.9 if int(beat * 16.0) % 2 == 0 else 0.3
				width = 2.5
			_overlay.draw_line(pos, pos + aim * length, NeonLook.hdr(TT.BEAM_COLOR, 1.0 + 2.0 * charge, alpha), width, true)

		if fire_beat >= 0.0 and beat >= fire_beat and beat < fire_beat + TT.LASER_FIRE_BEATS:
			var q := (beat - fire_beat) / TT.LASER_FIRE_BEATS
			var end := pos + aim * length
			_overlay.draw_line(pos, end, NeonLook.hdr(TT.BEAM_COLOR, 3.0, 1.0 - q), TT.LASER_WIDTH * 1.4 * (1.0 - q) + 1.0, true)
			_overlay.draw_line(pos, end, NeonLook.hdr(Color.WHITE, 3.0, 1.0 - q), TT.LASER_WIDTH * 0.35 * (1.0 - q) + 1.0, true)

		# Ship body: a neon arrowhead with two little engine glows.
		var side_v := Vector2(-aim.y, aim.x)
		var tip := pos + aim * 18.0
		var body := PackedVector2Array([tip, pos - aim * 12.0 + side_v * 14.0, pos - aim * 5.0,
			pos - aim * 12.0 - side_v * 14.0, tip])
		_overlay.draw_polyline(body, NeonLook.hdr(TT.SHIP_COLOR, 1.5 + 1.0 * k + 3.0 * charge), 2.5, true)
		for e: float in [-1.0, 1.0]:
			_overlay.draw_circle(pos - aim * 13.0 + side_v * (8.0 * e), 2.5, NeonLook.hdr(TT.SHIP_COLOR, 2.0 + 1.5 * k))
		if charge > 0.0:
			_overlay.draw_circle(tip, 2.0 + 6.0 * charge, NeonLook.hdr(TT.BEAM_COLOR, 2.0 + 2.0 * charge, 0.9))
