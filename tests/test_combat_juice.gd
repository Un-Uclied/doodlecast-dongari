extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(20.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_juice")

func ticks(count := 1) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame
	if SceneTransition.transitioning:
		await SceneTransition.finished

func test_juice() -> void:
	for mode in range(3):
		GameRun.begin_run(mode)
		GameRun.award(1000000)
		for seconds in [0.0, 0.09, 0.1, 0.19, 12.3, 18000.0]:
			GameRun.elapsed_seconds = seconds
			var score := GameRun.total_score
			GameRun.elapsed_seconds += 0.1
			assert(GameRun.total_score == score - 1, "Above zero, every 0.1s must cost exactly one point in every mode, even in a long run")
		GameRun.combat_score = 10
		GameRun.elapsed_seconds = 0.9
		assert(GameRun.total_score == 1)
		for seconds in [1.0, 1.1, 18000.0]:
			GameRun.elapsed_seconds = seconds
			assert(GameRun.total_score == 0, "The score must stay at zero when the time penalty exhausts earned points")
	GameRun.begin_run(0)
	assert(GameRun.total_score == 0 and GameRun.elapsed_seconds == 0.0)
	GameRun.elapsed_seconds = 1.0
	assert(GameRun.total_score == 0, "A run with no earned points must never have a negative total")
	GameRun.begin_run(0)
	var level := (load("res://scenes/levels_easy/level_01.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	level.set_process(false)
	while not level.navigation_ready:
		await get_tree().process_frame
	GameRun.elapsed_seconds = 12.3
	level._update_hud()
	assert(level.hud.get_node("Root/Top/%Score").text.contains("경과 00:12.3 · 감점 123점"), "Elapsed time must be positive and labeled separately from the time penalty")
	GameRun.elapsed_seconds = 0.0
	level._update_hud()
	level.player.set_physics_process(false)
	level.player.global_position = Vector2(120, 43.5)
	var front = await level.spawn_enemy(0)
	var rear = await level.spawn_enemy(0)
	assert(front.collision_mask == 5 and rear.collision_layer == 4)
	front.global_position = Vector2(64, 43.5)
	rear.global_position = Vector2(40, 43.5)
	front.speed = 0.0
	for enemy in [front, rear]:
		enemy.get_node("Contact").monitoring = false
	for index in range(65):
		await ticks()
		assert(front.global_position.distance_to(rear.global_position) >= 6.9, "Enemy body colliders must not overlap")
	assert(rear.global_position.x <= front.global_position.x - 6.9 and absf(rear.global_position.y - 43.5) < 0.01)
	assert(rear._path.is_empty(), "An enemy must not take a wall detour merely because another enemy blocks it")
	front.set_physics_process(false)
	rear.set_physics_process(false)
	var missed = await level.spawn_enemy(0)
	missed.set_physics_process(false)
	missed.get_node("Contact").monitoring = false
	front.global_position = level.player.global_position + Vector2(-32, 0)
	rear.global_position = level.player.global_position + Vector2(32, 0)
	missed.global_position = level.player.global_position + Vector2(0, 32)
	front.pattern.assign([&"chevron_up", &"horizontal", &"vertical"])
	rear.pattern.assign([&"horizontal"])
	missed.pattern.assign([&"vertical"])
	await ticks(2)
	level.canvas.gesture_finished.emit({"pattern_id": &"chevron_up"}, 0, 1)
	var single_hit_shake: float = level.player._shake_strength
	assert(single_hit_shake > 0.0 and level.get_node("Effects").get_child_count() == 1, "One matched enemy must trigger attack camera shake")
	await get_tree().create_timer(0.45).timeout
	assert(level.player._shake_strength == 0.0 and level.player.get_node("Camera2D").offset == Vector2.ZERO)
	level.canvas.gesture_finished.emit({"pattern_id": &"horizontal"}, 0, 1)
	assert(is_equal_approx(level.player._shake_strength, single_hit_shake * 2.0 + level.player.KILL_SHAKE), "Two matched enemies add both hit shakes plus the killed enemy's bonus")
	var effects := level.get_node("Effects")
	assert(effects.get_child_count() == 2, "Every matched enemy, including a killed one, must receive a lightning strike")
	assert(front.pattern == [&"vertical"] and rear.resolved and missed.pattern == [&"vertical"])
	for bolt in effects.get_children():
		assert(bolt.get_node("Arc").points[0] == Vector2.ZERO and bolt.get_node("Arc").points[-1] == bolt.target_offset)
		assert(bolt.get_node("Impact").emitting)
	var last_impact: Vector2 = effects.get_child(1).to_global(effects.get_child(1).target_offset)
	level.player.global_position.x += 12.0
	front.global_position.x -= 3.0
	await ticks(2)
	for bolt in effects.get_children():
		assert(bolt.global_position == level.player.global_position + Vector2(0, -12), "Lightning must follow a moving caster")
	assert(effects.get_child(0).to_global(effects.get_child(0).target_offset).is_equal_approx(front.global_position + Vector2(0, -8)), "Lightning must follow a surviving target")
	assert(effects.get_child(1).to_global(effects.get_child(1).target_offset).is_equal_approx(last_impact), "A killed target must leave its impact at the last known position")
	await get_tree().create_timer(0.45).timeout
	assert(effects.get_child_count() == 0, "Finished lightning and impact particles must be freed")
	level.canvas.gesture_finished.emit({"pattern_id": &"star"}, 0, 1)
	assert(effects.get_child_count() == 0 and level.player._shake_strength == 0.0, "An unmatched gesture must not create lightning or shake")
	assert(level.player.take_damage())
	assert(level.player.get_node("DamageParticles").emitting and level.player._shake_left > 0.0)
	var red: Color = level.player.get_node("DamageParticles").color_ramp.get_color(0)
	assert(red.r > red.g * 5.0 and red.r < 0.6, "Damage particles must be dark red")
	await ticks(2)
	assert(level.player.get_node("Camera2D").offset.length() > 0.0)
	await get_tree().create_timer(0.65).timeout
	assert(level.player.get_node("Camera2D").offset == Vector2.ZERO and not level.player.get_node("DamageParticles").emitting)
	level.player.dash_time_left = 0.24
	assert(not level.player.take_damage() and level.player._shake_left == 0.0 and not level.player.get_node("DamageParticles").emitting, "Invulnerability must not trigger blood or camera shake")
	level.player.dash_time_left = 0.0
	level._spawn_time_left = 1000.0
	level.set_process(true)
	await get_tree().create_timer(0.16).timeout
	assert(GameRun.elapsed_seconds >= 0.1)
	level._toggle_pause()
	var elapsed := GameRun.elapsed_seconds
	await get_tree().create_timer(0.16).timeout
	assert(GameRun.elapsed_seconds == elapsed, "Pause must freeze elapsed time and score")
	level._toggle_pause()
	await get_tree().create_timer(0.16).timeout
	assert(GameRun.elapsed_seconds > elapsed)
	level.finish_level(true)
	elapsed = GameRun.elapsed_seconds
	assert(not level.hud.get_node("%Results").visible, "Final-hit effects need a brief unobstructed moment")
	await get_tree().create_timer(0.4).timeout
	assert(GameRun.elapsed_seconds == elapsed and not level.hud.get_node("%Results").visible, "The door reveal must precede the result overlay")
	await get_tree().create_timer(2.5).timeout
	assert(level.hud.get_node("%Results").visible)
	assert(level.hud.get_node("Root/Results/%ResultPenalty").text == level.hud.format_number(GameRun.time_score()) + "점")
	level.hud.get_node("Root/Results/%Continue").pressed.emit()
	await ticks(2)
	assert(get_tree().current_scene.level_number == 2 and GameRun.elapsed_seconds >= elapsed)
	GameRun.begin_run(0)
	assert(GameRun.elapsed_seconds == 0.0 and GameRun.total_score == 0)
	print("PASS: enemy collision without detours, decisecond scoring and zero floor in all modes, timing pause/results/progression/reset, additive attack shake per matched enemy, matched-target lightning and moving endpoints/cleanup, dark-red damage burst, shake recovery, dash effect immunity")
	get_tree().quit()
