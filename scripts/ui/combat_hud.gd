extends CanvasLayer

signal pause_requested

const FORMAT := preload("res://scripts/ui/formatting.gd")
const FEEDBACK := preload("res://scripts/ui/hud/combat_feedback.gd").FEEDBACK

@onready var status = $Root/Top
@onready var effects = $Root/CombatFeedback
@onready var results = $Root/Results
@onready var pause_screen = $Root/Paused
@onready var menu_confirmation = $Root/MenuConfirmation

func _ready() -> void:
	for button: Button in find_children("*", "Button", true, false):
		button.mouse_entered.connect(func():
			if not button.disabled:
				button.grab_focus())

static func format_number(value: int) -> String:
	return FORMAT.format_number(value)

static func format_duration(seconds: float) -> String:
	return FORMAT.format_duration(seconds)

func confirm_menu() -> void:
	menu_confirmation.open()

func set_results(cleared: bool, level_score: int) -> void:
	results.set_results(cleared, level_score)

func show_results() -> void:
	if results.visible:
		return
	status.hide()
	effects.hide()
	results.show_results()

func set_paused(paused: bool) -> void:
	if paused:
		_reveal(pause_screen)
	else:
		pause_screen.hide()
	status.visible = not paused
	effects.visible = not paused and not results.visible
	pause_screen.get_node("%PauseStage").text = "DEBUG · 보스 테스트" if GameRun.debug_run else "%s  ·  레벨 %d / 6" % [GameRun.mode_name, GameRun.level_number]

func feedback(kind: StringName, count := 1) -> void:
	effects.play_feedback(kind, count)

func update_combo() -> void:
	status.update_combo()

func pulse_remaining() -> void:
	status.pulse_remaining()

func _reveal(overlay: Control) -> void:
	overlay.modulate.a = 0.0
	overlay.show()
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(overlay, "modulate:a", 1.0, 0.16)

func _input(event: InputEvent) -> void:
	if SceneTransition.transitioning:
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if menu_confirmation.visible:
			menu_confirmation.cancel()
		else:
			pause_requested.emit()
		get_viewport().set_input_as_handled()
