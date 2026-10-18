extends Node

const HUD := preload("res://scripts/combat_hud.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	get_tree().create_timer(30.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_menus")

func tick() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(path) == OK)

func press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await tick()
	event.pressed = false
	Input.parse_input_event(event)
	await tick()

func test_menus() -> void:
	assert(HUD.format_number(0) == "0" and HUD.format_number(19862) == "19,862" and HUD.format_number(-1663) == "-1,663")
	assert(HUD.format_number(1234567890) == "1,234,567,890")
	assert(HUD.format_duration(59.99) == "00:59.9" and HUD.format_duration(60.0) == "01:00.0" and HUD.format_duration(166.3) == "02:46.3")
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await tick()
	menu.student_id_input.text = "11013"
	menu.name_input.text = "홍길동"
	menu._start(1)
	assert(SceneTransition.transitioning and get_tree().paused and get_tree().current_scene == menu)
	menu._start(2)
	assert(GameRun.mode == 1, "Repeated menu actions during the fade must not change the selected mode")
	# Step the short fade explicitly so first-use resource loading cannot skip its middle.
	SceneTransition._fade.pause()
	SceneTransition._fade.custom_step(0.08)
	assert(SceneTransition.get_node("Fade").color.a > 0.0 and SceneTransition.get_node("Fade").color.a < 1.0 and get_tree().current_scene == menu)
	if DisplayServer.get_name() != "headless":
		await capture("res://.godot/scene-fade-preview.png")
	SceneTransition._fade.play()
	await get_tree().scene_changed
	assert(get_tree().current_scene.mode == 1 and SceneTransition.get_node("Fade").color.a > 0.99 and get_tree().paused, "Scenes must swap only under a fully black fade")
	await SceneTransition.finished
	assert(not get_tree().paused and not SceneTransition.get_node("Fade").visible)
	var level = get_tree().current_scene
	level._spawn_time_left = 1000.0
	level.player.set_physics_process(false)
	level.level_number = 4
	GameRun.level_number = 4
	GameRun.combat_score = 21525
	GameRun.elapsed_seconds = 166.3
	GameRun.defeated = 62
	GameRun.combo_meter = 0.0
	level._update_hud()
	level._toggle_pause()
	assert(get_tree().paused and level.hud.get_node("%Paused").visible and not level.hud.get_node("Root/Top").visible)
	assert(level.hud.get_node("%Resume").has_focus() and level.hud.get_node("%PauseMenu").text == "메인 메뉴로")
	assert(level.hud.get_node("%Paused").material == level.hud.get_node("%Results").material)
	var frame_style: StyleBoxFlat = level.hud.get_node("%ResultTitle").get_parent().get_parent().get_theme_stylebox("panel")
	assert(frame_style.bg_color.r > frame_style.bg_color.g and frame_style.corner_radius_top_left == 0, "Use a plum pixel frame with warm gold ornament")
	var elapsed := GameRun.elapsed_seconds
	await get_tree().create_timer(0.25).timeout
	assert(GameRun.elapsed_seconds == elapsed)
	if DisplayServer.get_name() != "headless":
		await capture("res://.godot/pause-menu-preview.png")
		var first := get_viewport().get_texture().get_image()
		await get_tree().create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		var second := get_viewport().get_texture().get_image()
		var changed := 0
		for y in range(110, 500):
			for x in range(50, 250):
				var before := first.get_pixel(x, y)
				var after := second.get_pixel(x, y)
				if maxf(absf(before.r - after.r), maxf(absf(before.g - after.g), absf(before.b - after.b))) > 0.004:
					changed += 1
		assert(changed > 100, "The faint scrolling shader must keep moving while gameplay is paused")
	level.hud.get_node("%PauseMenu").grab_focus()
	level.hud.get_node("%PauseMenu").pressed.emit()
	assert(level.hud.get_node("%MenuConfirmation").visible and get_tree().paused and not SceneTransition.transitioning and GameRun.active)
	assert(level.hud.get_node("%ExitCancel").has_focus(), "Opening confirmation must focus the safe cancel action")
	level.hud.get_node("%Resume").pressed.emit()
	assert(get_tree().paused, "The pause menu behind confirmation must not resume gameplay")
	await press_key(KEY_TAB)
	assert(level.hud.get_node("%ExitConfirm").has_focus())
	await press_key(KEY_TAB)
	assert(level.hud.get_node("%ExitCancel").has_focus(), "Keyboard focus must stay inside the confirmation")
	await press_key(KEY_ESCAPE)
	assert(not level.hud.get_node("%MenuConfirmation").visible and get_tree().paused and level.hud.get_node("%PauseMenu").has_focus(), "Escape must close only confirmation and preserve pause/focus")
	level.hud.get_node("%PauseMenu").pressed.emit()
	level.hud.get_node("%ExitCancel").pressed.emit()
	assert(get_tree().paused and not level.hud.get_node("%MenuConfirmation").visible and GameRun.active)
	level.hud.get_node("%Resume").pressed.emit()
	assert(not get_tree().paused and level.hud.get_node("Root/Top").visible)
	level.set_process(false)
	GameRun.elapsed_seconds = 166.3
	GameRun.health = 0
	level.player.health = 0
	level._starting_score = 17703
	level.finish_level(false)
	await get_tree().create_timer(0.95).timeout
	var hud = level.hud
	assert(hud.find_child("Retry", true, false) == null, "The first-level retry action must be removed")
	assert(hud.get_node("%ResultTitle").text == "GAME OVER" and hud.get_node("%ResultTotal").text == "19,862")
	assert(hud.get_node("%ResultLevelScore").text == "+2,159점" and hud.get_node("%ResultCombatScore").text == "21,525점")
	assert(hud.get_node("%ResultPenalty").text == "-1,663점" and hud.get_node("%ResultElapsed").text == "02:46.3")
	assert(hud.get_node("%ResultIdentity").text == "학번 11013  ·  홍*동")
	assert(hud.get_node("%Menu").text == "메인 메뉴로" and hud.get_node("%Menu").has_focus() and not hud.get_node("%Continue").visible)
	var result_card: Control = hud.get_node("%ResultTitle").get_parent().get_parent()
	await tick()
	var bounds := result_card.get_global_rect()
	assert(bounds.position.y >= 15.0 and bounds.end.y <= 633.0 and bounds.position.x >= 0, "The result card must fit the default viewport: %s" % bounds)
	if DisplayServer.get_name() != "headless":
		await capture("res://.godot/game-over-preview.png")
	get_tree().root.size = Vector2i(1920, 1080)
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	await tick()
	assert(result_card.get_global_rect().get_center().distance_to(Vector2(960, 540)) < 1.0)
	get_tree().root.size = Vector2i(960, 540)
	get_tree().root.content_scale_size = Vector2i(960, 540)
	await tick()
	var scroll: ScrollContainer = hud.get_node("%Results").get_node("Margin/Scroll")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await tick()
	assert(hud.get_node("%Menu").get_global_rect().end.y <= 524.0, "The main-menu button must stay reachable in a short viewport")
	hud.get_node("%Menu").pressed.emit()
	assert(hud.get_node("%MenuConfirmation").visible and not SceneTransition.transitioning and get_tree().current_scene == level)
	hud.get_node("%Continue").pressed.emit()
	assert(GameRun.level_number == 4, "Confirmation must block the next-level action behind it")
	hud.get_node("%ExitCancel").pressed.emit()
	assert(not get_tree().paused and not hud.get_node("%MenuConfirmation").visible and hud.get_node("%Menu").has_focus(), "Cancel must restore the result screen's original unpaused state and focus")
	hud.get_node("%Menu").pressed.emit()
	await tick()
	if DisplayServer.get_name() != "headless":
		await capture("res://.godot/menu-exit-confirm-preview.png")
	hud.get_node("%ExitConfirm").pressed.emit()
	assert(SceneTransition.transitioning and get_tree().paused)
	await SceneTransition.finished
	assert(get_tree().current_scene.name == "MainMenu" and not get_tree().paused)
	menu = get_tree().current_scene
	menu.student_id_input.text = "11013"
	menu._start(0)
	await SceneTransition.finished
	level = get_tree().current_scene
	level._spawn_time_left = 1000.0
	level.finish_level(true)
	while not level.hud.get_node("%Results").visible:
		await tick()
	assert(level.hud.get_node("%Continue").visible and level.hud.get_node("%Continue").has_focus())
	var combat_score := GameRun.combat_score
	level.hud.get_node("%Continue").pressed.emit()
	level.hud.get_node("%Continue").pressed.emit()
	assert(GameRun.level_number == 2, "Repeated continue actions cannot skip levels")
	await SceneTransition.finished
	level = get_tree().current_scene
	assert(level.level_number == 2 and GameRun.combat_score == combat_score)
	level._toggle_pause()
	level.hud.get_node("%PauseMenu").pressed.emit()
	assert(get_tree().paused and not SceneTransition.transitioning and level.hud.get_node("%MenuConfirmation").visible)
	level.hud.get_node("%ExitConfirm").pressed.emit()
	level.hud.get_node("%ExitConfirm").pressed.emit()
	level.hud.get_node("%ExitCancel").pressed.emit()
	assert(SceneTransition.transitioning and get_tree().paused, "Repeated confirmation/cancel actions must not interrupt the scene fade")
	await SceneTransition.finished
	assert(get_tree().current_scene.name == "MainMenu" and not get_tree().paused)
	assert(get_tree().current_scene.student_id_input.has_focus(), "Scene fades must restore keyboard focus to the new menu")
	print("PASS: readable result records, responsive cards, animated suit-pattern background while paused, exit confirmation/cancel/Escape with focus trap and pause preservation, blocked background actions, scene fades and clear progression")
	get_tree().quit()
