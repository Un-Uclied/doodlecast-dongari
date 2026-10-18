extends CharacterBody2D

signal removed(enemy: Node2D, defeated: bool)

enum Kind { SOLDIER, ORC, BOMB_WALKER, BAT, FLOATING_EYE }

const FRAMES := [preload("res://resources/enemies/soldier_frames.tres"), preload("res://resources/enemies/orc_frames.tres"), preload("res://resources/enemies/bomb_walker_frames.tres"), preload("res://resources/enemies/bat_frames.tres"), preload("res://resources/enemies/floating_eye_frames.tres")]
const CATALOG := preload("res://resources/patterns/catalog.tres")
const PROJECTILE := preload("res://scenes/enemy_projectile.tscn")

@export var kind: Kind = Kind.SOLDIER
## Special kinds always opt out of ordinary mob spacing.
@export var maintain_spacing := true
@export_range(8.0, 64.0, 1.0, "suffix:px") var separation_distance := 24.0

var pattern: Array[StringName] = []
var speed := 52.0
var reward := 100
var level: Node2D
var resolved := false
var _path := PackedVector2Array()
var _path_time_left := 0.0
var _age := 0.0
var _shot_time_left := 0.0
var _volley_angle := 0.0
var _facing := "south"
var _attack_time_left := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite

func _ready() -> void:
	sprite.sprite_frames = FRAMES[kind]
	if kind >= Kind.BOMB_WALKER:
		maintain_spacing = false
		collision_mask = 1
		sprite.material = null
		sprite.offset = Vector2(16, 16) - sprite.sprite_frames.get_meta("pivot")
	if kind == Kind.BOMB_WALKER:
		speed = 190.0
	elif kind == Kind.BAT:
		collision_layer = 0
		collision_mask = 0
		$CollisionShape2D.disabled = true
	elif kind == Kind.FLOATING_EYE:
		speed = 65.0
	_animate(Vector2.DOWN)
	$Contact.body_entered.connect(_on_contact)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if resolved or level == null or level.finished:
		return
	if $Contact.overlaps_body(level.player):
		_on_contact(level.player)
		if resolved:
			return
	_age += delta
	_attack_time_left = maxf(0.0, _attack_time_left - delta)
	if kind == Kind.BAT:
		_orbit_player(delta)
		return
	if kind == Kind.FLOATING_EYE and _age >= 1.0:
		velocity = Vector2.ZERO
		_shot_time_left -= delta
		if _shot_time_left <= 0.0:
			_fire_volley()
			_shot_time_left += 1.1
		_animate(level.player.global_position - global_position)
		return
	_chase_player(delta)

func _chase_player(delta: float) -> void:
	var target: Vector2 = level.player.global_position
	var walls := PhysicsShapeQueryParameters2D.new()
	walls.shape = $CollisionShape2D.shape
	walls.transform = $CollisionShape2D.global_transform
	walls.motion = target - global_position
	walls.collision_mask = 1
	# Only walls should trigger a path detour.
	if level.is_floor_segment(global_position, target) and get_world_2d().direct_space_state.cast_motion(walls)[0] == 1.0:
		_path.clear()
		_path_time_left = 0.0
	else:
		_path_time_left -= delta
		if _path_time_left <= 0.0:
			_path = level.path_to_player(global_position)
			_path_time_left = 0.25
		while not _path.is_empty() and global_position.distance_to(_path[0]) < 2.0:
			_path.remove_at(0)
		target = global_position if _path.is_empty() else _path[0]
	velocity = Vector2.ZERO
	var distance := global_position.distance_to(target)
	if distance > 0.0:
		velocity = global_position.direction_to(target) * minf(speed, distance / delta)
	if maintain_spacing:
		_apply_spacing(delta)
	_animate(velocity)
	move_and_slide()

func _orbit_player(delta: float) -> void:
	var offset: Vector2 = global_position - level.player.global_position
	var radius := maxf(0.0, offset.length() - 64.0 * delta)
	var angle := offset.angle() + minf(1.8, 110.0 / maxf(radius, 1.0)) * delta
	var target: Vector2 = level.player.global_position + Vector2.from_angle(angle) * radius
	velocity = (target - global_position) / delta
	global_position = target
	_animate(velocity)

