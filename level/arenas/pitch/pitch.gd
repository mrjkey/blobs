@tool
class_name Pitch
extends Node2D
## A football pitch centred on this node: a walled rectangle with bevelled
## corners (so the ball can't get stuck) and a goal in the middle of each end
## wall. Blobs can walk into the goals; the posts and the nets are solid.
## Team 0 defends the left goal, team 1 the right one. When a ball (group
## "balls") is all the way over a goal line, emits `goal_scored` with the
## team that scored, and stops counting until `counting` is set again.
## Colours from the theme: pitch.floor, pitch.lines, pitch.wall, team.0 / team.1.

signal goal_scored(team: int, ball: Blob)

const FLOOR_COLOR := Color(0.16, 0.34, 0.2)
const LINES_COLOR := Color(0.85, 0.95, 0.85, 0.5)
const WALL_COLOR := Color(0.55, 0.6, 0.8)

@export var size := Vector2(1400.0, 780.0):
	set(v):
		size = v
		queue_redraw()
@export var goal_width := 220.0: # the mouth, post to post
	set(v):
		goal_width = v
		queue_redraw()
@export var goal_depth := 70.0:
	set(v):
		goal_depth = v
		queue_redraw()
@export var corner := 90.0: # how much of each corner is cut off
	set(v):
		corner = v
		queue_redraw()
@export var post_radius := 7.0
## Off = balls in a goal don't count (the countdown, after a goal until the kick-off).
@export var counting := true


func _enter_tree() -> void:
	add_to_group("arena")
	add_to_group("blob_colliders")


func _ready() -> void:
	process_physics_priority = 20 # after blob abilities (10), with the other rules


## The middle of the goal line that `team` defends (world position).
func own_goal(team: int) -> Vector2:
	return global_position + Vector2(-size.x * 0.5 if team == 0 else size.x * 0.5, 0.0)


## The middle of the goal line that `team` shoots at.
func target_goal(team: int) -> Vector2:
	return own_goal(1 - team)


func collide(b: Blob, feel: PhysicsFeel) -> void:
	var half := size * 0.5
	var mouth := goal_width * 0.5
	var p := b.global_position - global_position
	var r := b.radius
	if p.y < -half.y + r:
		_hit(b, Vector2.DOWN, -half.y + r - p.y, feel)
	elif p.y > half.y - r:
		_hit(b, Vector2.UP, p.y - (half.y - r), feel)
	for s: float in [-1.0, 1.0]:
		var out := p.x * s # how far toward this end
		if out <= half.x - r - post_radius - corner:
			continue
		var n := Vector2(-s, 0.0) # back into the pitch
		if out <= half.x:
			# On the pitch side of the goal line: the end wall beside the goal.
			if absf(p.y) > mouth and out > half.x - r:
				_hit(b, n, out - (half.x - r), feel)
		else:
			# In the goal: its back and its sides.
			if out > half.x + goal_depth - r:
				_hit(b, n, out - (half.x + goal_depth - r), feel)
			if p.y > mouth - r:
				_hit(b, Vector2.UP, p.y - (mouth - r), feel)
			elif p.y < -mouth + r:
				_hit(b, Vector2.DOWN, -mouth + r - p.y, feel)
		for sy: float in [-1.0, 1.0]:
			_hit_point(b, Vector2(s * half.x, sy * mouth), r + post_radius, feel) # the posts
			# The bevelled corner: a wall across it, facing the middle.
			var cn := -Vector2(s, sy).normalized()
			var on_wall := Vector2(s * (half.x - corner), sy * half.y)
			var d := (p - on_wall).dot(cn)
			if d < r:
				_hit(b, cn, r - d, feel)
		p = b.global_position - global_position


func _hit_point(b: Blob, point: Vector2, reach: float, feel: PhysicsFeel) -> void:
	var d := b.global_position - global_position - point
	var dist := d.length()
	if dist >= reach or dist < 0.001:
		return
	_hit(b, d / dist, reach - dist, feel)


