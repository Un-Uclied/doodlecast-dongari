extends Node2D

var rage: float = 0.0
var _age: float = 0.0

func _process(delta: float) -> void:
	_age += delta
	$Glow.material.set_shader_parameter("aura_time", _age)
	$Glow.material.set_shader_parameter("rage", rage)
