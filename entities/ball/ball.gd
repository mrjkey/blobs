class_name Ball
extends Blob
## The ball of ball games (football). A Blob with no controller, no moves and
## no face, so everything blobs do already works on it: it collides with
## blobs, bounces off walls, flies when pushed and gets rammed by a bump dash
## (a ghost dash goes through it). Its numbers are in ball_stats.tres. Joins
## "balls" as well as "blobs"; an arena with goals looks for it there.

@export var start_mass := 0.7 # lighter than a blob, so a push sends it far


func _init() -> void:
	rules = MoveRules.new() # no dash, no energy, whatever the settings say


func _enter_tree() -> void:
	super._enter_tree()
	add_to_group("balls")


func _ready() -> void:
	mass = start_mass
	super._ready()
	color = GameTheme.current().value("ball.color", BallBody.COLOR)


## Scored: it bursts and is gone until reset(). It stays in its groups, but
## with `alive` off nothing moves it, hits it or counts it.
func explode() -> void:
	if not alive:
		return
	alive = false
	visible = false
	Juice.burst(global_position, color, 30, 620.0)
	Juice.burst(global_position, Color.WHITE, 14, 380.0)
	Juice.shockwave(global_position, radius, radius * 6.0, color.lightened(0.3), 0.35)
	Sfx.play("burst", randf_range(0.8, 0.9))
	halt()


## Back to `pos`, still and in play again (kick-off).
func reset(pos: Vector2) -> void:
	alive = true
	visible = true
	global_position = pos
	halt()
	body.swell = -0.6 # pops back in


## A ball never dies like a blob (no spin and fade, never freed): explode() hides it.
func _process(_delta: float) -> void:
	pass
