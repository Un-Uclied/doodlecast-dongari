extends ColorRect

const FORMAT := preload("res://scripts/ui/formatting.gd")
var _result_tween: Tween

func _ready() -> void:
	Leaderboard.status_changed.connect(_update_ranking_status)

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
	%ResultStage.text = "DEBUG · 보스 테스트" if GameRun.debug_run else "%s  ·  레벨 %d / 6" % [GameRun.mode_name, GameRun.level_number]
	%ResultTotal.text = FORMAT.format_number(GameRun.total_score)
	%ResultLevelScore.text = ("+" if level_score >= 0 else "") + FORMAT.format_number(level_score) + "점"
	%ResultCombatScore.text = FORMAT.format_number(GameRun.combat_score) + "점"
	%ResultElapsed.text = FORMAT.format_duration(GameRun.elapsed_seconds)
	%ResultPenalty.text = FORMAT.format_number(GameRun.time_score()) + "점"
	%ResultKills.text = FORMAT.format_number(GameRun.defeated) + "마리"
	%ResultHealth.text = "%d / 5" % GameRun.health
	%ResultModeMultiplier.text = "×%.2f" % GameRun.REWARD_MULTIPLIERS[GameRun.mode]
	%ResultComboMultiplier.text = "%s  ×%.1f" % [GameRun.COMBO_RANKS[GameRun.combo_rank], GameRun.combo_multiplier]
	%Continue.visible = cleared and not final_clear
	%RankingStatus.hide()
	_update_ranking_status()

func _update_ranking_status() -> void:
	%RankingStatus.text = "디버그 기록은 순위에 저장하지 않습니다." if GameRun.debug_run else Leaderboard.status

func show_results() -> void:
	if visible:
		return
	modulate.a = 0.0
	show()
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(self, "modulate:a", 1.0, 0.16)
	if %ClearMessage.visible:
		var width := get_viewport().get_visible_rect().size.x
		%Confetti.position = Vector2(width * 0.5, -16)
		%Confetti.emission_rect_extents = Vector2(width * 0.5, 1)
		%Confetti.restart()
		%YaySound.play()
	_result_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_result_tween.tween_method(func(value: float): %ResultTotal.text = FORMAT.format_number(roundi(value)), 0.0, float(GameRun.total_score), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	(%Continue if %Continue.visible else %Menu).grab_focus()
