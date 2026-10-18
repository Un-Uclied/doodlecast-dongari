extends PointLight2D

var _time := randf() * TAU

func _process(delta: float) -> void:
	_time += delta
	energy = 0.6 + sin(_time * 9.0) * 0.035 + sin(_time * 17.0) * 0.02
