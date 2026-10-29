extends Node2D

@export_range(8.0, 512.0, 1.0) var radius := 32.0
var _age := 0.0

func _ready() -> void:
	assert(radius > 0.0)
	var reach := radius * 1.1
	$Shockwave.polygon = PackedVector2Array([Vector2(-reach, -reach), Vector2(reach, -reach), Vector2(reach, reach), Vector2(-reach, reach)])
	$Shockwave.material.set_shader_parameter("radius", radius)
	$Sparks.emission_sphere_radius = minf(radius * 0.12, 14.0)
	$Sparks.initial_velocity_min = minf(radius * 1.8, 80.0)
	$Sparks.initial_velocity_max = minf(radius * 4.0, 160.0)
	$Smoke.emission_sphere_radius = minf(radius * 0.25, 32.0)
	$Flash.texture_scale = radius / 8.0
	$Sparks.restart()
	$Smoke.restart()

func _process(delta: float) -> void:
	_age += delta
	$Shockwave.material.set_shader_parameter("progress", minf(_age / 0.55, 1.0))
	$Flash.energy = maxf(0.0, 1.0 - _age / 0.18) * 0.65
	if _age >= 1.1:
		queue_free()
