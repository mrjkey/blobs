@tool
class_name NeonLook
extends RefCounted
## Helper for the neon skins.


## A colour pushed past 1.0 so it blooms when glow is on. k = how bright
## (2-3 = strong glow), scaled by the theme's `brightness`.
static func hdr(c: Color, k: float, a: float = 1.0) -> Color:
	k *= GameTheme.current().brightness
	return Color(c.r * k, c.g * k, c.b * k, a)
