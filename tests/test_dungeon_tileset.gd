extends SceneTree

func _initialize() -> void:
	create_timer(10.0).timeout.connect(func(): quit(1))
	call_deferred("test_tileset")

func test_tileset() -> void:
	var tileset := load("res://resources/Dungeon/TileSets/dungeon_tileset.tres") as TileSet
	assert(tileset != null and tileset.tile_size == Vector2i(16, 16))
	assert(tileset.get_source_count() == 10)
	assert(tileset.get_physics_layers_count() == 1)
	assert(tileset.get_physics_layer_collision_layer(0) == 1)
	assert(tileset.get_physics_layer_collision_mask(0) == 2)
	assert(ProjectSettings.get_setting("layer_names/2d_physics/layer_1") == "tile_walls")
	var ground := tileset.get_source(0) as TileSetAtlasSource
	assert(ground.texture.resource_path == "res://image_assets/dungeon_tileset/tileset.png")
	assert(ground.get_tiles_count() == 948)
	for cell in [Vector2i(7, 2), Vector2i(2, 8), Vector2i(2, 11), Vector2i(14, 9), Vector2i(27, 8), Vector2i(33, 13), Vector2i(64, 12), Vector2i(10, 38), Vector2i(37, 9)]:
		assert(ground.get_tile_data(cell, 0).get_collision_polygons_count(0) == 1, "Walls, edges and arch masonry must block movement: %s" % cell)
	for cell in [Vector2i(8, 6), Vector2i(8, 9), Vector2i(2, 12), Vector2i(2, 13), Vector2i(9, 30), Vector2i(9, 31), Vector2i(37, 10), Vector2i(38, 11), Vector2i(2, 19)]:
		assert(ground.get_tile_data(cell, 0).get_collision_polygons_count(0) == 0, "Floors, open doorways and cliff decoration must stay passable: %s" % cell)
	var image := ground.texture.get_image()
	for y in range(image.get_height() / 16):
		for x in range(image.get_width() / 16):
			var cell := Vector2i(x, y)
			assert(ground.has_tile(cell) == not image.get_region(Rect2i(cell * 16, Vector2i(16, 16))).is_invisible(), "Every visible tile must be registered, transparent tiles excluded")
	for id in range(10):
		var source := tileset.get_source(id) as TileSetAtlasSource
		assert(not source.has_tiles_outside_texture())
		if id > 0:
			assert(source.get_tile_data(Vector2i.ZERO, 0).get_collision_polygons_count(0) == 0, "Props keep their existing behavior")
			assert(source.get_tiles_count() == 1)
			assert(source.texture_region_size == Vector2i(source.texture.get_size()), "Props must remain whole")
			assert(source.get_tile_texture_region(Vector2i.ZERO).size == Vector2i(source.texture.get_size()))
			assert(source.get_tile_data(Vector2i.ZERO, 0).texture_origin.y == source.texture_region_size.y / 2 - 8)
	var layer := (load("res://resources/Dungeon/TileSets/dungeon_tiles.tscn") as PackedScene).instantiate() as TileMapLayer
	assert(layer.tile_set == tileset and layer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	assert(layer.get_used_cells().is_empty())
	layer.free()
	var map := (load("res://scenes/sandbox/test_scene.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	var space := root.get_world_2d().direct_space_state
	var map_bounds := (map.get_node("TileMapLayer") as TileMapLayer).get_used_rect()
	for edge in [Vector2(40, (map_bounds.position.y - 1) * 16), Vector2((map_bounds.position.x - 1) * 16, 24), Vector2((map_bounds.end.x + 1) * 16, 24), Vector2(40, (map_bounds.end.y + 1) * 16)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(40, 24), edge, 1))
		assert(not hit.is_empty(), "Each map boundary must block movement: %s" % edge)
	assert(space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(40, 8), Vector2(40, 40), 1)).is_empty(), "Floor must stay open")
	var spawn_query := PhysicsPointQueryParameters2D.new()
	spawn_query.position = map.get_node("Player").position + Vector2(0, -3.5)
	spawn_query.collision_mask = 1
	assert(space.intersect_point(spawn_query).is_empty(), "Player must spawn outside walls")
	print("PASS: dungeon atlas and props, tile_walls collision layer, walls on all four map edges, passable floors and open doorway tiles, safe player spawn")
	quit()
