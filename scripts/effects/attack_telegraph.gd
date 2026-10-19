extends Node2D

signal charged

@export var duration := 0.8
@export var radial_fill := false
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
	var start := points[0].x
	var end := points[0].x
	for point in points:
		start = minf(start, point.x)
		end = maxf(end, point.length() if radial_fill else point.x)
	$Fill.material.set_shader_parameter("radial_fill", radial_fill)
	$Fill.material.set_shader_parameter("fill_start", 0.0 if radial_fill else start)
	$Fill.material.set_shader_parameter("fill_end", end)
	$Fill.material.set_shader_parameter("progress", progress)

func _physics_process(delta: float) -> void:
	progress = minf(1.0, progress + delta / duration)
	$Fill.material.set_shader_parameter("progress", progress)
	if progress == 1.0:
		set_physics_process(false)
		charged.emit()
