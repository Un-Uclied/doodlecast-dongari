extends Node2D

var target_offset := Vector2.ZERO
var caster: Node2D
var target: Node2D
var _age := 0.0
var _flicker_left := 0.0

func _ready() -> void:
	$Impact.position = target_offset
	$Impact.restart()
	var impact := to_global(target_offset)
	$HitRing.top_level = true
	$HitRing.global_position = impact
	$Flash.top_level = true
	$Flash.global_position = impact
	var ring := PackedVector2Array()
	for index in range(33):
		ring.append(Vector2.from_angle(index * TAU / 32.0) * 12.0)
	$HitRing.points = ring
	_rebuild_arc()

func _process(delta: float) -> void:
	_age += delta
	if _age >= 0.4:
		queue_free()
		return
	var impact := to_global(target_offset)
	if is_instance_valid(caster):
		global_position = caster.global_position + Vector2(0, -12)
	if is_instance_valid(target):
		impact = target.hit_position()
	var previous_offset := target_offset
	target_offset = to_local(impact)
	_flicker_left -= delta
	if _flicker_left <= 0.0 or target_offset != previous_offset:
		_flicker_left = 0.035
		_rebuild_arc()
	for line: Line2D in [$Glow, $Arc, $Core]:
		line.modulate.a = maxf(0.0, 1.0 - _age / 0.24)
	$HitRing.scale = Vector2.ONE * (0.2 + _age * 3.5)
	$HitRing.modulate.a = maxf(0.0, 1.0 - _age / 0.32)
	$Flash.energy = maxf(0.0, 0.8 * (1.0 - _age / 0.2))

func _rebuild_arc() -> void:
	var points := PackedVector2Array([Vector2.ZERO])
	var segments := maxi(2, ceili(target_offset.length() / 10.0))
	var normal := target_offset.normalized().orthogonal()
	for index in range(1, segments):
		var progress := float(index) / segments
		points.append(target_offset * progress + normal * randf_range(-5.0, 5.0) * sin(progress * PI))
	points.append(target_offset)
	for line: Line2D in [$Glow, $Arc, $Core]:
		line.points = points
