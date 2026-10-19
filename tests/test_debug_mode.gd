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
	var menu = load("res://scenes/main_menu.tscn").instantiate()
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
	for number in range(1, 7):
		var level = get_tree().current_scene
		assert(level.level_number == number and GameRun.debug_run and level.enemy_budget() == 1)
		assert(level.player.health == 5 and level.hud.get_node("%Stage").text.begins_with("DEBUG"), "Each debug level must refill health and clearly identify the mode")
		while level.enemies.is_empty():
			await ticks()
		level.set_process(false)
		level.player.set_physics_process(false)
		var enemy = level.enemies[0]
		enemy.set_physics_process(false)
		enemy.get_node("Contact").monitoring = false
		assert(enemy.kind == number - 1 and level.spawned == 1 and level._pending_spawns.is_empty(), "Six debug levels must deterministically cover all six enemy kinds")
		assert(await level.spawn_enemy() == null, "Debug must never spawn a second enemy")
		level.player.health = 2
		GameRun.health = 2
		level.furniture.clear()
		enemy.pattern.assign([&"horizontal"])
		enemy.consume_pattern(&"horizontal")
		assert(level.finished and level.hud.get_node("%ResultStage").text.begins_with("DEBUG"))
		while not level.hud.get_node("%Results").visible:
			await ticks()
		assert(Leaderboard.pending.size() == pending_count, "Debug runs must never reach the real score queue, even with a valid student ID")
		if number < 6:
			level.hud.get_node("%Continue").pressed.emit()
			await ticks()
		else:
			assert(level.hud.get_node("%ResultTitle").text == "ALL CLEAR" and not level.hud.get_node("%Continue").visible)
			assert(level.hud.get_node("%RankingStatus").text.contains("디버그"))
			level._menu()
			level.hud.get_node("%ExitConfirm").pressed.emit()
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
	print("PASS: physical Konami keys through focused menu inputs, wrong/repeated-key rejection, no-ID debug entry, one deterministic enemy per level across all six kinds, health refill, DEBUG labels/results, no ranking writes, normal-mode reset, HARD x1.25")
	get_tree().quit()
