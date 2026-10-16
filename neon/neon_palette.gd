class_name NeonPalette
extends Resource
## Brightness and colours of the neon look. With glow on (main menu), anything
## drawn brighter than 1.0 blooms; neon colours are drawn at 1.5x-3x on purpose
## (see NeonLook.hdr()). The bloom itself is neon/neon_glow_env.tres.

@export var brightness := 0.75 # master dimmer for every neon colour (1.0 = original)
@export var blob_glow := 2.4 # brightness of blob outlines
@export var trail_frames := 12 # motion trail length in frames

@export_group("Ring")
@export var ring_glow := 1.4 # ring edge brightness between beats
@export var ring_pulse := 0.6 # extra ring brightness on each kick (0 = no pulse)
@export var ring_pulse_width := 1.0 # extra ring line width on each kick
@export var floor_color := Color(0.03, 0.0, 0.09, 0.6)
@export var moat_color := Color(0.1, 0.0, 0.04, 0.55)
@export var ring_color := Color(1.0, 0.6, 0.15)
@export var wall_color := Color(0.5, 0.3, 1.0)
