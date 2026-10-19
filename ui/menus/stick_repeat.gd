class_name StickRepeat
extends RefCounted
## A gamepad's left stick as menu steps, the way the d-pad gives them: one
## step per push past ON (it has to come back under OFF to step again), then,
## while it's held, a repeat every RATE seconds after DELAY. A menu feeds it
## every stick motion with motion() and calls repeats() once a frame.

const ON := 0.6
const OFF := 0.35
const DELAY := 0.45
const RATE := 0.12

var _dir := {} # "device:axis" -> -1, 0 or 1
var _wait := {} # "device:axis" -> seconds to the next repeat, while held


## The step a stick motion makes: "left", "right", "up", "down", or "" for none.
func motion(event: InputEventJoypadMotion) -> String:
	var key := "%d:%d" % [event.device, event.axis]
	var was: int = _dir.get(key, 0)
	var now := was
	if absf(event.axis_value) >= ON:
		now = 1 if event.axis_value > 0.0 else -1
	elif absf(event.axis_value) <= OFF:
		now = 0
	_dir[key] = now
	if now == 0:
		_wait.erase(key)
		return ""
	if now == was:
		return ""
	_wait[key] = DELAY
	return _step(event.axis, now)


## The repeats of sticks still held, `delta` seconds on: [[device, step], ...].
func repeats(delta: float) -> Array:
	var out: Array = []
	for key: String in _wait.keys():
		_wait[key] -= delta
		if _wait[key] <= 0.0:
			_wait[key] += RATE
			out.append([int(key.get_slice(":", 0)), _step(int(key.get_slice(":", 1)), _dir[key])])
	return out


static func _step(axis: int, dir: int) -> String:
	if axis == JOY_AXIS_LEFT_X:
		return "right" if dir > 0 else "left"
	return "down" if dir > 0 else "up"
