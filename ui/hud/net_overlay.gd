extends CanvasLayer
## The network overlay, toggled with F3 (Net adds it): who's connected and
## their pings, the host's clock, pretend lag and how many messages fly.

const REFRESH := 0.25

var _t := 0.0

@onready var text: Label = %Text


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = REFRESH
	text.text = Net.overlay_text()
