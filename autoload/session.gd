extends Node
## Autoload "Session": choices that must survive scene changes and reloads.
## Menus write here, game scenes read here in _ready().

signal theme_changed # theme_name changed (the THEME setting): menus restyle (MenuFrame)

const SETTINGS_PATH := "user://settings.cfg"
const MAX_RECENT := 8 # online games remembered (recent_hosts)
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

## The lobby's PLAYERS row per game (ModeInfo path -> how many play, computers
## filling the rest). Kept while the game runs, not saved.
var lobby_seats := {}

## Neon bloom (HDR 2D + glow). Off by default: the first scene that uses it
## loads slowly while the GPU compiles shaders. Saved between runs.
var glow := false:
	set(value):
		glow = value
		_save()

## The visual theme picked in SETTINGS (a key of THEMES). Saved between runs.
var theme_name := "classic":
	set(value):
		theme_name = value if THEMES.has(value) else "classic"
		_theme = null
		_save()
		theme_changed.emit()

## A theme the game in progress plays in instead of theme_name (ModeInfo.theme:
## a mode that only has one look). GameMode sets it while it runs. Not saved.
var theme_override := "":
	set(value):
		theme_override = value if THEMES.has(value) else ""
		_theme = null

## The GameTheme in use: theme_override, else theme_name. Use GameTheme.current(), which also works in the editor.
## (Typed Resource on purpose: this autoload loads first, before the classes a theme uses.)
var theme: Resource:
	get:
		if _theme == null:
			_theme = load(THEMES[theme_override if theme_override != "" else theme_name])
		return _theme

## Gameplay settings the player picked: option key -> choice id. Read them
## through GameSettings (core/settings/game_settings.gd), which has the
## defaults. Saved between runs.
var settings := {}

## In someone else's online game: the host's choices for the game's rules
## (GameSettings.use_host_settings()), read before `settings`. Not saved.
var host_settings := {}

## The name others see in online games (the online screen's YOUR NAME). Saved;
## the computer's own name to begin with.
var player_name := ""

## Online games joined before, newest first: {address, name}. Saved.
var recent_hosts: Array = []

var _theme: Resource # held, so the theme loads once (and live .tres edits reach this copy)


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		settings = cfg.get_value("gameplay", "settings", {}) # first: the setters below save
		player_name = cfg.get_value("online", "name", "")
		recent_hosts = cfg.get_value("online", "recent", [])
		glow = cfg.get_value("video", "glow", false)
		theme_name = cfg.get_value("video", "theme", "classic")
	if player_name.strip_edges() == "":
		player_name = computer_name()


func set_setting(key: String, id: String) -> void:
	settings[key] = id
	_save()


func set_player_name(value: String) -> void:
	player_name = value.strip_edges().left(16)
	_save()


## Put the game at `address`, hosted by `host`, first in recent_hosts.
func remember_host(address: String, host: String) -> void:
	forget_host(address)
	recent_hosts.push_front({address = address, name = host})
	recent_hosts.resize(mini(recent_hosts.size(), MAX_RECENT))
	_save()


func forget_host(address: String) -> void:
	recent_hosts = recent_hosts.filter(func(h: Variant) -> bool: return h is Dictionary and h.get("address", "") != address)
	_save()


## This computer's name: COMPUTERNAME on Windows, the host name on Linux.
static func computer_name() -> String:
	for key in ["COMPUTERNAME", "HOSTNAME"]:
		var n := OS.get_environment(key).strip_edges()
		if n != "":
			return n.to_upper().left(16)
	var f := FileAccess.open("/etc/hostname", FileAccess.READ)
	if f != null:
		var n := f.get_line().strip_edges()
		if n != "":
			return n.to_upper().left(16)
	return "PLAYER"


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep anything else already saved
	cfg.set_value("video", "glow", glow)
	cfg.set_value("video", "theme", theme_name)
	cfg.set_value("gameplay", "settings", settings)
	cfg.set_value("online", "name", player_name)
	cfg.set_value("online", "recent", recent_hosts)
	cfg.save(SETTINGS_PATH)
