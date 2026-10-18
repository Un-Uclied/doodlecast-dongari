extends Sprite2D

const TRAIL_LIFETIME := 0.14

@onready var _player = get_parent()
@onready var _sprite: AnimatedSprite2D = $"../Sprite"
@onready var _tip: Marker2D = $Marker2D
@onready var _orbit_radius: float = position.distance_to(_sprite_center())

var _trail_world := PackedVector2Array()
var _trail_ages := PackedFloat32Array()

func _process(delta: float) -> void:
	var active: bool = not _player.is_dead and _player.is_physics_processing()
	if active:
		aim_at(get_global_mouse_position())
	_update_trail(delta, active)

func aim_at(mouse_world: Vector2) -> void:
	var center := _sprite_center()
	var direction: Vector2 = _player.to_local(mouse_world) - center
	if direction.is_zero_approx():
		return
	position = center + direction.normalized() * _orbit_radius
	rotation = direction.angle()
	show_behind_parent = direction.y < 0.0

func _sprite_center() -> Vector2:
	var center := _sprite.offset
	if not _sprite.centered:
		center += _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame).get_size() * 0.5
	return _player.to_local(_sprite.to_global(center))

func _update_trail(delta: float, active: bool) -> void:
	$Marker2D/Sparks.emitting = active
	for index in range(_trail_ages.size()):
		_trail_ages[index] += delta
	while not _trail_ages.is_empty() and _trail_ages[0] >= TRAIL_LIFETIME:
		_trail_ages.remove_at(0)
		_trail_world.remove_at(0)
	if active:
		var point := _tip.global_position
		if not _trail_world.is_empty() and point.distance_to(_trail_world[-1]) > 64.0:
			_trail_world.clear()
			_trail_ages.clear()
		if _trail_world.is_empty() or point.distance_squared_to(_trail_world[-1]) > 0.0625:
			_trail_world.append(point)
			_trail_ages.append(0.0)
	var local_points := PackedVector2Array()
	for point in _trail_world:
		local_points.append(_tip.to_local(point))
	$Marker2D/TrailGlow.points = local_points
	$Marker2D/Trail.points = local_points
	var opacity := 1.0 - _trail_ages[-1] / TRAIL_LIFETIME if not _trail_ages.is_empty() else 0.0
	$Marker2D/TrailGlow.modulate.a = 0.25 * opacity
	$Marker2D/Trail.modulate.a = opacity
