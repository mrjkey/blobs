extends Node
## Autoload "Session": choices that must survive scene changes and reloads.
## Menus write here, game scenes read here in _ready().

const SETTINGS_PATH := "user://settings.cfg"
## Theme name -> its GameTheme resource (the THEME setting's choices).
const THEMES := {
	"neon": "res://themes/neon/neon.tres",
	"classic": "res://themes/classic/classic.tres",
}

## The game the lobby shows: the last one picked there (a ModeInfo).
var next_mode: Resource

## Who plays the next game: PlayerSlots, built by the lobby, and the path of
## the ModeInfo they were picked for. A mode only uses a lineup made for it;
## started on its own (F6) it makes a default one (PlayerSlot.default_lineup).
## (Untyped on purpose, like `theme`: this autoload loads before those classes.)
var lineup: Array = []
var lineup_mode := ""

## Neon bloom (HDR 2D + glow). Off by default: the first scene that uses it
## loads slowly while the GPU compiles shaders. Saved between runs.
var glow := false:
	set(value):
		glow = value
		_save()

## The visual theme picked in SETTINGS (a key of THEMES). Saved between runs.
var theme_name := "neon":
	set(value):
		theme_name = value if THEMES.has(value) else "neon"
		_theme = null
		_save()

## The GameTheme for theme_name. Use GameTheme.current(), which also works in the editor.
## (Typed Resource on purpose: this autoload loads first, before the classes a theme uses.)
var theme: Resource:
	get:
		if _theme == null:
			_theme = load(THEMES[theme_name])
		return _theme

## Gameplay settings the player picked: option key -> choice id. Read them
## through GameSettings (core/settings/game_settings.gd), which has the
## defaults. Saved between runs.
var settings := {}

var _theme: Resource # held, so the theme loads once (and live .tres edits reach this copy)


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		settings = cfg.get_value("gameplay", "settings", {}) # first: the setters below save
		glow = cfg.get_value("video", "glow", false)
		theme_name = cfg.get_value("video", "theme", "neon")


func set_setting(key: String, id: String) -> void:
	settings[key] = id
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep anything else already saved
	cfg.set_value("video", "glow", glow)
	cfg.set_value("video", "theme", theme_name)
	cfg.set_value("gameplay", "settings", settings)
	cfg.save(SETTINGS_PATH)
