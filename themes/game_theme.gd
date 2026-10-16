@tool
class_name GameTheme
extends Resource
## A visual theme: one skin per kind of thing, plus the HUD look, the
## background, the glow and the blob colours. The player picks one in the main
## menu (saved as Session.theme_name); everything reads it through current(),
## so switching themes restyles every scene without changing any scene.
## One .tres per theme: themes/classic/classic.tres, themes/neon/neon.tres.

const DEFAULT := "res://themes/neon/neon.tres"

@export var display_name := "Neon"
@export var brightness := 1.0 # master dimmer for HDR colours (see NeonLook.hdr())

@export_group("Skins")
@export var blob: BlobSkin
@export var trail: TrailSkin # empty = no motion trails
@export var fx: FxSkin
@export var room: RoomSkin
@export var ring: RingSkin
@export var track_bed: TrackBedSkin
@export var kill_lasers: KillLasersSkin
@export var wall: WallSkin
@export var bumper: BumperSkin
@export var food: FoodSkin
@export var laser: LaserSkin

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
