extends RefCounted
## Shared helpers for the neon look (used by the neon arena and the treadmill).

const NT = preload("res://scripts/neon/neon_tuning.gd")


## A colour pushed past 1.0 so it blooms. k = how bright (2-3 = strong glow).
static func hdr(c: Color, k: float, a: float = 1.0) -> Color:
	k *= NT.BRIGHTNESS
	return Color(c.r * k, c.g * k, c.b * k, a)


## Turns on HDR 2D for the viewport and returns a WorldEnvironment with glow.
## Add the returned node to the scene.
static func make_world_env(viewport: Viewport) -> WorldEnvironment:
	viewport.use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = NT.GLOW_INTENSITY
	env.glow_strength = NT.GLOW_STRENGTH
	env.glow_hdr_threshold = NT.GLOW_THRESHOLD
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var levels := [0.0, 1.0, 1.0, 0.8, 0.6, 0.0, 0.0]  # wider levels = softer, bigger halo
	for i in levels.size():
		env.set_glow_level(i, levels[i])
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	return world_env
