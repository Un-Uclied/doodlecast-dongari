class_name GestureRecognizer
extends RefCounted

const POINT_COUNT := 64

var configuration_error := ""
var _templates: Array[Dictionary] = []
var _ambiguity_margin := 0.035

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
			samples.append(normalized)
		_templates.append({"pattern": pattern, "samples": samples})

func recognize(points: PackedVector2Array, min_extent := 18.0) -> Dictionary:
	var result := {"pattern_id": &"", "candidate_id": &"", "display_name": "", "error": INF, "runner_up_error": INF, "reason": &"invalid_input"}
	if not configuration_error.is_empty():
		result.reason = &"invalid_catalog"
		return result
	var input := _normalize(points, min_extent)
	if input.is_empty():
		return result
	var closed_input := _normalize(points, min_extent, true)
	var best: PatternDefinition
	for entry in _templates:
		var candidate: PackedVector2Array = closed_input if entry.pattern.closed else input
		if candidate.is_empty():
			continue
		if entry.pattern.min_concavity > 0.0 and _concavity(candidate, entry.pattern.single_concavity) < entry.pattern.min_concavity:
			continue
		var error := INF
		for sample: PackedVector2Array in entry.samples:
			for offset in range(POINT_COUNT if entry.pattern.closed else 1):
				error = minf(error, _distance(candidate, sample, offset, false, entry.pattern.rotation_invariant))
				error = minf(error, _distance(candidate, sample, offset, true, entry.pattern.rotation_invariant))
		if error < result.error:
			result.runner_up_error = result.error
			result.error = error
			best = entry.pattern
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

func _concavity(points: PackedVector2Array, single_concavity := false) -> float:
	var hull := Geometry2D.convex_hull(points)
	if hull.size() < 3:
		return 0.0
	if hull[-1] != hull[0]:
		hull.append(hull[0])
	var deepest := 0.0
	var depths := PackedFloat32Array()
	for point in points:
		var nearest := INF
		for index in range(hull.size() - 1):
			var edge := hull[index + 1] - hull[index]
			var t := clampf((point - hull[index]).dot(edge) / maxf(0.000001, edge.length_squared()), 0.0, 1.0)
			nearest = minf(nearest, point.distance_to(hull[index] + edge * t))
		deepest = maxf(deepest, nearest)
		depths.append(nearest)
	if single_concavity:
		# Hearts have one notch; wide templates must not compete with five-notched stars.
		var threshold := maxf(0.025, deepest * 0.35)
		var regions := 0
		for index in range(depths.size()):
			if depths[index] > threshold and depths[(index + depths.size() - 1) % depths.size()] <= threshold:
				regions += 1
		if regions != 1:
			return 0.0
	return deepest

func _distance(input: PackedVector2Array, sample: PackedVector2Array, offset: int, reverse: bool, align_rotation: bool) -> float:
	var rotation := Transform2D.IDENTITY
	if align_rotation:
		var dot := 0.0
		var cross := 0.0
		for i in range(POINT_COUNT):
			var index := ((POINT_COUNT - 1 - i if reverse else i) + offset) % POINT_COUNT
			dot += input[index].dot(sample[i])
			cross += input[index].cross(sample[i])
		rotation = Transform2D(atan2(cross, dot), Vector2.ZERO)
	var error := 0.0
	for i in range(POINT_COUNT):
		var index := ((POINT_COUNT - 1 - i if reverse else i) + offset) % POINT_COUNT
		error += (rotation * input[index]).distance_to(sample[i])
	return error / POINT_COUNT

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
