extends Node

func _ready() -> void:
	get_tree().create_timer(15.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_menu")

func ticks() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if SceneTransition.transitioning:
		await SceneTransition.finished

func test_menu() -> void:
	for sample in [["", ""], ["김", "*"], ["김민", "김*"], ["홍길동", "홍*동"], [" 남궁민수 ", "남**수"]]:
		GameRun.set_player_info(" 00123 ", sample[0])
		assert(GameRun.student_id == "00123" and GameRun.masked_name == sample[1])
	GameRun.begin_run(1)
	assert(GameRun.student_id == "00123" and GameRun.masked_name == "남**수", "Retry must retain the masked player identity")
	GameRun.set_player_info("", "")
	var root := get_tree().root
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	get_tree().current_scene = menu
	var resolution := Vector2i(1152, 648)
	root.size = resolution
	root.content_scale_size = resolution
	await ticks()
	var rows := menu.get_node("Center/Rows") as Control
	var bounds := rows.get_global_rect()
	var panel := menu.get_node("Center") as Control
	assert(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= resolution.x and bounds.end.y <= resolution.y, "The full menu must fit the viewport: %s / %s" % [bounds, resolution])
	assert(bounds.get_center().distance_to(panel.get_global_rect().get_center()) < 1.0, "The container must keep the menu centered within its panel")
	assert(menu.student_id_input.has_focus())
	assert(menu.get_node("Center/Rows/Easy").disabled and menu.get_node("Center/Rows/Normal").disabled and menu.get_node("Center/Rows/Hard").disabled)
	menu._start(0)
	assert(get_tree().current_scene == menu, "An empty student ID must not start the game")
	assert(menu.student_id_input.max_length == 5)
	for invalid in ["", "   ", "1234", "abcde", "12a45", "+1234", "-1234", "12.34", " 1234", "1234 ", "１２３４５", "١٢٣٤٥"]:
		menu.student_id_input.text = invalid
		menu.student_id_input.text_changed.emit(invalid)
		for mode in ["Easy", "Normal", "Hard"]:
			assert(menu.get_node("Center/Rows/" + mode).disabled, "Only five ASCII digits may enable start: %s" % invalid)
		menu._start(0)
		assert(get_tree().current_scene == menu, "Invalid IDs must also be rejected by the start handler")
	for sample in [["123456789", "12345"], ["0a01b23", "00123"], ["a1!2?", "12"], ["한글１２١23", "23"]]:
		menu.student_id_input.text_changed.emit(sample[0])
		assert(menu.student_id_input.text == sample[1], "Input filtering must retain at most five ASCII digits")
	menu.student_id_input.text = "00123"
	menu.student_id_input.caret_column = 3
	menu.student_id_input.text_changed.emit("00a12")
	assert(menu.student_id_input.text == "0012" and menu.student_id_input.caret_column == 2, "Filtering must keep the caret by the same digits")
	for valid in ["00000", "12345", "00123"]:
		menu.student_id_input.text = valid
		menu.student_id_input.text_changed.emit(valid)
		for mode in ["Easy", "Normal", "Hard"]:
			assert(not menu.get_node("Center/Rows/" + mode).disabled)
	assert(menu.get_node("%NameHint").text.contains("홍*동"))
	assert(menu.get_node("Center/Rows/Normal").get_theme_font("font").resource_path == "res://fonts/Cafe24PROUP.ttf")
	assert(menu.student_id_input.get_theme_font("font").resource_path == "res://fonts/PF스타더스트 3.0 Bold.ttf")
	assert(menu.get_node("Center/Rows/Subtitle").get_theme_font("font").resource_path == "res://fonts/PF스타더스트 3.0 Bold.ttf")
	menu.get_node("Center/Rows/Hard").pressed.emit()
	await ticks()
	var level = get_tree().current_scene
	level._spawn_time_left = 1000.0
	assert(level.mode == 2 and GameRun.student_id == "00123" and GameRun.masked_name.is_empty(), "A valid student ID alone must be sufficient to play, preserving leading zeros")
	print("PASS: at most five ASCII digits while editing, mixed/pasted input filtered with caret preservation, exactly five required to start, leading zeros, optional masked name, fonts/layout and selected-mode start")
	get_tree().quit()
