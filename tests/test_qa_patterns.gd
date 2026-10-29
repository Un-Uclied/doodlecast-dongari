extends SceneTree

func _initialize() -> void:
	create_timer(15).timeout.connect(func(): quit(1))
	var recognizer := GestureRecognizer.new(load("res://resources/patterns/catalog.tres"))
	assert(recognizer.configuration_error.is_empty())
	# Independently traced from the QA attachment, including overlapping joins and long overshoots.
	var cases := {
		&"chevron_up": [
			PackedVector2Array([Vector2(63,187),Vector2(123,124),Vector2(134,163),Vector2(147,188)]),
			PackedVector2Array([Vector2(204,188),Vector2(227,132),Vector2(263,24),Vector2(266,120),Vector2(275,190)]),
			PackedVector2Array([Vector2(314,192),Vector2(366,176),Vector2(420,151),Vector2(458,137),Vector2(492,149),Vector2(547,173),Vector2(594,188),Vector2(612,188)]),
			PackedVector2Array([Vector2(652,190),Vector2(670,160),Vector2(686,183)]),
			PackedVector2Array([Vector2(732,178),Vector2(760,160),Vector2(790,133),Vector2(831,101),Vector2(879,136),Vector2(921,180)]),
			PackedVector2Array([Vector2(949,181),Vector2(961,155),Vector2(978,35),Vector2(989,92),Vector2(998,185)])],
		&"heart": [
			PackedVector2Array([Vector2(97,322),Vector2(107,305),Vector2(137,296),Vector2(163,307),Vector2(178,324),Vector2(177,340),Vector2(158,358),Vector2(132,369),Vector2(101,368),Vector2(86,341),Vector2(81,314),Vector2(85,293),Vector2(92,284),Vector2(108,292),Vector2(128,319)]),
			PackedVector2Array([Vector2(373,345),Vector2(358,319),Vector2(340,285),Vector2(333,283),Vector2(323,303),Vector2(320,348),Vector2(325,379),Vector2(343,406),Vector2(360,411),Vector2(382,401),Vector2(407,368),Vector2(421,325),Vector2(422,293),Vector2(416,282),Vector2(399,292),Vector2(366,332)]),
			PackedVector2Array([Vector2(625,269),Vector2(607,257),Vector2(586,257),Vector2(572,268),Vector2(568,287),Vector2(577,302),Vector2(611,321),Vector2(635,365),Vector2(649,334),Vector2(680,310),Vector2(702,281),Vector2(708,254),Vector2(702,240),Vector2(680,234),Vector2(658,241),Vector2(637,261),Vector2(622,279)]),
			PackedVector2Array([Vector2(866,314),Vector2(857,294),Vector2(844,276),Vector2(833,277),Vector2(817,293),Vector2(811,317),Vector2(815,343),Vector2(837,370),Vector2(863,379),Vector2(894,375),Vector2(922,355),Vector2(940,324),Vector2(941,305),Vector2(933,292),Vector2(907,291),Vector2(884,299),Vector2(864,312),Vector2(870,301)]),
			PackedVector2Array([Vector2(1104,345),Vector2(1092,312),Vector2(1069,267),Vector2(1047,244),Vector2(1036,242),Vector2(1023,270),Vector2(1012,320),Vector2(1012,365),Vector2(1022,404),Vector2(1038,422),Vector2(1067,420),Vector2(1102,401),Vector2(1134,363),Vector2(1149,312),Vector2(1153,264),Vector2(1149,259),Vector2(1133,283),Vector2(1114,306),Vector2(1093,337),Vector2(1080,357)])],
		&"star": [
			PackedVector2Array([Vector2(49,459),Vector2(100,541),Vector2(135,463),Vector2(5,501),Vector2(212,512),Vector2(27,472)]),
			PackedVector2Array([Vector2(313,443),Vector2(334,509),Vector2(300,580),Vector2(413,445),Vector2(246,511),Vector2(466,529),Vector2(302,468)]),
			PackedVector2Array([Vector2(577,443),Vector2(594,484),Vector2(597,573),Vector2(701,465),Vector2(793,457),Vector2(461,501),Vector2(775,506),Vector2(591,459)]),
			PackedVector2Array([Vector2(973,430),Vector2(1189,535),Vector2(815,490),Vector2(1239,429),Vector2(971,568),Vector2(957,477)])]
	}
	var count := 0
	for id in cases:
		for vertices: PackedVector2Array in cases[id]:
			for reverse in [false, true]:
				var points := vertices.duplicate()
				if reverse:
					points.reverse()
				var result := recognizer.recognize(points)
				assert(result.pattern_id == id, "QA attachment %s case %d: %s" % [id, count, result])
				count += 1
	for id in [&"square", &"triangle"]:
		var sample: PackedVector2Array = load("res://resources/patterns/%s.tres" % id).samples[0]
		for aspect in [Vector2(0.4, 1), Vector2(2.7, 1)]:
			var points := PackedVector2Array()
			for point in sample:
				points.append((point * aspect).rotated(0.32) * 100)
			var result := recognizer.recognize(points)
			assert(result.pattern_id == id, "Distorted polygon %s: %s" % [id, result])
	var rounded_box := PackedVector2Array()
	for index in range(4):
		var center: Vector2 = [Vector2(0.85, 0.15), Vector2(0.85, 0.85), Vector2(0.15, 0.85), Vector2(0.15, 0.15)][index]
		for step in range(17):
			rounded_box.append((center + Vector2.from_angle(-PI * 0.5 + index * PI * 0.5 + step * PI / 32) * 0.15) * 100)
	rounded_box.append(rounded_box[0])
	assert(recognizer.recognize(rounded_box).pattern_id == &"square", "Rounded corners must still form a square: %s" % recognizer.recognize(rounded_box))
	print("PASS: %d independently traced QA strokes in either direction, new distorted squares/triangles" % count)
	quit()
