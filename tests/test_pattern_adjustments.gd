extends Node

const WARNING := preload("res://scenes/effects/attack_telegraph.tscn")

func _ready() -> void:
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	get_tree().create_timer(20).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_adjustments")

func test_adjustments() -> void:
	var rules := preload("res://scripts/gameplay/level.gd").new()
	rules.rng.seed = 773
	var polygons := 0
	var total := 0
	for difficulty in range(1, 8):
		rules.difficulty = difficulty
		for trial in range(1000):
			for id in rules.generate_pattern():
				assert(id != &"heart", "No enemy difficulty may request the healing-only glyph")
				if difficulty == 2:
					total += 1
					if id in [&"square", &"triangle"]:
						polygons += 1
	rules.free()
	assert(float(polygons) / total < 0.22 and float(polygons) / total > 0.1)
	assert(&"spiral" in PatternCatalog.TIER_2 and not &"spiral" in PatternCatalog.TIER_3)
	var recognizer := GestureRecognizer.new(load("res://resources/patterns/catalog.tres"))
	for aspect in [Vector2(1, 1), Vector2(0.4, 1), Vector2(2, 1)]:
		for reverse in [false, true]:
			var diamond := PackedVector2Array()
			for point in [Vector2(0, -80), Vector2(60, 0), Vector2(0, 80), Vector2(-60, 0), Vector2(0, -80)]:
				diamond.append(point * aspect)
			if reverse:
				diamond.reverse()
			assert(recognizer.recognize(diamond).pattern_id == &"square", "Diamonds and stretched rhombi are the square spell")
	for rotation in [0.0, PI * 0.5]:
		var warning := WARNING.instantiate()
		warning.points = PackedVector2Array([Vector2(0, -12), Vector2(160, -12), Vector2(160, 12), Vector2(0, 12)])
		warning.position = Vector2(300, 300)
		warning.rotation = rotation
		warning.duration = 1
		add_child(warning)
		var material: ShaderMaterial = warning.get_node("Fill").material
		assert(material.get_shader_parameter("fill_center").is_equal_approx(Vector2(80, 0)))
		var charges := [0]
		warning.charged.connect(func(): charges[0] += 1)
		warning._physics_process(0.45)
		warning.set_physics_process(false)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var frame := get_viewport().get_texture().get_image()
			var transform: Transform2D = warning.get_global_transform_with_canvas()
			var center := frame.get_pixelv(Vector2i(transform * Vector2(80, 0)))
			var left := frame.get_pixelv(Vector2i(transform * Vector2(20, 0)))
			var right := frame.get_pixelv(Vector2i(transform * Vector2(140, 0)))
			assert(center.r > left.r + 0.15 and center.r > right.r + 0.15 and absf(left.r - right.r) < 0.02, "Warning must visibly grow from its own center in either orientation")
			if rotation == 0:
				assert(frame.save_png("res://.godot/warning-center-preview.png") == OK)
		warning._physics_process(0.55)
		assert(warning.progress == 1 and charges[0] == 1)
		warning.queue_free()
		await get_tree().process_frame
	print("PASS: no heart in all enemy tiers; box/triangle share %.1f%%; spiral tier 2; six diamond aliases; centered warning geometry, actual pixels and charge timing" % (100.0 * polygons / total))
	get_tree().quit()
