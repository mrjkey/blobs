extends Node2D
## Bumper Blobs: the arena, the physics step, pushes, food and the round flow.
## Everything is built in code so main.tscn is just this one node.

const T = preload("res://scripts/tuning.gd")
const OldBlob = preload("res://scripts/blob.gd")
const Brain = preload("res://scripts/ai_brain.gd")
const Fx = preload("res://scripts/fx.gd")
const Sfx = preload("res://scripts/sfx.gd")

var bot_looks := [
	{"name": "Bonk", "color": Color(1.0, 0.36, 0.36)},
	{"name": "Wobbles", "color": Color(0.45, 0.9, 0.4)},
	{"name": "Mochi", "color": Color(1.0, 0.7, 0.25)},
	{"name": "Gummy", "color": Color(0.75, 0.45, 1.0)},
	{"name": "Blorb", "color": Color(1.0, 0.5, 0.8)},
	{"name": "Squish", "color": Color(0.95, 0.95, 0.4)},
]

var blobs: Array = []        # living blobs, in step order
var foods: Array = []        # {pos, age, seed}
var wall_hits: Array = []    # {angle, age, power}
var player: OldBlob
var fx: Fx
var sfx: Sfx
var camera: Camera2D
var shake := 0.0
var hitstop := 0.0
var food_timer := 1.0
var state := "countdown"     # countdown -> playing -> over
var countdown := T.COUNTDOWN
var clock := 0.0

var _status: Label
var _banner: Label
var _hint: Label
var _banner_life := -1.0
var view_margin := 60.0      # extra world space shown around the wall


func _ready() -> void:
	randomize()
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	fx = _make_fx()
	fx.z_index = 10
	add_child(fx)
	sfx = Sfx.new()
	add_child(sfx)
	_build_hud()
	_spawn_blobs()


# --- Setup -------------------------------------------------------------------

