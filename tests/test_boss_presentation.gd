extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	get_tree().create_timer(35).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_presentation")

func ticks(count := 2) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png("res://.godot/boss-" + name + ".png") == OK)

func test_presentation() -> void:
	for mode in range(3):
		GameRun.begin_run(mode)
		var level = load("res://scenes/levels_%s/level_06.tscn" % GameRun.MODE_FOLDERS[mode]).instantiate()
		var original := {}
		for layer: TileMapLayer in level.find_children("*", "TileMapLayer", true, false):
			original[layer.name] = layer.tile_map_data.duplicate()
		var camera: Camera2D = level.get_node("Player/Camera2D")
		var original_zoom := camera.zoom
		var original_camera_position := camera.position
		var original_spawn: Vector2 = level.get_node("Player").position
		get_tree().root.add_child(level)
		level.set_process(false)
		while not level.navigation_ready:
			await ticks()
		for layer: TileMapLayer in level.find_children("*", "TileMapLayer", true, false):
			assert(layer.tile_map_data == original[layer.name], "Boss must preserve every difficulty-specific floor, wall, furnishing and pit")
		assert(level.player.position == original_spawn)
		assert(not camera.is_set_as_top_level() and camera.position == original_camera_position and camera.zoom == original_zoom and camera.position_smoothing_enabled)
		var boss_cell: Vector2i = level.tiles.local_to_map(level.tiles.to_local(level._center + Vector2(0, -3.5)))
		assert(boss_cell in level.walkable_cells, "The boss must start on reachable floor in the original map")
		level._process(level._intro.duration + 0.1)
		assert(level.state == level.State.READY and level.get_node("Projectiles").get_child_count() == 0)
		level._process(2.1)
		level._clear_attacks()
		await ticks()
		level.player.set_physics_process(false)
		level.player.practice_invulnerable = true
		level.player.global_position = level._center + Vector2(0, 64)
		camera.reset_smoothing()
		await ticks()
		assert(camera.global_position.is_equal_approx(level.player.global_position + original_camera_position), "Camera must follow the player")
		for label: Label in level.hud.find_children("*", "Label", true, false):
			assert(not label.text.contains("공격 타임!") and not label.text.contains("HP 100%"))
		level._attacks.assign([0])
		level._start_next_attack()
		assert(level._warning_sound.playing and level._cast_sparks.emitting)
		var hazards: Array = level.get_node("Projectiles").get_children().filter(func(node): return node.get_script() == preload("res://scripts/effects/boss_attack.gd") and not node.is_queued_for_deletion())
		assert(not hazards.is_empty())
		level._impact_left = 0
		level.player._shake_strength = 0
		for hazard in hazards:
			assert(not hazard.active and not hazard._sparks.emitting)
			assert(hazard._sparks.emission_shape == CPUParticles2D.EMISSION_SHAPE_POINTS)
			for point in hazard._sparks.emission_points:
				assert(Geometry2D.is_point_in_polygon(point, hazard.polygon))
			hazard._activate()
		assert(level._fire_sound.playing and is_equal_approx(level.player._shake_strength, 2.6), "An entire grid must share one impact sound and shake")
		assert(hazards.all(func(hazard): return hazard._sparks.emitting))
		await get_tree().create_timer(0.12).timeout
		if mode == 1:
			await capture("fire-impact")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var lit := get_viewport().get_texture().get_image()
				for hazard in hazards:
					hazard._sparks.hide()
				await RenderingServer.frame_post_draw
				var bare := get_viewport().get_texture().get_image()
				var changed := 0
				for y in range(130, 500):
					for x in range(64, 1088):
						if lit.get_pixel(x, y).r > bare.get_pixel(x, y).r + 0.03:
							changed += 1
				assert(changed > 20, "Fire embers must visibly render inside the attack fields")
		for hazard in hazards:
			hazard._physics_process(hazard.charge_duration + hazard.active_duration)
			assert(not hazard.active and not hazard._sparks.emitting and not hazard._flame.visible)
		level._clear_attacks()
		level._attacks.assign([3])
		level._start_next_attack()
		level._impact_left = 0
		level._update_attack(level.WARNING_SECONDS[mode] + 0.31)
		assert(level._rush_sound.playing and level.get_node("ProjectileSound").playing)
		level._update_attack(0.8)
		assert(level.boss.global_position.distance_to(level._dash_origin) < 1)
		level._begin_window()
		var previous_position: Vector2 = level.player.global_position
		for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			level.player.global_position = level.boss.to_global(level.boss.offset) + direction * 90.0
			level._face_player()
			var expected: String = "IdleN" if direction == Vector2.UP else ("IdleS" if direction == Vector2.DOWN else ("IdleW" if direction == Vector2.LEFT else "IdleE"))
			assert(level.boss.animation == expected)
		level.player.global_position = previous_position
		level._face_player()
		for id in level.attack_sequence.duplicate():
			level.canvas.gesture_finished.emit({"pattern_id": id}, 0, 1)
		assert(level.boss_health == level.MAX_BOSS_HEALTH - level.WINDOW_DAMAGE and level._health_bar.value == level.boss_health and level._health_trail.value == level.MAX_BOSS_HEALTH)
		assert(not level._health_bar.show_percentage and level._health_bar.modulate.r > 1 and level._health_root.scale == Vector2.ONE and level._hit_sound.playing)
		assert(level.player._shake_strength >= 6 and level.get_node("Effects").get_child_count() >= 7)
		await get_tree().create_timer(0.12).timeout
		if mode == 1:
			await capture("health-impact")
		var trail: float = level._health_trail.value
		get_tree().paused = true
		await get_tree().create_timer(0.2, true).timeout
		assert(level._health_trail.value == trail, "Pause must freeze the delayed health-bar damage")
		get_tree().paused = false
		await get_tree().create_timer(0.7).timeout
		assert(is_equal_approx(level._health_trail.value, level.boss_health) and level._health_root.scale.is_equal_approx(Vector2.ONE))
		assert(camera.offset == Vector2.ZERO)
		level._begin_window()
		if mode == 1:
			await capture("clean-window")
		level.finish_level(false)
		assert(not level._health_root.visible and not level._strip.visible and not level._timer.visible)
		assert(not level._warning_sound.playing and not level._fire_sound.playing and not level._rush_sound.playing)
		level.queue_free()
		await ticks()
	Music.stop()
	await get_tree().create_timer(0.2).timeout
	print("PASS: original maps/spawns and following cameras; native boss HUD, immediate damage, delayed trail, flash and pause; point-emitted fire particles, coalesced impact shake/audio, dash/volley/hit sound and cleanup")
	get_tree().quit()
