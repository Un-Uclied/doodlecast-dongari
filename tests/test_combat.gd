extends Node

const LEVEL_SCRIPT := preload("res://scripts/level.gd")
const EXPECTED_DIFFICULTIES := [[1, 1, 2, 2, 3, 4], [2, 2, 3, 3, 4, 5], [3, 3, 4, 4, 5, 6]]

@onready var root: Window = get_tree().root

func _ready() -> void:
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(1152, 648)
	get_tree().create_timer(25.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_combat")

func ticks(count := 1) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame
	if SceneTransition.transitioning:
		await SceneTransition.finished

func test_combat() -> void:
	for mode in range(3):
		GameRun.begin_run(mode)
		assert(GameRun.award(100) == [75, 100, 125][mode])
		for number in range(1, 7):
			GameRun.level_number = number
			var scene := (load(GameRun.level_path()) as PackedScene).instantiate()
			assert(scene.difficulty == EXPECTED_DIFFICULTIES[mode][number - 1])
			assert(scene.level_number == number and scene.mode == mode)
			assert(scene.enemy_budget() == 12 + 2 * scene.difficulty + number, "Every level must add exactly four enemies")
			var old_interval: float = (4.0 - 0.4 * scene.difficulty) * (1.0 - 0.04 * (number - 1)) / GameRun.SPAWN_MULTIPLIERS[mode]
			if mode == GameRun.Mode.HARD:
				assert(is_equal_approx(scene.spawn_interval(), 2.0 - 0.1 * (number - 1)), "HARD must start at 2 seconds and reach 1.5 seconds gradually")
			else:
				assert(scene.spawn_interval() < old_interval * 0.85 and scene.spawn_interval() > 0.8 and scene.spawn_interval() < 1.7)
			assert(scene.has_node("Player") and scene.has_node("Enemies") and scene.has_node("HUD"))
			assert(scene.get_node("TileMapLayerFurniture").get_used_cells_by_id(LEVEL_SCRIPT.CLOSED_DOOR_SOURCE).size() == 1, "All 18 levels must inherit the edited exit door")
			scene.free()
	var rules := LEVEL_SCRIPT.new()
	rules.rng.seed = 417
	for difficulty in range(1, 8):
		rules.difficulty = difficulty
		for sample in range(200):
			var sequence: Array[StringName] = rules.generate_pattern()
			var hard := 0
			for symbol in sequence:
				assert(symbol in [&"horizontal", &"vertical", &"chevron_up", &"chevron_down", &"star", &"spiral"])
				if symbol in [&"star", &"spiral"]:
					hard += 1
			if difficulty == 1:
				assert(sequence.size() in [1, 2] and hard == 0)
			if difficulty == 7:
				assert(sequence.size() in [6, 7] and hard in [2, 3])
			assert(hard <= sequence.size())
	rules.mode = 1
	rules.difficulty = 2
	rules.level_number = 1
	var interval := rules.spawn_interval()
	var budget := rules.enemy_budget()
	rules.level_number = 2
	assert(rules.enemy_budget() > budget and rules.spawn_interval() < interval, "Repeated DIFF levels must still get harder")
	assert(rules.spawn_interval() / interval > 0.98, "The per-level acceleration must be gentler than the old four percent step")
	rules.free()
	for kind in ["soldier", "orc"]:
		var frames := load("res://resources/enemies/%s_frames.tres" % kind) as SpriteFrames
		assert(frames.get_frame_count("idle") == 6 and frames.get_frame_count("walk") == 8)

	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	get_tree().current_scene = menu
	await ticks(2)
	menu.get_node("%StudentId").text = "10101"
	menu.get_node("%StudentId").text_changed.emit("10101")
	menu.get_node("%PlayerName").text = "홍길동"
	menu.get_node("Center/Rows/Easy").pressed.emit()
	await ticks(2)
	var level = get_tree().current_scene
	while not level.navigation_ready:
		await get_tree().process_frame
	assert(level.mode == 0 and level.level_number == 1 and GameRun.combat_score == 0 and level.player.health == 5)
	level._spawn_time_left = 0.0
	await ticks(2)
	assert(level.spawned == 1 and level.enemies.is_empty() and level._pending_spawns.size() == 1, "Spawn warning must precede the enemy")
	while level.enemies.is_empty():
		await ticks()
	assert(level.spawned == 1 and level.enemies.size() == 1, "Timer must spawn an enemy")
	level._spawn_time_left = 1000.0
	level.player.set_physics_process(false)
	var first = level.enemies[0]
	first.get_node("Contact").monitoring = false
	var distance: float = first.global_position.distance_to(level.player.global_position)
	assert(distance > 90.0, "Spawns must leave reaction time")
	await ticks(30)
	assert(first.global_position.distance_to(level.player.global_position) < distance, "Enemies must chase over reachable floor")
	first.set_physics_process(false)
	first.pattern.assign([&"horizontal", &"vertical"])
	first.global_position = level.player.global_position + Vector2(40, 0)
	var second = await level.spawn_enemy(0)
	assert(second != null)
	second.set_physics_process(false)
	second.pattern.assign([&"horizontal", &"vertical"])
	second.global_position = level.player.global_position + Vector2(60, 0)
	assert(first.is_on_screen() and second.is_on_screen())
	var kill_points := roundi(first.reward * 0.75 * 1.1) + roundi(second.reward * 0.75 * 1.1)
	level.canvas.gesture_finished.emit({"pattern_id": &"star"}, 0, 1)
	assert(first.pattern.size() == 2 and second.pattern.size() == 2, "Wrong symbols must not consume a pattern")
	level.canvas.gesture_finished.emit({"pattern_id": &"horizontal"}, 0, 1)
	assert(first.pattern == [&"vertical"] and second.pattern == [&"vertical"], "One gesture consumes one symbol on every matching visible enemy")
	assert(GameRun.combat_score == 0, "Only a completed sequence awards a kill")
	level.canvas.gesture_finished.emit({"pattern_id": &"vertical"}, 0, 1)
	await ticks(2)
	assert(not is_instance_valid(first) and not is_instance_valid(second))
	assert(GameRun.combat_score == kill_points and GameRun.defeated == 2)
	var distant = await level.spawn_enemy(0)
	distant.set_physics_process(false)
	distant.pattern.assign([&"horizontal"])
	distant.global_position = Vector2(10000, 10000)
	kill_points += roundi(distant.reward * 0.75 * 1.1)
	level.canvas.gesture_finished.emit({"pattern_id": &"horizontal"}, 0, 1)
	assert(distant.resolved and distant.pattern.is_empty(), "Patterns must damage matching enemies at any distance, including offscreen")
	var contact = await level.spawn_enemy(0)
	# Timed hurt immunity is covered by test_player and test_combat_flow.
	level.player.hurt_invulnerability_duration = 0.0
	contact.set_physics_process(false)
	contact.global_position = level.player.global_position
	await ticks(3)
	assert(not is_instance_valid(contact) and level.player.health == 4 and not level.player.is_dead)
	assert(GameRun.health == 4 and GameRun.combat_score == kill_points, "Touch must hurt once and grant no score")
	level.player.dash_time_left = 0.24
	contact = await level.spawn_enemy(0)
	contact.speed = 0.0
	contact.global_position = level.player.global_position
	await ticks(3)
	assert(is_instance_valid(contact) and not contact.resolved and level.player.health == 4, "Dash immunity must preserve both the player and the enemy")
	var contact_position: Vector2 = level.player.global_position
	level.player.global_position += Vector2(40, 0)
	await ticks(3)
	level.player.dash_time_left = 0.0
	await ticks(3)
	assert(is_instance_valid(contact) and level.player.health == 4, "Passing through an enemy during a dash must leave it alive")
	level.player.dash_time_left = 0.24
	level.player.global_position = contact_position
	await ticks(3)
	assert(is_instance_valid(contact) and level.player.health == 4)
	level.player.dash_time_left = 0.0
	await ticks(3)
	assert(not is_instance_valid(contact) and level.player.health == 3, "Contact must be rechecked when immunity ends while still overlapping")
	for hit in range(3):
		contact = await level.spawn_enemy(0)
		assert(contact != null)
		contact.set_physics_process(false)
		contact.global_position = level.player.global_position
		await ticks(3)
	assert(level.finished and level.player.is_dead and GameRun.health == 0)
	await get_tree().create_timer(0.4).timeout
	assert(level.hud.get_node("%ResultTitle").text == "GAME OVER")
	assert(level.hud.get_node("%Results").visible and not level.canvas.input_enabled)
	assert(level.hud.get_node("%ResultCombatScore").text == level.hud.format_number(kill_points) + "점")
	assert(level.hud.get_node("%ResultIdentity").text.contains("10101") and level.hud.get_node("%ResultIdentity").text.contains("홍*동"))

	GameRun.begin_run(1)
	GameRun.health = 3
	GameRun.combat_score = 1000
	GameRun.open_level()
	await ticks(2)
	level = get_tree().current_scene
	while not level.navigation_ready:
		await get_tree().process_frame
	level._spawn_time_left = 1000.0
	assert(level.player.health == 3)
	level.spawned = level.enemy_budget() - 1
	var last = await level.spawn_enemy(0)
	last.pattern.assign([&"horizontal"])
	var expected: int = GameRun.total_score + last.reward + 250 * level.difficulty
	last.consume_pattern(&"horizontal")
	await ticks(2)
	assert(level.finished and level.hud.get_node("%ResultTitle").text == "LEVEL CLEAR")
	assert(level.hud.get_node("%Continue").visible and GameRun.total_score == expected)
	var earned := GameRun.combat_score
	var elapsed := GameRun.elapsed_seconds
	level.hud.get_node("%Continue").pressed.emit()
	await ticks(2)
	level = get_tree().current_scene
	while not level.navigation_ready:
		await get_tree().process_frame
	level._spawn_time_left = 1000.0
	assert(level.level_number == 2 and level.difficulty == 2 and level.player.health == 3)
	assert(GameRun.combat_score == earned and GameRun.elapsed_seconds >= elapsed, "Next level must preserve earned points and elapsed combat time")
	GameRun.begin_run(2)
	GameRun.level_number = 6
	GameRun.combat_score = 2000
	GameRun.open_level()
	await ticks(2)
	level = get_tree().current_scene
	while not level.navigation_ready:
		await get_tree().process_frame
	level._spawn_time_left = 1000.0
	level.spawned = level.enemy_budget() - 1
	last = await level.spawn_enemy(0)
	last.pattern.assign([&"horizontal"])
	expected = GameRun.total_score + roundi(last.reward * 1.25) + roundi(250 * level.difficulty * 1.25)
	last.consume_pattern(&"horizontal")
	await ticks(2)
	assert(level.finished and level.hud.get_node("%ResultTitle").text == "ALL CLEAR")
	assert(not level.hud.get_node("%Continue").visible and GameRun.total_score == expected)
	assert(level.hud.get_node("%ResultTotal").text == level.hud.format_number(expected))
	level.hud.get_node("%Menu").pressed.emit()
	level.hud.get_node("%ExitConfirm").pressed.emit()
	await ticks(2)
	assert(get_tree().current_scene.name == "MainMenu")
	get_tree().current_scene.student_id_input.text = "10101"
	get_tree().current_scene._start(2)
	await ticks(2)
	assert(get_tree().current_scene.level_number == 1 and get_tree().current_scene.mode == 2)
	assert(GameRun.combat_score == 0 and GameRun.health == 5)
	get_tree().current_scene._toggle_pause()
	get_tree().current_scene.hud.get_node("%PauseMenu").pressed.emit()
	get_tree().current_scene.hud.get_node("%ExitConfirm").pressed.emit()
	await ticks(2)
	assert(get_tree().current_scene.name == "MainMenu")
	print("PASS: all 18 difficulty settings, DIFF 1/7 sequence limits, scaling, Soldier/Orc animations, menu/spawn/chase, ordered multi-target gestures at unlimited distance including offscreen, contact/despawn, five HP, dash immunity, score multipliers, game over, six-level progression, clear/retry/menu")
	get_tree().quit()
