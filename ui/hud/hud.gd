class_name Hud
extends CanvasLayer
## On-screen text for a round: a status line (top left), a hint (bottom) and a
## big banner in the middle. Looks come from the theme on the Frame node.

const BANNER_FADE := 0.4 # seconds a timed banner takes to fade out

var _banner_life := -1.0

@onready var status: Label = %Status
@onready var hint: Label = %Hint
@onready var banner: Label = %Banner


func set_status(text: String) -> void:
	status.text = text


func set_hint(text: String) -> void:
	hint.text = text


## Show `text` in the middle. With `life` > 0 it fades out after that many
## seconds; otherwise it stays until replaced.
func show_banner(text: String, color: Color, life := -1.0) -> void:
	banner.text = text
	banner.modulate = color
	_banner_life = life


## Count 3, 2, 1 over `seconds` (with a pop on each number), then flash `go_text`.
## Await it: `await hud.play_countdown(2.4)`.
func play_countdown(seconds: float, go_text := "BUMP!") -> void:
	var left := seconds
	var shown := 0
	while left > 0.0:
		var n := ceili(left / (seconds / 3.0))
		if n != shown:
			shown = n
			Sfx.play("pop", 0.8 + 0.1 * (3 - n))
			show_banner(str(n), Color.WHITE)
		await get_tree().physics_frame
		left -= get_physics_process_delta_time() * Engine.time_scale
	show_banner(go_text, Color(1.0, 0.9, 0.4), 0.8)
	Sfx.play("pop", 0.6)


func _process(delta: float) -> void:
	if _banner_life > 0.0:
		_banner_life -= delta
		banner.modulate.a = clampf(_banner_life / BANNER_FADE, 0.0, 1.0)
		if _banner_life <= 0.0:
			banner.text = ""
