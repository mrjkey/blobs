extends Control
## PLAY ONLINE, from the main menu: host a game, or join one. Games hosted on
## this network show up on their own (LanDiscovery), games joined before are
## under RECENT (Session.recent_hosts; Delete or X forgets the focused one),
## and any address can be typed in. Once the host lets us in, the lobby
## opens. YOUR NAME is what the others see (Session.player_name).

@export_file("*.tscn") var main_menu_path: String
@export_file("*.tscn") var lobby_path: String
@export var row_scene: PackedScene # a Button: one game found or remembered
@export var max_recent := 4

var _found_shown := "" # what the found list shows, so it's rebuilt only when that changes

@onready var found: VBoxContainer = %Found
@onready var recent: VBoxContainer = %Recent


func _ready() -> void:
	%NameEdit.text = Session.player_name
	%NameEdit.placeholder_text = Session.computer_name()
	Net.joined.connect(_on_joined)
	Net.left.connect(_say)
	Net.search_lan(true)
	_build_recent()
	_refresh_found()
	_say(Net.last_error)
	Net.last_error = ""
	%HostButton.grab_focus()


func _exit_tree() -> void:
	Net.search_lan(false)


func _process(_delta: float) -> void:
	_refresh_found()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		return
	var forget: bool = (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_DELETE) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X)
	var focused := get_viewport().gui_get_focus_owner()
	if forget and focused != null and focused.get_parent() == recent:
		Session.forget_host(focused.get_meta("address"))
		_build_recent()
		%HostButton.grab_focus()
		get_viewport().set_input_as_handled()


func _say(text: String) -> void:
	%Status.text = text


func _on_name_edit_text_changed(text: String) -> void:
	Session.set_player_name(text if text.strip_edges() != "" else Session.computer_name())


func _on_host_button_pressed() -> void:
	var err := Net.host()
	if err != OK:
		_say("Couldn't host: port %d is taken. Is another copy of the game hosting?" % Net.PORT)
		return
	get_tree().change_scene_to_file(lobby_path)


func _on_join_button_pressed() -> void:
	_join(%AddressEdit.text)


func _on_address_edit_text_submitted(text: String) -> void:
	_join(text)


func _join(address: String) -> void:
	address = address.strip_edges()
	if address == "":
		_say("Type the host's address first, like 192.168.1.20")
		%AddressEdit.grab_focus()
		return
	var problem := Net.join(address)
	_say(problem if problem != "" else "Joining %s..." % address)


func _on_joined() -> void:
	get_tree().change_scene_to_file(lobby_path)


func _on_back_button_pressed() -> void:
	Net.leave()
	get_tree().change_scene_to_file(main_menu_path)


## The games on this network, rebuilt when the list changes (keeping the focus on the same game).
func _refresh_found() -> void:
	var games: Array = Net.discovery.found.values()
	games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.name < b.name)
	var lines := PackedStringArray()
	for g: Dictionary in games:
		lines.append("%s|%s" % [_address_of(g), _describe(g)])
	var shown := "\n".join(lines)
	if shown == _found_shown:
		return
	_found_shown = shown
	var focused := get_viewport().gui_get_focus_owner()
	var refocus: String = focused.get_meta("address") if focused != null and focused.get_parent() == found else ""
	for row in found.get_children():
		found.remove_child(row)
		row.queue_free()
	for g: Dictionary in games:
		var row := _add_row(found, _address_of(g), _describe(g))
		if row.get_meta("address") == refocus:
			row.grab_focus()
	if refocus != "" and get_viewport().gui_get_focus_owner() == null:
		%HostButton.grab_focus()
	%FoundEmpty.visible = games.is_empty()


func _build_recent() -> void:
	for row in recent.get_children():
		recent.remove_child(row)
		row.queue_free()
	for h: Variant in Session.recent_hosts.slice(0, max_recent):
		if h is Dictionary:
			_add_row(recent, str(h.get("address", "")), "%s   ·   %s" % [h.get("name", "?"), h.get("address", "")])
	%RecentHeading.visible = recent.get_child_count() > 0


func _add_row(list: VBoxContainer, address: String, text: String) -> Button:
	var row: Button = row_scene.instantiate()
	row.text = text
	row.set_meta("address", address)
	row.pressed.connect(_join.bind(address))
	list.add_child(row)
	return row


## What to join a found game at: its address, plus its port if that isn't the usual one.
func _address_of(g: Dictionary) -> String:
	return g.address if g.port == Net.PORT else "%s:%d" % [g.address, g.port]


func _describe(g: Dictionary) -> String:
	var doing: String = "in the lobby" if g.status == "" else "playing " + g.status
	var text := "%s   ·   %s   ·   %s" % [g.name, _address_of(g), doing]
	if g.computers > 1:
		text += ", %d computers" % g.computers
	if g.protocol != Net.PROTOCOL:
		text += "   (another version)"
	return text
