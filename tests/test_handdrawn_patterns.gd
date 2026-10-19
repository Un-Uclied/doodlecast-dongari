extends SceneTree

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(1))
	call_deferred("test_patterns")

func rough(points: PackedVector2Array, aspect: Vector2, size: float) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for index in range(points.size()):
		var point := points[index] * aspect
		point += Vector2(sin(index * 1.7), cos(index * 2.3)) * 0.012
		stroke.append(point.rotated(0.23) * size + Vector2(380, 280))
	return stroke

func rounded_heart(notch: float, start: int) -> PackedVector2Array:
	var outline := [Vector2(0, notch), Vector2(0.18, -0.5), Vector2(0.55, -0.5), Vector2(0.55, -0.12), Vector2(0.55, 0.1), Vector2(0.25, 0.32), Vector2(0, 0.5), Vector2(-0.25, 0.32), Vector2(-0.55, 0.1), Vector2(-0.55, -0.12), Vector2(-0.55, -0.5), Vector2(-0.18, -0.5), Vector2(0, notch)]
	var points := PackedVector2Array()
	for segment in range(4):
		for step in range(24):
			var i := segment * 3
			points.append(outline[i].bezier_interpolate(outline[i + 1], outline[i + 2], outline[i + 3], step / 24.0))
	var stroke := PackedVector2Array()
	for index in range(points.size() + 1):
		stroke.append(points[(index + start) % points.size()])
	return stroke

func test_patterns() -> void:
	var catalog = load("res://resources/patterns/catalog.tres")
	var recognizer := GestureRecognizer.new(catalog)
	var count := 0
	for shape in [&"star", &"heart"]:
		var pattern = load("res://resources/patterns/%s.tres" % shape)
		for sample: PackedVector2Array in pattern.samples:
			for aspect in [Vector2(0.7, 1), Vector2(1.35, 1)]:
				for size in [48.0, 160.0]:
					var stroke := rough(sample, aspect, size)
					assert(recognizer.recognize(stroke).pattern_id == shape, "Small, uneven hand-drawn %s: %s" % [shape, recognizer.recognize(stroke)])
					stroke.reverse()
					assert(recognizer.recognize(stroke).pattern_id == shape)
					count += 2
	# Independently drawn curves, rather than stretched copies of a recognition template.
	for notch in [-0.18, -0.28]:
		for start in [0, 37]:
			for width in [1.6, 2.2]:
				for size in [48.0, 160.0]:
					var stroke := rough(rounded_heart(notch, start), Vector2(width, 1), size)
					assert(recognizer.recognize(stroke).pattern_id == &"heart", "Wide, round heart with a shallow notch: %s" % recognizer.recognize(stroke))
					stroke.reverse()
					assert(recognizer.recognize(stroke).pattern_id == &"heart")
					count += 2
	for aspect in [Vector2.ONE, Vector2(2.2, 1)]:
		var ellipse := PackedVector2Array()
		for step in range(97):
			ellipse.append(Vector2.from_angle(TAU * step / 96.0) * aspect * 60.0)
		assert(recognizer.recognize(ellipse).pattern_id == &"", "A circle or wide ellipse must not become a heart")
	for polygon in [PackedVector2Array([Vector2(0, -50), Vector2(75, 50), Vector2(-75, 50), Vector2(0, -50)]), PackedVector2Array([Vector2(-75, -50), Vector2(75, -50), Vector2(75, 50), Vector2(-75, 50), Vector2(-75, -50)])]:
		assert(recognizer.recognize(polygon).pattern_id != &"heart", "A triangle or box must not become a heart")
	for turns in [1.0, 1.25, 1.75, 2.4, 3.0]:
		for direction in [-1, 1]:
			for exponent in [0.75, 1.35]:
				var points := PackedVector2Array()
				for index in range(121):
					var t := index / 120.0
					points.append(Vector2.from_angle(direction * TAU * turns * t + 0.6) * (0.04 + 0.46 * pow(t, exponent)))
				var stroke := rough(points, Vector2(1.25, 1), 160.0)
				assert(recognizer.recognize(stroke).pattern_id == &"spiral", "Variable winding, hand speed and radius: %s turns, %s" % [turns, recognizer.recognize(stroke)])
				stroke.reverse()
				assert(recognizer.recognize(stroke).pattern_id == &"spiral")
				count += 2
	print("PASS: %d hand-drawn star/heart/spiral variants including independent wide/round/shallow-notched hearts, arbitrary starts, small strokes, aspect distortion, both star styles, 1–3 turns, either direction and noise; circles/ellipses/polygons excluded from hearts" % count)
	quit()
