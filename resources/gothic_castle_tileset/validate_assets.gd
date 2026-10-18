extends SceneTree

const PACK := "res://Resources/GothicCastle/"
const IMAGES := "res://Images/Gothic Castle Tileset/"

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var tiles := load(PACK + "TileSets/castle_tileset.tres") as TileSet
	assert(tiles != null and tiles.tile_size == Vector2i(16, 16))
	assert(tiles.get_source_count() == 6)
	var tile_count := 0
	for i in range(6):
		var source := tiles.get_source(i) as TileSetAtlasSource
		assert(source != null and not source.has_tiles_outside_texture())
		assert(source.get_tiles_count() > 0)
		tile_count += source.get_tiles_count()
		for j in range(source.get_tiles_count()):
			var size := source.get_tile_size_in_atlas(source.get_tile_id(j))
			assert(size == (Vector2i(1, 2) if i == 4 else Vector2i(2, 2) if i == 5 else Vector2i(1, 1)))
	var knight := load(PACK + "Characters/noble_knight_frames.tres") as SpriteFrames
	assert(knight.get_animation_names().size() == 16)
	assert(knight.get_frame_count("walk_south") == 4)
	assert(knight.get_frame_count("idle_south") == 6)
	assert(knight.get_frame_count("attack_south") == 7)
	assert(knight.get_frame_count("death") == 8)
	assert(knight.get_animation_loop("walk_south"))
	assert(not knight.get_animation_loop("attack_south"))
	assert(not knight.get_animation_loop("death"))
	check_frames(knight)
	var knight_scene := (load(PACK + "Characters/noble_knight.tscn") as PackedScene).instantiate() as AnimatedSprite2D
	assert(knight_scene.sprite_frames == knight, "Scene must share the editable SpriteFrames resource")
	knight_scene.free()
	var tile_scene := (load(PACK + "TileSets/castle_tiles.tscn") as PackedScene).instantiate() as TileMapLayer
	assert(tile_scene.tile_set == tiles, "Scene must share the editable TileSet resource")
	tile_scene.free()
	var block := load(PACK + "Characters/block_frames.tres") as SpriteFrames
	assert(block.get_animation_names().size() == 5)
	check_frames(block)
	var animated_count := 0
	for file in DirAccess.get_files_at(IMAGES + "Props/Animated_Props"):
		if not file.ends_with(".png"):
			continue
		animated_count += 1
		var frames := load(PACK + "Props/Animated/" + file.get_basename() + "_frames.tres") as SpriteFrames
		assert(frames != null)
		check_frames(frames)
		var forward := "open"
		var backward := "close"
		if frames.has_animation("activate"):
			forward = "activate"
			backward = "deactivate"
		elif frames.has_animation("extend"):
			forward = "extend"
			backward = "retract"
		if frames.has_animation(forward):
			assert(not frames.get_animation_loop(forward))
			var count := frames.get_frame_count(forward)
			assert(count == frames.get_frame_count(backward))
			for i in range(count):
				assert(frames.get_frame_texture(forward, i).region == frames.get_frame_texture(backward, count - 1 - i).region)
	assert(animated_count == 27)
	var static_count := 0
	for file in DirAccess.get_files_at(IMAGES + "Props/Individual_Props"):
		if not file.ends_with(".png"):
			continue
		static_count += 1
		var packed := load(PACK + "Props/Static/" + file.get_basename() + ".tscn") as PackedScene
		assert(packed != null)
		var sprite := packed.instantiate() as Sprite2D
		assert(sprite != null and sprite.texture != null)
		assert(sprite.offset.y == -sprite.texture.get_height() / 2.0)
		assert(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
		sprite.free()
	assert(static_count == 48)
	var gallery := (load(PACK + "asset_gallery.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	await process_frame
	await process_frame
	print("PASS: 102 PNGs, %d tiles, 21 character animations, 27 animated props, 48 static props, gallery startup" % tile_count)
	quit()

func check_frames(frames: SpriteFrames) -> void:
	for animation in frames.get_animation_names():
		assert(frames.get_frame_count(animation) > 0)
		for i in range(frames.get_frame_count(animation)):
			var frame := frames.get_frame_texture(animation, i) as AtlasTexture
			assert(frame != null and frame.atlas != null and frame.filter_clip)
			assert(Rect2(Vector2.ZERO, frame.atlas.get_size()).encloses(frame.region))
