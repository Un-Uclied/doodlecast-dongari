extends SceneTree

var _results: Array[Dictionary] = []

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(1152, 648)
	create_timer(10.0).timeout.connect(func(): quit(1))
	call_deferred("test_input")

func ticks(count := 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func mouse_button(point: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	# Headless windows use a dummy size, so inject mouse positions in viewport space.
	root.push_input(event, true)

func mouse_motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func test_input() -> void:
	var original_accumulation := Input.use_accumulated_input
	var map := (load("res://scenes/test_scene.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await ticks(2)
	var canvas = map.get_node("GestureCanvas/Canvas")
	var player = map.get_node("Player")
	canvas.gesture_finished.connect(func(result: Dictionary, started: int, completed: int):
		assert(completed >= started)
		_results.append(result))
	var start: Vector2 = player.position
	mouse_button(Vector2(200, 300), true)
	assert(canvas.drawing and not Input.use_accumulated_input)
	assert(canvas.get_node("CursorParticles").emitting and canvas.get_node("CursorParticles").position == Vector2(200, 300))
	key(KEY_D, true)
	await ticks(2)
	assert(player.position.x > start.x, "Drawing must allow WASD movement")
	assert(canvas.get_node("CursorParticles").get_global_transform_with_canvas().origin == Vector2(200, 300), "The cursor emitter must stay in screen space while the camera moves")
	key(KEY_SHIFT, true)
	await ticks()
	assert(player.is_invulnerable, "Drawing must allow dash")
	key(KEY_SHIFT, false)
	key(KEY_D, false)
	mouse_motion(Vector2(280, 300))
	mouse_button(Vector2(380, 300), false)
	assert(_results.size() == 1 and _results[0].pattern_id == &"horizontal")
	assert(not canvas.drawing and Input.use_accumulated_input == original_accumulation)
	assert(not canvas.get_node("CursorParticles").emitting, "Mouse release must stop cursor emission")
	var raw_points: PackedVector2Array = canvas.points.duplicate()
	canvas._refresh_trail()
	assert(canvas.points == raw_points, "Visual smoothing must never change recognizer input")
	assert(canvas.get_node("Stroke").width > 6.0 and canvas.get_node("Stroke").joint_mode == Line2D.LINE_JOINT_ROUND)
	assert(canvas.get_node("Stroke").begin_cap_mode == Line2D.LINE_CAP_ROUND and canvas.get_node("Stroke").end_cap_mode == Line2D.LINE_CAP_ROUND)
	assert(canvas.result_label.text.contains("가로선"))
	var blocker := Button.new()
	blocker.position = Vector2(450, 300)
	blocker.size = Vector2(100, 60)
	var ui := CanvasLayer.new()
	ui.layer = 20
	root.add_child(ui)
	ui.add_child(blocker)
	await process_frame
	mouse_motion(Vector2(475, 325))
	mouse_button(Vector2(475, 325), true)
	assert(not canvas.drawing, "UI must consume the start click")
	assert(not canvas.get_node("CursorParticles").emitting)
	mouse_button(Vector2(475, 325), false)
	ui.free()
	mouse_button(Vector2(200, 300), true)
	mouse_motion(Vector2(200, 380))
	mouse_button(Vector2(200, 380), true, MOUSE_BUTTON_RIGHT)
	mouse_button(Vector2(200, 380), false)
	assert(not canvas.drawing and _results.size() == 1, "Cancelled stroke must not produce a result")
	assert(not canvas.get_node("CursorParticles").emitting and canvas.get_node("Stroke").get_point_count() == 0)
	mouse_button(Vector2(200, 300), true)
	root.focus_exited.emit()
	assert(not canvas.drawing and Input.use_accumulated_input == original_accumulation)
	assert(not canvas.get_node("CursorParticles").emitting)
	mouse_button(Vector2(200, 300), false)
	mouse_button(Vector2(200, 300), true)
	paused = true
	await process_frame
	await process_frame
	assert(not canvas.drawing and Input.use_accumulated_input == original_accumulation)
	paused = false
	assert(not canvas.get_node("CursorParticles").emitting)
	mouse_button(Vector2(200, 300), false)
	Input.use_accumulated_input = false
	mouse_button(Vector2(200, 300), true)
	mouse_button(Vector2(200, 450), false)
	assert(_results.size() == 2 and _results[-1].pattern_id == &"vertical")
	assert(not Input.use_accumulated_input, "Restore the previous setting, not a hard-coded default")
	Input.use_accumulated_input = original_accumulation
	var original_minimum: float = canvas.min_stroke_size_percent
	var threshold_test_end := Vector2(200 + minf(canvas.size.x, canvas.size.y) * 0.15, 300)
	canvas.min_stroke_size_percent = 20.0
	mouse_button(Vector2(200, 300), true)
	mouse_button(threshold_test_end, false)
	assert(_results[-1].pattern_id == &"" and _results[-1].reason == &"invalid_input", "A stroke below the configured minimum must be rejected")
	canvas.min_stroke_size_percent = 10.0
	mouse_button(Vector2(200, 300), true)
	mouse_button(threshold_test_end, false)
	assert(_results.size() == 4 and _results[-1].pattern_id == &"horizontal", "Lowering the minimum must allow the same stroke")
	canvas.min_stroke_size_percent = original_minimum
	var check := PackedVector2Array([Vector2(650, 430), Vector2(690, 490), Vector2(830, 340)])
	var star := (load("res://resources/patterns/star.tres") as PatternDefinition).samples[0].duplicate()
	star[-1] = star[0].lerp(star[-2], 0.3)
	for i in range(star.size()):
		star[i] = (star[i] * Vector2(1.4, 1)).rotated(0.4) * 160 + Vector2(820, 300)
	for stroke in [check, star]:
		mouse_button(stroke[0], true)
		for i in range(1, stroke.size()):
			mouse_motion(stroke[i])
		mouse_button(stroke[-1], false)
	assert(_results.size() == 6 and _results[-2].pattern_id == &"chevron_down" and _results[-1].pattern_id == &"star", "Real mouse events must accept checks and tilted, wide, slightly unfinished stars")
	mouse_button(Vector2(200, 300), true)
	player.fall()
	assert(not canvas.drawing and not canvas.input_enabled)
	assert(not canvas.get_node("CursorParticles").emitting)
	assert(Input.use_accumulated_input == original_accumulation)
	mouse_button(Vector2(200, 450), false)
	assert(_results.size() == 6)
	map.free()
	print("PASS: mouse input, checks and tilted/unfinished stars, one result per stroke, concurrent movement/dash, UI blocking, cancel/focus/pause/death cleanup, input-setting restoration, configurable minimum size")
	quit()
