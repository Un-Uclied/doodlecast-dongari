extends Area2D

@export var charge_duration := 0.8
@export var beam_width := 16.0
@export var beam_length := 4096.0
var caster: Node2D
var level: Node2D
var active := false
var _flame_time := 0.0

func _ready() -> void:
	if not is_instance_valid(caster) or not is_instance_valid(level) or level.finished:
		stop()
		return
	var half := beam_width * 0.5
	var reach := beam_length * 0.5
	var polygon := PackedVector2Array([Vector2(-reach, -half), Vector2(reach, -half), Vector2(reach, half), Vector2(-reach, half)])
	$Hitbox.polygon = polygon
	$Flame.polygon = polygon
	$Flame.material.set_shader_parameter("beam_length", beam_length)
	$Flame.material.set_shader_parameter("half_width", half)
	$Warning.points = polygon
	$Warning.duration = charge_duration
	$Warning.restart()
	$Sparks.emission_rect_extents = Vector2(reach, half * 0.65)
	$Warning.charged.connect(_activate)
	$FireSound.stream = $FireSound.stream.duplicate()
	$FireSound.stream.loop = true
	$WarningSound.play()

func _activate() -> void:
	if not is_instance_valid(caster) or caster.resolved or level.finished:
		stop()
		return
	active = true
	$WarningSound.stop()
	$FireSound.play()
	$Warning.hide()
	$Flame.show()
	$Sparks.emitting = true
	$Light.enabled = true

func _physics_process(delta: float) -> void:
	if not is_instance_valid(caster) or caster.resolved or not caster.is_inside_tree() or not is_instance_valid(level) or level.finished:
		stop()
		return
	if active:
		_flame_time += delta
		$Flame.material.set_shader_parameter("flame_time", _flame_time)
		if overlaps_body(level.player):
			level.player.take_damage()

func stop() -> void:
	active = false
	$WarningSound.stop()
	$FireSound.stop()
	set_physics_process(false)
	hide()
	queue_free()
