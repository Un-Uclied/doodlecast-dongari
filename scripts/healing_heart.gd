extends Node2D

func _ready() -> void:
	var sample: PackedVector2Array = preload("res://resources/patterns/heart.tres").samples[0]
	var bounds := Rect2(sample[0], Vector2.ZERO)
	for point in sample:
		bounds = bounds.expand(point)
	var stroke := PackedVector2Array()
	for point in sample:
		stroke.append((point - bounds.get_center()) * (9.0 / maxf(bounds.size.x, bounds.size.y)))
	$Pattern/Icon.points = stroke
	var tween := create_tween().set_loops()
	tween.tween_property($Sprite, "position:y", -15.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Sprite, "position:y", -11.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