func _hit(b: Blob, n: Vector2, depth: float, feel: PhysicsFeel) -> void:
	var impact := BlobPhysics.bounce(b, n, depth, feel.wall_restitution)
	if impact > 0.0:
		BlobPhysics.wall_feedback(b.global_position - n * b.radius, impact, GameTheme.current().value("pitch.wall", WALL_COLOR))


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not counting:
		return
	for ball: Blob in get_tree().get_nodes_in_group("balls"):
		var x := ball.global_position.x - global_position.x
		if absf(x) > size.x * 0.5 + ball.radius:
			counting = false
			goal_scored.emit(1 if x < 0.0 else 0, ball) # in the left goal: team 1 scored
			return


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw() # neon walls pulse with the music


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("pitch", self):
		return
	var st := theme.style
	var half := size * 0.5
	var mouth := goal_width * 0.5
	var lines: Color = theme.value("pitch.lines", LINES_COLOR)
	var wall_col: Color = theme.value("pitch.wall", WALL_COLOR)
	var outline := _outline()
	draw_colored_polygon(outline, theme.value("pitch.floor", FLOOR_COLOR))
	for team in 2:
		var s := -1.0 if team == 0 else 1.0
		var col := theme.team_color(team)
		# Each half faintly in the colour of the team defending it, and its goal.
		var half_rect := Rect2(Vector2(minf(0.0, s * half.x), -half.y), Vector2(half.x, size.y))
		for poly in Geometry2D.intersect_polygons(outline, ThemeStyle.rect_points(half_rect)):
			draw_colored_polygon(poly, st.color(col, 0.6, 0.07))
		var net := Rect2(Vector2(s * half.x if s > 0.0 else -half.x - goal_depth, -mouth), Vector2(goal_depth, goal_width))
		draw_rect(net, st.color(col, 0.8, 0.22))
		for i in range(1, 6):
			var y := -mouth + goal_width * i / 6.0
			st.line(self, Vector2(s * half.x, y), Vector2(s * (half.x + goal_depth), y), col, 1.0, 1.0, 0.4)
		for i in range(1, 3):
			var x := s * (half.x + goal_depth * i / 3.0)
			st.line(self, Vector2(x, -mouth), Vector2(x, mouth), col, 1.0, 1.0, 0.4)
		# The box in front of it.
		var box := Rect2(Vector2(s * half.x - (0.0 if s < 0.0 else 150.0), -mouth - 70.0), Vector2(150.0, goal_width + 140.0))
		draw_rect(box, st.color(lines, 1.0), false, 2.0)
		st.line(self, Vector2(s * half.x, -mouth), Vector2(s * half.x, mouth), col, 3.0, 1.6)
	st.line(self, Vector2(0.0, -half.y), Vector2(0.0, half.y), lines, 2.0)
	st.ring(self, Vector2.ZERO, 110.0, lines, 2.0)
	st.dot(self, Vector2.ZERO, 5.0, lines)
	# The walls: around the pitch, with a gap at each goal, then the nets' frames.
	var w := 14.0 * st.bold
	var wall := st.color(wall_col, 1.4 + 0.4 * st.kick(self))
	var top := PackedVector2Array([Vector2(-half.x, -mouth), Vector2(-half.x, -half.y + corner),
		Vector2(-half.x + corner, -half.y), Vector2(half.x - corner, -half.y),
		Vector2(half.x, -half.y + corner), Vector2(half.x, -mouth)])
	var bottom := PackedVector2Array()
	for q in top:
		bottom.append(Vector2(q.x, -q.y))
	draw_polyline(top, wall, w, true)
	draw_polyline(bottom, wall, w, true)
	for s: float in [-1.0, 1.0]:
		var frame := PackedVector2Array([Vector2(s * half.x, -mouth), Vector2(s * (half.x + goal_depth), -mouth),
			Vector2(s * (half.x + goal_depth), mouth), Vector2(s * half.x, mouth)])
		draw_polyline(frame, st.color(wall_col, 1.2), maxf(w * 0.6, 3.0), true)
		for sy: float in [-1.0, 1.0]:
			st.disc(self, Vector2(s * half.x, sy * mouth), post_radius, Color.WHITE, 0.0, 1.0, 1.5, 2.0)


## The pitch floor's outline (the rectangle with its corners cut).
func _outline() -> PackedVector2Array:
	var h := size * 0.5
	var c := corner
	return PackedVector2Array([Vector2(-h.x + c, -h.y), Vector2(h.x - c, -h.y), Vector2(h.x, -h.y + c),
		Vector2(h.x, h.y - c), Vector2(h.x - c, h.y), Vector2(-h.x + c, h.y), Vector2(-h.x, h.y - c),
		Vector2(-h.x, -h.y + c)])

