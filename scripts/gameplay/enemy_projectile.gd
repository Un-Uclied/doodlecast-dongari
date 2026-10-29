extends Area2D

var level: Node2D
var velocity := Vector2.ZERO
var _life_left := 6.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_life_left -= delta
	if level == null or level.finished or _life_left <= 0.0:
		queue_free()
		return
	position += velocity * delta

func _on_body_entered(body: Node2D) -> void:
	if level != null and body == level.get_node("TileMapLayerPits"):
		return
	if level != null and not level.finished and body == level.player:
		body.take_damage()
	queue_free()
