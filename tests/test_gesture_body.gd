extends SceneTree

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	var recognizer := GestureRecognizer.new(load("res://resources/patterns/catalog.tres"))
	var cases := {
		&"square": [
			PackedVector2Array([Vector2(57,94), Vector2(298,94), Vector2(298,243), Vector2(115,239), Vector2(121,44)]),
			PackedVector2Array([Vector2(120,44), Vector2(115,239), Vector2(298,243), Vector2(298,94), Vector2(57,94)])],
		&"triangle": [
			PackedVector2Array([Vector2(148,329), Vector2(337,467), Vector2(123,456), Vector2(184,350), Vector2(196,317)]),
			PackedVector2Array([Vector2(196,317), Vector2(184,350), Vector2(123,456), Vector2(337,467), Vector2(148,329)])]
	}
	var count := 0
	var timings: Array[int] = []
	for id in cases:
		for stroke: PackedVector2Array in cases[id]:
			for angle in [0.0, 0.23, 1.1, 2.5]:
				var points := PackedVector2Array()
				for point in stroke:
					points.append(point.rotated(angle))
				var started := Time.get_ticks_usec()
				var result := recognizer.recognize(points)
				timings.append(Time.get_ticks_usec() - started)
				assert(result.pattern_id == id, "Overshooting %s must not become heart: %s" % [id, result])
				count += 1
	for id in [&"square", &"triangle"]:
		var polygon: PackedVector2Array = load("res://resources/patterns/%s.tres" % id).samples[0]
		var size := polygon.size() - 1
		for start in range(size):
			for tail in [0.1, 0.25]:
				var vertices := PackedVector2Array()
				var first := polygon[start]
				vertices.append(first - (polygon[(start + 1) % size] - first) * tail)
				for step in range(1, size):
					vertices.append(polygon[(start + step) % size])
				vertices.append(first + (first - polygon[(start + size - 1) % size]) * tail)
				for aspect in [Vector2(0.5, 1), Vector2(2, 1)]:
					for angle in [0.0, 0.3, 1.2]:
						for reverse in [false, true]:
							var points := PackedVector2Array()
							for index in range(vertices.size()):
								var jitter := Vector2(sin(index * 2.3), cos(index * 1.7)) * 0.005
								points.append(((vertices[index] + jitter) * aspect).rotated(angle) * 180 + Vector2(350, 230))
							if reverse:
								points.reverse()
							var started := Time.get_ticks_usec()
							var result := recognizer.recognize(points)
							timings.append(Time.get_ticks_usec() - started)
							assert(result.pattern_id == id, "Body with varied join/size/tilt/noise %s: %s" % [id, result])
							count += 1
	timings.sort()
	print("PASS: %d crossed-join polygons: attachment, every starting corner, tails, distortion, rotation, reversal and noise; median %.2fms, p95 %.2fms" % [count, timings[timings.size() / 2] / 1000.0, timings[int(timings.size() * 0.95)] / 1000.0])
	quit()
