@tool
class_name FoodSkin
extends ThemeSkin
## Classic food: a round pellet with a soft halo and a shine. Pops in with an
## overshoot, then bobs.

@export var color := Color(1.0, 0.9, 0.35) # also the burst when it's eaten


func draw(food: Food) -> void:
	var pop := minf(food.age / 0.25, 1.0)
	var s := (1.0 + 0.4 * sin(pop * PI)) * pop
	var r := food.radius * s * (1.0 + 0.12 * sin(food.age * 6.0 + food.phase))
	food.draw_circle(Vector2.ZERO, r * 2.0, Color(color, 0.15))
	food.draw_circle(Vector2.ZERO, r, color)
	food.draw_circle(Vector2(-r, -r) * 0.3, r * 0.35, Color(1, 1, 1, 0.6))
