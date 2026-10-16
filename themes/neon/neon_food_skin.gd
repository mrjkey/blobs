@tool
class_name NeonFoodSkin
extends FoodSkin
## Neon food: a spinning diamond that swells a little on each kick drum.


func draw(food: Food) -> void:
	var pop := minf(food.age / 0.25, 1.0)
	var r := food.radius * (1.0 + 0.4 * sin(pop * PI)) * pop * (1.3 + 0.2 * kick(food))
	var pts := PackedVector2Array()
	for j in 4:
		pts.append(Vector2.from_angle(food.age * 2.0 + food.phase + j * PI / 2.0) * r)
	var outline := pts.duplicate()
	outline.append(pts[0])
	food.draw_colored_polygon(pts, NeonLook.hdr(color, 0.5, 0.5))
	food.draw_polyline(outline, NeonLook.hdr(color, 2.5), 2.0, true)
