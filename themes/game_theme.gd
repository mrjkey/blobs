@tool
class_name GameTheme
extends Resource
## A visual theme. Elements draw themselves (one default drawing each) with the
## theme's `style`, ask it for their colours and options with value(), and
## fall back to their own defaults for anything the theme doesn't set. The
## player picks a theme in the main menu (Session.theme_name); everything reads
## it through current(). One .tres per theme: themes/classic/classic.tres,
## themes/neon/neon.tres.

const DEFAULT := "res://themes/neon/neon.tres"

@export var display_name := "Neon"
@export var style: ThemeStyle

## Colours and options by name, e.g. "wall.color" or "food.shape". Elements
## ask with their own default (see value()), so only differences go here.
@export var values := {}

## Rare: element name -> ThemeSkin that replaces that element's default drawing.
@export var overrides := {}

@export_group("Screen")
@export var hud: Theme # the HUD's text style
@export var backdrop: PackedScene # drawn behind everything (e.g. the neon grid); may be empty
@export var glow: PackedScene # bloom, used when Session.glow is on; may be empty
@export var clear_color := Color(0.07, 0.07, 0.11)
@export var beat_zoom := 0.0 # camera thump on each kick drum

@export_group("Blob colours")
@export var player_color := Color(0.3, 0.85, 1.0)
@export var p2_color := Color(1.0, 0.5, 0.1)
@export var bot_colors := PackedColorArray()

static var _editor_theme: GameTheme


## The theme in use (in the editor: the default one, for @tool previews).
static func current() -> GameTheme:
	if Engine.is_editor_hint():
		if _editor_theme == null:
			_editor_theme = load(DEFAULT)
		return _editor_theme
	return Session.theme


## The theme's value for `key`, or `default` when it doesn't set one.
func value(key: String, default: Variant) -> Variant:
	return values.get(key, default)


## Every colour a blob can be: the players' and the bots' colours, without
## repeats. Lineups pick from it by index (PlayerSlot.color_index).
func palette() -> PackedColorArray:
	var out := PackedColorArray([player_color, p2_color])
	for c in bot_colors:
		if not out.has(c):
			out.append(c)
	return out


func palette_color(index: int) -> Color:
	var p := palette()
	return p[posmod(index, p.size())]


## Draws `node` with this theme's override for `element`, if it has one.
## Elements start their _draw() with: if theme.draw_override("bumper", self): return
func draw_override(element: String, node: CanvasItem) -> bool:
	var skin: ThemeSkin = overrides.get(element)
	if skin == null:
		return false
	skin.draw(node)
	return true
