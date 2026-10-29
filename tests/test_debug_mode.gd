extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	get_tree().create_timer(35.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_debug")

func ticks(count := 1) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame
	if SceneTransition.transitioning:
		await SceneTransition.finished

func key(code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await ticks()

func test_debug() -> void:
	GameRun.set_player_info("", "")
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await ticks(2)
	assert(menu.get_node("Center/Rows/Hard").text.contains("1.25"))
	for code in [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_X]:
		await key(code)
	assert(get_tree().current_scene == menu and not GameRun.debug_run, "A wrong command must not enter debug mode")
	var command: Array = menu.KONAMI.duplicate()
	for index in range(command.size()):
		if index == 2:
			await key(KEY_UP, true)
		await key(command[index])
	assert(GameRun.debug_run and GameRun.mode_name == "DEBUG" and GameRun.student_id.is_empty(), "Konami must work with focused inputs and no student ID; key repeats must be ignored")
	# Let the real queue accept writes while blocking its network calls, to catch debug leakage.
	var was_enabled := Leaderboard.enabled
	Leaderboard.enabled = true
	Leaderboard._busy = true
	var pending_count := Leaderboard.pending.size()
	GameRun.set_player_info("12345", "디버그")
	var level = get_tree().current_scene
	assert(level.is_boss_fight() and level.level_number == 6 and level.enemy_budget() == 0 and level.onboarding == null)
	assert(level.player.health == 5 and level.hud.get_node("Root/Top/%Stage").text == "DEBUG · BOSS TEST")
	assert(await level.spawn_enemy() == null and level.enemies.is_empty())
	level.set_process(false)
	level.player.set_physics_process(false)
	while not level.navigation_ready:
		await ticks()
	level.player.health = 1
	GameRun.health = 1
	level._schedule_heart(1)
	level._update_heart_drop(7)
	assert(is_instance_valid(level._heart), "Debug boss must include the real healing-item rules")
	level.canvas.gesture_finished.emit({"pattern_id": &"heart"}, 0, 1)
	assert(level.player.health == 2 and level._heart == null)
	for cycle in range(ceili(float(level.MAX_BOSS_HEALTH) / level.WINDOW_DAMAGE)):
		level._begin_window()
		assert(not &"heart" in level.attack_sequence)
		for id in level.attack_sequence.duplicate():
			level.canvas.gesture_finished.emit({"pattern_id": id}, 0, 1)
	assert(level.finished and level.boss_health == 0)
	while not level.hud.get_node("%Results").visible:
		await ticks()
	assert(Leaderboard.pending.size() == pending_count, "Debug boss completion must never enter the real score queue")
	assert(level.hud.get_node("Root/Results/%ResultTitle").text == "ALL CLEAR" and not level.hud.get_node("Root/Results/%Continue").visible)
	assert(level.hud.get_node("Root/Results/%ResultStage").text == "DEBUG · 보스 테스트")
	assert(level.hud.get_node("Root/Results/%RankingStatus").text.contains("디버그"))
	level._menu()
	level.hud.get_node("Root/MenuConfirmation/%ExitConfirm").pressed.emit()
	await ticks()
	Leaderboard.enabled = was_enabled
	Leaderboard._busy = false
	menu = get_tree().current_scene
	menu.student_id_input.text = "00123"
	menu._start(GameRun.Mode.HARD)
	await ticks()
	var normal = get_tree().current_scene
	normal.set_process(false)
	assert(not GameRun.debug_run and GameRun.mode_name == "HARD" and normal.enemy_budget() > 1)
	assert(GameRun.award(100) == 125, "A normal run must restore standard budgets and the new HARD reward multiplier")
	print("PASS: Konami/wrong/repeated-key handling, no-ID entry into one boss-only debug stage, real hearts and attack windows, DEBUG UI/results, no next stage or ranking writes, normal-mode reset")
	Music.stop()
	normal.queue_free()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
