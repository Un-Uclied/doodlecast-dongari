extends Node

const MOCK := preload("res://tests/fixtures/leaderboard_mock.gd")
var capture := false

func _ready() -> void:
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	get_tree().current_scene = null
	capture = DisplayServer.get_name() != "headless"
	get_tree().create_timer(55).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_update")

func test_update() -> void:
	await test_tutorial_storage()
	assert(await test_spawns())
	assert(await test_onboarding())
	for mode in range(3):
		assert(await test_boss(mode))
	Music.stop()
	await get_tree().create_timer(0.2).timeout
	print("PASS: QA integration: existing/local player state, announced spawns, tier-1 bomb, shared badges, healing-only heart, six-kind/eight-offensive-symbol plus heart-pickup onboarding, clean restart; all boss modes, attacks, phases, deadlines, hearts, pause, victory")
	get_tree().quit()

func ticks(count := 2) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func screenshot(name: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png("res://.godot/qa-" + name + ".png") == OK)

func add_level(path: String):
	var level = load(path).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	level.set_process(false)
	level.player.set_physics_process(false)
	while not level.navigation_ready:
		await get_tree().process_frame
	return level

func test_tutorial_storage() -> void:
	var first = MOCK.new()
	first.enabled = false
	first.storage_dir = "user://qa-tutorial-" + str(Time.get_ticks_usec())
	add_child(first)
	first.complete_tutorial("00123")
	first.complete_tutorial("00123")
	assert(first.tutorials.size() == 1 and first.requests.is_empty(), "Completing practice must not create a separate server record")
	assert(await first.tutorial_completed("00123"))
	var storage: String = first.storage_dir
	first.free()
	first = MOCK.new()
	first.enabled = false
	first.storage_dir = storage
	add_child(first)
	assert(await first.tutorial_completed("00123"), "Local completion must survive an app restart")
	first.free()
	var second = MOCK.new()
	second.enabled = false
	second.storage_dir = "user://qa-second-pc-" + str(Time.get_ticks_usec())
	add_child(second)
	second.enabled = true
	second.responses = [{"code": 200, "body": [{"document": {"fields": {"participant_key": {"stringValue": "00123".sha256_text()}}}}]}]
	assert(await second.tutorial_completed("00123"), "Another PC must find an existing play record for the student")
	assert(second.requests[-1].url.ends_with(":runQuery") and second.requests.size() == 1)
	assert(second.requests[-1].data.structuredQuery.limit == 1 and second.requests[-1].data.structuredQuery.from[0].collectionId == "doodlecast_runs")
	assert(not JSON.stringify(second.requests).contains("00123"), "Do not send the raw student ID in tutorial records")
	assert(not await second.tutorial_completed("+1234"))
	second.responses = [{"code": 200, "body": [{"readTime": "2026-10-28T00:00:00Z"}]}]
	assert(not await second.tutorial_completed("00322"), "No matching play record means first-time onboarding")
	second.responses = [{"code": 0, "body": {}}]
	assert(not await second.tutorial_completed("00321"), "An unavailable server must allow a first-time local tutorial")
	second.free()

func collect_spawn(level, output: Array) -> void:
	output.append(await level.spawn_enemy(0))

func test_spawns() -> bool:
	GameRun.begin_run(1)
	GameRun.tutorial_required = false
	var level = await add_level("res://scenes/levels_normal/level_01.tscn")
	var bomb = await level.spawn_enemy(2)
	bomb.set_physics_process(false)
	assert(bomb.pattern.size() == 1 and bomb.pattern[0] in PatternCatalog.TIER_1)
	var single_badge_size: Vector2 = bomb.get_node("Pattern").local_rect().size
	assert(bomb.global_position.distance_to(level.player.global_position) >= level.min_spawn_distance)
	var original_position: Vector2 = level.player.global_position
	var before: int = level.spawned
	var result: Array = []
	collect_spawn(level, result)
	assert(not level._pending_spawns.is_empty())
	var location: Vector2 = level._pending_spawns[0].global_position
	level.player.global_position = location
	level.player.practice_invulnerable = true
	while result.is_empty():
		await ticks(1)
	assert(result.size() == 1 and result[0] != null and level.spawned == before + 1, "Approaching an existing warning must preserve the spawn")
	result[0].set_physics_process(false)
	assert(result[0].global_position.distance_to(location) < 0.1, "An enemy must appear at its announced location")
	level.player.global_position = original_position
	bomb.pattern.assign([&"heart", &"vertical"])
	level.player.health = 4
	GameRun.health = 4
	level._heart = level.HEALING_HEART.instantiate()
	level.get_node("Pickups").add_child(level._heart)
	var badge: Node2D = level._heart.get_node("Pattern")
	assert(badge.get_script() == bomb.get_node("Pattern").get_script())
	assert(badge.local_rect().size == single_badge_size, "One-symbol enemy and healing-item badges must have identical dimensions")
	assert(badge.local_rect().size.x < 25 and badge.material.light_mode == bomb.get_node("Pattern").material.light_mode)
	level.canvas.gesture_finished.emit({"pattern_id": &"heart"}, 0, 1)
	assert(level.player.health == 5 and level._heart == null and bomb.pattern == [&"heart", &"vertical"], "Heart input must only heal, even if an enemy is incorrectly assigned a heart")
	var other = await level.spawn_enemy(0)
	other.set_physics_process(false)
	bomb.pattern.assign([&"star", &"spiral", &"square"])
	other.pattern.assign([&"star", &"spiral", &"triangle"])
	other.global_position = bomb.global_position + Vector2(24, 0)
	bomb._update_badge_position()
	other._update_badge_position()
	assert(other.badge_center.y < bomb.badge_center.y, "Nearby pattern badges must use separate rows")
	level.queue_free()
	await ticks()
	return true

