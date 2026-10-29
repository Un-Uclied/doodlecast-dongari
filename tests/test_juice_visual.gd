extends Node

func _ready() -> void:
	get_tree().create_timer(15.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_visuals")

func mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_tree().root.push_input(event, true)

func mouse_motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(event, true)

func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.save_png(path) == OK)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func test_visuals() -> void:
	assert(DisplayServer.get_name() != "headless", "Use a real renderer for the effects preview")
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	GameRun.begin_run(0)
	GameRun.combat_score = 2000
	GameRun.elapsed_seconds = 13.2
	var level := (load("res://scenes/levels_easy/level_01.tscn") as PackedScene).instantiate()
	level.get_node("Player/Camera2D").position_smoothing_enabled = false
	get_tree().root.add_child(level)
	level.set_process(false)
	level.player.set_physics_process(false)
	while not level.navigation_ready:
		await get_tree().process_frame
	var positions := [Vector2(-70, -12), Vector2(68, 5), Vector2(35, -52)]
	for index in range(3):
		var enemy = await level.spawn_enemy(0)
		enemy.set_physics_process(false)
		enemy.get_node("Contact").monitoring = false
		enemy.global_position = level.player.global_position + positions[index]
		enemy.sprite.sprite_frames = enemy.FRAMES[index % 2]
		enemy.sprite.play("idle")
		enemy.pattern.assign([&"star", &"vertical"] if index < 2 else [&"horizontal"])
		enemy.queue_redraw()
	level.canvas.get_node("Panel").hide()
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	var icons := get_viewport().get_texture().get_image()
	var vertical_transform: Transform2D = level.enemies[0].get_global_transform_with_canvas()
	var vertical_center := Vector2i(vertical_transform * Vector2(7, -36))
	assert(icons.get_pixelv(vertical_center).b > 0.5, "The vertical icon must be drawn in the center of its slot")
	for side in [-4, 4]:
		var margin := Vector2i(vertical_transform * Vector2(7 + side, -36))
		assert(icons.get_pixelv(margin).b < 0.2, "The vertical icon must leave equal clear margins")
	var horizontal_center := Vector2i(level.enemies[2].get_global_transform_with_canvas() * Vector2(0, -36))
	assert(icons.get_pixelv(horizontal_center).r > 0.5, "The horizontal icon must be vertically centered as well")
	var star = load("res://resources/patterns/star.tres")
	var sample: PackedVector2Array = star.samples[0]
	var origin := Vector2(840, 340)
	var point: Vector2 = origin + sample[0] * 180.0
	mouse_button(point, true)
	for index in range(1, sample.size()):
		point = origin + sample[index] * 180.0
		mouse_motion(point)
		await get_tree().create_timer(0.018).timeout
	await get_tree().create_timer(0.25).timeout
	assert(level.canvas.drawing and level.canvas.get_node("CursorParticles").emitting)
	assert(level.canvas.get_node("Stroke").get_point_count() > sample.size(), "The renderer must smooth sparse gesture corners")
	await capture("res://.godot/magic-trail-preview.png")
	for line in ["GlowStroke", "Stroke", "CoreStroke"]:
		level.canvas.get_node(line).hide()
	await RenderingServer.frame_post_draw
	var sparks := get_viewport().get_texture().get_image()
	level.canvas.get_node("CursorParticles").hide()
	await RenderingServer.frame_post_draw
	var background := get_viewport().get_texture().get_image()
	var visible_sparks := 0
	for y in range(int(point.y) - 48, int(point.y) + 48):
		for x in range(int(point.x) - 48, int(point.x) + 48):
			if sparks.get_pixel(x, y).b > background.get_pixel(x, y).b + 0.02:
				visible_sparks += 1
	assert(visible_sparks > 5, "Cursor particles must actually render around the screen-space mouse position")
	for line in ["GlowStroke", "Stroke", "CoreStroke", "CursorParticles"]:
		level.canvas.get_node(line).show()
	mouse_button(point, false)
	assert(level.canvas.last_result.pattern_id == &"star" and level.get_node("Effects").get_child_count() == 2)
	assert(not level.canvas.show_recognition_details and level.canvas.detail_label.text == "적 2마리 적중 · 0마리 처치", "Gameplay feedback must show hit counts instead of recognition diagnostics")
	level.player.take_damage()
	await get_tree().create_timer(0.12).timeout
	await capture("res://.godot/combat-juice-preview.png")
	await get_tree().create_timer(0.65).timeout
	assert(level.get_node("Effects").get_child_count() == 0 and not level.canvas.get_node("CursorParticles").emitting)
	assert(level.player.get_node("Camera2D").offset == Vector2.ZERO)
	level.player.global_position = Vector2(0, 230)
	level.player._hurt_invulnerability_left = 0.0
	level.player.set_physics_process(true)
	key(KEY_D, true)
	key(KEY_SHIFT, true)
	for frame in range(12):
		await get_tree().physics_frame
		await get_tree().process_frame
	key(KEY_SHIFT, false)
	key(KEY_D, false)
	level.player.set_physics_process(false)
	level.player.sprite.pause()
	for enemy in level.enemies:
		enemy.sprite.pause()
	var dash: CPUParticles2D = level.player.get_node("DashParticles")
	assert(dash.emitting and dash.direction == Vector2.LEFT)
	await capture("res://.godot/dash-particles-preview.png")
	var dash_image := get_viewport().get_texture().get_image()
	dash.hide()
	await RenderingServer.frame_post_draw
	var no_dash := get_viewport().get_texture().get_image()
	var center := Vector2i(level.player.get_global_transform_with_canvas().origin)
	var dash_pixels := 0
	for y in range(center.y - 50, center.y + 8):
		for x in range(center.x - 140, center.x - 20):
			if dash_image.get_pixel(x, y).b > no_dash.get_pixel(x, y).b + 0.03:
				dash_pixels += 1
	assert(dash_pixels > 20, "Dash particles must render a visible blue trail behind the moving player")
	print("PASS: centered icons, real pentagram gesture, smooth magic ink/cursor sparks, lightning, damage effects/shake cleanup, visible world-space dash particle trail; previews saved in .godot")
	get_tree().quit()
