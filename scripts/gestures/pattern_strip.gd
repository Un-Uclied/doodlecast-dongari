extends Control

const CATALOG := preload("res://resources/patterns/catalog.tres")
var patterns: Array[StringName] = []:
	set(value):
		patterns = value
		queue_redraw()
var glyph_size := 24.0

func _draw() -> void:
	CATALOG.draw_sequence(self, patterns, size * 0.5, glyph_size)
