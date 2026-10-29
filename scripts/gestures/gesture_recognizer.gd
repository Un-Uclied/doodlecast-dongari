class_name GestureRecognizer
extends RefCounted

const POINT_COUNT := 64
const CLOUD_COUNT := 32

var configuration_error := ""
var _templates: Array[Dictionary] = []
var _ambiguity_margin := 0.015

func _init(catalog: PatternCatalog) -> void:
	if catalog == null or catalog.patterns.is_empty():
		configuration_error = "Pattern catalog is empty."
		return
	if not is_finite(catalog.ambiguity_margin) or catalog.ambiguity_margin < 0.0 or catalog.ambiguity_margin > 1.0:
		configuration_error = "Invalid ambiguity margin."
		return
	_ambiguity_margin = catalog.ambiguity_margin
	var ids := {}
	for pattern in catalog.patterns:
		if pattern == null or pattern.id == &"" or ids.has(pattern.id):
			configuration_error = "Pattern IDs must be nonempty and unique."
			return
		ids[pattern.id] = true
		if not is_finite(pattern.max_error) or pattern.max_error <= 0.0 or pattern.max_error > 1.0 or pattern.samples.is_empty() or not is_finite(pattern.min_concavity) or pattern.min_concavity < 0.0 or pattern.min_concavity > 0.3:
			configuration_error = "Invalid threshold or missing samples: %s" % pattern.id
			return
		var samples: Array[PackedVector2Array] = []
		for sample in pattern.samples:
			var normalized := _normalize(sample, 0.0001, pattern.closed)
			if normalized.is_empty():
				configuration_error = "Invalid sample: %s" % pattern.id
				return
			if pattern.id in [&"horizontal", &"vertical", &"chevron_up", &"chevron_down"]:
				normalized = _align_open(normalized, pattern.id)
			samples.append(_point_cloud(normalized, pattern.closed, pattern.id not in [&"horizontal", &"vertical"]))
		_templates.append({"pattern": pattern, "samples": samples})

func recognize(points: PackedVector2Array, min_extent := 18.0) -> Dictionary:
	var result := {"pattern_id": &"", "candidate_id": &"", "display_name": "", "error": INF, "runner_up_error": INF, "reason": &"invalid_input"}
	if not configuration_error.is_empty():
		result.reason = &"invalid_catalog"
		return result
	var input := _normalize(points, min_extent)
	if input.is_empty():
		return result
	var shape := _axis_shape(input)
	var simple := _simplify(shape, 0.045)
	var crossings := _crossings(simple)
	var winding := _winding(_simplify(shape, 0.018))
	var open_family: StringName = _open_family(input, shape, winding)
	var family := &""
	var body := PackedVector2Array()
	if open_family in [&"horizontal", &"vertical"]:
		family = open_family
	elif crossings >= 4 and _recess_info(input).depth >= 0.035:
		family = &"star"
	elif absf(winding.orbit) > 8.0 and _spiral_evidence(input, winding):
		family = &"spiral"
	else:
		body = _closed_body(input)
		if not body.is_empty():
			family = &"closed"
		else:
			family = open_family
	if family == &"":
		result.reason = &"no_match"
		return result
	var closed := family in [&"closed", &"star"]
	var stroke := body if family == &"closed" else input
	if family in [&"horizontal", &"vertical", &"chevron_up", &"chevron_down"]:
		stroke = _align_open(stroke, family)
	var recess := _recess_info(_axis_shape(stroke))
	var edges := _long_edges(_simplify(_axis_shape(stroke), 0.045))
	var oriented: Array[PackedVector2Array] = []
	for step in range(24 if closed or family == &"spiral" else 1):
		var rotated := PackedVector2Array()
		for point in stroke:
			rotated.append(point.rotated(TAU * step / 24.0))
		oriented.append(_point_cloud(rotated, closed, family not in [&"horizontal", &"vertical"]))
	var best: PatternDefinition
	for entry in _templates:
		var pattern: PatternDefinition = entry.pattern
		if not _eligible(pattern, family, recess, edges):
			continue
		var error := INF
		for sample: PackedVector2Array in entry.samples:
			error = minf(error, _cloud_error(oriented, sample, pattern.rotation_invariant))
			if error < 0.015:
				break
		if error < result.error:
			result.runner_up_error = result.error
			result.error = error
			best = pattern
		elif error < result.runner_up_error:
			result.runner_up_error = error
	if best == null:
		result.reason = &"no_match"
		return result
	result.candidate_id = best.id
	result.display_name = best.display_name
	if result.error > best.max_error:
		result.reason = &"no_match"
	elif result.runner_up_error - result.error < _ambiguity_margin:
		result.reason = &"ambiguous"
	else:
		result.pattern_id = best.id
		result.reason = &"recognized"
	return result

