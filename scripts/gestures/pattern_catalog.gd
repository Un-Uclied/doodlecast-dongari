class_name PatternCatalog
extends Resource

const TIER_1 := [&"horizontal", &"vertical"]
const INTERMEDIATE_PATTERNS := [&"chevron_up", &"chevron_down", &"spiral"]
const TIER_2 := INTERMEDIATE_PATTERNS + [&"square", &"triangle"]
const TIER_3 := [&"star"]
const COMBAT_POOL := TIER_1 + TIER_1 + INTERMEDIATE_PATTERNS + INTERMEDIATE_PATTERNS + [&"square", &"triangle"]
const GLYPH_SIZE := 10.0

@export var patterns: Array[PatternDefinition] = []
@export_range(0.0, 0.25, 0.005) var ambiguity_margin := 0.015

func sequence_rect(sequence: Array[StringName], center: Vector2, glyph_size := GLYPH_SIZE) -> Rect2:
	var size := Vector2(sequence.size() * (glyph_size + 4.0) + 4.0, glyph_size + 8.0)
	return Rect2(center - size * 0.5, size)

func draw_sequence(surface: CanvasItem, sequence: Array[StringName], center: Vector2, glyph_size := GLYPH_SIZE) -> void:
	if sequence.is_empty():
		return
	var pitch := glyph_size + 4.0
	var rect := sequence_rect(sequence, center, glyph_size)
	surface.draw_rect(rect, Color(0.045, 0.02, 0.065, 0.96))
	var active := Rect2(rect.position + Vector2(2, 1), Vector2(pitch, glyph_size + 6))
	surface.draw_rect(active, Color(0.3, 0.18, 0.04, 0.9))
	surface.draw_rect(active, Color(1.0, 0.86, 0.36), false, 1.2)
	var tip := Vector2(active.get_center().x, active.position.y - 2)
	surface.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-3, -4), tip + Vector2(3, -4)]), Color(1.0, 0.86, 0.36))
	for index in range(sequence.size()):
		for definition in patterns:
			if definition.id != sequence[index]:
				continue
			var sample: PackedVector2Array = definition.samples[0]
			var bounds := Rect2(sample[0], Vector2.ZERO)
			for point in sample:
				bounds = bounds.expand(point)
			var stroke := PackedVector2Array()
			var origin := Vector2(rect.position.x + 2 + pitch * (index + 0.5), center.y)
			for point in sample:
				stroke.append(origin + (point - bounds.get_center()) * glyph_size / maxf(bounds.size.x, bounds.size.y))
			surface.draw_polyline(stroke, Color(1.0, 0.9, 0.48) if index == 0 else Color(0.88, 0.77, 1.0), 1.0 if glyph_size < 20 else 2.0, true)
			break
