class_name OptionList
extends VBoxContainer
## One OptionRow per entry of GameSettings.OPTIONS shown in `context`, with
## a `header_scene` label over each group of them (an option's `group`) when
## one is set. Changing a row saves and applies it right away. Used by the
## settings menu ("menu") and the sandbox lab ("lab").

signal changed

@export var row_scene: PackedScene
@export_enum("menu", "lab") var context := "menu" # options marked `only` for the other one are left out
@export var help: Label # describes the focused row's current choice
@export var header_scene: PackedScene # a Label over each group; none: no headings


func _ready() -> void:
	var group := ""
	for o: Dictionary in GameSettings.OPTIONS:
		if o.get("only", context) != context:
			continue
		if header_scene != null and o.get("group", group) != group:
			group = o.group
			var header: Label = header_scene.instantiate()
			header.text = group
			add_child(header)
		var row: OptionRow = row_scene.instantiate()
		row.setup(o, GameSettings.choice(o.key))
		row.changed.connect(_on_row_changed)
		row.focus_entered.connect(_show_help.bind(row))
		add_child(row)


func focus_first() -> void:
	for row in get_children():
		if row is OptionRow:
			row.grab_focus()
			_show_help(row)
			return


func _on_row_changed(row: OptionRow) -> void:
	GameSettings.set_choice(row.key(), row.id())
	_show_help(row)
	changed.emit()


func _show_help(row: OptionRow) -> void:
	if help != null:
		help.text = row.help_text()
