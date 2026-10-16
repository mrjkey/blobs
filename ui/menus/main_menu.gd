extends Control
## The first scene. Each button swaps the whole scene for another one.
##
## Scene links are file paths (@export_file), not PackedScene slots: the
## treadmill menu links back here, and two scenes holding PackedScenes of each
## other is a cyclic load that Godot refuses. Paths also load only on click.

@export_file("*.tscn") var treadmill_menu_path: String
@export_file("*.tscn") var ring_path: String
@export_file("*.tscn") var sandbox_path: String

@onready var treadmill_button: Button = $Center/Column/Buttons/TreadmillButton
@onready var glow_button: Button = %GlowButton
@onready var theme_button: Button = %ThemeButton

func _ready() -> void:
	treadmill_button.grab_focus()
	_show_settings()


func _on_treadmill_button_pressed() -> void:
	get_tree().change_scene_to_file(treadmill_menu_path)


func _on_ring_button_pressed() -> void:
	get_tree().change_scene_to_file(ring_path)


func _on_sandbox_button_pressed() -> void:
	get_tree().change_scene_to_file(sandbox_path)


## Next theme in Session.THEMES (saved). Every scene draws in it from then on.
func _on_theme_button_pressed() -> void:
	var names: Array = Session.THEMES.keys()
	Session.theme_name = names[(names.find(Session.theme_name) + 1) % names.size()]
	_show_settings()


## Bloom on/off (saved), for themes that have it. Off keeps scenes quick to load.
func _on_glow_button_pressed() -> void:
	Session.glow = not Session.glow
	_show_settings()


func _show_settings() -> void:
	var theme := GameTheme.current()
	theme_button.text = "THEME:  %s" % theme.display_name.to_upper()
	glow_button.disabled = theme.glow == null
	glow_button.text = "GLOW:  ON" if Session.glow else "GLOW:  OFF"
	if glow_button.disabled:
		glow_button.text = "GLOW:  -"


func _on_quit_button_pressed() -> void:
	get_tree().quit()
