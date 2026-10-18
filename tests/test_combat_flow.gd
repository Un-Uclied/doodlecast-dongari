extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	get_tree().create_timer(20.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_flow")

func ticks(count := 1) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func test_flow() -> void:
	GameRun.begin_run(0)
	var level = load("res://scenes/levels_easy/level_01.tscn").instantiate()
	get_tree().root.add_child(level)
	level.set_process(false)
	while not level.navigation_ready:
		await get_tree().process_frame
	var player = level.player
	assert(player.hurt_invulnerability_duration == 1.0)
	assert(player.take_damage() and player.health == 4 and player.is_invulnerable)
	assert(player.get_node("HurtSound").playing)
	player.get_node("HurtSound").stop()
	assert(not player.take_damage() and player.health == 4 and not player.get_node("HurtSound").playing, "Blocked hits must produce neither damage nor sound")
	var touching = await level.spawn_enemy(0)
	touching.set_physics_process(false)
	touching.global_position = player.global_position
	await ticks(3)
	assert(is_instance_valid(touching) and not touching.resolved and player.health == 4, "Hurt immunity must preserve an overlapping enemy without more damage")
	touching._remove(false)
	await get_tree().create_timer(0.22).timeout
	var opacities: Array[float] = []
	for frame in range(12):
		await ticks()
		if not player.sprite.modulate.a in opacities:
			opacities.append(player.sprite.modulate.a)
	assert(opacities.min() < 0.5 and opacities.max() > 0.9, "Hurt immunity must blink after the initial damage flash")
	get_tree().paused = true
	var immunity_left: float = player._hurt_invulnerability_left
	await get_tree().create_timer(0.12).timeout
	assert(player._hurt_invulnerability_left == immunity_left, "Pause must freeze hurt immunity")
	get_tree().paused = false
	await get_tree().create_timer(immunity_left + 0.06).timeout
	assert(not player.is_invulnerable and player.sprite.modulate == Color.WHITE)
	player.set_physics_process(false)
	player.global_position = Vector2(0, 140)
	var first = await level.spawn_enemy(0)
	var last = await level.spawn_enemy(0)
	for enemy in [first, last]:
		enemy.set_physics_process(false)
		enemy.get_node("Contact").monitoring = false
		enemy.pattern.assign([&"horizontal", &"vertical"])
	first.global_position = player.global_position + Vector2(-32, 0)
	last.global_position = player.global_position + Vector2(32, 0)
	await ticks(2)
	level.canvas.gesture_finished.emit({"pattern_id": &""}, 0, 1)
	assert(level.get_node("MagicFailSound").playing and not level.get_node("MagicSuccessSound").playing, "Unrecognized gestures need failure audio")
	level.get_node("MagicFailSound").stop()
	level.canvas.gesture_finished.emit({"pattern_id": &"star"}, 0, 1)
	assert(not level.get_node("MagicFailSound").playing, "A recognized but unmatched gesture must stay silent")
	level.get_node("MagicFailSound").stop()
	level.canvas.gesture_finished.emit({"pattern_id": &"horizontal"}, 0, 1)
	assert(level.get_node("MagicSuccessSound").playing and not level.get_node("MagicFailSound").playing)
	assert(first.pattern == [&"vertical"] and last.pattern == [&"vertical"], "A multi-target match must keep the existing combat behavior")
	var furniture: TileMapLayer = level.furniture
	var doors := furniture.get_used_cells_by_id(level.CLOSED_DOOR_SOURCE)
	assert(doors.size() == 1, "The edited map must have its closed exit door")
	var door_cell: Vector2i = doors[0]
	var door_center := furniture.to_global(furniture.map_to_local(door_cell) - Vector2(furniture.get_cell_tile_data(door_cell).texture_origin))
	level.spawned = level.enemy_budget()
	first.consume_pattern(&"vertical")
	assert(not level.finished and furniture.get_cell_source_id(door_cell) == level.CLOSED_DOOR_SOURCE, "A remaining enemy must keep the door shut")
	var elapsed := GameRun.elapsed_seconds
	last.consume_pattern(&"vertical")
	assert(level.finished and level.get_node("LevelClearSound").playing)
	assert(not level.get_node("DoorOpenSound").playing and not level.hud.get_node("%Results").visible)
	var camera: Camera2D = player.get_node("Camera2D")
	var start := camera.global_position
	await get_tree().create_timer(0.7).timeout
	assert(camera.global_position.distance_to(door_center) < start.distance_to(door_center) and camera.global_position.distance_to(door_center) > 1.0, "The camera must tween toward the door")
	assert(furniture.get_cell_source_id(door_cell) == level.CLOSED_DOOR_SOURCE, "The door must wait for the camera")
	await get_tree().create_timer(0.65).timeout
	assert(furniture.get_cell_source_id(door_cell) == level.OPEN_DOOR_SOURCE)
	assert(camera.global_position.is_equal_approx(door_center) and level.get_node("DoorOpenSound").playing)
	assert(not level.hud.get_node("%Results").visible and GameRun.elapsed_seconds == elapsed)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png("res://.godot/open-door-preview.png") == OK)
	await get_tree().create_timer(1.4).timeout
	assert(level.hud.get_node("%Results").visible)
	level.free()
	# Losing must not play a clear fanfare or reveal/open the door.
	GameRun.begin_run(0)
	level = load("res://scenes/levels_easy/level_01.tscn").instantiate()
	get_tree().root.add_child(level)
	level.set_process(false)
	level.player.health = 1
	assert(level.player.take_damage() and level.player.is_dead and level.finished)
	await get_tree().create_timer(0.4).timeout
	assert(level.furniture.get_cell_source_id(door_cell) == level.CLOSED_DOOR_SOURCE)
	assert(not level.get_node("LevelClearSound").playing and not level.get_node("DoorOpenSound").playing)
	assert(level.hud.get_node("%Results").visible)
	level.free()
	print("PASS: timed and paused hurt immunity/blinking, damage sound suppression, magic success/failure audio, all-enemies gate, camera tween then open-door tile/sound then results, frozen clear score, death keeps door shut")
	get_tree().quit()
