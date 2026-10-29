extends SceneTree

const MODES := ["easy", "normal", "hard"]

func _initialize() -> void:
	call_deferred("test_maps")

func test_maps() -> void:
	create_timer(15.0).timeout.connect(func(): quit(1))
	var maps: Array[Node2D] = []
	for mode in range(MODES.size()):
		var path := "res://scenes/maps/%s_map.tscn" % MODES[mode]
		var packed := load(path) as PackedScene
		assert(packed.get_state().get_base_scene_state().get_path() == "res://scenes/gameplay/combat_level.tscn")
		var map := packed.instantiate() as Node2D
		assert(map.mode == mode, "F6 on a map must use its own mode")
		maps.append(map)
		for number in range(1, 7):
			var level_path := "res://scenes/levels_%s/level_%02d.tscn" % [MODES[mode], number]
			var level_scene := load(level_path) as PackedScene
			assert(level_scene.get_state().get_base_scene_state().get_path() == path, "Each level must inherit its mode's editable map")
			var level := level_scene.instantiate() as Node2D
			for child in map.get_children():
				if child is TileMapLayer:
					assert(level.has_node(NodePath(child.name)))
					assert(level.get_node(NodePath(child.name)).tile_map_data == child.tile_map_data, "All six levels must receive every map layer")
			assert(level.get_node("Player").position == map.get_node("Player").position)
			assert(level.mode == mode and level.level_number == number)
			level.free()
	# Runtime door changes and tile painting must stay local to an instance/mode.
	var normal_floor: TileMapLayer = maps[1].get_node("TileMapLayer")
	var normal_bytes: PackedByteArray = normal_floor.tile_map_data.duplicate()
	var hard_floor: TileMapLayer = maps[2].get_node("TileMapLayer")
	var hard_bytes: PackedByteArray = hard_floor.tile_map_data.duplicate()
	var easy_floor: TileMapLayer = maps[0].get_node("TileMapLayer")
	easy_floor.erase_cell(easy_floor.get_used_cells()[0])
	assert(normal_floor.tile_map_data == normal_bytes and hard_floor.tile_map_data == hard_bytes)
	for map in maps:
		assert(not map.get_node("TileMapLayerPits").get_used_cells().is_empty(), "Each edited mode map must preserve its painted pits")
	for map in maps:
		map.free()
	# Run each mode through real initialization and enemy placement.
	for mode in range(MODES.size()):
		root.get_node("GameRun").begin_run(mode)
		var level = load("res://scenes/levels_%s/level_01.tscn" % MODES[mode]).instantiate()
		root.add_child(level)
		level.set_process(false)
		level.player.set_physics_process(false)
		while not level.navigation_ready:
			await process_frame
		assert(not level.walkable_cells.is_empty())
		assert((await level.spawn_enemy()) != null, "Each mode's preserved map must support enemy spawns")
		assert(level.player.died.is_connected(level.canvas._on_player_died), "The standalone combat template must preserve player/gesture signals")
		level.queue_free()
		await process_frame
	print("PASS: three editable mode maps, inheritance and every tile layer/spawn position in all 18 levels, independent tile state, preserved painted pits, all modes initialize/spawn with player signals")
	quit()