func test_onboarding() -> bool:
	GameRun.set_player_info("00123", "")
	GameRun.begin_run(2)
	GameRun.tutorial_required = true
	var level = await add_level("res://scenes/levels_hard/level_01.tscn")
	var tutorial = level.onboarding
	assert(tutorial != null)
	tutorial.set_process(false)
	tutorial._process(5.1)
	assert(level.spawned == 0 and not level.canvas.input_enabled, "Five seconds alone must not bypass the dash lesson")
	level.player.set_physics_process(true)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(1)
	event.pressed = false
	Input.parse_input_event(event)
	assert(level.player.dash_time_left > 0)
	level.player.set_physics_process(false)
	tutorial._process(0.05)
	await get_tree().create_timer(0.25).timeout
	assert(level.enemies.size() == 1 and tutorial.lesson == 1)
	assert(not level.player.take_damage(true), "The learning section must never kill a first-time player")
	tutorial._process(0.8)
	await screenshot("onboarding")
	var symbols := {}
	for index in range(6):
		var enemy = level.enemies[0]
		enemy.set_physics_process(false)
		assert(enemy.kind == index and enemy.pattern.size() <= 2)
		assert(not &"heart" in enemy.pattern)
		if is_instance_valid(level._heart):
			symbols[&"heart"] = true
			level.canvas.gesture_finished.emit({"pattern_id": &"heart"}, 0, 1)
			assert(level._heart == null and level.player.health == 5)
		for id in enemy.pattern.duplicate():
			symbols[id] = true
			level.canvas.gesture_finished.emit({"pattern_id": id}, 0, 1)
		if index < 5:
			tutorial._process(0.1)
			await get_tree().create_timer(0.25).timeout
	assert(symbols.size() == 9, "The curriculum must cover every symbol")
	if SceneTransition.transitioning:
		await SceneTransition.finished
	level = get_tree().current_scene
	level._spawn_time_left = 1000
	assert(level.mode == 2 and level.level_number == 1 and level.onboarding == null)
	assert(GameRun.combat_score == 0 and GameRun.defeated == 0 and GameRun.hits_taken == 0 and GameRun.health == 5 and GameRun.elapsed_seconds < 0.5, "Practice must not change ranked run statistics")
	assert(Leaderboard.tutorials.get("00123".sha256_text()) == 1)
	level.queue_free()
	await ticks()
	return true

func hazards(level) -> Array:
	return level.get_node("Projectiles").get_children().filter(func(node): return node.get_script() == preload("res://scripts/effects/boss_attack.gd") and not node.is_queued_for_deletion())

