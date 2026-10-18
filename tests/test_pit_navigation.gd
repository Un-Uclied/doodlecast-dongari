extends Node

func _ready() -> void:
	get_tree().create_timer(18.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_pits")

func ticks(count := 1) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func test_pits() -> void:
	for mode in range(3):
		GameRun.begin_run(mode)
		var level = load(GameRun.level_path()).instantiate()
		get_tree().root.add_child(level)
		level.set_process(false)
		level.player.set_physics_process(false)
		while not level.navigation_ready:
			await get_tree().process_frame
		var pits: TileMapLayer = level.get_node("TileMapLayerPits")
		var blocked := 0
		for cell in pits.get_used_cells():
			if pits.get_cell_tile_data(cell).get_collision_polygons_count(0) == 0:
				continue
			var world := pits.to_global(pits.map_to_local(cell))
			var grid_cell: Vector2i = level.tiles.local_to_map(level.tiles.to_local(world))
			assert(level.grid.is_point_solid(grid_cell), "Each colliding pit tile must block the path grid in every mode")
			assert(not grid_cell in level.walkable_cells, "Pit tiles must never be spawn candidates")
			blocked += 1
		assert(blocked > 0)
		level.free()
	GameRun.begin_run(0)
	var level = load(GameRun.level_path()).instantiate()
	get_tree().root.add_child(level)
	level.set_process(false)
	level.player.set_physics_process(false)
	while not level.navigation_ready:
		await get_tree().process_frame
	level.player.global_position = Vector2(88, 123.5)
	var enemy = await level.spawn_enemy(0)
	enemy.get_node("Contact").monitoring = false
	enemy.global_position = Vector2(-88, 123.5)
	await ticks(2)
	assert(not level.is_floor_segment(enemy.global_position, level.player.global_position))
	var path: PackedVector2Array = level.path_to_player(enemy.global_position)
	assert(not path.is_empty(), "A pit must produce a reachable detour")
	for point in path:
		var cell: Vector2i = level.tiles.local_to_map(level.tiles.to_local(point + Vector2(0, -3.5)))
		assert(not level.grid.is_point_solid(cell))
	for step in range(660):
		await ticks()
		var feet: Vector2 = enemy.global_position + Vector2(0, -3.5)
		var cell: Vector2i = level.tiles.local_to_map(level.tiles.to_local(feet))
		assert(not level.grid.is_point_solid(cell), "The enemy must physically stay outside the pit throughout the detour")
		if enemy.global_position.distance_to(level.player.global_position) < 4.0:
			break
	assert(enemy.global_position.distance_to(level.player.global_position) < 4.0, "The enemy must reach the player instead of getting stuck on a pit edge")
	assert(not level.player.is_dead, "Colliding pit tiles must not cause falling death")
	level.free()
	print("PASS: colliding pit layers excluded from paths/spawns in all three modes, real enemy detour around the edited EASY pit without falling or getting stuck")
	get_tree().quit()
