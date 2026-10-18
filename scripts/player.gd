extends CharacterBody2D

signal died(by_falling: bool)
signal health_changed(current: int, maximum: int)

const MOVE_SPEED := 90.0
const DASH_SPEED := 300.0
const DASH_DURATION := 0.36
const DASH_COOLDOWN := 0.55
const MAX_HEALTH := 5

@export_range(0.0, 5.0, 0.1, "suffix:s") var hurt_invulnerability_duration := 1.0

@onready var sprite: AnimatedSprite2D = $Sprite

var is_dead := false
var health := MAX_HEALTH
var _damage_flash_left := 0.0
var _hurt_invulnerability_left := 0.0
var _shake_left := 0.0
var _shake_strength := 0.0
var facing := Vector2.DOWN
var dash_direction := Vector2.DOWN
var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var is_invulnerable: bool:
	get:
		return not is_dead and (dash_time_left > 0.0 or _hurt_invulnerability_left > 0.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	dash_time_left = maxf(0.0, dash_time_left - delta)
	dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
	_damage_flash_left = maxf(0.0, _damage_flash_left - delta)
	_hurt_invulnerability_left = maxf(0.0, _hurt_invulnerability_left - delta)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dash_time_left == 0.0:
		if direction != Vector2.ZERO:
			facing = direction
		if Input.is_action_just_pressed("dash") and dash_cooldown_left == 0.0:
			dash_direction = facing
			dash_time_left = DASH_DURATION
			dash_cooldown_left = DASH_COOLDOWN
			$DashSound.play()
	$DashParticles.direction = -dash_direction
	$DashParticles.emitting = dash_time_left > 0.0
	velocity = dash_direction * DASH_SPEED if dash_time_left > 0.0 else direction * MOVE_SPEED
	var suffix := "north" if facing.y < 0.0 else "south"
	if absf(facing.x) > absf(facing.y):
		suffix = "west" if facing.x < 0.0 else "east"
	sprite.modulate = Color(1.0, 0.8, 1.0, 0.65) if dash_time_left > 0.0 else Color.WHITE
	if _damage_flash_left > 0.0:
		sprite.modulate = Color(1.0, 0.35, 0.35)
	elif _hurt_invulnerability_left > 0.0:
		sprite.modulate.a = 0.35 if int(_hurt_invulnerability_left * 12.0) % 2 == 0 else 1.0
	sprite.play(("idle_" if velocity == Vector2.ZERO else "walk_") + suffix)
	move_and_slide()

func take_damage() -> bool:
	if is_dead or is_invulnerable:
		return false
	_hurt_invulnerability_left = hurt_invulnerability_duration
	$HurtSound.play()
	$DamageParticles.restart()
	shake_camera(2.8)
	health -= 1
	health_changed.emit(health, MAX_HEALTH)
	_damage_flash_left = 0.15
	if health == 0:
		_die(false)
	return true

func _process(delta: float) -> void:
	var previous_left := _shake_left
	_shake_left = maxf(0.0, _shake_left - delta)
	_shake_strength = _shake_strength * _shake_left / previous_left if previous_left > 0.0 else 0.0
	$Camera2D.offset = Vector2(randf_range(-_shake_strength, _shake_strength), randf_range(-_shake_strength, _shake_strength)) if _shake_left > 0.0 else Vector2.ZERO

func shake_camera(strength: float) -> void:
	_shake_strength += strength
	_shake_left = 0.28

func fall() -> void:
	if not is_dead:
		_die(true)

func _die(by_falling: bool) -> void:
	is_dead = true
	if health != 0:
		health = 0
		health_changed.emit(health, MAX_HEALTH)
	dash_time_left = 0.0
	_hurt_invulnerability_left = 0.0
	$DashParticles.emitting = false
	velocity = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.stop()
	died.emit(by_falling)
