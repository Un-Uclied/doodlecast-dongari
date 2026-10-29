extends Node

const ENEMY := preload("res://scripts/gameplay/enemy.gd")
var completed_spawns: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	get_tree().create_timer(25.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_feedback")

func ticks(count := 1) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func make_level() -> Node2D:
	GameRun.begin_run(0)
	var level = load(GameRun.level_path()).instantiate()
	level.get_node("Player/Camera2D").position_smoothing_enabled = false
	get_tree().root.add_child(level)
	level.set_process(false)
	level.player.set_physics_process(false)
	while not level.navigation_ready:
		await get_tree().process_frame
	return level

func request_spawn(level: Node2D, kind: int) -> void:
	completed_spawns.append(await level.spawn_enemy(kind))

func test_feedback() -> void:
	var level = await make_level()
	request_spawn(level, ENEMY.Kind.BOMB_WALKER)
	assert(level.enemies.is_empty() and level._pending_spawns.size() == 1 and completed_spawns.is_empty())
	var warning: Node2D = level._pending_spawns[0]
	var location := warning.global_position
	var timer: Timer = warning.get_node("SpawnTimer")
	assert(is_equal_approx(timer.wait_time, 0.2) and warning.get_node("Sparks").emitting)
	assert(warning.get_node("Sparks").color_ramp.get_color(0).r > 0.9 and warning.get_node("Light").energy > 0.0)
	assert(level.hud.get_node("Root/Top/%Remaining").text == "남은 적  %d" % level.enemy_budget(), "Warnings must not reduce the remaining enemy count")
	level.player.get_node("Camera2D").global_position = location
	level.canvas.get_node("Panel").hide()
	level.canvas.gesture_finished.emit({"pattern_id": &"horizontal"}, 0, 1)
	assert(GameRun.combo_meter == 0.0, "An unborn enemy cannot be hit by gestures")
	await get_tree().create_timer(0.07).timeout
	assert(level.enemies.is_empty() and completed_spawns.is_empty(), "Enemy must not appear before the warning delay")
	get_tree().paused = true
	var remaining := timer.time_left
	await get_tree().create_timer(0.12).timeout
	assert(timer.time_left == remaining and level.enemies.is_empty(), "Pause must freeze spawn warnings")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var lit := get_viewport().get_texture().get_image()
		assert(lit.save_png("res://.godot/spawn-warning-preview.png") == OK)
		warning.get_node("Sparks").hide()
		await RenderingServer.frame_post_draw
		var no_sparks := get_viewport().get_texture().get_image()
		var spark_pixels := 0
		for y in range(260, 390):
			for x in range(510, 640):
				if lit.get_pixel(x, y).r > no_sparks.get_pixel(x, y).r + 0.02:
					spark_pixels += 1
		assert(spark_pixels > 10, "The warning's individual red particles must render as well as its glow")
		warning.get_node("Sparks").show()
		warning.hide()
		await RenderingServer.frame_post_draw
		var background := get_viewport().get_texture().get_image()
		var red_pixels := 0
		for y in range(260, 390):
			for x in range(510, 640):
				if lit.get_pixel(x, y).r > background.get_pixel(x, y).r + 0.05:
					red_pixels += 1
		assert(red_pixels > 100, "The red spawn warning must actually render")
		warning.show()
	get_tree().paused = false
	await timer.timeout
	assert(completed_spawns.size() == 1 and level.enemies.size() == 1 and level._pending_spawns.is_empty())
	var enemy = completed_spawns[0]
	assert(enemy.global_position == location, "The enemy must appear at the warning position")
	enemy.set_physics_process(false)
	enemy.get_node("Contact").monitoring = false
	level.spawned = level.enemy_budget() - 1
	request_spawn(level, ENEMY.Kind.SOLDIER)
	assert(level._pending_spawns[0].global_position.distance_to(enemy.global_position) >= 24.0)
	enemy.pattern.assign([&"horizontal"])
	enemy.consume_pattern(&"horizontal")
	assert(not level.finished, "Killing the last visible enemy cannot clear a level with a pending spawn")
	while completed_spawns.size() < 2:
		await ticks()
	enemy = completed_spawns[1]
	enemy.set_physics_process(false)
	enemy.get_node("Contact").monitoring = false
	enemy.pattern.assign([&"horizontal"])
	enemy.consume_pattern(&"horizontal")
	assert(level.finished, "Clear starts only when the pending enemy has also been defeated")
	level.queue_free()
	await ticks(2)

	level = await make_level()
	var pits: TileMapLayer = level.get_node("TileMapLayerPits")
	var pit_point := Vector2.ZERO
	for cell in pits.get_used_cells():
		if pits.get_cell_tile_data(cell).get_collision_polygons_count(0) > 0:
			pit_point = pits.to_global(pits.map_to_local(cell))
			break
	var bullet = ENEMY.PROJECTILE.instantiate()
	bullet.level = level
	level.get_node("Projectiles").add_child(bullet)
	bullet.global_position = pit_point
	bullet.velocity = Vector2(80, 0)
	await ticks(24)
	assert(is_instance_valid(bullet) and bullet.global_position.x > pit_point.x + 30.0, "Bullets must survive real pit collision events and fly onward")
	bullet.queue_free()
	bullet = ENEMY.PROJECTILE.instantiate()
	bullet.level = level
	level.get_node("Projectiles").add_child(bullet)
	bullet.global_position = Vector2(8, -16)
	await ticks(2)
	assert(not is_instance_valid(bullet), "A real wall must still remove a bullet")
	level.player.global_position = Vector2(0, 200)
	level.player.get_node("Camera2D").global_position = Vector2(0, 110)
	var directions := [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]
	var suffixes := ["south", "east", "north", "west"]
	for kind in range(ENEMY.Kind.BOMB_WALKER, ENEMY.Kind.FLOATING_EYE + 1):
		for index in range(4):
			enemy = await level.spawn_enemy(kind)
			enemy.set_physics_process(false)
			enemy.get_node("Contact").monitoring = false
			enemy.global_position = Vector2(-84 + 56 * index, 70 + 50 * (kind - ENEMY.Kind.BOMB_WALKER))
			enemy.pattern.assign([&"vertical"])
			enemy.queue_redraw()
			enemy.velocity = directions[index] * 100.0
			enemy._animate(directions[index])
			var action := "walk" if kind == ENEMY.Kind.BOMB_WALKER else "idle"
			assert(enemy.sprite.animation == action + "_" + suffixes[index] and not enemy.sprite.flip_h)
			var atlas: AtlasTexture = enemy.sprite.sprite_frames.get_frame_texture(enemy.sprite.animation, 0)
			assert(atlas.region.position.y == (384 if kind == ENEMY.Kind.BOMB_WALKER else 256) + index * 32, "Direction frames must match the JSON rows, not Hurt or the wrong facing")
			var duration: float = enemy.sprite.sprite_frames.get_frame_duration(enemy.sprite.animation, 0) / enemy.sprite.sprite_frames.get_animation_speed(enemy.sprite.animation)
			assert(is_equal_approx(duration, 0.083), "Keep the original JSON frame timing")
			assert(enemy.sprite.offset.y == [-10.0, -5.0, -7.0][kind - ENEMY.Kind.BOMB_WALKER], "Feet alignment must use the original JSON pivot")
			enemy.sprite.pause()
	level.get_node("TileMapLayerPits").hide()
	level.canvas.get_node("Panel").hide()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png("res://.godot/enemy-directions-preview.png") == OK)
	level.queue_free()
	await ticks(2)

	level = await make_level()
	completed_spawns.clear()
	request_spawn(level, ENEMY.Kind.BAT)
	level.finish_level(false)
	assert(not level._pending_spawns[0].visible)
	await get_tree().create_timer(0.25).timeout
	assert(completed_spawns == [null] and level.enemies.is_empty() and level._pending_spawns.is_empty(), "Game over must cancel a pending enemy")
	level.queue_free()
	await ticks(2)
	level = await make_level()
	request_spawn(level, ENEMY.Kind.BAT)
	level.queue_free()
	await ticks(16)
	print("PASS: red warning then 0.2s spawn, pause/gesture exclusion/position/count/clear/cancel/unload, real bullets pass pits but stop at walls, JSON cardinal frames/timing/pivots for all three special enemies")
	get_tree().quit()
