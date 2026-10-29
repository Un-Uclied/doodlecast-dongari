extends Node2D

const EXPLOSION := preload("res://scenes/effects/boss_explosion.tscn")
var level: Node2D
var polygon := PackedVector2Array()
var charge_duration := 1.0
var active_duration := 0.65
var explosive := false
var age := 0.0
var active := false
var _hit := false
@onready var _warning: Node2D = $Warning
@onready var _flame: Polygon2D = $Flame
@onready var _edge: Line2D = $Edge
@onready var _sparks: CPUParticles2D = $Embers

func _ready() -> void:
	assert(polygon.size() >= 3 and charge_duration > 0)
	_warning.points = polygon
	_warning.duration = charge_duration
	_warning.restart()
	_warning.charged.connect(_activate)
	_flame.polygon = polygon
	_edge.points = polygon.duplicate()
	_edge.add_point(polygon[0])
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	var samples := PackedVector2Array()
	for attempt in range(256):
		var point := bounds.position + Vector2(randf(), randf()) * bounds.size
		if Geometry2D.is_point_in_polygon(point, polygon):
			samples.append(point)
		if samples.size() == 64:
			break
	assert(not samples.is_empty())
	_sparks.emission_points = samples
	_sparks.amount = clampi(int(bounds.get_area() / 160.0), 16, 80)

func _activate() -> void:
	if level.finished:
		queue_free()
		return
	active = true
	_warning.hide()
	_flame.show()
	_edge.show()
	_sparks.restart()
	level._attack_impact()
	if explosive:
		var blast := EXPLOSION.instantiate()
		blast.radius = 26.0
		add_child(blast)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(level) or level.finished:
		queue_free()
		return
	age += delta
	if age >= charge_duration + active_duration:
		active = false
		_flame.hide()
		_edge.hide()
		_sparks.emitting = false
	if active:
		_flame.material.set_shader_parameter("flame_time", age)
		_flame.material.set_shader_parameter("fade", clampf((charge_duration + active_duration - age) / 0.15, 0.0, 1.0))
		if not _hit and Geometry2D.is_point_in_polygon(to_local(level.player.global_position + Vector2(0, -5)), polygon):
			_hit = level.player.take_damage()
	if age >= charge_duration + active_duration + _sparks.lifetime:
		queue_free()
