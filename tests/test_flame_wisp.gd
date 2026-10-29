extends Node

const ENEMY := preload("res://scripts/gameplay/enemy.gd")
const WARNING := preload("res://scenes/effects/attack_telegraph.tscn")
var completed: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	get_tree().create_timer(35.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_wisp")

func ticks(count := 1) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func make_level(mode := 0, clear_pits := false) -> Node2D:
	GameRun.begin_run(mode)
	var level = load(GameRun.level_path()).instantiate()
	if clear_pits:
		level.get_node("TileMapLayerPits").clear()
	level.get_node("Player/Camera2D").position_smoothing_enabled = false
	get_tree().root.add_child(level)
	level.set_process(false)
	level.player.set_physics_process(false)
	while not level.navigation_ready:
		await get_tree().process_frame
	return level

func request_spawn(level: Node2D, kind: int) -> void:
	var enemy = await level.spawn_enemy(kind)
	if enemy != null:
		enemy.set_physics_process(false)
		enemy.get_node("Contact").monitoring = false
	completed.append(enemy)

func make_wall(level: Node2D, location: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	collider.shape = box
	wall.add_child(collider)
	level.add_child(wall)
	wall.global_position = location
	return wall

func test_wisp() -> void:
	for mode in range(3):
		var map = await make_level(mode)
		completed.clear()
		for index in range(mode + 1):
			request_spawn(map, ENEMY.Kind.FLAME_WISP)
		assert(map._pending_spawns.size() == mode + 1 and completed.is_empty())
		var budget_used: int = map.spawned
		assert(await map.spawn_enemy(ENEMY.Kind.FLAME_WISP) == null)
		assert(map.spawned == budget_used, "Pending warnings must reserve the mode's wisp cap without consuming extra budget")
		request_spawn(map, ENEMY.Kind.SOLDIER)
		while completed.size() < mode + 2:
			await ticks()
		assert(map._pending_spawns.is_empty() and map.enemies.size() == mode + 2)
		assert(await map.spawn_enemy(ENEMY.Kind.FLAME_WISP) == null, "Live wisps also count toward the cap")
		completed[0]._remove(true)
		request_spawn(map, ENEMY.Kind.FLAME_WISP)
		while completed.size() < mode + 3:
			await ticks()
		assert(completed[-1] != null, "A defeated wisp must free its spawn slot")
		map.queue_free()
		await ticks(2)

	var level = await make_level(0, true)
	# Keep real map collisions and add an obstacle to verify the beam spans through walls.
	var wall := make_wall(level, Vector2(96, 92), Vector2(8, 64))
	level.player.global_position = Vector2(80, 100)
	var wisp = await level.spawn_enemy(ENEMY.Kind.FLAME_WISP)
	wisp.get_node("Contact").monitoring = false
	wisp.global_position = Vector2(-64, 100)
	await ticks(30)
	assert(wisp.global_position.x > -34.0 and wisp.velocity.length() > 60.0 and wisp._laser == null, "Wisp follows for its first second")
	await ticks(31)
	var laser = wisp._laser
	var anchor: Vector2 = wisp.global_position
	assert(is_instance_valid(laser) and not laser.active and wisp.velocity == Vector2.ZERO)
	assert(wisp._laser_direction == Vector2.RIGHT and wisp.sprite.offset.y == -8.0 and not wisp.maintain_spacing)
	assert(wisp.sprite.animation == "idle_east")
	var warning = laser.get_node("Warning")
	assert(laser.get_node("WarningSound").playing and not laser.get_node("FireSound").playing)
	assert(laser.get_node("FireSound").stream.loop and not load("res://sounds/fire.mp3").loop, "Loop fire locally without changing the original asset")
	assert(warning.points == laser.get_node("Hitbox").polygon and warning.points == warning.get_node("Fill").polygon, "Warning and damage shape must span the same complete line")
	assert(laser.beam_length == 4096.0 and warning.points[0].x == -2048.0 and warning.points[1].x == 2048.0, "The beam must extend equally far on both sides of the caster, through walls")
	assert(laser.get_node("Sparks").position == Vector2.ZERO and laser.get_node("Sparks").emission_rect_extents.x == 2048.0)
	level.player.global_position = laser.global_position + Vector2(24, 8)
	await ticks(23)
	assert(level.player.health == 5 and not laser.active, "Charging is harmless even inside its hitbox")
	assert(wisp.global_position == anchor and wisp._laser_direction == Vector2.RIGHT, "After chasing, position and cardinal direction stay locked")
	get_tree().paused = true
	var paused_progress: float = warning.progress
	await get_tree().process_frame
	await get_tree().process_frame
	var paused_warning_audio: float = laser.get_node("WarningSound").get_playback_position()
	await get_tree().create_timer(0.12).timeout
	assert(warning.progress == paused_progress)
	assert(absf(laser.get_node("WarningSound").get_playback_position() - paused_warning_audio) < 0.04, "Pause must freeze warning audio after the mixer buffer: %f -> %f" % [paused_warning_audio, laser.get_node("WarningSound").get_playback_position()])
	await render_warning(level, laser)
	get_tree().paused = false
	await ticks(35)
	assert(laser.active and not warning.visible and warning.progress == 1.0)
	assert(not laser.get_node("WarningSound").playing and laser.get_node("FireSound").playing, "Charging audio must switch to looping fire on activation")
	var fire: AudioStreamPlayer = laser.get_node("FireSound")
	fire.play(maxf(0.0, fire.stream.get_length() - 0.05))
	assert(level.player.health == 4 and wisp.sprite.animation == "attack_east", "A fully charged beam damages once and uses Attack frames")
	assert(wisp.sprite.sprite_frames.get_animation_loop("attack_east"))
	await ticks(12)
	assert(fire.playing and fire.get_playback_position() < 0.5, "Fire audio must actually wrap at the end of the clip")
	assert(level.player.health == 4, "Sustained overlap must respect hurt immunity")
	level.player.global_position = laser.global_position + Vector2(-24, 8)
	level.player._hurt_invulnerability_left = 0.0
	level.player.dash_time_left = 0.3
	await ticks(10)
	assert(level.player.health == 4, "Dash immunity must reject continuous beam damage")
	level.player.dash_time_left = 0.0
	await ticks(2)
	assert(level.player.health == 3 and laser.overlaps_body(level.player), "The opposite side of the caster must also damage when immunity ends")
	get_tree().paused = true
	var paused_flame_time: float = laser._flame_time
	await get_tree().process_frame
	await get_tree().process_frame
	var paused_fire_audio := fire.get_playback_position()
	await get_tree().create_timer(0.1).timeout
	assert(laser._flame_time == paused_flame_time and level.player.health == 3)
	assert(absf(fire.get_playback_position() - paused_fire_audio) < 0.04, "Pause must freeze fire audio after the mixer buffer")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var flame_image := get_viewport().get_texture().get_image()
		for x in [-128, 128]:
			var pixel := flame_image.get_pixelv(Vector2i(laser.get_global_transform_with_canvas() * Vector2(x, 0)))
			assert(pixel.r > 0.9 and pixel.g > 0.4, "The fire shader must visibly render on both sides of the caster")
		assert(flame_image.save_png("res://.godot/flame-laser-preview.png") == OK)
	get_tree().paused = false
	wisp.pattern.assign([&"horizontal"])
	wisp.consume_pattern(&"horizontal")
	assert(not laser.active and not laser.visible, "Killing the caster must immediately stop an active beam")
	assert(not laser.get_node("WarningSound").playing and not laser.get_node("FireSound").playing, "Caster removal must immediately silence its warning and fire")
	await ticks(2)
	assert(not is_instance_valid(laser))
	wall.queue_free()
	await ticks(2)

	# Real pits and off-center walls must not shorten the line in either direction.
	var pits: TileMapLayer = level.get_node("TileMapLayerPits")
	var original = load("res://scenes/maps/easy_map.tscn").instantiate()
	var source_pits: TileMapLayer = original.get_node("TileMapLayerPits")
	for cell in source_pits.get_used_cells():
		if source_pits.get_cell_tile_data(cell).get_collision_polygons_count(0) > 0:
			pits.set_cell(Vector2i(0, 5), source_pits.get_cell_source_id(cell), source_pits.get_cell_atlas_coords(cell))
			break
	original.free()
	wall = make_wall(level, Vector2(40, 100), Vector2(8, 8))
	await ticks(3)
	level.player.global_position = Vector2(80, 100)
	wisp = await level.spawn_enemy(ENEMY.Kind.FLAME_WISP)
	wisp.get_node("Contact").monitoring = false
	wisp.global_position = Vector2(-64, 100)
	wisp._age = 1.0
	await ticks(2)
	laser = wisp._laser
	assert(is_instance_valid(laser) and laser.beam_length == 4096.0, "Pits and walls must not shorten the line")
	await render_pit_warning(level, laser, Vector2(8, 88))
	level.player.global_position = laser.global_position + Vector2(1000, 8)
	level.player._hurt_invulnerability_left = 0.0
	await ticks(50)
	assert(laser.active and level.player.health == 2, "The line must damage far beyond walls and pits on its positive side")
	level.player.global_position = laser.global_position + Vector2(-1000, 8)
	level.player._hurt_invulnerability_left = 0.0
	await ticks(2)
	assert(level.player.health == 1, "The negative side must reach equally far behind the caster")
	wisp.queue_free()
	level.enemies.erase(wisp)
	await ticks(2)
	assert(not is_instance_valid(laser), "Direct caster deletion also removes its beam")
	wall.queue_free()
	pits.clear()
	await ticks(2)

	var directions := [Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	for direction in directions:
		level.player.global_position = Vector2(-48, 140) + direction * 60.0
		wisp = await level.spawn_enemy(ENEMY.Kind.FLAME_WISP)
		wisp.get_node("Contact").monitoring = false
		wisp.global_position = Vector2(-48, 140)
		wisp._age = 1.0
		await ticks(2)
		assert(wisp._laser_direction == direction and is_instance_valid(wisp._laser))
		assert(Vector2.RIGHT.rotated(wisp._laser.global_rotation).is_equal_approx(direction))
		var ends: PackedVector2Array = wisp._laser.get_node("Hitbox").polygon
		assert((ends[0] + ends[2]).is_zero_approx(), "Horizontal and vertical beams must both be centered on the caster")
		if direction != Vector2.DOWN:
			var charging_laser = wisp._laser
			wisp._remove(true)
			assert(not charging_laser.get_node("WarningSound").playing, "Killing the caster during charge must silence its warning")
			await ticks(2)
	level.finish_level(false)
	await ticks(2)
	assert(level.get_node("Projectiles").get_child_count() == 0, "Ending a level must clear charging beams too")
	level.queue_free()
	await ticks(2)
	await test_sector()
	print("PASS: wisp mode caps include pending warnings, chase/anchor/cardinal axes, matching 4096px centered warning/hitbox, charge-only safety, both sides damage through walls/pits at long range, continuous damage/immunity/pause, attack animation, kill/end/unload cleanup, reusable sector and isolated materials")
	Music.stop()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func render_pit_warning(level: Node2D, laser: Area2D, point: Vector2) -> void:
	assert(level.get_node("TileMapLayerPits").z_index < laser.get_node("Warning").z_index, "Warning must sort above pit tiles")
	if DisplayServer.get_name() == "headless":
		return
	get_tree().paused = true
	level.player.get_node("Camera2D").global_position = point
	await RenderingServer.frame_post_draw
	var lit := get_viewport().get_texture().get_image()
	assert(lit.save_png("res://.godot/pit-warning-preview.png") == OK)
	laser.get_node("Warning").hide()
	await RenderingServer.frame_post_draw
	var background := get_viewport().get_texture().get_image()
	var pixel := Vector2i(level.get_global_transform_with_canvas() * point)
	assert(lit.get_pixelv(pixel).r > background.get_pixelv(pixel).r + 0.04, "Red warning must visibly render over a real pit tile")
	laser.get_node("Warning").show()
	get_tree().paused = false

func render_warning(level: Node2D, laser: Area2D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	level.player.get_node("Camera2D").global_position = Vector2(8, 105)
	level.canvas.get_node("Panel").hide()
	await RenderingServer.frame_post_draw
	var charged_image := get_viewport().get_texture().get_image()
	assert(charged_image.save_png("res://.godot/flame-warning-preview.png") == OK)
	var warning = laser.get_node("Warning")
	warning.hide()
	await RenderingServer.frame_post_draw
	var background := get_viewport().get_texture().get_image()
	var transform := laser.get_global_transform_with_canvas()
	for x in [-128, 128]:
		var filled: Vector2i = transform * Vector2(x, -3)
		assert(charged_image.get_pixelv(filled).r - background.get_pixelv(filled).r > 0.15, "Centered charge must visibly fill both sides of the caster")
	warning.show()

func test_sector() -> void:
	var sector = WARNING.instantiate()
	sector.points = PackedVector2Array([Vector2.ZERO])
	for index in range(25):
		sector.points.append(Vector2.from_angle(-PI / 3.0 + index * PI / 36.0) * 64.0)
	sector.duration = 0.1
	var other = WARNING.instantiate()
	add_child(sector)
	add_child(other)
	assert(sector.get_node("Fill").polygon == sector.points)
	assert(sector.get_node("Outline").points.size() == sector.points.size() + 1)
	assert(sector.get_node("Fill").material != other.get_node("Fill").material)
	assert(sector.get_node("Fill").material.get_shader_parameter("fill_radius") > 0)
	var charges := [0]
	sector.charged.connect(func(): charges[0] += 1)
	await ticks(10)
	assert(sector.progress == 1.0 and charges[0] == 1 and other.progress < 0.3, "Each warning's duration, fill and completion are independent")
	sector.queue_free()
	other.queue_free()
