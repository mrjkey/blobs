extends Node
## Autoload "Juice": game feel that any component can trigger without knowing
## what scene it is in. Screen shake, hitstop, sparks and shockwaves, and the
## `impact` signal that background effects (like the neon grid) listen to.
## Numbers live in autoload/juice_settings.tres.

## Something hit something at `pos` with roughly `strength` px/s.
signal impact(pos: Vector2, strength: float)

var settings: JuiceSettings = preload("res://autoload/juice_settings.tres")

## Current screen shake in pixels. GameCamera reads it.
var shake_amount := 0.0

var _hitstop_until := 0 # Time.get_ticks_usec() when the freeze ends
var _last_usec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	# Real time, not delta: delta is 0 during hitstop, and shake keeps fading through it.
	var now := Time.get_ticks_usec()
	var real_delta := (now - _last_usec) / 1000000.0
	_last_usec = now
	shake_amount *= exp(-settings.shake_decay * real_delta)
	if Engine.time_scale == 0.0 and now >= _hitstop_until:
		Engine.time_scale = 1.0


func shake(amount: float) -> void:
	shake_amount = minf(shake_amount + amount, settings.shake_max)


## Freeze the game for `seconds` (real time). Overlapping calls keep the longest.
func hitstop(seconds: float) -> void:
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_usec() + int(seconds * 1000000.0))
	Engine.time_scale = 0.0


func impact_at(pos: Vector2, strength: float) -> void:
	impact.emit(pos, strength)


## Sparks, drawn by the FxLayer in the current scene (nothing happens without one).
func burst(pos: Vector2, color: Color, count: int, speed: float = 250.0) -> void:
	var fx := get_tree().get_first_node_in_group("fx")
	if fx != null:
		fx.burst(pos, color, count, speed)


## An expanding ring, drawn by the FxLayer in the current scene.
func shockwave(pos: Vector2, from_r: float, to_r: float, color: Color, duration: float = 0.28) -> void:
	var fx := get_tree().get_first_node_in_group("fx")
	if fx != null:
		fx.shockwave(pos, from_r, to_r, color, duration)
