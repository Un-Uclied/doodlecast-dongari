extends "res://scripts/gameplay/enemy_projectile.gd"

var turn_rate: float = 0.0
var tint: Color = Color(1.0, 0.78, 0.35)

func _ready() -> void:
	assert(velocity.is_finite() and is_finite(turn_rate))
	super._ready()
	_life_left = 4.0
	$Orb.modulate = tint
	$Glow.modulate = Color(tint, 0.28)

func _physics_process(delta: float) -> void:
	velocity = velocity.rotated(turn_rate * delta)
	super._physics_process(delta)
