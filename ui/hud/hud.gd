class_name Hud
extends CanvasLayer
## On-screen text for a round: a status line (top left), a hint (bottom), a
## big banner in the middle and a scoreboard (top centre, team modes). The text style is the current theme's `hud`.

signal countdown_finished

const BANNER_FADE := 0.4 # seconds a timed banner takes to fade out

var _banner_life := -1.0
var _count_left := 0.0 # > 0 while a countdown runs
var _count_total := 0.0
var _count_shown := 0
var _go_text := ""

@onready var status: Label = %Status
@onready var hint: Label = %Hint
@onready var banner: Label = %Banner
@onready var score: ScoreBar = %Score


func _ready() -> void:
	$Frame.theme = GameTheme.current().hud


func set_status(text: String) -> void:
	status.text = text


func set_hint(text: String) -> void:
	hint.text = text


## The scoreboard: pieces of text with their colours, [[text, colour], ...]. [] hides it.
func set_score(pieces: Array) -> void:
	if pieces != score.pieces:
		score.pieces = pieces
		score.queue_redraw()


## Show `text` in the middle. With `life` > 0 it fades out after that many
## seconds; otherwise it stays until replaced.
func show_banner(text: String, color: Color, life := -1.0) -> void:
	banner.text = text
	banner.modulate = color
	_banner_life = life


## Count 3, 2, 1 over `seconds` (with a pop on each number), then flash `go_text`.
## Returns `countdown_finished`, so it can be awaited: `await hud.play_countdown(2.4)`.
## Runs from _physics_process, so leaving the scene mid-count just stops it.
func play_countdown(seconds: float, go_text := "BUMP!") -> Signal:
	_count_total = seconds
	_count_left = seconds
	_count_shown = 0
	_go_text = go_text
	_show_count()
	return countdown_finished


func _physics_process(delta: float) -> void:
	if _count_left <= 0.0:
		return
	_count_left -= delta
	if _count_left > 0.0:
		_show_count()
		return
	show_banner(_go_text, Color(1.0, 0.9, 0.4), 0.8)
	Sfx.play("pop", 0.6)
	countdown_finished.emit()


func _show_count() -> void:
	var n := ceili(_count_left / (_count_total / 3.0))
	if n != _count_shown:
		_count_shown = n
		Sfx.play("pop", 0.8 + 0.1 * (3 - n))
		show_banner(str(n), Color.WHITE)


func _process(delta: float) -> void:
	if _banner_life > 0.0:
		_banner_life -= delta
		banner.modulate.a = clampf(_banner_life / BANNER_FADE, 0.0, 1.0)
		if _banner_life <= 0.0:
			banner.text = ""
