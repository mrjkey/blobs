extends RefCounted
## Shared helpers for the neon look (used by the neon arena and the treadmill).
## The bloom itself is neon/neon_glow.tscn.

const NT = preload("res://scripts/neon/neon_tuning.gd")


## A colour pushed past 1.0 so it blooms. k = how bright (2-3 = strong glow).
static func hdr(c: Color, k: float, a: float = 1.0) -> Color:
	k *= NT.BRIGHTNESS
	return Color(c.r * k, c.g * k, c.b * k, a)

