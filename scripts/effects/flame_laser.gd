extends Area2D

@export var charge_duration := 0.8
@export var beam_width := 16.0
var caster: Node2D
var level: Node2D
var active := false
var beam_length := 0.0
var _flame_time := 0.0

func _ready() -> void:
	if not is_instance_valid(caster) or not is_instance_valid(level) or level.finished:
		stop()
		return
	beam_length = _wall_distance()
	if beam_length < 1.0:
		stop()
		return
	var half := beam_width * 0.5
	var polygon := PackedVector2Array([Vector2(0, -half), Vector2(beam_length, -half), Vector2(beam_length, half), Vector2(0, half)])
	$Hitbox.polygon = polygon
	$Flame.polygon = polygon
	$Flame.material.set_shader_parameter("beam_length", beam_length)
	$Flame.material.set_shader_parameter("half_width", half)
	$Warning.points = polygon
	$Warning.duration = charge_duration
	$Warning.restart()
	$Sparks.position.x = beam_length * 0.5
	$Sparks.emission_rect_extents = Vector2(beam_length * 0.5, half * 0.65)
	$Warning.charged.connect(_activate)

func _wall_distance() -> float:
	var rect: Rect2i = level.tiles.get_used_rect()
	var maximum: float = level.tiles.to_global(level.tiles.map_to_local(rect.position)).distance_to(level.tiles.to_global(level.tiles.map_to_local(rect.end))) + 32.0
	var direction := Vector2.RIGHT.rotated(global_rotation)
	var box := RectangleShape2D.new()
	box.size = Vector2(maximum, beam_width)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.transform = Transform2D(global_rotation, global_position + direction * maximum * 0.5)
	query.collision_mask = 1
	var space := get_world_2d().direct_space_state
	var scanned: Array[RID] = []
	var pits: Array[RID] = []
	# Pit tiles share the wall layer; exclude their bodies before sweeping the full beam width.
	while true:
		var hits := space.intersect_shape(query, 32)
		if hits.is_empty():
			break
		for hit in hits:
			if not hit.rid in scanned:
				scanned.append(hit.rid)
			if hit.collider == level.get_node("TileMapLayerPits") and not hit.rid in pits:
				pits.append(hit.rid)
		query.exclude = scanned
	box = RectangleShape2D.new()
	box.size = Vector2(0.1, beam_width)
	query.shape = box
	query.transform = Transform2D(global_rotation, global_position)
	query.exclude = pits
	if not space.intersect_shape(query, 1).is_empty():
		return 0.0
	query.motion = direction * maximum
	return maxf(0.0, space.cast_motion(query)[0] * maximum - 0.1)

func _activate() -> void:
	if not is_instance_valid(caster) or caster.resolved or level.finished:
		stop()
		return
	active = true
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
	set_physics_process(false)
	hide()
	queue_free()