func test_boss(mode: int) -> bool:
	GameRun.begin_run(mode)
	GameRun.tutorial_required = false
	var level = await add_level("res://scenes/levels_%s/level_06.tscn" % GameRun.MODE_FOLDERS[mode])
	assert(level.is_boss_fight() and level.enemy_budget() == 0 and level.enemies.is_empty())
	if mode == 1:
		await get_tree().create_timer(0.75).timeout
		await screenshot("boss-intro")
	var elapsed := GameRun.elapsed_seconds
	level._process(level._intro.duration + 0.1)
	assert(level.state == level.State.READY and level.get_node("Projectiles").get_child_count() == 0)
	level._process(2.1)
	assert(GameRun.elapsed_seconds == elapsed, "The boss introduction must not charge a time penalty")
	assert(level.state == level.State.ATTACK and level._attacks.size() == level.ATTACKS_PER_CYCLE[mode] - 1)
	level.player.set_physics_process(false)
	level.player.practice_invulnerable = true
	level.boss_health = level.MAX_BOSS_HEALTH
	assert(level.phase == 1)
	level.boss_health = int(level.MAX_BOSS_HEALTH * 0.5)
	level._begin_cycle()
	assert(level.phase == 2 and level._attacks.size() == level.ATTACKS_PER_CYCLE[mode])
	for kind in range(level.AttackKind.size()):
		level._clear_attacks()
		await ticks()
		level._attacks.assign([kind])
		level._start_next_attack()
		match kind:
			0:
				assert(hazards(level).size() >= 5)
				if mode == 1:
					await screenshot("boss-grid")
			1:
				assert(hazards(level).size() == 2, "Phase two must warn two distinct sectors")
				assert(hazards(level).all(func(hazard): return hazard.charge_duration == level.SECTOR_WARNING_SECONDS[mode]))
			2:
				for index in range(level._waves_total):
					level._update_attack(level._wave_interval)
				assert(level._wave_index == level._waves_total and hazards(level).size() == level._waves_total)
			3:
				level._update_attack(level.WARNING_SECONDS[mode] + 0.31)
				assert(level.get_node("Projectiles").get_children().filter(func(node): return node is Area2D).size() == 24 + (level.phase - 1) * 6)
				level._update_attack(0.8)
				assert(level.boss.global_position.distance_to(level._dash_origin) < 1)
			4, 5, 7:
				level._update_attack(level.WARNING_SECONDS[mode] + 0.1)
				var bullets: Array = level.get_node("Projectiles").get_children().filter(func(node): return node is Area2D and not node.is_queued_for_deletion())
				assert(not bullets.is_empty())
				assert(bullets.all(func(bullet): return bullet.velocity.length() >= level.BULLET_SPEED[mode] * 0.7))
				assert(bullets.any(func(bullet): return absf(bullet.turn_rate) > 0.01))
			6:
				for index in range(level._waves_total):
					level._update_attack(level._wave_interval)
				assert(level._wave_index == level._waves_total and not hazards(level).is_empty())
	level._clear_attacks()
	await ticks()
	level.boss_health = level.MAX_BOSS_HEALTH
	level.player.practice_invulnerable = false
	var hazard = level.ATTACK.instantiate()
	hazard.level = level
	hazard.polygon = level._circle(level.player.global_position, 26)
	hazard.charge_duration = 0.05
	hazard.active_duration = 0.4
	level.get_node("Projectiles").add_child(hazard)
	assert(not hazard.active and level.player.health == 5, "Warnings must not hurt")
	get_tree().paused = true
	var hazard_age: float = hazard.age
	await get_tree().create_timer(0.06, true).timeout
	assert(hazard.age == hazard_age and not hazard.active)
	get_tree().paused = false
	level.player.dash_time_left = 0.3
	await get_tree().create_timer(0.12).timeout
	assert(hazard.active and level.player.health == 5, "Ordinary boss fire must honor dash immunity")
	level.player.dash_time_left = 0
	await ticks(2)
	assert(level.player.health == 4, "The actual fire polygon must damage an overlapping player")
	await ticks(2)
	assert(level.player.health == 4, "One hazard must not repeatedly drain health")
	level._clear_attacks()
	level.player.health = 5
	GameRun.health = 5
	GameRun.hits_taken = 0
	level._begin_window()
	assert(level.attack_sequence.size() == 7 and level.window_left == level.WINDOW_SECONDS[mode])
	assert(not &"heart" in level.attack_sequence, "Boss attack windows must never request heart input")
	var window: float = level.window_left
	level.set_process(true)
	get_tree().paused = true
	await get_tree().create_timer(0.05, true).timeout
	assert(level.window_left == window, "Pause must freeze the attack deadline")
	get_tree().paused = false
	level.set_process(false)
	if mode == 1:
		await screenshot("boss-window")
	level.player.dash_time_left = 0.3
	level.player._hurt_invulnerability_left = 1
	level._process(window + 0.1)
	assert(level.player.health == 4 and GameRun.hits_taken == 1, "A failed seven-symbol window must bypass both dash and hurt immunity")
	level._end_window(false)
	assert(level.player.health == 4, "Timeout damage must occur exactly once")
	level.player.health = 1
	GameRun.health = 1
	level._heart_delay = -1
	level._heart_critical = false
	level._schedule_heart(1)
	level._update_heart_drop(7)
	assert(is_instance_valid(level._heart), "Hearts must remain available without a mob-kill budget")
	level._begin_window()
	level.attack_sequence[0] = &"heart"
	level.canvas.gesture_finished.emit({"pattern_id": &"heart"}, 0, 1)
	assert(level.player.health == 2 and level.attack_sequence.size() == 7 and level._heart == null, "Healing must not advance boss attack symbols")
	for cycle in range(ceili(float(level.MAX_BOSS_HEALTH) / level.WINDOW_DAMAGE)):
		level._begin_window()
		var remaining: int = level.attack_sequence.size()
		level.canvas.gesture_finished.emit({"pattern_id": &""}, 0, 1)
		assert(level.attack_sequence.size() == remaining and level.boss_health == level.MAX_BOSS_HEALTH - cycle * level.WINDOW_DAMAGE)
		for id in level.attack_sequence.duplicate():
			level.canvas.gesture_finished.emit({"pattern_id": id}, 0, 1)
	assert(level.boss_health == 0 and level.finished and level.hud.get_node("Root/Results/%ResultTitle").text == "ALL CLEAR")
	level.queue_free()
	await ticks()
	return true
