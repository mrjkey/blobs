class_name NeonGlow
extends WorldEnvironment
## Bloom for the neon look: anything drawn brighter than 1.0 glows. Only on when
## Session.glow is (the main menu toggles it), because the first scene that uses
## it loads slowly while the GPU compiles shaders. HDR 2D is switched on while
## this node is in the tree and off again when it leaves, so scenes without it
## render normally. Glow numbers live in neon/neon_glow_env.tres.


func _enter_tree() -> void:
	if Session.glow:
		get_viewport().use_hdr_2d = true
	else:
		environment = null


func _exit_tree() -> void:
	if Session.glow:
		get_viewport().use_hdr_2d = false
