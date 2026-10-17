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


## Back to `pos`, still (kick-off).
func reset(pos: Vector2) -> void:
	global_position = pos
	vel = Vector2.ZERO
	stun = 0.0
	body.swell = -0.6 # pops back in
