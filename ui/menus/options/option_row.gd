class_name OptionRow
extends Button
## One row of an OptionList: a setting's name and its current value.
## Click, Enter, right or D for the next value; left or A for the previous one.

signal changed(row: OptionRow)

var _option := {}
var _index := 0


## `option` is one entry of GameSettings.OPTIONS; `current` the chosen id.
func setup(option: Dictionary, current: String) -> void:
	_option = option
	_index = 0
	for i in option.choices.size():
		if option.choices[i][0] == current:
			_index = i
	_refresh()


func key() -> String:
	return _option.key


func id() -> String:
	return _option.choices[_index][0]


func help_text() -> String:
	return _option.choices[_index][2]


func _pressed() -> void:
	step(1)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right") or _is_key(event, KEY_D):
		step(1)
		accept_event()
	elif event.is_action_pressed("ui_left") or _is_key(event, KEY_A):
		step(-1)
		accept_event()


func step(by: int) -> void:
	_index = posmod(_index + by, _option.choices.size())
	_refresh()
	changed.emit(self)


func _refresh() -> void:
	text = "%s:   <  %s  >" % [_option.label, _option.choices[_index][1]]


func _is_key(event: InputEvent, k: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == k