func _spawn_blobs() -> void:
	var count := T.BOT_COUNT + 1
	var start_angle := randf() * TAU
	for i in count:
		var b: OldBlob = _make_blob()
		b.game = self
		b.position = Vector2.from_angle(start_angle + TAU * i / count) * T.RING_RADIUS * 0.6
		b.look = -b.position.normalized()
		if i == 0:
			b.is_player = true
			b.display_name = "You"
			b.color = T.PLAYER_COLOR
			player = b
		else:
			var looks: Dictionary = bot_looks[(i - 1) % bot_looks.size()]
			b.display_name = looks["name"]
			b.color = looks["color"]
			b.brain = Brain.new(b, self)
		b.set_mass(1.0)
		b.draw_radius = b.radius
		add_child(b)
		blobs.append(b)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = _make_label(layer, 24, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	_status.offset_left = 18
	_status.offset_top = 12
	_hint = _make_label(layer, 20, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	_hint.offset_bottom = -12
	_hint.text = "WASD / arrows: move     SPACE: push     R: restart"
	_banner = _make_label(layer, 96, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)


func _make_label(parent: Node, font_px: int, h: HorizontalAlignment, v: VerticalAlignment) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = font_px
	ls.outline_size = maxi(int(font_px * 0.2), 4)
	ls.outline_color = Color(0, 0, 0, 0.85)
	l.label_settings = ls
	l.horizontal_alignment = h
	l.vertical_alignment = v
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return l


# --- Main loop ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("quit"):
		get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")
		return
	_read_player_input()
	clock += delta

	if hitstop > 0.0:
		hitstop -= delta
		return

	if state == "countdown":
		_tick_countdown(delta)
	else:
		for b in blobs:
			if b.brain:
				b.brain.think(delta)
		_before_simulate(delta)

	var h := delta / T.SUBSTEPS
	for _i in T.SUBSTEPS:
		for b in blobs:
			b.step_motion(h)
		_collide_blobs()
		_collide_walls()
	for b in blobs.duplicate():
		b.step_ability(delta)
	_check_ring(delta)
	_update_food(delta)
	for b in blobs:
		b.step_visuals(delta)
	_check_round_over()


func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	var fit := minf(vp.x, vp.y) / (T.WALL_RADIUS * 2.0 + view_margin)
	camera.zoom = Vector2(fit, fit)
	shake = minf(shake, T.SHAKE_MAX)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	shake *= exp(-T.SHAKE_DECAY * delta)

	for hit in wall_hits:
		hit["age"] += delta
	wall_hits = wall_hits.filter(func(hit): return hit["age"] < 0.35)

	var status := "Blobs left: %d" % blobs.size()
	if is_instance_valid(player) and player.alive:
		status += "     Your size: %.2fx" % player.mass
	_status.text = status

	if _banner_life > 0.0:
		_banner_life -= delta
		_banner.modulate.a = clampf(_banner_life / 0.4, 0.0, 1.0)
		if _banner_life <= 0.0:
			_banner.text = ""
	queue_redraw()


func _read_player_input() -> void:
	if not is_instance_valid(player) or not player.alive:
		return
	if state == "countdown":
		player.move_dir = Vector2.ZERO
		return
	player.move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("push"):
		player.push_buffer = T.PUSH_BUFFER


func _tick_countdown(delta: float) -> void:
	countdown -= delta
	if countdown <= 0.0:
		state = "playing"
		_show_banner("BUMP!", Color(1.0, 0.9, 0.4), 0.8)
		sfx.play("pop", 0.6)
	else:
		var n := ceili(countdown / (T.COUNTDOWN / 3.0))
		if _banner.text != str(n):
			sfx.play("pop", 0.8 + 0.1 * (3 - n))
		_show_banner(str(n), Color.WHITE)


func _show_banner(text: String, col: Color, life: float = -1.0) -> void:
	_banner.text = text
	_banner.modulate = col
	_banner_life = life


# --- Physics -----------------------------------------------------------------

func _collide_blobs() -> void:
	for i in blobs.size():
		var a: OldBlob = blobs[i]
		for j in range(i + 1, blobs.size()):
			var b: OldBlob = blobs[j]
			var d := b.position - a.position
			var rsum := a.radius + b.radius
			var dist2 := d.length_squared()
			if dist2 >= rsum * rsum:
				continue
			var dist := sqrt(dist2)
			var n := d / dist if dist > 0.001 else Vector2.from_angle(randf() * TAU)
			var ia := 1.0 / a.mass
			var ib := 1.0 / b.mass
			var isum := ia + ib
			# Push apart, lighter blob moves more.
			var overlap := rsum - dist
			a.position -= n * overlap * ia / isum
			b.position += n * overlap * ib / isum
			# Bounce.
			var vn := (b.vel - a.vel).dot(n)
			if vn < 0.0:
				var impact := -vn
				var jimp := (1.0 + T.BLOB_RESTITUTION) * impact / isum
				if impact > T.BUMP_POP_MIN_IMPACT:
					jimp += T.BUMP_POP / isum
				a.vel -= n * jimp * ia
				b.vel += n * jimp * ib
				_on_blob_contact(a, b, n, impact)


func _on_blob_contact(a: OldBlob, b: OldBlob, n: Vector2, impact: float) -> void:
	_on_impact(a.position + n * a.radius, impact)
	var share_a := (1.0 / a.mass) / (1.0 / a.mass + 1.0 / b.mass)
	a.bump(n, impact * share_a * 2.0)
	b.bump(n, impact * (1.0 - share_a) * 2.0)
	if impact > 90.0:
		var pitch := randf_range(0.9, 1.15) / sqrt((a.mass + b.mass) * 0.5)
		sfx.play("boing", pitch, linear_to_db(clampf(impact / 500.0, 0.2, 1.0)))
	if impact > T.SPARK_MIN_IMPACT:
		var contact := a.position + n * a.radius
		fx.burst(contact, a.color.lerp(b.color, 0.5).lightened(0.3), int(clampf(impact / 60.0, 3.0, 14.0)), impact * 0.5)
	if impact > T.SHAKE_MIN_IMPACT:
		add_shake(impact * T.SHAKE_PER_IMPACT)
	if impact > T.HITSTOP_MIN_IMPACT:
		hitstop = maxf(hitstop, T.HITSTOP_BUMP)


func _collide_walls() -> void:
	for other in blobs:
		var b: OldBlob = other
		var dist := b.position.length()
		var limit := T.WALL_RADIUS - b.radius
		if dist <= limit:
			continue
		var n := b.position / dist
		b.position = n * limit
		var vn := b.vel.dot(n)
		if vn > 0.0:
			b.vel -= n * vn * (1.0 + T.WALL_RESTITUTION)
			b.bump(n, vn)
			if vn > 120.0:
				_on_impact(b.position + n * b.radius, vn)
				wall_hits.append({"angle": n.angle(), "age": 0.0, "power": clampf(vn / 600.0, 0.0, 1.0)})
				fx.burst(b.position + n * b.radius, T.WALL_COLOR.lightened(0.4), int(clampf(vn / 80.0, 3.0, 10.0)), vn * 0.4)
				sfx.play("wall", randf_range(0.9, 1.1), linear_to_db(clampf(vn / 500.0, 0.2, 1.0)))
			if vn > T.SHAKE_MIN_IMPACT:
				add_shake(vn * T.SHAKE_PER_IMPACT * 0.7)


## Called by a blob when its push goes off.
func do_push(pusher: OldBlob) -> void:
	var reach := pusher.push_reach()
	fx.shockwave(pusher.position, pusher.radius, reach, pusher.color.lightened(0.5))
	sfx.play("push", randf_range(0.95, 1.05) / sqrt(pusher.mass), 0.0, 0.0)
	var hits := 0
	for other in blobs:
		var b: OldBlob = other
		if b == pusher:
			continue
		var d := b.position - pusher.position
		var dist := d.length()
		if dist - b.radius > reach:
			continue
		var n := d / dist if dist > 0.001 else Vector2.from_angle(randf() * TAU)
		var gap := maxf(dist - b.radius - pusher.radius, 0.0)
		var falloff := lerpf(1.0, T.PUSH_FALLOFF, clampf(gap / (reach - pusher.radius), 0.0, 1.0))
		var dv := T.PUSH_IMPULSE * pusher.push_power() * falloff / pow(b.mass, T.PUSH_RESIST_EXP)
		# Cancel any motion toward the pusher so a push always lands cleanly.
		var incoming := b.vel.dot(n)
		if incoming < 0.0:
			b.vel -= n * incoming
		b.vel += n * dv
		b.stun = maxf(b.stun, T.PUSH_STUN)
		b.flash = 1.0
		b.bump(n, dv)
		pusher.vel -= n * dv * T.PUSH_RECOIL * b.mass / pusher.mass
		fx.burst(b.position - n * b.radius, b.color.lightened(0.4), 10, dv * 0.6)
		hits += 1
	_on_impact(pusher.position, T.PUSH_IMPULSE * (1.0 if hits > 0 else 0.5))
	if hits > 0:
		hitstop = maxf(hitstop, T.HITSTOP_PUSH)
		add_shake(T.SHAKE_PUSH * minf(hits, 2))
		sfx.play("boing", randf_range(0.7, 0.8), 3.0, 0.0)
	else:
		add_shake(T.SHAKE_WHIFF)


func add_shake(amount: float) -> void:
	shake = minf(shake + amount, T.SHAKE_MAX)


# --- Hooks for variants (see scripts/neon/neon_game.gd) ----------------------

## Out-of-bounds slow zone. The arena uses everything outside the ring.
func in_mud(pos: Vector2) -> bool:
	return pos.length() > T.RING_RADIUS


func _make_blob() -> OldBlob:
	return OldBlob.new()


func _make_fx() -> Fx:
	return Fx.new()


## Runs every unfrozen physics frame after the bots think, before movement.
func _before_simulate(_delta: float) -> void:
	pass


## Something hit something at `pos` with roughly `strength` px/s.
func _on_impact(_pos: Vector2, _strength: float) -> void:
	pass


# --- Rules -------------------------------------------------------------------

func _check_ring(delta: float) -> void:
	for other in blobs.duplicate():
		var b: OldBlob = other
		if b.position.length() > T.RING_RADIUS:
			b.outside_time += delta
			if b.outside_time >= T.RING_OUT_TIME and state == "playing":
				_eliminate(b)
		else:
			b.outside_time = maxf(b.outside_time - delta * 2.0, 0.0)


func _eliminate(b: OldBlob) -> void:
	_on_impact(b.position, 1500.0)
	blobs.erase(b)
	b.die()
	fx.burst(b.position, b.color, 28, 380.0)
	fx.shockwave(b.position, b.radius, b.radius * 4.0, b.color, 0.45)
	sfx.play("out", randf_range(0.9, 1.1))
	add_shake(10.0)
	hitstop = maxf(hitstop, 0.08)
	if b.is_player:
		_show_banner("BUMPED OUT!", Color(1.0, 0.45, 0.4), 2.0)


func _check_round_over() -> void:
	if state != "playing" or blobs.size() > 1:
		return
	state = "over"
	if blobs.is_empty():
		_show_banner("DRAW!", Color.WHITE)
	elif blobs[0].is_player:
		_show_banner("YOU WIN!", Color(1.0, 0.9, 0.35))
	else:
		_show_banner("%s WINS" % blobs[0].display_name.to_upper(), blobs[0].color)
	_hint.text = "Press R to play again"


func _update_food(delta: float) -> void:
	if state == "playing":
		food_timer -= delta
		if food_timer <= 0.0:
			food_timer = T.FOOD_SPAWN_INTERVAL * randf_range(0.7, 1.3)
			if foods.size() < T.FOOD_MAX:
				_spawn_food()
	for f in foods:
		f["age"] += delta
	for f in foods.duplicate():
		var fpos: Vector2 = f["pos"]
		for other in blobs:
			var b: OldBlob = other
			if b.position.distance_to(fpos) < b.radius + T.FOOD_RADIUS:
				foods.erase(f)
				b.eat()
				fx.burst(fpos, T.FOOD_COLOR, 10, 160.0)
				sfx.play("pop", randf_range(0.95, 1.1), -2.0)
				break


func _spawn_food() -> void:
	for _attempt in 12:
		var p := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * T.RING_RADIUS * 0.8
		var clear := true
		for other in blobs:
			var b: OldBlob = other
			if b.position.distance_to(p) < b.radius + 30.0:
				clear = false
				break
		if clear:
			foods.append({"pos": p, "age": 0.0, "seed": randf() * TAU})
			return


# --- Drawing (arena + food; blobs draw themselves) --------------------------

func _draw() -> void:
	# Out-of-bounds mud between the ring and the wall, with slow hazard stripes.
	draw_circle(Vector2.ZERO, T.WALL_RADIUS, T.MOAT_COLOR)
	var mid := (T.WALL_RADIUS + T.RING_RADIUS) * 0.5
	var stripe_w := T.WALL_RADIUS - T.RING_RADIUS
	var stripes := 36
	for i in stripes:
		var a0 := TAU * i / stripes + clock * 0.05
		draw_arc(Vector2.ZERO, mid, a0, a0 + TAU / stripes * 0.5, 6, Color(1.0, 0.3, 0.25, 0.07), stripe_w, false)

	# Ring floor.
	draw_circle(Vector2.ZERO, T.RING_RADIUS, T.FLOOR_COLOR)
	for k: float in [0.33, 0.66]:
		draw_arc(Vector2.ZERO, T.RING_RADIUS * k, 0.0, TAU, 96, Color(1, 1, 1, 0.05), 2.0, true)
	draw_circle(Vector2.ZERO, 6.0, Color(1, 1, 1, 0.08))
	var edge_pulse := 0.85 + 0.15 * sin(clock * 3.0)
	var edge_col := T.RING_EDGE_COLOR
	edge_col.a = edge_pulse
	draw_arc(Vector2.ZERO, T.RING_RADIUS, 0.0, TAU, 128, edge_col, 5.0, true)

	# Bouncy wall, with a flash where something just hit it.
	var wall_r := T.WALL_RADIUS + 7.0
	draw_arc(Vector2.ZERO, wall_r, 0.0, TAU, 128, T.WALL_COLOR, 14.0, true)
	for hit in wall_hits:
		var t: float = hit["age"] / 0.35
		var power: float = hit["power"]
		var ang: float = hit["angle"]
		var span := 0.15 + 0.2 * power
		draw_arc(Vector2.ZERO, wall_r, ang - span, ang + span, 16,
			Color(1, 1, 1, (1.0 - t) * 0.9), 14.0 + 8.0 * power * (1.0 - t), true)

	# Food: pops in with an overshoot, then bobs.
	for f in foods:
		var age: float = f["age"]
		var fpos: Vector2 = f["pos"]
		var fseed: float = f["seed"]
		var pop := minf(age / 0.25, 1.0)
		var s := (1.0 + 0.4 * sin(pop * PI)) * pop
		var r := T.FOOD_RADIUS * s * (1.0 + 0.12 * sin(clock * 6.0 + fseed))
		draw_circle(fpos, r * 2.0, Color(T.FOOD_COLOR, 0.15))
		draw_circle(fpos, r, T.FOOD_COLOR)
		draw_circle(fpos + Vector2(-r, -r) * 0.3, r * 0.35, Color(1, 1, 1, 0.6))
