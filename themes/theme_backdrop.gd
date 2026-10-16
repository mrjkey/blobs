class_name ThemeBackdrop
extends Node2D
## Adds the current theme's background (e.g. the neon grid) and its glow (when
## Session.glow is on) to the scene, and sets the clear colour. Put one near
## the top of every game scene.


func _ready() -> void:
	var theme := GameTheme.current()
	RenderingServer.set_default_clear_color(theme.clear_color)
	if theme.backdrop != null:
		add_child(theme.backdrop.instantiate())
	if theme.glow != null:
		add_child(theme.glow.instantiate())
