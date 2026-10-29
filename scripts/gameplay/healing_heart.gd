extends Node2D

var pattern: Array[StringName] = [&"heart"]

func _ready() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property($Sprite, "position:y", -15.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Sprite, "position:y", -11.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
