extends Node

const ENEMY := preload("res://scripts/enemy.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(20.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_enemies")

func ticks(count := 1) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func test_enemies() -> void:
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	for mode in range(3):
		GameRun.begin_run(mode)
		var map = load(GameRun.level_path()).instantiate()
		get_tree().root.add_child(map)
		map.set_process(false)
		map.player.set_physics_process(false)
		while not map.navigation_ready:
			await get_tree().process_frame
		var expected_lights := 0
		for layer: TileMapLayer in map.find_children("*", "TileMapLayer", true, false):
			for cell in layer.get_used_cells():
				var source := layer.tile_set.get_source(layer.get_cell_source_id(cell))
				if source.resource_name in ["torch1", "candlestick1"]:
					expected_lights += 1
		assert(expected_lights > 0 and map.get_node("Lighting").get_child_count() == expected_lights, "All painted torches/candles must receive lights in each mode")
		assert(map.get_node("Ambient").color.v < 0.8 and map.hud is CanvasLayer)
		map.rng.seed = 193
		var kinds := {}
		for index in range(ENEMY.Kind.size()):
			var enemy = await map.spawn_enemy(index)
			assert(enemy != null)
			assert(enemy.reward == enemy.pattern.size() * 100, "Difficult symbols must not add extra kill points")
			kinds[enemy.kind] = true
			enemy.set_physics_process(false)
			enemy.get_node("Contact").monitoring = false
			if enemy.kind == ENEMY.Kind.BOMB_WALKER:
				assert(enemy.pattern.size() == 1 and enemy.pattern[0] in map.SIMPLE_PATTERNS and enemy.reward == 100)
			elif enemy.kind in [ENEMY.Kind.BAT, ENEMY.Kind.FLOATING_EYE, ENEMY.Kind.FLAME_WISP]:
				assert(enemy.pattern.size() >= map.LENGTHS[map.difficulty - 1].x, "Bat, eye and wisp use ordinary difficulty rules")
			if enemy.kind >= ENEMY.Kind.BOMB_WALKER:
				assert(not enemy.maintain_spacing and enemy.sprite.material == null)
				assert(enemy.sprite.sprite_frames.get_frame_count("idle_south") == (6 if enemy.kind == ENEMY.Kind.BAT else 8))
			map.enemies.erase(enemy)
			enemy.free()
			map.spawned = 0
		assert(kinds.size() == 6, "Normal level spawning must include all six enemy kinds")
		map.queue_free()
		await get_tree().process_frame

	GameRun.begin_run(0)
	var level = load(GameRun.level_path()).instantiate()
	level.get_node("TileMapLayerPits").clear()
	level.get_node("Player/Camera2D").position_smoothing_enabled = false
	get_tree().root.add_child(level)
	level.set_process(false)
	level.player.set_physics_process(false)
	level.player.global_position = Vector2(0, 100)
	while not level.navigation_ready:
		await get_tree().process_frame
	var bomb = await level.spawn_enemy(ENEMY.Kind.BOMB_WALKER)
	bomb.get_node("Contact").monitoring = false
	bomb.global_position = Vector2(120, 100)
	await ticks()
	assert(bomb.velocity.length() > 180.0 and bomb.global_position.x < 119.0, "Bomb must rush on its first physics step")
	bomb.set_physics_process(false)
	var bat = await level.spawn_enemy(ENEMY.Kind.BAT)
	bat.get_node("Contact").monitoring = false
	bat.global_position = Vector2(90, 100)
	var orbit_started: float = bat._age
	assert(bat.collision_layer == 0 and bat.collision_mask == 0 and bat.get_node("CollisionShape2D").disabled)
	await ticks(60)
	var offset: Vector2 = bat.global_position - level.player.global_position
	assert(absf(offset.length() - maxf(0.0, 90.0 - 64.0 * (bat._age - orbit_started))) < 1.0 and offset.angle() > 0.7, "Bat must orbit while reducing its actual radius by 64px per simulated second")
	bat.global_position = Vector2(8, -16)
	level.player.global_position = Vector2(8, -80)
	await ticks(2)
	assert(bat.global_position.y < -16.0, "Flying bat must move inside solid wall cells")
	bat.set_physics_process(false)
	level.player.global_position = Vector2(120, 100)
	var eye = await level.spawn_enemy(ENEMY.Kind.FLOATING_EYE)
	eye.get_node("Contact").monitoring = false
	eye.global_position = Vector2(-80, 100)
	await ticks(30)
	assert(eye.global_position.x > -50.0 and level.get_node("Projectiles").get_child_count() == 0, "Eye follows without shooting during its first second")
	await ticks(31)
	var anchor: Vector2 = eye.global_position
	assert(eye.velocity == Vector2.ZERO and level.get_node("Projectiles").get_child_count() == 5)
	var volley = level.get_node("Projectiles").get_children()
	for index in range(5):
		assert(is_equal_approx(volley[index].velocity.length(), 80.0))
		assert(absf(wrapf(volley[index].velocity.angle_to(volley[(index + 1) % 5].velocity) - TAU / 5.0, -PI, PI)) < 0.001, "Five shots must be evenly spaced around the eye")
	level.player.global_position += Vector2(0, 60)
	await ticks(70)
	assert(eye.global_position == anchor and eye._volley_angle > 0.3, "Eye must stay anchored and repeatedly rotate its five-shot volleys")
	eye.set_physics_process(false)
	for bullet in level.get_node("Projectiles").get_children():
		bullet.queue_free()
	await ticks(2)
	var bullet = ENEMY.PROJECTILE.instantiate()
	bullet.level = level
	level.get_node("Projectiles").add_child(bullet)
	bullet.global_position = level.player.global_position + Vector2(-25, -8)
	bullet.velocity = Vector2(80, 0)
	await ticks(20)
	assert(level.player.health == 4 and not is_instance_valid(bullet), "Real projectile overlap must damage once and remove the projectile")
	bullet = ENEMY.PROJECTILE.instantiate()
	bullet.level = level
	level.get_node("Projectiles").add_child(bullet)
	bullet.global_position = level.player.global_position + Vector2(0, -8)
	await ticks(2)
	assert(level.player.health == 4 and not is_instance_valid(bullet), "Hurt/dash invulnerability must reject bullet damage")
	bullet = ENEMY.PROJECTILE.instantiate()
	bullet.level = level
	level.get_node("Projectiles").add_child(bullet)
	bullet.global_position = Vector2(8, -16)
	await ticks(2)
	assert(not is_instance_valid(bullet), "Wall contact must remove enemy bullets")
	bullet = ENEMY.PROJECTILE.instantiate()
	bullet.level = level
	level.get_node("Projectiles").add_child(bullet)
	bullet.global_position = Vector2(0, 50)
	bullet.velocity = Vector2(80, 0)
	get_tree().paused = true
	var paused_position: Vector2 = bullet.global_position
	await get_tree().create_timer(0.1).timeout
	assert(bullet.global_position == paused_position, "Pause freezes projectiles")
	get_tree().paused = false
	bullet._life_left = 0.01
	await ticks(2)
	assert(not is_instance_valid(bullet), "Old bullets must expire")
	level.player.global_position = Vector2(0, 78)
	bomb.global_position = Vector2(-64, 50)
	bat.global_position = Vector2(62, 48)
	eye.global_position = Vector2(0, 30)
	for enemy in [bomb, bat, eye]:
		enemy.pattern.assign([&"horizontal", &"vertical"])
		enemy.queue_redraw()
		enemy.sprite.play("idle_south")
	level.canvas.get_node("Panel").hide()
	eye._fire_volley()
	await ticks(12)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var lit := get_viewport().get_texture().get_image()
		level.get_node("Lighting").hide()
		await RenderingServer.frame_post_draw
		var dark := get_viewport().get_texture().get_image()
		var lit_pixels := 0
		for y in range(100, 500):
			for x in range(300, 850):
				if lit.get_pixel(x, y).r > dark.get_pixel(x, y).r + 0.025:
					lit_pixels += 1
		assert(lit_pixels > 500, "Torch lights must visibly illuminate the rendered world")
		level.get_node("Lighting").show()
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png("res://.godot/new-enemies-preview.png") == OK)
	level.canvas.gesture_finished.emit({"pattern_id": &"horizontal"}, 0, 1)
	assert(level.get_node("Effects").get_child_count() == 3)
	var impact: Vector2 = bomb.hit_position()
	var effect = level.get_node("Effects").get_child(0)
	assert(effect.get_node("Impact").amount >= 32 and effect.get_node("HitRing").global_position == impact)
	level.player.global_position.x += 5.0
	bomb.global_position.x -= 5.0
	await ticks(3)
	assert(effect.get_node("HitRing").global_position == impact, "The burst ring must stay at the hit position as actors move")
	level.hud.pulse_remaining()
	level.hud._remaining_tween.pause()
	level.hud._remaining_tween.custom_step(0.1)
	assert(level.hud.get_node("%Remaining").scale.x > 1.6, "Kill text impact must be larger than before")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png("res://.godot/magic-hit-preview.png") == OK)
	level.finish_level(true)
	await ticks(2)
	assert(level.get_node("Projectiles").get_child_count() == 0, "Clear/game over removes every remaining bullet")
	level.free()
	print("PASS: all six kinds spawn in all modes, simple fast bomb, shrinking collision-free bat orbit, eye follows then anchors/fires rotating volleys, bullet damage/immunity/walls/pause/expiry/clear, automatic torch lights, fixed hit bursts, larger kill text")
	get_tree().quit()
