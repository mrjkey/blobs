@tool
class_name NeonRoomSkin
extends RoomSkin
## Neon walled room: a see-through floor (the grid shows) and a glowing double wall.


func draw(room: BoxRoom) -> void:
	var rect := Rect2(-room.size * 0.5, room.size)
	room.draw_rect(rect, floor_color)
	room.draw_rect(rect.grow(6.0), NeonLook.hdr(wall_color, 1.4 + 0.4 * kick(room)), false, 4.0, true)
	room.draw_rect(rect.grow(-4.0), NeonLook.hdr(wall_color, 0.7, 0.4), false, 1.5, true)
