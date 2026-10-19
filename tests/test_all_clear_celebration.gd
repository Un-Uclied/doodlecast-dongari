extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	get_tree().create_timer(15.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_celebration")

func test_celebration() -> void:
	for sample in [[1, true, false], [6, false, false], [6, true, true]]:
		GameRun.begin_run(GameRun.Mode.HARD)
		GameRun.level_number = sample[0]
		GameRun.combat_score = 50000
		GameRun.elapsed_seconds = 67.8
		GameRun.health = 3
		GameRun.hits_taken = 4
		GameRun.defeated = 100
		var hud = load("res://scenes/combat_hud.tscn").instantiate()
		get_tree().root.add_child(hud)
		hud.set_results(sample[1], 1000)
		var art: TextureRect = hud.get_node("%VictoryArt")
		assert(art.visible == sample[2], "Victory art belongs only on all clear")
		assert(art.texture.resource_path == "res://image_assets/마법 지팡이를 든 승리의 픽셀 소년.png" and art.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		assert(not hud.get_node("%YaySound").playing and not hud.get_node("%Confetti").emitting)
		hud.show_results()
		await get_tree().process_frame
		await get_tree().process_frame
		if sample[2]:
			var card: Control = hud.get_node("%ResultTitle").get_parent().get_parent()
			assert(art.size.x > 100.0 and art.size.y > 100.0)
			assert(art.get_global_rect().end.x < card.get_global_rect().position.x, "The portrait must not cover the result text or buttons")
		assert(hud.get_node("%ClearMessage").visible == sample[2])
		assert(hud.get_node("%YaySound").playing == sample[2] and hud.get_node("%Confetti").emitting == sample[2])
		if sample[2]:
			assert(hud.get_node("%ClearMessage").text == "마왕성 던전을 클리어 했습니다!")
			assert(hud.get_node("%ResultTitle").text == "ALL CLEAR" and not hud.get_node("%Continue").visible)
			await get_tree().create_timer(0.12).timeout
			var position: float = hud.get_node("%YaySound").get_playback_position()
			hud.show_results()
			await get_tree().create_timer(0.12).timeout
			assert(hud.get_node("%YaySound").get_playback_position() > position, "Showing an already open result must not restart the celebration")
			if DisplayServer.get_name() != "headless":
				await get_tree().create_timer(0.55).timeout
				await RenderingServer.frame_post_draw
				var lit := get_viewport().get_texture().get_image()
				assert(lit.save_png("res://.godot/all-clear-celebration-preview.png") == OK)
				hud.get_node("%Confetti").hide()
				await RenderingServer.frame_post_draw
				var background := get_viewport().get_texture().get_image()
				var paper_pixels := 0
				for y in range(450):
					for x in range(1152):
						var a := lit.get_pixel(x, y)
						var b := background.get_pixel(x, y)
						if a.r > b.r + 0.2 or a.g > b.g + 0.2 or a.b > b.b + 0.2:
							paper_pixels += 1
				assert(paper_pixels > 100, "Confetti must visibly render over the result background")
			for resolution in [Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(640, 480)]:
				get_tree().root.size = resolution
				get_tree().root.content_scale_size = resolution
				await get_tree().process_frame
				await get_tree().process_frame
				var card: Control = hud.get_node("%ResultTitle").get_parent().get_parent()
				assert(art.get_global_rect().end.x < card.get_global_rect().position.x, "The portrait must leave results unobstructed at %s" % resolution)
				if DisplayServer.get_name() != "headless" and resolution.x == 960:
					await RenderingServer.frame_post_draw
					assert(get_viewport().get_texture().get_image().save_png("res://.godot/clear-character-small-preview.png") == OK)
		hud.queue_free()
		await get_tree().process_frame
	print("PASS: all-clear-only victory portrait, supplied texture and nonblocking layout at 640–1920px; final-only message/confetti/yay, celebration plays once, score/menu remain usable")
	get_tree().quit()
