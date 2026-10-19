class_name PromptBar
extends Control
## A row of button prompts, like a console's legend bar: each prompt is some
## glyphs (ButtonGlyph codes) and what they do, e.g.
##   prompts = [[["a", "key:SPACE"], "Join"], [["b", "key:ESC"], "Back"]]
## The lobby's legends and its READY banner use it; draw_prompt() is shared
## with the lobby's player panels.

const GLYPH_GAP := 5.0 # between the glyphs of one prompt
const TEXT_GAP := 9.0 # between the glyphs and the text

@export var glyph_height := 30.0
@export var font_size := 20
@export var text_color := Color(0.8, 0.83, 0.98)
@export var gap := 36.0 # between prompts
@export_enum("Left", "Center", "Right") var align := 1

var prompts: Array = []:
	set(value):
		prompts = value
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var widths: Array[float] = []
	var total := 0.0
	for p: Array in prompts:
		var w := prompt_width(font, p, glyph_height, font_size)
		widths.append(w)
		total += w
	total += gap * maxi(prompts.size() - 1, 0)
	var x: float = [0.0, (size.x - total) * 0.5, size.x - total][align]
	for i in prompts.size():
		draw_prompt(self, font, Vector2(x, size.y * 0.5), prompts[i], glyph_height, font_size, text_color)
		x += widths[i] + gap


static func prompt_width(font: Font, prompt: Array, h: float, fs: int) -> float:
	var w := 0.0
	for g: String in prompt[0]:
		w += ButtonGlyph.width(font, g, h) + GLYPH_GAP
	if prompt[1] == "":
		return w - GLYPH_GAP
	return w - GLYPH_GAP + TEXT_GAP + font.get_string_size(prompt[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## Paints one prompt with its left edge at `at` (vertically centred); returns its width.
static func draw_prompt(ci: CanvasItem, font: Font, at: Vector2, prompt: Array, h: float, fs: int, color: Color) -> float:
	var x := at.x
	for g: String in prompt[0]:
		x += ButtonGlyph.draw(ci, font, Vector2(x, at.y), g, h) + GLYPH_GAP
	x -= GLYPH_GAP
	if prompt[1] != "":
		x += TEXT_GAP
		var y := at.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		ci.draw_string(font, Vector2(x, y), prompt[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
		x += font.get_string_size(prompt[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return x - at.x
