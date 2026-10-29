extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	get_tree().create_timer(15.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_combo")

func ticks(count := 1) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func test_combo() -> void:
	for mode in range(3):
		GameRun.begin_run(mode)
		for rank in range(5):
			GameRun.combo_meter = rank * 20.0
			assert(GameRun.combo_rank == rank)
			assert(GameRun.award(100) == roundi(100 * GameRun.REWARD_MULTIPLIERS[mode] * (1.0 + rank * 0.1)), "Every combo rank must combine with the selected mode's multiplier")
	GameRun.begin_run(0)
	GameRun.register_attack(1, 0)
	assert(GameRun.combo_meter == 3.0)
	GameRun.register_attack(1, 1)
	assert(GameRun.combo_meter == 10.0 and GameRun.combo_rank == 0)
	GameRun.combo_meter = 0.0
	GameRun.register_attack(2, 0)
	assert(GameRun.combo_meter == 7.5, "Simultaneous hits must keep a bonus while gains are halved")
	GameRun.register_attack(10, 10)
	assert(GameRun.combo_meter == 100.0 and GameRun.combo_rank == 4)
	GameRun.combo_meter = 10.0
	GameRun.decay_combo(1.0)
	var low_loss := 10.0 - GameRun.combo_meter
	GameRun.combo_meter = 90.0
	GameRun.decay_combo(1.0)
	assert(90.0 - GameRun.combo_meter > low_loss, "High ranks must drain faster")
	GameRun.combo_meter = 0.0
	GameRun.fail_gesture()
	assert(GameRun.combo_meter == 0.0)
	GameRun.begin_run(0)
	assert(GameRun.combo_meter == 0.0 and GameRun.combo_rank == 0)
	var level = load("res://scenes/levels_easy/level_01.tscn").instantiate()
	get_tree().root.add_child(level)
	level.set_process(false)
	level.player.set_physics_process(false)
	while not level.navigation_ready:
		await get_tree().process_frame
	level._spawn_time_left = 1000.0
	for index in range(6):
		var enemy = await level.spawn_enemy(0)
		enemy.set_physics_process(false)
		enemy.get_node("Contact").monitoring = false
		enemy.pattern.assign([&"horizontal"])
		enemy.reward = 100
		enemy.global_position = level.player.global_position + Vector2(-72 + index * 24, -28)
	await ticks(2)
	level.canvas.gesture_finished.emit({"pattern_id": &"horizontal"}, 0, 1)
	assert(GameRun.combo_meter == 64.5 and GameRun.combo_rank == 3, "Six simultaneous kills must no longer instantly fill the gauge")
	assert(GameRun.combat_score == 6 * 98, "All simultaneous kills must use the same earned A multiplier")
	assert(level.hud.get_node("Root/Top/%ComboRank").text == "A  ×1.3")
	assert(level.hud.get_node("Root/Top/%ComboGauge").value == 64.5)
	# Step the short impact explicitly so first-use shader compilation cannot skip it.
	var impact: Tween = level.hud.status._remaining_tween
	impact.pause()
	impact.custom_step(0.04)
	assert(level.hud.get_node("Root/Top/%Remaining").scale.x > 1.0, "A kill must enlarge the remaining-enemies label")
	var score: Label = level.hud.get_node("Root/Top/%Score")
	var gauge: ProgressBar = level.hud.get_node("Root/Top/%ComboGauge")
	assert(gauge.get_global_rect().position.y >= score.get_global_rect().end.y, "The combo gauge must be below the yellow score text")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png("res://.godot/combo-impact-preview.png") == OK)
	impact.play()
	await get_tree().create_timer(0.35).timeout
	assert(level.hud.get_node("Root/Top/%Remaining").scale.is_equal_approx(Vector2.ONE), "The impact must restore the label's original scale")
	level.canvas.gesture_finished.emit({"pattern_id": &"star"}, 0, 1)
	assert(GameRun.combo_meter == 64.5, "A recognized but unmatched pattern must not be treated as an unrecognized drawing")
	level.canvas.gesture_finished.emit({"pattern_id": &""}, 0, 1)
	assert(GameRun.combo_meter == 52.5 and GameRun.combo_rank == 2)
	level.canvas.gesture_finished.emit({"pattern_id": &""}, 0, 1)
	assert(GameRun.combo_meter == 40.5 and GameRun.combo_rank == 2, "A failed drawing can lower the rank")
	var survivor = await level.spawn_enemy(0)
	survivor.set_physics_process(false)
	survivor.get_node("Contact").monitoring = false
	survivor.global_position = level.player.global_position + Vector2(40, -28)
	survivor.pattern.assign([&"vertical", &"horizontal"])
	GameRun.combo_meter = 0.0
	level.canvas.gesture_finished.emit({"pattern_id": &"vertical"}, 0, 1)
	assert(GameRun.combo_meter == 3.0 and survivor.pattern == [&"horizontal"], "A hit must fill the meter without requiring a kill")
	level.set_process(true)
	level._toggle_pause()
	var paused_meter := GameRun.combo_meter
	await get_tree().create_timer(0.12).timeout
	assert(GameRun.combo_meter == paused_meter)
	level._toggle_pause()
	await get_tree().create_timer(0.12).timeout
	assert(GameRun.combo_meter < paused_meter)
	level.finish_level(false)
	var final_meter := GameRun.combo_meter
	await get_tree().create_timer(0.12).timeout
	assert(GameRun.combo_meter == final_meter, "Results must freeze combo decay")
	level.free()
	print("PASS: D/C/B/A/S multipliers in all modes, hit/kill/multi-hit gains, cap and failure floor, faster high-rank drain, common multiplier for simultaneous kills, HUD placement and impact reset, pause/results freeze")
	get_tree().quit()
