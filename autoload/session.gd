extends Node
## Autoload "Session": choices that must survive scene changes and reloads.
## Menus write here, game scenes read here in _ready().

const SETTINGS_PATH := "user://settings.cfg"

## Treadmill mode picked in ui/menus/treadmill_menu.tscn (0 = 1P vs computer,
## 1 = 2P versus, 2 = 2P + computer, 3 = watch). -1 = not picked yet, e.g. when
## treadmill.tscn is run on its own with F6.
var treadmill_mode := -1

## Neon bloom (HDR 2D + glow). Off by default: the first scene that uses it
## loads slowly while the GPU compiles shaders. Saved between runs.
var glow := false:
	set(value):
		glow = value
		_save()


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		glow = cfg.get_value("video", "glow", false)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep anything else already saved
	cfg.set_value("video", "glow", glow)
	cfg.save(SETTINGS_PATH)
