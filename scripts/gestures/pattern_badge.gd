extends Node2D

const CATALOG := preload("res://resources/patterns/catalog.tres")

func _ready() -> void:
	var ink := CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = ink
	z_index = 3

func _draw() -> void:
	CATALOG.draw_sequence(self, get_parent().pattern, Vector2.ZERO)

func local_rect() -> Rect2:
	return CATALOG.sequence_rect(get_parent().pattern, Vector2.ZERO)