func _eligible(pattern: PatternDefinition, family: StringName, recess: Dictionary, edges: int) -> bool:
	if family != &"closed":
		return pattern.id == family
	if not pattern.closed:
		return false
	if recess.depth < pattern.min_concavity or (pattern.single_concavity and (recess.regions < 1 or recess.regions > 2)):
		return false
	match pattern.id:
		&"star":
			return recess.regions >= 3
		&"square":
			return edges <= 5
		&"triangle":
			return edges <= 4
	return true

func _align_open(points: PackedVector2Array, family: StringName) -> PackedVector2Array:
	var delta: Vector2 = points[-1] - points[0]
	if delta.length_squared() < 0.000001:
		return points
	var axis: float = PI * 0.5 if family == &"vertical" else (0.0 if delta.x >= 0.0 else PI)
	var correction: float = axis - delta.angle()
	var aligned := PackedVector2Array()
	for point in points:
		aligned.append(point.rotated(correction))
	return aligned

func _axis_shape(points: PackedVector2Array) -> PackedVector2Array:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var scale := Vector2(maxf(bounds.size.x, 0.08), maxf(bounds.size.y, 0.08))
	var output := PackedVector2Array()
	for point in points:
		output.append((point - bounds.get_center()) / scale)
	return output

func _point_cloud(points: PackedVector2Array, closed: bool, stretch: bool) -> PackedVector2Array:
	var path := _axis_shape(points) if stretch else points.duplicate()
	if closed and path[-1] != path[0]:
		path.append(path[0])
	var sampled := _normalize(path)
	var cloud := PackedVector2Array()
	for index in range(0, POINT_COUNT, 2):
		cloud.append(sampled[index])
	return cloud

func _cloud_error(oriented: Array[PackedVector2Array], sample: PackedVector2Array, rotate: bool) -> float:
	var best := INF
	var aligned := oriented[0]
	# Cheap coverage chooses orientation only; every class is scored with the same one-to-one assignment.
	for cloud in oriented:
		var distance := 0.0
		for index in range(0, CLOUD_COUNT, 2):
			var nearest := INF
			for other in range(CLOUD_COUNT):
				nearest = minf(nearest, cloud[index].distance_squared_to(sample[other]))
			distance += nearest
		if distance < best:
			best = distance
			aligned = cloud
		if not rotate:
			break
	return _assign(aligned, sample)

func _assign(input: PackedVector2Array, sample: PackedVector2Array) -> float:
	var costs := PackedFloat64Array()
	for point in input:
		for other in sample:
			costs.append(point.distance_to(other))
	var rows := PackedFloat64Array()
	var columns := PackedFloat64Array()
	var matched := PackedInt32Array()
	var previous := PackedInt32Array()
	rows.resize(CLOUD_COUNT + 1)
	columns.resize(CLOUD_COUNT + 1)
	matched.resize(CLOUD_COUNT + 1)
	previous.resize(CLOUD_COUNT + 1)
	# Minimum-cost bipartite assignment: each ink point gets one distinct template point.
	for row in range(1, CLOUD_COUNT + 1):
		matched[0] = row
		var column := 0
		var minimum := PackedFloat64Array()
		var used := PackedByteArray()
		minimum.resize(CLOUD_COUNT + 1)
		minimum.fill(INF)
		used.resize(CLOUD_COUNT + 1)
		while true:
			used[column] = 1
			var current := matched[column]
			var delta := INF
			var next := 0
			for other in range(1, CLOUD_COUNT + 1):
				if used[other]:
					continue
				var cost := costs[(current - 1) * CLOUD_COUNT + other - 1] - rows[current] - columns[other]
				if cost < minimum[other]:
					minimum[other] = cost
					previous[other] = column
				if minimum[other] < delta:
					delta = minimum[other]
					next = other
			for other in range(CLOUD_COUNT + 1):
				if used[other]:
					rows[matched[other]] += delta
					columns[other] -= delta
				else:
					minimum[other] -= delta
			column = next
			if matched[column] == 0:
				break
		while column != 0:
			var next := previous[column]
			matched[column] = matched[next]
			column = next
	return -columns[0] / CLOUD_COUNT

