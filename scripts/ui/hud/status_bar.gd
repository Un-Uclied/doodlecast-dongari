extends HBoxContainer

var _remaining_tween: Tween

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
