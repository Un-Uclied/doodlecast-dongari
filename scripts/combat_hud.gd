extends CanvasLayer

signal pause_requested

const FEEDBACK := {
	&"cast": {"color": Color(0.74, 0.42, 1.0), "caption": "시전 성공", "strength": 0.22, "duration": 0.3},
	&"fail": {"color": Color(1.0, 0.36, 0.16), "caption": "시전 실패", "strength": 0.4, "duration": 0.38},
	&"hit": {"color": Color(1.0, 0.86, 0.36), "caption": "적중 ×%d", "strength": 0.3, "duration": 0.26},
	&"kill": {"color": Color(1.0, 0.65, 0.12), "caption": "처치 ×%d", "strength": 0.52, "duration": 0.48},
	&"damage": {"color": Color(1.0, 0.08, 0.18), "caption": "피격 -1", "strength": 0.7, "duration": 0.55},
	&"heal": {"color": Color(0.65, 1.0, 0.42), "caption": "체력 +1", "strength": 0.42, "duration": 0.65},
}

var _remaining_tween: Tween
var _result_tween: Tween
var _action_tween: Tween
var _damage_tween: Tween
var _feedback_tween: Tween
var _menu_was_paused := false
var _menu_focus: Control

func _ready() -> void:
	%ExitCancel.pressed.connect(_cancel_menu)
	Leaderboard.status_changed.connect(_update_ranking_status)
	for button: Button in find_children("*", "Button", true, false):
		button.mouse_entered.connect(func():
			if not button.disabled:
				button.grab_focus())

func confirm_menu() -> void:
	if %MenuConfirmation.visible:
		return
	_menu_was_paused = get_tree().paused
	_menu_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	%MenuConfirmation.show()
	%ExitCancel.grab_focus()

func _cancel_menu() -> void:
	if SceneTransition.transitioning or not %MenuConfirmation.visible:
		return
	%MenuConfirmation.hide()
	get_tree().paused = _menu_was_paused
	if is_instance_valid(_menu_focus):
		_menu_focus.grab_focus()

static func format_number(value: int) -> String:
	var text := str(absi(value))
	for index in range(text.length() - 3, 0, -3):
		text = text.insert(index, ",")
	return ("-" if value < 0 else "") + text

static func format_duration(seconds: float) -> String:
	var tenths := floori(maxf(seconds, 0.0) * 10.0 + 0.000001)
	return "%02d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]

func set_results(cleared: bool, level_score: int) -> void:
	var final_clear := cleared and GameRun.level_number == 6
	%VictoryArt.visible = final_clear
	%ClearMessage.visible = final_clear
	%ResultTitle.text = "ALL CLEAR" if final_clear else ("LEVEL CLEAR" if cleared else "GAME OVER")
	%ResultTitle.modulate = Color(1, 0.86, 0.4) if final_clear else (Color(0.87, 0.67, 1) if cleared else Color(1, 0.76, 0.44))
	%ResultIdentity.text = "학번 " + GameRun.student_id
	if not GameRun.masked_name.is_empty():
		%ResultIdentity.text += "  ·  " + GameRun.masked_name
	%ResultIdentity.visible = not GameRun.student_id.is_empty()
	%ResultStage.text = "%s  ·  레벨 %d / 6" % [GameRun.mode_name, GameRun.level_number]
	%ResultTotal.text = format_number(GameRun.total_score)
	%ResultLevelScore.text = ("+" if level_score >= 0 else "") + format_number(level_score) + "점"
	%ResultCombatScore.text = format_number(GameRun.combat_score) + "점"
	%ResultElapsed.text = format_duration(GameRun.elapsed_seconds)
	%ResultPenalty.text = format_number(GameRun.time_score()) + "점"
	%ResultKills.text = format_number(GameRun.defeated) + "마리"
	%ResultHealth.text = "%d / 5" % GameRun.health
	%ResultModeMultiplier.text = "×%.2f" % GameRun.REWARD_MULTIPLIERS[GameRun.mode]
	%ResultComboMultiplier.text = "%s  ×%.1f" % [GameRun.COMBO_RANKS[GameRun.combo_rank], GameRun.combo_multiplier]
	%Continue.visible = cleared and not final_clear
	%RankingStatus.hide()
	_update_ranking_status()