func _closed_body(points: PackedVector2Array) -> PackedVector2Array:
	var bounds := Rect2(points[0], Vector2.ZERO)
	var lengths := PackedFloat32Array([0.0])
	for index in range(1, points.size()):
		bounds = bounds.expand(points[index])
		lengths.append(lengths[-1] + points[index - 1].distance_to(points[index]))
	var best := PackedVector2Array()
	var best_area := 0.0
	for first in range(points.size() - 3):
		for last in range(first + 2, points.size() - 1):
			# A small incidental pen loop must not replace the shape's main body.
			if lengths[last + 1] - lengths[first] < lengths[-1] * 0.65:
				continue
			var hit = Geometry2D.segment_intersects_segment(points[first], points[first + 1], points[last], points[last + 1])
			if hit == null and (first < 3 or last >= points.size() - 4):
				var a := points[first]
				var b := points[first + 1]
				var c := points[last]
				var d := points[last + 1]
				for pair in [[a, Geometry2D.get_closest_point_to_segment(a, c, d)], [b, Geometry2D.get_closest_point_to_segment(b, c, d)], [Geometry2D.get_closest_point_to_segment(c, a, b), c], [Geometry2D.get_closest_point_to_segment(d, a, b), d]]:
					if pair[0].distance_to(pair[1]) < 0.035:
						hit = (pair[0] + pair[1]) * 0.5
						break
			if hit == null:
				continue
			var loop := PackedVector2Array([hit])
			loop.append_array(points.slice(first + 1, last + 1))
			loop.append(hit)
			var area := 0.0
			for index in range(loop.size() - 1):
				area += loop[index].cross(loop[index + 1])
			area = absf(area) * 0.5
			if area > best_area and area > bounds.get_area() * 0.25:
				best_area = area
				best = loop
	var shape := _axis_shape(points)
	if best.is_empty() and shape[0].distance_to(shape[-1]) < 0.35:
		best = points.duplicate()
		best.append(best[0])
	return _normalize(best) if not best.is_empty() else best

func _winding(points: PackedVector2Array) -> Dictionary:
	var orbit := 0.0
	var turn := 0.0
	var total := 0.0
	var largest := 0.0
	for index in range(points.size() - 1):
		orbit += points[index].angle_to(points[index + 1])
		if index > 0:
			var angle := (points[index] - points[index - 1]).angle_to(points[index + 1] - points[index])
			turn += angle
			total += absf(angle)
			largest = maxf(largest, absf(angle))
	return {"orbit": orbit, "turn": turn, "consistency": absf(turn) / maxf(total, 0.001), "largest": largest}

func _spiral_evidence(input: PackedVector2Array, winding: Dictionary) -> bool:
	return input[0].distance_to(input[-1]) > 0.18 and absf(winding.turn) > 4.8 and winding.consistency > 0.55 and winding.largest < 1.5

func _open_family(input: PackedVector2Array, shape: PackedVector2Array, winding: Dictionary) -> StringName:
	var length: float = 0.0
	var travel := Vector2.ZERO
	var deviation: float = 0.0
	var lengths := PackedFloat32Array([0.0])
	for index in range(1, input.size()):
		var movement: Vector2 = input[index] - input[index - 1]
		length += movement.length()
		travel += movement.abs()
		lengths.append(length)
	for point in input:
		deviation = maxf(deviation, point.distance_to(Geometry2D.get_closest_point_to_segment(point, input[0], input[-1])))
	var delta: Vector2 = input[-1] - input[0]
	# Preserve the mouse path's dominant axis before template comparison removes its tilt.
	if deviation < 0.075 and delta.length() / maxf(length, 0.001) > 0.84:
		if absf(delta.x) > absf(delta.y) * 1.25 and travel.x > travel.y * 1.15:
			return &"horizontal"
		if absf(delta.y) > absf(delta.x) * 1.25 and travel.y > travel.x * 1.15:
			return &"vertical"
	if _spiral_evidence(input, winding):
		return &"spiral"
	var x_travel: float = 0.0
	for index in range(1, shape.size()):
		x_travel += absf(shape[index].x - shape[index - 1].x)
	var span: float = shape[-1].x - shape[0].x
	if absf(span) <= 0.35 or absf(span) / maxf(x_travel, 0.001) <= 0.6:
		return &""
	var above: float = 0.0
	var below: float = 0.0
	var apex: int = 0
	var largest: float = 0.0
	for index in range(shape.size()):
		var height: float = lerpf(shape[0].y, shape[-1].y, (shape[index].x - shape[0].x) / span) - shape[index].y
		above = maxf(above, height)
		below = maxf(below, -height)
		if absf(height) > largest:
			largest = absf(height)
			apex = index
	if apex < 3 or apex >= input.size() - 3 or deviation < 0.09:
		return &""
	var first_arm: float = input[0].distance_to(input[apex]) / maxf(lengths[apex], 0.001)
	var second_arm: float = input[apex].distance_to(input[-1]) / maxf(length - lengths[apex], 0.001)
	if largest > 0.2 and minf(above, below) < largest * 0.35 and minf(first_arm, second_arm) > 0.72:
		return &"chevron_up" if above > below else &"chevron_down"
	return &""

