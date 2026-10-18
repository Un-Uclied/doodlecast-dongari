extends SceneTree

func _initialize() -> void:
	create_timer(10.0).timeout.connect(func(): quit(1))
	call_deferred("test_recognizer")

func test_recognizer() -> void:
	var catalog := load("res://resources/patterns/catalog.tres") as PatternCatalog
	assert(catalog.patterns.size() == 6)
	var recognizer := GestureRecognizer.new(catalog)
	assert(recognizer.configuration_error.is_empty(), recognizer.configuration_error)
	for pattern in catalog.patterns:
		var stroke := PackedVector2Array()
		for point in pattern.samples[0]:
			stroke.append(point * 150.0 + Vector2(300, 180))
		assert(recognizer.recognize(stroke).pattern_id == pattern.id, "Canonical: %s" % pattern.id)
		stroke.reverse()
		assert(recognizer.recognize(stroke).pattern_id == pattern.id, "Reversed: %s" % pattern.id)
		var dense := PackedVector2Array()
		for segment in range(stroke.size() - 1):
			for i in range(10):
				var point := stroke[segment].lerp(stroke[segment + 1], float(i * i) / 100.0)
				dense.append(point * 1.8 + Vector2(45, -70) + Vector2(sin(i) * 1.2, cos(i) * 1.2))
		dense.append(stroke[-1] * 1.8 + Vector2(45, -70))
		assert(recognizer.recognize(dense).pattern_id == pattern.id, "Size, position, speed, noise: %s" % pattern.id)
	for invalid in [PackedVector2Array(), PackedVector2Array([Vector2.ONE]), PackedVector2Array([Vector2.ONE, Vector2.ONE]), PackedVector2Array([Vector2.ZERO, Vector2(3, 0)]), PackedVector2Array([Vector2.ZERO, Vector2(NAN, 100)])]:
		assert(recognizer.recognize(invalid).pattern_id == &"", "Degenerate input must be rejected")
	var unknowns: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(100, 100), Vector2(250, 250)]),
		PackedVector2Array([Vector2(100, 100), Vector2(150, 200), Vector2(200, 100), Vector2(250, 200), Vector2(300, 100)])
	]
	var circle := PackedVector2Array()
	for i in range(65):
		circle.append(Vector2(cos(TAU * i / 64), sin(TAU * i / 64)) * 90 + Vector2(300, 300))
	unknowns.append(circle)
	for stroke in unknowns:
		assert(recognizer.recognize(stroke).pattern_id == &"", "Unregistered shape must be rejected")
	var star := load("res://resources/patterns/star.tres") as PatternDefinition
	var pentagram := star.samples[0]
	assert(star.samples.size() == 1 and pentagram.size() == 6 and pentagram[0] == pentagram[-1], "The icon and recognizer must share a closed five-line pentagram")
	var crossings := 0
	for first in range(pentagram.size() - 1):
		for second in range(first + 2, pentagram.size() - 1):
			if first == 0 and second == pentagram.size() - 2:
				continue
			if Geometry2D.segment_intersects_segment(pentagram[first], pentagram[first + 1], pentagram[second], pentagram[second + 1]) != null:
				crossings += 1
	assert(crossings == 5, "The displayed star must contain the pentagram's five interior crossings")
	var outline := PackedVector2Array()
	for point in PackedVector2Array([Vector2(0.5, 0), Vector2(0.617557, 0.338197), Vector2(0.975528, 0.345492), Vector2(0.690211, 0.561803), Vector2(0.793893, 0.904508), Vector2(0.5, 0.7), Vector2(0.206107, 0.904508), Vector2(0.309789, 0.561803), Vector2(0.024472, 0.345492), Vector2(0.382443, 0.338197), Vector2(0.5, 0)]):
		outline.append(point * 150.0 + Vector2(300, 180))
	assert(recognizer.recognize(outline).pattern_id == &"", "The previous hollow outline must no longer cast a star spell")
	outline.reverse()
	assert(recognizer.recognize(outline).pattern_id == &"", "The reversed hollow outline must also be rejected")
	for sample in star.samples:
		for start in range(sample.size() - 1):
			var stroke := PackedVector2Array()
			for i in range(sample.size() - 1):
				stroke.append(sample[(start + i) % (sample.size() - 1)].rotated(0.37) * 200 + Vector2(350, 250))
			stroke.append(stroke[0])
			assert(recognizer.recognize(stroke).pattern_id == &"star", "Star must allow different starting vertices and rotation")
		var mid_edge := sample[0].lerp(sample[1], 0.43)
		var stroke := PackedVector2Array([mid_edge * 200])
		for i in range(1, sample.size()):
			stroke.append(sample[i] * 200)
		stroke.append(mid_edge * 200)
		assert(recognizer.recognize(stroke).pattern_id == &"star", "Star may start halfway along an edge")
	for turns in [1.7, 2.2]:
		for direction in [-1, 1]:
			var stroke := PackedVector2Array()
			for i in range(101):
				var t := float(i) / 100
				var angle: float = direction * TAU * turns * t + 0.7
				stroke.append(Vector2(cos(angle), sin(angle)) * (0.05 + 0.45 * t) * 240 + Vector2(300, 300))
			assert(recognizer.recognize(stroke).pattern_id == &"spiral", "Spiral must allow either winding direction and rotation")
			stroke.reverse()
			assert(recognizer.recognize(stroke).pattern_id == &"spiral", "Spiral may be drawn inward or outward")
	var closed_only := PatternCatalog.new()
	closed_only.patterns = [star]
	assert(GestureRecognizer.new(closed_only).recognize(PackedVector2Array([Vector2.ZERO, Vector2(150, 0)])).pattern_id == &"", "Open input must be rejected when only closed patterns exist")
	var duplicate_samples := catalog.duplicate(true) as PatternCatalog
	duplicate_samples.patterns[0].samples.append(duplicate_samples.patterns[0].samples[0])
	assert(GestureRecognizer.new(duplicate_samples).recognize(PackedVector2Array([Vector2.ZERO, Vector2(150, 0)])).pattern_id == &"horizontal", "Runner-up must be a different pattern ID")
	var duplicate_ids := catalog.duplicate(true) as PatternCatalog
	duplicate_ids.patterns[1].id = duplicate_ids.patterns[0].id
	var invalid_recognizer := GestureRecognizer.new(duplicate_ids)
	assert(not invalid_recognizer.configuration_error.is_empty())
	assert(invalid_recognizer.recognize(PackedVector2Array([Vector2.ZERO, Vector2(150, 0)])).pattern_id == &"")
	print("PASS: six gestures, reverse strokes, translation/scale, uneven sampling/noise, pentagram icon and recognition, hollow star rejection, star start positions/rotation, spiral winding/rotation, invalid inputs, unknown shapes, catalog validation")
	quit()
