class_name KillLasers
extends Node2D
## Two lasers across the track, belt_height() apart and centred on this node: the mode moves it up the track as it scrolls. A blob that ends
## up past either one is out (`blob.die()`). With `lethal` off they hold blobs
## between them instead (the round's over: keep the winner in view). Group "kill_lasers"; bots read kill_top() /
## kill_bottom() to keep clear. Draws above the blobs (z_index 5); colour from
## the theme: kill_lasers.color.

signal blob_lasered(blob: Blob)

const COLOR := Color(1.0, 0.25, 0.2)

@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")
@export var enabled := true # off = do nothing (e.g. during the countdown)
@export var lethal := true

var clock := 0.0 # seconds, for the flicker


func _enter_tree() -> void:
	add_to_group("kill_lasers")


func _ready() -> void:
	process_physics_priority = 20 # after blob abilities (10)


## The distance between the lasers: TrackSettings.belt_height scaled by the TRACK VIEW setting.
func belt_height() -> float:
	return settings.belt_height * GameSettings.track_view()


func kill_top() -> float:
	return global_position.y - belt_height() * 0.5


func kill_bottom() -> float:
	return global_position.y + belt_height() * 0.5


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	var top := kill_top()
	var bottom := kill_bottom()
	for b: Blob in get_tree().get_nodes_in_group("blobs"):
		if not b.alive:
			continue
		var y := b.global_position.y
		if y <= bottom and y >= top:
			continue
		if lethal:
			var edge_y := bottom if y > bottom else top
			Juice.burst(Vector2(b.global_position.x, edge_y), GameTheme.current().value("kill_lasers.color", COLOR), 24, 500.0)
			Sfx.play("zap", randf_range(0.9, 1.1), 0.0, 0.0)
			b.die()
			blob_lasered.emit(b)
		else:
			b.global_position.y = clampf(y, top, bottom)


## Online (NetGame): where the host's are.
func net_state() -> Array:
	return [global_position]


func net_apply(s: Array) -> void:
	global_position = s[0]


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("kill_lasers", self):
		return
	var st := theme.style
	var col: Color = theme.value("kill_lasers.color", COLOR)
	var k := st.kick(self)
	var half := settings.track_width * 0.5
	for y: float in [kill_top(), kill_bottom()]:
		var flicker := 0.85 + 0.15 * sin(clock * 40.0 + y * 0.1)
		var a := to_local(Vector2(-half, y))
		var b := to_local(Vector2(half, y))
		st.line(self, a, b, col, 14.0, 0.9, 0.2)
		st.line(self, a, b, col, 4.0, (2.2 + 0.5 * k) * flicker, flicker)
		for end: Vector2 in [a, b]:
			st.dot(self, end, 7.0, col, 2.5)

