extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	get_tree().create_timer(25.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_heart")

func ticks(count := 1) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func draw_heart(canvas: Control) -> void:
	var sample: PackedVector2Array = load("res://resources/patterns/heart.tres").samples[0]
	var stroke := PackedVector2Array()
	for point in sample:
		stroke.append(point * Vector2(1.8, 1.0) * 48.0 + Vector2(510, 260))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = stroke[0]
	get_tree().root.push_input(event, true)
	assert(canvas.drawing)
	for point in stroke:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = point
		get_tree().root.push_input(motion, true)
	event = event.duplicate()
	event.pressed = false
	event.position = stroke[-1]
	get_tree().root.push_input(event, true)
	assert(canvas.last_result.pattern_id == &"heart")

func test_heart() -> void:
	GameRun.begin_run(GameRun.Mode.EASY)
	var level = load(GameRun.level_path()).instantiate()
	level.get_node("Player/Camera2D").position_smoothing_enabled = false
	get_tree().root.add_child(level)
	level.set_process(false)
	level.player.set_physics_process(false)
	level._spawn_time_left = 10000.0
	while not level.navigation_ready:
		await ticks()
	assert(level.player.take_damage() and GameRun.hits_taken == 1)
	var scheduled: float = level._heart_delay
	assert(not level.player.take_damage() and GameRun.hits_taken == 1 and level._heart_delay == scheduled, "Invulnerability must not reroll heart drops or inflate hit counts")
	level.spawned = 5
	level._combat_seconds = 10.0
	var previous_rate := 0
	for hp in [4, 3, 2]:
		var successes := 0
		level.rng.seed = 1729
		for attempt in range(1000):
			level._heart_delay = -1.0
			level._schedule_heart(hp)
			if level._heart_delay >= 0.0:
				successes += 1
				assert(level._heart_delay >= 3.0 and level._heart_delay <= 6.0)
		assert(successes > previous_rate + 100, "Lower HP must materially increase drop probability")
		previous_rate = successes
	level._heart_delay = 0.0
	level._combat_seconds = 2.0
	level._update_heart_drop(0.0)
	assert(level._heart == null, "Drops must never appear in the first eight seconds")
	level._combat_seconds = 10.0
	level.spawned = 1
	level._update_heart_drop(0.0)
	assert(level._heart == null, "Drops must wait for the early combat phase to finish")
	level.spawned = 12
	level._update_heart_drop(0.0)
	assert(level._heart_delay < 0.0 and level._heart == null, "A pending drop must be cancelled in the final cleanup phase")
	level._schedule_heart(2)
	assert(level._heart_delay < 0.0, "Late hits must not schedule another drop")
	level.spawned = 5
	level._heart_delay = 4.0
	level.set_process(true)
	level._toggle_pause()
	var elapsed: float = level._combat_seconds
	await get_tree().create_timer(0.12).timeout
	assert(level._heart_delay == 4.0 and level._combat_seconds == elapsed, "Pause must freeze combat eligibility and drop delay")
	level._toggle_pause()
	await get_tree().create_timer(0.12).timeout
	assert(level._heart_delay < 4.0)
	level.set_process(false)
	level._heart_delay = 0.0
	level._update_heart_drop(0.0)
	var heart: Node2D = level._heart
	assert(is_instance_valid(heart) and level._heart_spawned and level.get_node("Pickups").get_child_count() == 1)
	var distance := heart.global_position.distance_to(level.player.global_position)
	assert(distance >= 24.0 and distance <= 96.0)
	var cell: Vector2i = level.tiles.local_to_map(level.tiles.to_local(heart.global_position + Vector2(0, -3.5)))
	assert(cell in level.walkable_cells and not level.grid.is_point_solid(cell), "The heart must spawn near the player on reachable, collision-free floor")
	var sprite: AnimatedSprite2D = heart.get_node("Sprite")
	assert(sprite.is_playing() and sprite.sprite_frames.get_frame_count("idle") == 10)
	assert(sprite.sprite_frames.get_frame_texture("idle", 5).atlas.get_size() == Vector2(192, 32))
	assert(heart.get_node("Light").energy > 0.0 and heart.find_children("*", "Area2D").is_empty())
	assert(heart.find_children("*", "Label").is_empty(), "The pickup must show a pattern badge instead of a text instruction")
	var icon: Line2D = heart.get_node("Pattern/Icon")
	assert(icon.points.size() >= 32 and icon.points[0].is_equal_approx(icon.points[-1]))
	var icon_bounds := Rect2(icon.points[0], Vector2.ZERO)
	for point in icon.points:
		icon_bounds = icon_bounds.expand(point)
	assert(icon_bounds.get_center().is_equal_approx(Vector2.ZERO) and is_equal_approx(icon_bounds.size.x, 9.0), "The heart glyph must match the enemies' centered 9px pattern style")
	await ticks(14)
	assert(sprite.frame != 0, "The golden-heart sheet must actually animate")
	await preview_heart(level, heart)
	level.player.global_position = heart.global_position
	var hp: int = level.player.health
	await ticks(3)
	assert(level.player.health == hp and is_instance_valid(level._heart), "Touching the heart must not collect it")
	level.canvas.gesture_finished.emit({"pattern_id": &"star"}, 0, 1)
	assert(is_instance_valid(level._heart) and level.player.health == hp)
	level.player.health = 5
	GameRun.health = 5
	level.canvas.gesture_finished.emit({"pattern_id": &"heart"}, 0, 1)
	assert(is_instance_valid(level._heart) and level.player.health == 5, "Full health must not waste the item")
	level.player.health = 2
	GameRun.health = 2
	var hits := GameRun.hits_taken
	var score := GameRun.combat_score
	draw_heart(level.canvas)
	assert(level._heart == null and level.player.health == 3 and GameRun.health == 3)
	assert(GameRun.hits_taken == hits and GameRun.ranking_result(false).hits == hits, "Healing must not erase previously recorded hits")
	assert(GameRun.combat_score == score and level.get_node("Effects").get_child_count() == 1)
	assert(level.hud.get_node("%FeedbackText").text == "체력 +1" and level.get_node("MagicSuccessSound").playing)
	level._schedule_heart(1)
	assert(level._heart_delay < 0.0, "Only one heart may spawn per level, including after collection")
	if DisplayServer.get_name() != "headless":
		await ticks(6)
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png("res://.godot/heal-burst-preview.png") == OK)
	assert(level.player.heal(100) == 2 and level.player.health == 5 and level.player.heal(1) == 0)
	await get_tree().create_timer(0.75).timeout
	assert(level.get_node("Effects").get_child_count() == 0)
	level._heart_delay = 2.0
	level.finish_level(false)
	assert(level._heart_delay < 0.0 and level._heart == null)
	level.queue_free()
	await ticks(2)
	await test_critical_drop()
	print("PASS: health-dependent drop odds, random 3–6s delay, eight-second/progress window, pause/late cancellation, one nearby safe-floor animated glowing heart, no touch/wrong-pattern pickup, real 48px heart mouse gesture heals once, full-health cap, accurate cumulative hits, healing FX and cleanup")
	get_tree().quit()

