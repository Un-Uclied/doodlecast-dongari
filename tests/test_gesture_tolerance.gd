extends SceneTree

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): quit(1))
	call_deferred("test_tolerance")

func rough_stroke(vertices: PackedVector2Array, aspect: Vector2, angle: float) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for segment in range(vertices.size() - 1):
		for i in range(12):
			var t := float(i * i) / 144.0
			var point := vertices[segment].lerp(vertices[segment + 1], t)
			point += Vector2(sin(segment * 2.3 + i), cos(segment + i * 1.7)) * 0.009
			stroke.append((point * aspect).rotated(angle) * 200 + Vector2(320, 220))
	stroke.append((vertices[-1] * aspect).rotated(angle) * 200 + Vector2(320, 220))
	return stroke

func test_tolerance() -> void:
	var catalog := load("res://resources/patterns/catalog.tres") as PatternCatalog
	var recognizer := GestureRecognizer.new(catalog)
	var checks: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(0, 0.45), Vector2(0.22, 0.75), Vector2(1, 0)]),
		PackedVector2Array([Vector2(0, 0.35), Vector2(0.18, 0.62), Vector2(1, 0)]),
		PackedVector2Array([Vector2(0, 0.55), Vector2(0.3, 0.9), Vector2(1, 0)]),
		PackedVector2Array([Vector2(0, 0.5), Vector2(0.16, 0.72), Vector2(1, 0)])
	]
	for check in checks:
		for mirror_x in [-1, 1]:
			for mirror_y in [-1, 1]:
				for angle in [-0.2, 0.0, 0.2]:
					var stroke := rough_stroke(check, Vector2(mirror_x, mirror_y), angle)
					var expected := &"chevron_down" if mirror_y == 1 else &"chevron_up"
					var result := recognizer.recognize(stroke)
					assert(result.pattern_id == expected, "Uneven check arms, tilt and noise: %s, %s" % [expected, result])
					stroke.reverse()
					assert(recognizer.recognize(stroke).pattern_id == expected, "Checks must allow either drawing direction")
	var star := load("res://resources/patterns/star.tres") as PatternDefinition
	for aspect in [Vector2(0.65, 1), Vector2(1.4, 1)]:
		for gap in [0.0, 0.3, -0.12]:
			var vertices := star.samples[0].duplicate()
			for i in range(vertices.size() - 1):
				vertices[i] += Vector2(sin(i * 2.7), cos(i * 1.9)) * 0.045
			vertices[-1] = vertices[0].lerp(vertices[-2], gap)
			for degrees in range(0, 360, 15):
				var stroke := rough_stroke(vertices, aspect, deg_to_rad(degrees))
				var result := recognizer.recognize(stroke)
				assert(result.pattern_id == &"star", "Skewed, wobbly, unfinished/overshot star at %s degrees: %s" % [degrees, result])
				stroke.reverse()
				assert(recognizer.recognize(stroke).pattern_id == &"star", "Rough stars must allow either drawing direction")
	# Broadening the star tolerance must not turn missing edges or simple loops into spells.
	var incomplete := star.samples[0].duplicate()
	incomplete.resize(5)
	var unknowns: Array[PackedVector2Array] = [
		incomplete,
		PackedVector2Array([Vector2(0, 0), Vector2(0.5, 1), Vector2(1, 0), Vector2(0, 0)]),
		PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0)]),
		PackedVector2Array([Vector2(0, 0), Vector2(1, 1)]),
		PackedVector2Array([Vector2(0, 0), Vector2(0.3, 1), Vector2(0.6, 0), Vector2(1, 1)]),
		PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 0), Vector2(1, 0)])
	]
	var circle := PackedVector2Array()
	for i in range(65):
		circle.append(Vector2(cos(TAU * i / 64), sin(TAU * i / 64)))
	unknowns.append(circle)
	for vertices in unknowns:
		for angle in [0.0, 0.25]:
			var result := recognizer.recognize(rough_stroke(vertices, Vector2.ONE, angle))
			assert(result.pattern_id == &"", "Unrelated or incomplete shapes must remain rejected: %s" % result)
	print("PASS: 96 noisy/mirrored/reversed checks; 288 rotated, skewed, wobbly, unfinished/overshot stars; incomplete stars, circles, polygons, diagonals and scribbles rejected")
	quit()
