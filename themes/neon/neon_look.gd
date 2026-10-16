@tool
class_name NeonLook
extends RefCounted
## Helpers for the neon look, shared by everything drawn in neon.

static var palette: NeonPalette = preload("res://themes/neon/neon_palette.tres")


## A colour pushed past 1.0 so it blooms. k = how bright (2-3 = strong glow).
static func hdr(c: Color, k: float, a: float = 1.0) -> Color:
	k *= palette.brightness
	return Color(c.r * k, c.g * k, c.b * k, a)


## The node in group "music" (a Techno), or null.
static func music(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group("music")


## 1.0 on each kick drum, fading before the next; 0 without music.
static func kick(tree: SceneTree) -> float:
	var m := music(tree)
	return m.kick_env() if m != null else 0.0


## Beats of the music since its scene started. Without music, a steady 128 BPM
## clock so beat-driven things (lasers) still work in a test scene.
static func beat(tree: SceneTree) -> float:
	var m := music(tree)
	return m.beat() if m != null else Time.get_ticks_usec() / 1000000.0 * 128.0 / 60.0