func _update_ranking_status() -> void:
	%RankingStatus.text = "디버그 기록은 순위에 저장하지 않습니다." if GameRun.debug_run else Leaderboard.status

func show_results() -> void:
	if %Results.visible:
		return
	$Root/Top.hide()
	%CombatFeedback.hide()
	_reveal(%Results)
	if %ClearMessage.visible:
		var width := get_viewport().get_visible_rect().size.x
		%Confetti.position = Vector2(width * 0.5, -16)
		%Confetti.emission_rect_extents = Vector2(width * 0.5, 1)
		%Confetti.restart()
		%YaySound.play()
	_result_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_result_tween.tween_method(func(value: float): %ResultTotal.text = format_number(roundi(value)), 0.0, float(GameRun.total_score), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	(%Continue if %Continue.visible else %Menu).grab_focus()

func set_paused(paused: bool) -> void:
	if paused:
		_reveal(%Paused)
	else:
		%Paused.hide()
	$Root/Top.visible = not paused
	%CombatFeedback.visible = not paused and not %Results.visible
	%PauseStage.text = "%s  ·  레벨 %d / 6" % [GameRun.mode_name, GameRun.level_number]

func feedback(kind: StringName, count := 1) -> void:
	var preset: Dictionary = FEEDBACK[kind]
	var flash: ColorRect = %DamageFlash if kind == &"damage" else %ActionFlash
	var previous: Tween = _damage_tween if kind == &"damage" else _action_tween
	if previous != null:
		previous.kill()
	flash.material.set_shader_parameter("tint", preset.color)
	flash.material.set_shader_parameter("strength", preset.strength)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_property(flash.material, "shader_parameter/strength", 0.0, preset.duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if kind == &"damage":
		_damage_tween = tween
	else:
		_action_tween = tween
	if _feedback_tween != null:
		_feedback_tween.kill()
	%FeedbackText.text = preset.caption % count if kind in [&"hit", &"kill"] else preset.caption
	%FeedbackText.modulate = preset.color
	%FeedbackText.pivot_offset = %FeedbackText.size * 0.5
	%FeedbackText.scale = Vector2.ONE * (1.22 if kind in [&"kill", &"damage"] else 1.1)
	_feedback_tween = create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_feedback_tween.tween_property(%FeedbackText, "modulate:a", 0.0, preset.duration * 0.7).set_delay(preset.duration * 0.3)
	_feedback_tween.tween_property(%FeedbackText, "scale", Vector2.ONE, preset.duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _reveal(overlay: Control) -> void:
	overlay.modulate.a = 0.0
	overlay.show()
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(overlay, "modulate:a", 1.0, 0.16)

func update_combo() -> void:
	%ComboRank.text = "%s  ×%.1f" % [GameRun.COMBO_RANKS[GameRun.combo_rank], GameRun.combo_multiplier]
	%ComboGauge.value = GameRun.combo_meter

func pulse_remaining() -> void:
	if _remaining_tween != null:
		_remaining_tween.kill()
	# RemainingSlot keeps container relayout from resetting the label's animated scale.
	%Remaining.pivot_offset = %Remaining.size * 0.5
	%Remaining.scale = Vector2.ONE
	_remaining_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_remaining_tween.tween_property(%Remaining, "scale", Vector2(1.65, 1.65), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_remaining_tween.tween_property(%Remaining, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _input(event: InputEvent) -> void:
	if SceneTransition.transitioning:
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if %MenuConfirmation.visible:
			_cancel_menu()
		else:
			pause_requested.emit()
		get_viewport().set_input_as_handled()
