extends Node

func _ready() -> void:
	get_tree().create_timer(15.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_y_sort")

func marker(parent: Node2D, color: Color) -> void:
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array([Vector2(-8, -24), Vector2(8, -24), Vector2(8, 0), Vector2(-8, 0)])
	shape.color = color
	parent.add_child(shape)

func check_pixel(point: Vector2i, color: Color, message: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.get_pixelv(point).is_equal_approx(color), message)

func test_y_sort() -> void:
	assert(DisplayServer.get_name() != "headless", "Use a real renderer for this pixel-order test")
	get_tree().root.size = Vector2i(512, 320)
	get_tree().root.content_scale_size = Vector2i(512, 320)
	GameRun.begin_run(0)
	var level := (load("res://scenes/levels_easy/level_01.tscn") as PackedScene).instantiate()
	level.get_node("Player/Camera2D").enabled = false
	get_tree().root.add_child(level)
	level.set_process(false)
	level.get_node("Ambient").color = Color.WHITE
	level.get_node("Lighting").hide()
	level.player.set_physics_process(false)
	while not level.navigation_ready:
		await get_tree().process_frame
	var enemy = await level.spawn_enemy(0)
	enemy.set_physics_process(false)
	enemy.get_node("Contact").monitoring = false
	enemy.pattern.clear()
	enemy.queue_redraw()
	level.player.sprite.hide()
	level.player.get_node("Shadow").hide()
	enemy.sprite.hide()
	level.get_node("GestureCanvas").hide()
	level.hud.hide()
	assert(level.y_sort_enabled and level.get_node("Enemies").y_sort_enabled and level.get_node("Projectiles").y_sort_enabled)
	assert(level.tiles.z_index < level.player.z_index and level.player.z_index == enemy.z_index)
	level.tiles.hide()
	level.position = Vector2(128, 128)
	level.get_node("Enemies").position = Vector2(17, -11)
	level.player.position = Vector2.ZERO
	enemy.global_position = Vector2(128, 124)
	marker(level.player, Color.GREEN)
	marker(enemy, Color.RED)
	await check_pixel(Vector2i(128, 112), Color.GREEN, "A player below an enemy must draw in front, across nested containers")
	enemy.global_position.y = 132
	await check_pixel(Vector2i(128, 112), Color.RED, "An enemy below the player must draw in front")
	enemy.global_position.x = 180
	var projectile := Node2D.new()
	level.get_node("Projectiles").position = Vector2(-21, 19)
	level.get_node("Projectiles").add_child(projectile)
	marker(projectile, Color.BLUE)
	projectile.global_position = Vector2(128, 132)
	await check_pixel(Vector2i(128, 112), Color.BLUE, "Future projectiles must share the actors' Y sorting")
	projectile.global_position.y = 124
	await check_pixel(Vector2i(128, 112), Color.GREEN, "The player must also cover a projectile above it")
	projectile.hide()
	level.tiles.show()
	var floor_marker := Polygon2D.new()
	floor_marker.polygon = PackedVector2Array([Vector2(-256, -256), Vector2(256, -256), Vector2(256, 256), Vector2(-256, 256)])
	floor_marker.color = Color.WHITE
	level.tiles.add_child(floor_marker)
	level.player.position.y = -40
	await check_pixel(Vector2i(128, 72), Color.GREEN, "Floor tiles must remain behind actors even at negative Y coordinates")
	print("PASS: rendered player/enemy depth in both directions, translated enemy/projectile containers, future projectile depth, floor behind actors at negative Y")
	get_tree().quit()
