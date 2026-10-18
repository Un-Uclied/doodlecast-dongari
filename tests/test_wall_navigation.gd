extends Node

func _ready() -> void:
	get_tree().create_timer(15.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_walls")

func test_walls() -> void:
	for mode in range(3):
		GameRun.begin_run(mode)
		var level = load(GameRun.level_path()).instantiate()
		get_tree().root.add_child(level)
		level.set_process(false)
		level.player.set_physics_process(false)
		assert(not level.navigation_ready and (await level.spawn_enemy()) == null, "Spawning must wait for real tile collisions")
		while not level.navigation_ready:
			await get_tree().process_frame
		for cell in [Vector2i(-1, -2), Vector2i(0, -2), Vector2i(0, -1)]:
			assert(level.grid.is_point_solid(cell) and not cell in level.walkable_cells, "The blocked doorway positions from the screenshot must never be spawn/path candidates")
		var defaults = level.ENEMY.instantiate()
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = defaults.get_node("CollisionShape2D").shape
		query.collision_mask = 1
		defaults.free()
		var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
		for cell in level.walkable_cells:
			query.transform = Transform2D(0.0, level.tiles.to_global(level.tiles.map_to_local(cell)))
			assert(space.intersect_shape(query, 1).is_empty(), "Every candidate must fit the enemy's actual foot collider")
		level.rng.seed = 821
		for index in range(12):
			var enemy = await level.spawn_enemy()
			assert(enemy != null)
			enemy.set_physics_process(false)
			enemy.get_node("Contact").monitoring = false
			query.transform = enemy.get_node("CollisionShape2D").global_transform
			assert(space.intersect_shape(query, 1).is_empty(), "Actual spawns must stay outside wall/prop/pit collisions")
		level.queue_free()
		await get_tree().process_frame
	print("PASS: physics-ready spawn gate, blocked doorway regression, every reachable spawn/path candidate fits the enemy collider, 36 seeded spawns outside walls and pits across all modes")
	get_tree().quit()
