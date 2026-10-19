extends Control

const KONAMI := [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]
var _command: Array[int] = []

@onready var student_id_input: LineEdit = %StudentId
@onready var name_input: LineEdit = %PlayerName
@onready var _logo_height: float = $Center/Rows/TextureRect.custom_minimum_size.y

func _ready() -> void:
	Music.play_track(Music.MENU_TRACK)
	$Center/Rows/Easy.pressed.connect(_start.bind(GameRun.Mode.EASY))
	$Center/Rows/Normal.pressed.connect(_start.bind(GameRun.Mode.NORMAL))
	$Center/Rows/Hard.pressed.connect(_start.bind(GameRun.Mode.HARD))
	%Tutorial.pressed.connect(_open_tutorial)
	student_id_input.text_changed.connect(_on_student_id_changed)
	_on_student_id_changed(student_id_input.text)
	student_id_input.grab_focus()
	resized.connect(_fit_logo)
	call_deferred("_fit_logo")
	for button: Button in [$Center/Rows/Easy, $Center/Rows/Normal, $Center/Rows/Hard, %Tutorial]:
		button.mouse_entered.connect(func():
			if not button.disabled:
				button.grab_focus())
	$Center/Rows.modulate.a = 0.0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property($Center/Rows, "modulate:a", 1.0, 0.25)

func _fit_logo() -> void:
	var logo: TextureRect = $Center/Rows/TextureRect
	var other_height: float = $Center/Rows.get_combined_minimum_size().y - logo.custom_minimum_size.y
	logo.custom_minimum_size.y = clampf(size.y - other_height - 32.0, 0.0, _logo_height)

func _input(event: InputEvent) -> void:
	if SceneTransition.transitioning or not event is InputEventKey or not event.pressed or event.echo:
		return
	_command.append(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	if _command.size() > KONAMI.size():
		_command.pop_front()
	if _command == KONAMI:
		get_viewport().set_input_as_handled()
		GameRun.set_player_info(student_id_input.text, name_input.text)
		GameRun.begin_run(GameRun.Mode.NORMAL, true)
		GameRun.open_level()

func _is_valid_student_id(text: String) -> bool:
	if text.length() != 5:
		return false
	for digit in text:
		if digit < "0" or digit > "9":
			return false
	return true

func _update_start_state(text: String) -> void:
	for button in [$Center/Rows/Easy, $Center/Rows/Normal, $Center/Rows/Hard]:
		button.disabled = not _is_valid_student_id(text)

func _on_student_id_changed(text: String) -> void:
	var digits := ""
	var caret := 0
	for index in range(text.length()):
		if text[index] >= "0" and text[index] <= "9" and digits.length() < 5:
			digits += text[index]
			if index < student_id_input.caret_column:
				caret += 1
	if text != digits:
		student_id_input.text = digits
		student_id_input.caret_column = caret
	_update_start_state(digits)

func _start(mode: int) -> void:
	if SceneTransition.transitioning:
		return
	if not _is_valid_student_id(student_id_input.text):
		student_id_input.grab_focus()
		return
	GameRun.set_player_info(student_id_input.text, name_input.text)
	GameRun.begin_run(mode)
	GameRun.open_level()

func _open_tutorial() -> void:
	if not SceneTransition.transitioning:
		SceneTransition.change_scene("res://scenes/tutorial.tscn")
