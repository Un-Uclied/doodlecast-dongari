extends Node

func _ready() -> void:
	get_tree().create_timer(25.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_movement")

func ticks(count := 1) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func test_movement() -> void:
	GameRun.begin_run(0)
	var level := (load("res://scenes/levels_easy/level_01.tscn") as PackedScene).instantiate()
	# Keep the movement fixtures independent of hand-painted pit layouts.
	level.get_node("TileMapLayerPits").clear()
	get_tree().root.add_child(level)
	level.set_process(false)
	level.player.set_physics_process(false)
	level.player.global_position = Vector2(0, 100)
	while not level.navigation_ready:
		await get_tree().process_frame
	var enemy = await level.spawn_enemy(0)
	assert(enemy != null)
	var defaults := (load("res://scenes/gameplay/enemies/enemy.tscn") as PackedScene).instantiate()
	assert(enemy.speed == defaults.speed, "Spawning must preserve the speed configured on the enemy")
	defaults.free()
	enemy.set_physics_process(false)
	enemy.get_node("Contact").monitoring = false
	await ticks(2)
	var start: Vector2 = level.player.global_position + Vector2(72, 48)
	var direction := start.direction_to(level.player.global_position)
	for speed in [24.0, 48.0]:
		enemy.global_position = start
		enemy.speed = speed
		enemy._path = PackedVector2Array([start + Vector2(0, 32)])
		enemy._path_time_left = 10.0
		enemy.set_physics_process(true)
		await ticks(6)
		enemy.set_physics_process(false)
		var travel: Vector2 = enemy.global_position - start
		assert(absf(travel.cross(direction)) < 0.01, "Clear floor must produce a straight chase, ignoring an old detour")
		assert(absf(travel.length() - speed * 6.0 / Engine.physics_ticks_per_second) < 0.02, "Configured speed must control the actual movement distance")
	level.player.global_position += Vector2(32, 0)
	var before: Vector2 = enemy.global_position
	direction = before.direction_to(level.player.global_position)
	enemy.set_physics_process(true)
	await ticks()
	enemy.set_physics_process(false)
	assert(absf((enemy.global_position - before).cross(direction)) < 0.01, "A clear chase must aim at the player's current position")

	level.player.global_position = Vector2(72, 43.5)
	enemy.global_position = Vector2(8, 43.5)
	enemy.speed = 42.0
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector2(40, 40)
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 16)
	collider.shape = rectangle
	wall.add_child(collider)
	level.add_child(wall)
	level.grid.set_point_solid(Vector2i(2, 2), true)
	await ticks(2)
	assert(enemy.test_move(enemy.global_transform, level.player.global_position - enemy.global_position), "The wall fixture must block direct movement")
	assert(not level.is_floor_segment(enemy.global_position, level.player.global_position))
	enemy.set_physics_process(true)
	for step in range(240):
		await ticks()
		var feet: Vector2 = enemy.global_position + Vector2(0, -3.5)
		var nearest := feet.clamp(Vector2(32, 32), Vector2(48, 48))
		assert(feet.distance_to(nearest) >= 3.4, "The enemy's circle must not penetrate the wall: %s" % feet)
		if enemy.global_position.distance_to(level.player.global_position) < 4.0:
			break
	enemy.set_physics_process(false)
	assert(enemy.global_position.distance_to(level.player.global_position) < 4.0, "A blocked enemy must navigate around the wall and resume a direct chase")
	wall.free()
	assert(not level.is_floor_segment(Vector2(8, 43.5), level.player.global_position), "Direct movement must not cut through missing floor even without a physics wall")
	level.player.global_position = Vector2(180, 140)
	enemy.global_position = Vector2(64, 140)
	enemy.speed = 0.0
	var rear = await level.spawn_enemy(0)
	rear.global_position = Vector2(36, 140)
	rear.get_node("Contact").monitoring = false
	await ticks(70)
	assert(enemy.global_position.distance_to(rear.global_position) >= 23.9, "Ordinary mobs must stop at the spacing distance")
	assert(rear.global_position.x > 36.0 and rear.global_position.x < 40.1, "A blocked mob must still use the free gap")
	rear.maintain_spacing = false
	await ticks(70)
	assert(enemy.global_position.distance_to(rear.global_position) < 8.0, "Special enemies must be able to bypass spacing")
	rear.maintain_spacing = true
	enemy.maintain_spacing = false
	rear.global_position = Vector2(36, 140)
	await ticks(70)
	assert(enemy.global_position.distance_to(rear.global_position) < 8.0, "Ordinary mobs must not impose spacing on an exempt enemy")
	enemy.maintain_spacing = true
	enemy.speed = 42.0
	enemy.global_position = Vector2(40, 100)
	rear.global_position = enemy.global_position
	enemy.set_physics_process(true)
	await ticks(70)
	assert(enemy.global_position.distance_to(rear.global_position) >= 23.9, "Coincident mobs must separate without choosing the same escape direction")
	var third = await level.spawn_enemy(0)
	third.get_node("Contact").monitoring = false
	enemy.global_position = Vector2(40, 100)
	rear.global_position = Vector2(16, 100)
	third.global_position = Vector2(28, 124)
	for step in range(150):
		await ticks()
		for pair in [[enemy, rear], [enemy, third], [rear, third]]:
			assert(pair[0].global_position.distance_to(pair[1].global_position) >= 23.9, "A moving pack must preserve spacing while converging on the player")
	for index in range(6):
		var extra = await level.spawn_enemy(0)
		extra.get_node("Contact").monitoring = false
	level.player.global_position = Vector2(180, 180)
	for index in range(level.enemies.size()):
		level.enemies[index].global_position = Vector2((index % 3) * 28, 64 + (index / 3) * 28)
	for step in range(240):
		await ticks()
		for index in range(level.enemies.size()):
			for other in range(index + 1, level.enemies.size()):
				assert(level.enemies[index].global_position.distance_to(level.enemies[other].global_position) >= 23.9, "A crowded pack must not undo another neighbor's spacing")
	level.free()
	print("PASS: preserved enemy speed, straight chase at two speeds, live target updates, wall detour without penetration, missing-floor protection, ordinary-mob spacing in pairs/three/nine, exempt enemies, coincident spawn recovery")
	get_tree().quit()
