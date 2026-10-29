extends Control

@export_range(1.0, 6.0, 0.1) var duration := 3.2
var _age: float = 0.0

func _process(delta: float) -> void:
	_age += delta
	$Backdrop.material.set_shader_parameter("pattern_time", _age)

func _ready() -> void:
	$Knight.resized.connect(_fit_aura)
	for element: Control in [$Mage, $Knight, $Seal]:
		element.modulate.a = 0.0
	$Seal.scale = Vector2(1.3, 1.3)
	call_deferred("_reveal")

func _reveal() -> void:
	_fit_aura()
	var tween := create_tween().set_parallel()
	for portrait: Control in [$Mage, $Knight]:
		var destination := portrait.position.x
		portrait.position.x += -64.0 if portrait == $Mage else 64.0
		tween.tween_property(portrait, "position:x", destination, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(portrait, "modulate:a", 1.0, 0.5).set_delay(0.1)
	tween.tween_property($Seal, "modulate:a", 1.0, 0.3).set_delay(0.45)
	tween.tween_property($Seal, "scale", Vector2.ONE, 0.4).set_delay(0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property($Backdrop.material, "shader_parameter/reveal", 1.0, 0.5).set_delay(0.45)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_delay(duration - 0.25)
	tween.tween_property($BossStart, "volume_db", -30.0, 0.25).set_delay(duration - 0.25)
	$BossStart.play()

func _fit_aura() -> void:
	$Knight/Aura.position = $Knight.size * 0.5
	$Knight/Aura.scale = Vector2.ONE * minf($Knight.size.x, $Knight.size.y) / 74.0

func _exit_tree() -> void:
	$BossStart.stop()
