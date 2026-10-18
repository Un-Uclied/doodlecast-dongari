extends PanelContainer

const GOLD := Color(0.83, 0.64, 0.33)

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	for x in [0, 1]:
		for y in [0, 1]:
			var corner := Vector2(4 if x == 0 else size.x - 4, 4 if y == 0 else size.y - 4)
			var inward := Vector2(1 if x == 0 else -1, 1 if y == 0 else -1)
			draw_line(corner, corner + Vector2(inward.x * 12, 0), GOLD, 2.0)
			draw_line(corner, corner + Vector2(0, inward.y * 12), GOLD, 2.0)
			draw_rect(Rect2(corner + inward * 4 - Vector2.ONE, Vector2(2, 2)), GOLD)
	var center := Vector2(size.x * 0.5, 0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-4, 0), center + Vector2(0, -3), center + Vector2(4, 0), center + Vector2(0, 3)]), GOLD)
