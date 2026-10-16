@tool
class_name ThemeStyle
extends Resource
## How a theme paints the elements. Every element has one default drawing,
## written with these primitives; a theme only changes the numbers and flags
## here (embedded in its .tres), so a new element works in every theme
## without any theme-specific code. Classic: plain colours, solid bodies with
## a darker rim and a drop shadow. Neon: glowing colours, dark glass bodies
## with bright edges, halos, trails, streak sparks, thin walls, a beat pulse.

@export_group("Colour")
## 0 = plain colours. Above 0 = HDR colours that bloom when glow is on (k * glow * brightness).
@export var glow := 0.0
@export var brightness := 1.0 # master dimmer for glowing colours
@export var fill := 1.0 # body brightness: 1 = solid colour, ~0.12 = dark glass
@export var fill_alpha := 1.0
@export var flash_fill := 0.6 # how far a flash turns a body white
@export var edge := 0.5 # edge brightness: 0.5 = a darker rim, ~1.6 = a bright glowing edge
@export var edge_flash := 0.0 # extra edge brightness while flashing
@export var ink := Color(0.08, 0.08, 0.12) # eye pupils (and X-eyes and brows without glow)

@export_group("Features")
@export var shadows := true # drop shadows under bodies
@export var highlights := true # the shine on blobs and food
@export var halos := false # a soft glow around blobs
@export var trail_frames := 0 # motion trail length (0 = no trails)
@export var spark_streak := 0.0 # 0 = round sparks; > 0 = streaks this many seconds of velocity long
@export var pulse := 0.0 # how much things react to the music's kick drum
@export var bold := 1.0 # width of the heavy strokes (arena walls): 1 = thick, ~0.3 = thin


## `c` the way this theme shows it, at intensity `k` (only glowing themes use k).
func color(c: Color, k := 1.0, alpha := -1.0) -> Color:
	var out := c
	if glow > 0.0:
		var m := k * glow * brightness
		out = Color(c.r * m, c.g * m, c.b * m, c.a)
	if alpha >= 0.0:
		out.a = alpha
	return out


## The edge colour of a body of colour `c`; `k` scales a glowing edge.
func edge_color(c: Color, k := 1.0, flash := 0.0) -> Color:
	if glow > 0.0:
		return color(c, edge * k + edge_flash * flash)
	return Color(c.r * edge, c.g * edge, c.b * edge, c.a)


## The fill colour of a body of colour `c`, darkened by `shade`, whitened by `flash`.
func fill_color(c: Color, flash := 0.0, shade := 1.0) -> Color:
	var m := fill * shade
	return Color(c.r * m, c.g * m, c.b * m, fill_alpha).lerp(Color.WHITE, flash * flash_fill)


## X-eyes, brows and blink lines on a body of colour `c`.
func mark(c: Color) -> Color:
	return color(c, 2.5) if glow > 0.0 else ink


## The music's kick drum (1 on the beat, fading) times `pulse`; 0 in the editor.
func kick(node: Node) -> float:
	if pulse <= 0.0 or Engine.is_editor_hint():
		return 0.0
	return pulse * Techno.current_kick(node.get_tree())


## A solid shape: shadow, (halo), fill, edge. `points` go round the shape once.
## `k` scales the edge's glow, `width` its thickness.
func body(ci: CanvasItem, points: PackedVector2Array, c: Color, flash := 0.0, shade := 1.0,
		k := 1.0, width := 3.0, halo := false) -> void:
	if shadows:
		var shadow := PackedVector2Array()
		for p in points:
			shadow.append(p + Vector2(3.0, 6.0))
		ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
	if halo and halos:
		ci.draw_colored_polygon(_grown(points, 7.0), color(c.lerp(Color.WHITE, flash * 0.6), 1.0, 0.12))
	ci.draw_colored_polygon(points, fill_color(c, flash, shade))
	outline(ci, points, edge_color(c, k, flash), width)


## A closed outline through `points`, in an exact colour (use color() / edge_color()).
func outline(ci: CanvasItem, points: PackedVector2Array, c: Color, width := 3.0) -> void:
	var loop := points.duplicate()
	loop.append(points[0])
	ci.draw_polyline(loop, c, width, true)


func disc(ci: CanvasItem, centre: Vector2, r: float, c: Color, flash := 0.0, shade := 1.0,
		k := 1.0, width := 3.0, halo := false) -> void:
	body(ci, circle_points(centre, r), c, flash, shade, k, width, halo)


func box(ci: CanvasItem, rect: Rect2, c: Color, flash := 0.0, shade := 1.0, k := 1.0, width := 3.0) -> void:
	body(ci, rect_points(rect), c, flash, shade, k, width)


func line(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, width: float, k := 1.0, alpha := -1.0) -> void:
	ci.draw_line(a, b, color(c, k, alpha), width, true)


## A circle (or an arc from `from` to `to`) stroked `width` wide.
func ring(ci: CanvasItem, centre: Vector2, r: float, c: Color, width: float, k := 1.0, alpha := -1.0,
		from := 0.0, to := TAU) -> void:
	ci.draw_arc(centre, r, from, to, maxi(48, int(r * 0.4)), color(c, k, alpha), width, true)


func dot(ci: CanvasItem, p: Vector2, r: float, c: Color, k := 1.0, alpha := -1.0) -> void:
	ci.draw_circle(p, r, color(c, k, alpha))


static func circle_points(centre: Vector2, r: float, segments := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		pts.append(centre + Vector2.from_angle(TAU * i / segments) * r)
	return pts


static func rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)])


## `points` pushed `by` pixels away from their centre.
static func _grown(points: PackedVector2Array, by: float) -> PackedVector2Array:
	var centre := Vector2.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	var out := PackedVector2Array()
	for p in points:
		out.append(p + (p - centre).normalized() * by)
	return out
