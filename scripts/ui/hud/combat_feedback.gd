extends Control

const FEEDBACK := {
	&"cast": {"color": Color(0.74, 0.42, 1.0), "caption": "시전 성공", "strength": 0.22, "duration": 0.3},
	&"fail": {"color": Color(1.0, 0.36, 0.16), "caption": "시전 실패", "strength": 0.4, "duration": 0.38},
	&"hit": {"color": Color(1.0, 0.86, 0.36), "caption": "적중 ×%d", "strength": 0.3, "duration": 0.26},
	&"kill": {"color": Color(1.0, 0.65, 0.12), "caption": "처치 ×%d", "strength": 0.52, "duration": 0.48},
	&"damage": {"color": Color(1.0, 0.08, 0.18), "caption": "피격 -1", "strength": 0.7, "duration": 0.55},
	&"heal": {"color": Color(0.65, 1.0, 0.42), "caption": "체력 +1", "strength": 0.42, "duration": 0.65},
}

var _action_tween: Tween
var _damage_tween: Tween
var _feedback_tween: Tween

func play_feedback(kind: StringName, count := 1) -> void:
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