func test_critical_drop() -> void:
	for phase in [&"early", &"late", &"entry"]:
		var late: bool = phase == &"late"
		GameRun.begin_run(GameRun.Mode.EASY)
		if phase == &"entry":
			GameRun.health = 1
		var level = load(GameRun.level_path()).instantiate()
		get_tree().root.add_child(level)
		level.set_process(false)
		level.player.set_physics_process(false)
		level._spawn_time_left = 10000.0
		while not level.navigation_ready:
			await ticks()
		level.spawned = level.enemy_budget() - 1 if late else 0
		level._combat_seconds = 120.0 if late else 0.0
		if phase != &"entry":
			level.player.health = 2
			GameRun.health = 2
			level._heart_delay = 3.0
			assert(level.player.take_damage() and level.player.health == 1)
		assert(level._heart_critical and level._heart_delay == 7.0, "One HP must upgrade any reservation to a guaranteed seven-second drop, at any combat phase")
		if phase != &"entry":
			assert(not level.player.take_damage() and level._heart_delay == 7.0)
		level._update_heart_drop(6.75)
		assert(level._heart == null and level._heart_delay == 0.25)
		level._schedule_heart(1)
		assert(level._heart_delay == 0.25, "Repeated checks must not restart the critical countdown")
		level.set_process(true)
		level._toggle_pause()
		await get_tree().create_timer(0.1).timeout
		assert(level._heart_delay == 0.25 and level._heart == null)
		level._toggle_pause()
		level.set_process(false)
		# Even a crowd must not suppress the guarantee; the floor must still be safe.
		if late:
			for cell in level.walkable_cells:
				var blocker := Node2D.new()
				level.add_child(blocker)
				blocker.global_position = level.tiles.to_global(level.tiles.map_to_local(cell)) + Vector2(0, 3.5)
				level._pending_spawns.append(blocker)
			level.spawned += level._pending_spawns.size()
		level._update_heart_drop(0.25)
		assert(is_instance_valid(level._heart) and level._heart_spawned and not level._heart_critical, "A heart must appear at seven seconds even before the early window or after the late cutoff, including crowded floor")
		var cell: Vector2i = level.tiles.local_to_map(level.tiles.to_local(level._heart.global_position + Vector2(0, -3.5)))
		assert(cell in level.walkable_cells and not level.grid.is_point_solid(cell))
		level._schedule_heart(1)
		assert(level._heart_delay < 0.0, "The critical guarantee must still respect the one-heart-per-level limit")
		level.queue_free()
		await ticks(2)
	# Death and level completion must cancel an unexpired guarantee.
	for death in [false, true]:
		GameRun.begin_run(GameRun.Mode.EASY)
		var level = load(GameRun.level_path()).instantiate()
		get_tree().root.add_child(level)
		level.set_process(false)
		level.player.set_physics_process(false)
		level.player.health = 1
		level._schedule_heart(1)
		if death:
			level.player.is_dead = true
			level._update_heart_drop(7.0)
		else:
			level.finish_level(true)
		assert(level._heart_delay < 0.0 and not level._heart_critical and level._heart == null)
		level.queue_free()
		await ticks(2)
	print("PASS: one-HP fixed 7s guarantee after damage or level entry, early/late/crowded floor, pending reservation upgrade, pause, no timer reset, per-level cap and death/clear cancellation")

func preview_heart(level: Node2D, heart: Node2D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_tree().paused = true
	level.player.get_node("Camera2D").global_position = heart.global_position
	await RenderingServer.frame_post_draw
	var lit := get_viewport().get_texture().get_image()
	assert(lit.save_png("res://.godot/healing-heart-preview.png") == OK)
	heart.get_node("Light").hide()
	await RenderingServer.frame_post_draw
	var dark := get_viewport().get_texture().get_image()
	var changed := 0
	for y in range(260, 370):
		for x in range(520, 630):
			if lit.get_pixel(x, y).r > dark.get_pixel(x, y).r + 0.025:
				changed += 1
	assert(changed > 100, "The heart must visibly cast warm light onto the floor")
	heart.get_node("Light").show()
	get_tree().paused = false
