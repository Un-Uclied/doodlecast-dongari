extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	get_tree().create_timer(25.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_feedback")

func ticks(count := 1) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func expect_feedback(hud: CanvasLayer, kind: StringName, text: String) -> void:
	assert(hud.get_node("Root/CombatFeedback/%FeedbackText").text == text)
	var flash: ColorRect = hud.get_node("Root/CombatFeedback/%DamageFlash" if kind == &"damage" else "Root/CombatFeedback/%ActionFlash")
	assert(flash.material.get_shader_parameter("tint") == hud.FEEDBACK[kind].color)
	assert(is_equal_approx(flash.material.get_shader_parameter("strength"), hud.FEEDBACK[kind].strength))
	assert(flash.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(hud.get_node("Root/CombatFeedback/%FeedbackText").scale.x > 1.0)

func render_feedback(level: Node2D, kind: StringName) -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	var lit := get_viewport().get_texture().get_image()
	assert(lit.save_png("res://.godot/feedback-%s-preview.png" % kind) == OK)
	level.hud.get_node("%CombatFeedback").hide()
	await RenderingServer.frame_post_draw
	var background := get_viewport().get_texture().get_image()
	var edge := lit.get_pixel(8, 324)
	var base := background.get_pixel(8, 324)
	assert(absf(edge.r - base.r) + absf(edge.g - base.g) + absf(edge.b - base.b) > 0.04, "Each event must visibly tint the screen edges")
	assert(lit.get_pixel(576, 324).is_equal_approx(background.get_pixel(576, 324)), "The center must stay clear of the vignette")
	level.hud.get_node("%CombatFeedback").show()
	get_tree().paused = false

func test_feedback() -> void:
	GameRun.begin_run(GameRun.Mode.HARD)
	var level = load(GameRun.level_path()).instantiate()
	get_tree().root.add_child(level)
	level.set_process(false)
	level.player.set_physics_process(false)
	while not level.navigation_ready:
		await ticks()
	var hud: CanvasLayer = level.hud
	assert(hud.get_node("Root/CombatFeedback/%ActionFlash").material != hud.get_node("Root/CombatFeedback/%DamageFlash").material)
	var enemy = await level.spawn_enemy(0)
	var survivor = await level.spawn_enemy(1)
	for target in [enemy, survivor]:
		target.set_physics_process(false)
		target.get_node("Contact").monitoring = false
	enemy.pattern.assign([&"horizontal", &"vertical"])
	survivor.pattern.assign([&"star", &"horizontal"])
	level.canvas.gesture_finished.emit({"pattern_id": &"spiral"}, 0, 1)
	expect_feedback(hud, &"cast", "시전 성공")
	assert(not level.get_node("MagicFailSound").playing and level.player._shake_strength == 0.0)
	await render_feedback(level, &"cast")
	level.canvas.gesture_finished.emit({"pattern_id": &""}, 0, 1)
	expect_feedback(hud, &"fail", "시전 실패")
	await render_feedback(level, &"fail")
	level.canvas.gesture_finished.emit({"pattern_id": &"horizontal"}, 0, 1)
	expect_feedback(hud, &"hit", "적중 ×1")
	assert(level.player._shake_strength >= 1.5 and enemy.pattern == [&"vertical"])
	await render_feedback(level, &"hit")
	level.player._shake_strength = 0.0
	level.canvas.gesture_finished.emit({"pattern_id": &"vertical"}, 0, 1)
	expect_feedback(hud, &"kill", "처치 ×1")
	assert(level.player._shake_strength >= 3.9 and enemy.resolved and not level.finished)
	await render_feedback(level, &"kill")
	level.player._shake_strength = 0.0
	assert(level.player.take_damage())
	expect_feedback(hud, &"damage", "피격 -1")
	assert(level.player._shake_strength >= 5.0)
	await render_feedback(level, &"damage")
	var red: float = hud.get_node("Root/CombatFeedback/%DamageFlash").material.get_shader_parameter("strength")
	level.canvas.gesture_finished.emit({"pattern_id": &"star"}, 0, 1)
	expect_feedback(hud, &"hit", "적중 ×1")
	assert(hud.get_node("Root/CombatFeedback/%DamageFlash").material.get_shader_parameter("strength") == red, "Attack feedback must not erase the independent damage rim")
	assert(not level.player.take_damage(), "Rejected damage must not trigger another damage flash")
	level.player.shake_camera(100.0)
	assert(level.player._shake_strength == 10.0, "Large multi-kills must cap camera shake")
	level._toggle_pause()
	var paused: float = hud.get_node("Root/CombatFeedback/%ActionFlash").material.get_shader_parameter("strength")
	await get_tree().create_timer(0.12).timeout
	assert(not hud.get_node("%CombatFeedback").visible and hud.get_node("Root/CombatFeedback/%ActionFlash").material.get_shader_parameter("strength") == paused)
	level._toggle_pause()
	await get_tree().create_timer(0.7).timeout
	assert(hud.get_node("Root/CombatFeedback/%ActionFlash").material.get_shader_parameter("strength") == 0.0)
	assert(hud.get_node("Root/CombatFeedback/%DamageFlash").material.get_shader_parameter("strength") == 0.0)
	assert(hud.get_node("Root/CombatFeedback/%FeedbackText").modulate.a == 0.0 and hud.get_node("Root/CombatFeedback/%FeedbackText").scale == Vector2.ONE)
	assert(level.player.get_node("Camera2D").offset == Vector2.ZERO)
	level.finish_level(false)
	await get_tree().create_timer(0.4).timeout
	assert(not hud.get_node("%CombatFeedback").visible)
	level.queue_free()
	await ticks(2)
	print("PASS: actual cast/fail/hit/kill/damage events have distinct captions and colored edge feedback, clear center, independent damage rim, stronger hit/kill/hurt shake with cap/recovery, pause freeze, no input blocking, result cleanup")
	Music.stop()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