func _animate(direction: Vector2) -> void:
	if kind <= Kind.ORC:
		if velocity.x != 0.0:
			sprite.flip_h = velocity.x < 0.0
		sprite.play("walk" if velocity != Vector2.ZERO else "idle")
		return
	if direction != Vector2.ZERO:
		_facing = "north" if direction.y < 0.0 else "south"
		if absf(direction.x) > absf(direction.y):
			_facing = "west" if direction.x < 0.0 else "east"
	var action := "walk" if kind == Kind.BOMB_WALKER and velocity != Vector2.ZERO else "idle"
	if kind == Kind.FLOATING_EYE and _attack_time_left > 0.0:
		action = "attack"
	sprite.flip_h = false
	sprite.play(action + "_" + _facing)

func _fire_volley() -> void:
	_attack_time_left = 0.67
	var origin := hit_position()
	var aim := origin.angle_to_point(level.player.global_position + Vector2(0, -8))
	for index in range(5):
		var bullet := PROJECTILE.instantiate()
		bullet.level = level
		bullet.velocity = Vector2.from_angle(aim + _volley_angle + index * TAU / 5.0) * 80.0
		level.get_node("Projectiles").add_child(bullet)
		bullet.global_position = origin
	_volley_angle += 0.17

func hit_position() -> Vector2:
	return global_position + Vector2(0, sprite.offset.y)

func _apply_spacing(delta: float) -> void:
	for other in level.enemies:
		if other == self or other.resolved or not other.maintain_spacing:
			continue
		var offset: Vector2 = global_position - other.global_position
		var distance := offset.length()
		var gap := maxf(separation_distance, other.separation_distance)
		if distance > gap + speed * delta * 2.0:
			continue
		var away := offset / distance if distance > 0.001 else (Vector2.LEFT if get_instance_id() < other.get_instance_id() else Vector2.RIGHT)
		# Each mob can close only half the free gap, leaving room for its neighbor's step.
		var minimum_speed := (gap - distance) / (2.0 * delta)
		velocity += away * maxf(0.0, minimum_speed - velocity.dot(away))
	velocity = velocity.limit_length(speed)
	# A later neighbor's correction must not squeeze an earlier neighbor's gap.
	for other in level.enemies:
		if other == self or other.resolved or not other.maintain_spacing:
			continue
		var offset: Vector2 = global_position - other.global_position
		var gap := maxf(separation_distance, other.separation_distance)
		if (offset + velocity * delta).length_squared() < minf(gap * gap, offset.length_squared()):
			velocity = Vector2.ZERO
			return
	if not level.is_floor_segment(global_position, global_position + velocity * delta):
		velocity = Vector2.ZERO

func is_on_screen() -> bool:
	return get_viewport_rect().has_point(get_global_transform_with_canvas().origin)

func consume_pattern(pattern_id: StringName) -> bool:
	if resolved or pattern.is_empty() or pattern[0] != pattern_id:
		return false
	pattern.pop_front()
	sprite.modulate = Color(2.0, 2.0, 2.5)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.14)
	queue_redraw()
	if pattern.is_empty():
		_remove(true)
	return true

func _on_contact(body: Node2D) -> void:
	if resolved or level == null or level.finished or body != level.player:
		return
	if not body.take_damage():
		return
	_remove(false)

func _remove(defeated: bool) -> void:
	resolved = true
	removed.emit(self, defeated)
	queue_free()

func _draw() -> void:
	if pattern.is_empty():
		return
	var width := pattern.size() * 12.0 + 6.0
	draw_rect(Rect2(-width / 2.0, -35.0, width, 15.0), Color(0.07, 0.025, 0.09, 0.95))
	for index in range(pattern.size()):
		for definition in CATALOG.patterns:
			if definition.id != pattern[index]:
				continue
			var sample: PackedVector2Array = definition.samples[0]
			var bounds := Rect2(sample[0], Vector2.ZERO)
			for point in sample:
				bounds = bounds.expand(point)
			var icon_scale := 9.0 / maxf(bounds.size.x, bounds.size.y)
			var center := Vector2(-width / 2.0 + 9.0 + index * 12.0, -27.5)
			var stroke := PackedVector2Array()
			for point in sample:
				stroke.append(center + (point - bounds.get_center()) * icon_scale)
			var color := Color(1.0, 0.55, 0.7) if pattern[index] in [&"star", &"spiral"] else Color(0.85, 0.68, 1.0)
			if index == 0:
				color = Color(1.0, 0.88, 0.35)
			draw_polyline(stroke, color, 1.0, true)
			break
