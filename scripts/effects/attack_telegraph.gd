extends Node2D

signal charged

@export var duration := 0.8
@export var points := PackedVector2Array([Vector2(0, -8), Vector2(160, -8), Vector2(160, 8), Vector2(0, 8)])
var progress := 0.0

func _ready() -> void:
	restart()

func restart() -> void:
	assert(points.size() >= 3 and duration > 0.0)
	progress = 0.0
	set_physics_process(true)
	$Fill.polygon = points
	var outline := points.duplicate()
	outline.append(points[0])
	$Outline.points = outline
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var center := bounds.get_center()
	var radius := 0.0
	for point in points:
		radius = maxf(radius, center.distance_to(point))
	$Fill.material.set_shader_parameter("fill_center", center)
	$Fill.material.set_shader_parameter("fill_radius", radius)
	$Fill.material.set_shader_parameter("progress", progress)

func _physics_process(delta: float) -> void:
	progress = minf(1.0, progress + delta / duration)
	$Fill.material.set_shader_parameter("progress", progress)
	if progress == 1.0:
		set_physics_process(false)
		charged.emit()
