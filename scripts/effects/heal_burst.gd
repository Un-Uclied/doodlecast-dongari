extends Node2D

func _ready() -> void:
	for index in range(33):
		$Ring.add_point(Vector2.from_angle(TAU * index / 32.0) * 10.0)
	$Sparks.restart()
	var tween := create_tween().set_parallel()
	tween.tween_property($Ring, "scale", Vector2(2.4, 2.4), 0.65).from(Vector2(0.3, 0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.65)
	tween.tween_property($Light, "energy", 0.0, 0.65)
	tween.chain().tween_callback(queue_free)