func _long_edges(points: PackedVector2Array) -> int:
	var count := 0
	for index in range(points.size() - 1):
		if points[index].distance_to(points[index + 1]) > 0.28:
			count += 1
	return count

func _recess_info(points: PackedVector2Array) -> Dictionary:
	var hull := Geometry2D.convex_hull(points)
	var depths := PackedFloat32Array()
	var deepest := 0.0
	for point in points:
		var nearest := INF
		for index in range(hull.size() - 1):
			nearest = minf(nearest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, hull[index], hull[index + 1])))
		depths.append(nearest)
		deepest = maxf(deepest, nearest)
	var threshold := maxf(0.025, deepest * 0.35)
	var regions := 0
	for index in range(depths.size()):
		if depths[index] > threshold and depths[(index + depths.size() - 1) % depths.size()] <= threshold:
			regions += 1
	return {"depth": deepest, "regions": regions}

func _simplify(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() <= 2:
		return points
	var farthest := tolerance
	var split := -1
	for index in range(1, points.size() - 1):
		var distance := points[index].distance_to(Geometry2D.get_closest_point_to_segment(points[index], points[0], points[-1]))
		if distance > farthest:
			farthest = distance
			split = index
	if split < 0:
		return PackedVector2Array([points[0], points[-1]])
	var output := _simplify(points.slice(0, split + 1), tolerance)
	output.resize(output.size() - 1)
	output.append_array(_simplify(points.slice(split), tolerance))
	return output

func _crossings(points: PackedVector2Array) -> int:
	var count := 0
	for first in range(points.size() - 1):
		for second in range(first + 2, points.size() - 1):
			var hit = Geometry2D.segment_intersects_segment(points[first], points[first + 1], points[second], points[second + 1])
			if hit != null and hit.distance_to(points[first]) > 0.04 and hit.distance_to(points[first + 1]) > 0.04 and hit.distance_to(points[second]) > 0.04 and hit.distance_to(points[second + 1]) > 0.04:
				count += 1
	return count

func _normalize(points: PackedVector2Array, min_extent := 0.0001, closed := false) -> PackedVector2Array:
	var clean := PackedVector2Array()
	for point in points:
		if not point.is_finite():
			return PackedVector2Array()
		if clean.is_empty() or point.distance_squared_to(clean[-1]) > 0.000001:
			clean.append(point)
	if clean.size() < 2:
		return PackedVector2Array()
	var bounds := Rect2(clean[0], Vector2.ZERO)
	var total_length := 0.0
	for i in range(clean.size()):
		bounds = bounds.expand(clean[i])
		if i > 0:
			total_length += clean[i - 1].distance_to(clean[i])
	var extent := maxf(bounds.size.x, bounds.size.y)
	if extent < min_extent or not is_finite(total_length) or not is_finite(extent):
		return PackedVector2Array()
	if closed:
		var gap := clean[0].distance_to(clean[-1])
		if clean.size() < 3 or gap > extent * 0.45:
			return PackedVector2Array()
		if gap > 0.0:
			total_length += gap
			clean.append(clean[0])
	var normalized := PackedVector2Array()
	var centroid := Vector2.ZERO
	var segment := 1
	var walked := 0.0
	var segment_length := clean[0].distance_to(clean[1])
	for i in range(POINT_COUNT):
		var target := total_length * i / (POINT_COUNT if closed else POINT_COUNT - 1)
		while segment < clean.size() - 1 and walked + segment_length < target:
			walked += segment_length
			segment += 1
			segment_length = clean[segment - 1].distance_to(clean[segment])
		var weight := clampf((target - walked) / segment_length, 0.0, 1.0)
		var point := (clean[segment - 1].lerp(clean[segment], weight) - bounds.position) / extent
		normalized.append(point)
		centroid += point
	centroid /= POINT_COUNT
	for i in range(POINT_COUNT):
		normalized[i] -= centroid
	return normalized
