@tool
class_name RoomSkin
extends ThemeSkin
## Classic walled room: a flat floor inside a thick wall.

@export var floor_color := Color(0.19, 0.22, 0.31)
@export var wall_color := Color(0.55, 0.6, 0.8) # also the sparks when something hits it


func draw(room: BoxRoom) -> void:
	var rect := Rect2(-room.size * 0.5, room.size)
	room.draw_rect(rect, floor_color)
	room.draw_rect(rect.grow(7.0), wall_color, false, 14.0)
