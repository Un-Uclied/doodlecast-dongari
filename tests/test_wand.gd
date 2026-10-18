extends SceneTree

func _initialize() -> void:
	create_timer(12.0).timeout.connect(func(): quit(1))
	call_deferred("test_wand")

func test_wand() -> void:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	var wand = player.get_node("Wand")
	wand.set_process(false)
	player.get_node("Camera2D").enabled = false
	var authored_position: Vector2 = wand.position
	root.add_child(player)
	var radius := authored_position.distance_to(Vector2(0, -16))
	assert(is_equal_approx(wand._orbit_radius, radius))
	assert(wand.get_node("Marker2D").position == Vector2(5, 0), "Keep the authored tip marker")
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(1, -1).normalized()]:
		wand.aim_at(player.to_global(Vector2(0, -16) + direction * 100.0))
		assert(wand.position.is_equal_approx(Vector2(0, -16) + direction * radius), "Orbit the sprite center, including its offset, at the authored radius")
		assert(Vector2.RIGHT.rotated(wand.rotation).is_equal_approx(direction), "The wand's positive X tip must face the mouse")
		assert(wand.show_behind_parent == (direction.y < 0.0))
	var previous: Transform2D = wand.transform
	wand.aim_at(player.to_global(Vector2(0, -16)))
	assert(wand.transform == previous, "A cursor at the pivot must not collapse or invalidate the orbit")
	player.sprite.position = Vector2(3, -2)
	player.sprite.offset = Vector2(4, -12)
	player.sprite.scale = Vector2(2, 2)
	player.position = Vector2(120, 80)
	player.rotation = 0.4
	player.scale = Vector2(1.5, 1.5)
	var center := Vector2(11, -26)
	var target: Vector2 = player.to_global(center + Vector2(100, 0))
	wand.aim_at(target)
	assert(wand.position.is_equal_approx(center + Vector2(radius, 0)), "Sprite transforms and parent transforms must preserve the orbit center")
	var aim: Vector2 = wand.global_transform.x.normalized()
	assert(aim.is_equal_approx(player.to_global(center).direction_to(target)))
	player.sprite.centered = false
	wand.aim_at(player.to_global(Vector2(43, 6) + Vector2(100, 0)))
	assert(wand.position.is_equal_approx(Vector2(43, 6) + Vector2(radius, 0)), "An uncentered sprite must include half the current frame size")
	player.sprite.centered = true
	wand.aim_at(target)
	wand._update_trail(0.01, true)
	var old_tip: Vector2 = wand.get_node("Marker2D").global_position
	player.position += Vector2(8, 3)
	wand.aim_at(player.to_global(center + Vector2(0, 100)))
	wand._update_trail(0.04, true)
	var trail: Line2D = wand.get_node("Marker2D/Trail")
	assert(trail.get_point_count() == 2)
	assert(trail.to_global(trail.points[0]).is_equal_approx(old_tip), "Old trail samples must stay in world space when the player moves or the wand rotates")
	assert(trail.to_global(trail.points[-1]).is_equal_approx(wand.get_node("Marker2D").global_position))
	wand._update_trail(0.05, false)
	assert(trail.modulate.a > 0.0 and trail.modulate.a < 1.0, "A stopped trail must fade before its samples expire")
	player.position += Vector2(1000, 1000)
	wand._update_trail(0.01, true)
	assert(trail.get_point_count() == 1, "Teleports must clear the old trail instead of drawing a long streak")
	player.set_physics_process(false)
	previous = wand.transform
	wand._process(0.2)
	assert(wand.transform == previous and not wand.get_node("Marker2D/Sparks").emitting and trail.get_point_count() == 0, "Finished gameplay must freeze aiming and let the short trail expire")
	player.set_physics_process(true)
	player.rotation = 0.0
	player.scale = Vector2.ONE
	player.position = Vector2(100, 100)
	player.sprite.position = Vector2.ZERO
	player.sprite.offset = Vector2(0, -16)
	player.sprite.scale = Vector2.ONE
	var mouse_world: Vector2 = wand.get_global_mouse_position()
	wand._process(0.016)
	assert(wand.global_transform.x.normalized().is_equal_approx(player.to_global(Vector2(0, -16)).direction_to(mouse_world)), "The current viewport mouse position must drive aiming")
	assert(wand.get_node("Marker2D/Sparks").emitting)
	var frozen: Transform2D = wand.transform
	paused = true
	wand.set_process(true)
	await process_frame
	await process_frame
	assert(wand.transform == frozen, "SceneTree pause must freeze the wand along with gameplay")
	paused = false
	wand.set_process(false)
	player.fall()
	previous = wand.transform
	wand._process(0.2)
	assert(wand.transform == previous and not wand.get_node("Marker2D/Sparks").emitting and trail.get_point_count() == 0)
	player.free()
	print("PASS: mouse orbit around the offset sprite center, authored radius/tip, cardinal/diagonal directions, transformed/uncentered sprites, world-space short trail and fade, teleport cleanup, viewport mouse aiming, pause/finish/death cleanup")
	quit()
