extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(25.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_music")

func ticks() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if SceneTransition.transitioning:
		await SceneTransition.finished

func press_escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await ticks()

func check_loop() -> void:
	assert(Music.stream.loop, "Both MP3 imports must loop")
	Music.seek(Music.stream.get_length() - 0.1)
	await get_tree().create_timer(0.4).timeout
	assert(Music.playing and Music.get_playback_position() < 1.5, "Playback must wrap at the end of the track")

func check_ducked(since: float) -> void:
	await get_tree().create_timer(0.45).timeout
	assert(Music.playing and not Music.stream_paused, "Overlays must leave music playing")
	assert(Music.get_playback_position() > since, "Music must advance while an overlay is open")
	assert(is_equal_approx(Music.volume_db, Music.DUCKED_DB), "Overlay music must fade to the reduced volume")

func test_music() -> void:
	var music_id := Music.get_instance_id()
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	assert(Music.stream == Music.MENU_TRACK and Music.playing and Music.volume_db == -60.0)
	await get_tree().create_timer(0.2).timeout
	assert(Music.volume_db > -60.0 and Music.volume_db < Music.NORMAL_DB, "Menu music must fade in")
	await get_tree().create_timer(1.1).timeout
	assert(is_equal_approx(Music.volume_db, Music.NORMAL_DB))
	await check_loop()
	menu.get_node("%StudentId").text = "10101"
	menu._start(0)
	await ticks()
	var level = get_tree().current_scene
	level._spawn_time_left = 1000.0
	assert(Music.stream == Music.GAME_TRACK and Music.playing and Music.get_instance_id() == music_id)
	await check_loop()
	await get_tree().create_timer(1.0).timeout
	var enemy = await level.spawn_enemy(0)
	var before: Vector2 = enemy.global_position
	var position := Music.get_playback_position()
	level.hud.get_node("%PauseButton").pressed.emit()
	assert(get_tree().paused and level.hud.get_node("%Paused").visible and not level.canvas.input_enabled)
	await check_ducked(position)
	assert(enemy.global_position == before and not level.player.can_process(), "Pause must freeze gameplay")
	await press_escape()
	assert(not get_tree().paused and not level.hud.get_node("%Paused").visible and level.canvas.input_enabled)
	await get_tree().create_timer(0.4).timeout
	assert(is_equal_approx(Music.volume_db, Music.NORMAL_DB) and enemy.global_position != before)
	await press_escape()
	assert(get_tree().paused)
	level.hud.get_node("%Resume").pressed.emit()
	assert(not get_tree().paused)

	position = Music.get_playback_position()
	level.finish_level(false)
	await check_ducked(position)
	await press_escape()
	assert(not get_tree().paused and Music.ducked, "Escape on a result screen must not resume gameplay or restore volume")
	position = Music.get_playback_position()
	GameRun.begin_run(0)
	GameRun.open_level()
	await ticks()
	level = get_tree().current_scene
	level._spawn_time_left = 1000.0
	assert(Music.get_playback_position() >= position, "Retry must not restart the gameplay track")
	await get_tree().create_timer(0.4).timeout
	assert(is_equal_approx(Music.volume_db, Music.NORMAL_DB))

	position = Music.get_playback_position()
	level.finish_level(true)
	await check_ducked(position)
	position = Music.get_playback_position()
	level.hud.get_node("%Continue").pressed.emit()
	await ticks()
	level = get_tree().current_scene
	level._spawn_time_left = 1000.0
	assert(level.level_number == 2 and Music.get_playback_position() >= position, "Next level must preserve the music playback position")
	await get_tree().create_timer(0.4).timeout
	assert(is_equal_approx(Music.volume_db, Music.NORMAL_DB))
	GameRun.level_number = 6
	GameRun.open_level()
	await ticks()
	level = get_tree().current_scene
	level._spawn_time_left = 1000.0
	position = Music.get_playback_position()
	level.finish_level(true)
	await check_ducked(position)
	assert(level.hud.get_node("%ResultTitle").text == "ALL CLEAR")
	level.hud.get_node("%Menu").pressed.emit()
	level.hud.get_node("%ExitConfirm").pressed.emit()
	await ticks()
	assert(get_tree().current_scene.name == "MainMenu")
	get_tree().current_scene.student_id_input.text = "10101"
	get_tree().current_scene._start(0)
	await ticks()
	level = get_tree().current_scene
	level._spawn_time_left = 1000.0
	await press_escape()
	assert(get_tree().paused)
	level.hud.get_node("%PauseMenu").pressed.emit()
	level.hud.get_node("%ExitConfirm").pressed.emit()
	await ticks()
	assert(not get_tree().paused and get_tree().current_scene.name == "MainMenu")
	assert(Music.stream == Music.MENU_TRACK and Music.playing and Music.volume_db < Music.NORMAL_DB)
	print("PASS: menu fade-in, both tracks loop across their endings, persistent music through six levels/retry, game-over/clear/pause ducking without stopping, pause/resume/menu controls")
	get_tree().quit()
