extends CanvasLayer

signal pause_requested

var _remaining_tween: Tween
var _result_tween: Tween
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
	%ResultTitle.text = "ALL CLEAR" if final_clear else ("LEVEL CLEAR" if cleared else "GAME OVER")
	%ResultTitle.modulate = Color(1, 0.86, 0.4) if final_clear else (Color(0.87, 0.67, 1) if cleared else Color(1, 0.76, 0.44))
	%ResultIdentity.text = "학번 " + GameRun.student_id
	if not GameRun.masked_name.is_empty():
		%ResultIdentity.text += "  ·  " + GameRun.masked_name
	%ResultIdentity.visible = not GameRun.student_id.is_empty()
	%ResultStage.text = "%s  ·  레벨 %d / 6" % [GameRun.MODE_NAMES[GameRun.mode], GameRun.level_number]
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
	%RankingStatus.visible = not cleared or final_clear
	_update_ranking_status()

func _update_ranking_status() -> void:
	%RankingStatus.text = Leaderboard.status

func show_results() -> void:
	if %Results.visible:
		return
	$Root/Top.hide()
	_reveal(%Results)
	_result_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_result_tween.tween_method(func(value: float): %ResultTotal.text = format_number(roundi(value)), 0.0, float(GameRun.total_score), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	(%Continue if %Continue.visible else %Menu).grab_focus()

func set_paused(paused: bool) -> void:
	if paused:
		_reveal(%Paused)
	else:
		%Paused.hide()
	$Root/Top.visible = not paused
	%PauseStage.text = "%s  ·  레벨 %d / 6" % [GameRun.MODE_NAMES[GameRun.mode], GameRun.level_number]

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
