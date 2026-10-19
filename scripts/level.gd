extends Node2D

enum Difficulty {
	LEVEL_1 = 1,
	LEVEL_2,
	LEVEL_3,
	LEVEL_4,
	LEVEL_5,
	LEVEL_6,
	LEVEL_7,
}

@export var difficulty: Difficulty = Difficulty.LEVEL_1
@export_range(1, 6, 1) var level_number: int = 1
@export_enum("Easy", "Normal", "Hard") var mode: int = 1

const ENEMY := preload("res://scenes/enemy.tscn")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const LIGHTNING := preload("res://scenes/effects/lightning.tscn")
const TORCH_LIGHT := preload("res://scenes/effects/torch_light.tscn")
const SPAWN_WARNING := preload("res://scenes/effects/spawn_warning.tscn")
const CLOSED_DOOR_SOURCE := 2
const OPEN_DOOR_SOURCE := 3
const LENGTHS := [Vector2i(1, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7)]
const HARD_COUNTS := [Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 3)]
const SIMPLE_PATTERNS := [&"horizontal", &"vertical", &"chevron_up", &"chevron_down"]
const HARD_PATTERNS := [&"star", &"spiral"]

var finished := false
var spawned := 0
var enemies: Array[Node2D] = []
var _pending_spawns: Array[Node2D] = []
var rng := RandomNumberGenerator.new()
var grid := AStarGrid2D.new()
var walkable_cells: Array[Vector2i] = []
var _spawn_time_left := 1.5
var _starting_score := 0
var navigation_ready := false

@onready var player = $Player
@onready var tiles: TileMapLayer = $TileMapLayer
@onready var furniture: TileMapLayer = $TileMapLayerFurniture
@onready var canvas = $GestureCanvas/Canvas
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	Music.play_track(Music.GAME_TRACK)
	if not GameRun.active or GameRun.mode != mode:
		GameRun.begin_run(mode)
	GameRun.level_number = level_number
	player.health = GameRun.health
	_starting_score = GameRun.total_score
	rng.randomize()
	_setup_lighting()
	_build_grid()
	_refine_navigation()
	canvas.gesture_finished.connect(_on_gesture_finished)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(func(_falling: bool): finish_level(false))
	hud.get_node("%Continue").pressed.connect(_continue)
	hud.get_node("%Menu").pressed.connect(_menu)
	hud.pause_requested.connect(_toggle_pause)
	hud.get_node("%PauseButton").pressed.connect(_toggle_pause)
	hud.get_node("%Resume").pressed.connect(_toggle_pause)
	hud.get_node("%PauseMenu").pressed.connect(_menu)
	hud.get_node("%ExitConfirm").pressed.connect(_confirm_menu)
	canvas.get_node("Panel").position.y = 76.0
	canvas.show_recognition_details = false
	canvas.result_label.text = "적 머리 위의 기호를 왼쪽부터 그리세요."
	canvas.detail_label.text = "같은 기호의 적들을 한 번에 공격할 수 있습니다."
	_update_hud()

func _setup_lighting() -> void:
	for layer: TileMapLayer in find_children("*", "TileMapLayer", true, false):
		if not layer.enabled or layer.tile_set == null:
			continue
		for cell in layer.get_used_cells():
			var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			if source == null or source.resource_name not in ["torch1", "candlestick1"]:
				continue
			var data := layer.get_cell_tile_data(cell)
			var flame := layer.map_to_local(cell) - Vector2(data.texture_origin) + Vector2(0, -source.texture_region_size.y * 0.5 + 7)
			var light := TORCH_LIGHT.instantiate()
			$Lighting.add_child(light)
			light.global_position = layer.to_global(flame)

func enemy_budget() -> int:
	return 12 + 2 * difficulty + level_number

func spawn_interval() -> float:
	return 0.85 * (4.0 - 0.4 * difficulty) * (1.0 - 0.04 * (level_number - 1)) / GameRun.SPAWN_MULTIPLIERS[mode]

func generate_pattern() -> Array[StringName]:
	var bounds: Vector2i = LENGTHS[difficulty - 1]
	var hard_bounds: Vector2i = HARD_COUNTS[difficulty - 1]
	var length := rng.randi_range(bounds.x, bounds.y)
	var hard_count := rng.randi_range(hard_bounds.x, hard_bounds.y)
	var sequence: Array[StringName] = []
	for index in range(length):
		var pool: Array = HARD_PATTERNS if index < hard_count else SIMPLE_PATTERNS
		sequence.append(pool[rng.randi_range(0, pool.size() - 1)])
	for index in range(sequence.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var symbol := sequence[index]
		sequence[index] = sequence[other]
		sequence[other] = symbol
	return sequence

func _build_grid() -> void:
	grid.region = tiles.get_used_rect()
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	grid.fill_solid_region(grid.region, true)
	var candidates: Array[Vector2i] = []
	for cell in tiles.get_used_cells():
		var data := tiles.get_cell_tile_data(cell)
		if tiles.get_cell_source_id(cell) == 0 and data != null and data.get_collision_polygons_count(0) == 0:
			grid.set_point_solid(cell, false)
			candidates.append(cell)
	# Collision tiles on overlay layers (including pits) also block paths and spawns.
	for layer in find_children("*", "TileMapLayer", true, false):
		if layer == tiles or not layer.enabled or not layer.collision_enabled or layer.tile_set == null:
			continue
		for cell in layer.get_used_cells():
			var data: TileData = layer.get_cell_tile_data(cell)
			if data == null:
				continue
			for physics_layer in range(layer.tile_set.get_physics_layers_count()):
				if (layer.tile_set.get_physics_layer_collision_layer(physics_layer) & 1) == 0 or data.get_collision_polygons_count(physics_layer) == 0:
					continue
				var point: Vector2 = layer.to_global(layer.map_to_local(cell))
				var blocked := tiles.local_to_map(tiles.to_local(point))
				if grid.is_in_boundsv(blocked):
					grid.set_point_solid(blocked, true)
	var start := tiles.local_to_map(tiles.to_local(player.global_position + Vector2(0, -3.5)))
	assert(grid.is_in_boundsv(start) and not grid.is_point_solid(start), "Player must start on a floor cell")
	for cell in candidates:
		if not grid.is_point_solid(cell) and not grid.get_id_path(start, cell).is_empty():
			walkable_cells.append(cell)
	assert(not walkable_cells.is_empty(), "Level needs reachable floor tiles")

func _refine_navigation() -> void:
	# TileMap collisions reach the physics server after the first physics step.
	await get_tree().physics_frame
	await get_tree().process_frame
	var enemy := ENEMY.instantiate()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = enemy.get_node("CollisionShape2D").shape
	query.collision_mask = 1
	enemy.free()
	var space := get_world_2d().direct_space_state
	for cell in walkable_cells:
		query.transform = Transform2D(0.0, tiles.to_global(tiles.map_to_local(cell)))
		if not space.intersect_shape(query, 1).is_empty():
			grid.set_point_solid(cell, true)
	var start := tiles.local_to_map(tiles.to_local(player.global_position + Vector2(0, -3.5)))
	walkable_cells = walkable_cells.filter(func(cell: Vector2i): return not grid.is_point_solid(cell) and not grid.get_id_path(start, cell).is_empty())
	navigation_ready = true

func is_floor_segment(from: Vector2, to: Vector2) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / (tiles.tile_set.tile_size.x * 0.5)))
	for index in range(steps + 1):
		var feet := from.lerp(to, float(index) / steps) + Vector2(0, -3.5)
		var cell := tiles.local_to_map(tiles.to_local(feet))
		if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
			return false
	return true

func path_to_player(from: Vector2) -> PackedVector2Array:
	var start := tiles.local_to_map(tiles.to_local(from + Vector2(0, -3.5)))
	var target := tiles.local_to_map(tiles.to_local(player.global_position + Vector2(0, -3.5)))
	var path := PackedVector2Array()
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(target) or grid.is_point_solid(start) or grid.is_point_solid(target):
		return path
	var cells := grid.get_id_path(start, target)
	for index in range(1, cells.size()):
		path.append(tiles.to_global(tiles.map_to_local(cells[index])) + Vector2(0, 3.5))
	if not cells.is_empty():
		path.append(player.global_position)
	return path

func _process(delta: float) -> void:
	if finished:
		return
	var previous_time_score := GameRun.time_score()
	GameRun.elapsed_seconds += delta
	GameRun.decay_combo(delta)
	hud.update_combo()
	if GameRun.time_score() != previous_time_score:
		_update_hud()
	_spawn_time_left -= delta
	if _spawn_time_left <= 0.0 and spawned < enemy_budget() and enemies.size() + _pending_spawns.size() < mini(10, 3 + difficulty):
		_spawn_time_left = spawn_interval()
		if await spawn_enemy() == null and not finished:
			_spawn_time_left = 0.5

func spawn_enemy(kind_override: int = -1) -> Node2D:
	if not navigation_ready or finished or spawned >= enemy_budget():
		return null
	var kinds := range(ENEMY_SCRIPT.Kind.size())
	var wisps := 0
	for enemy in enemies:
		if enemy.kind == ENEMY_SCRIPT.Kind.FLAME_WISP:
			wisps += 1
	for warning in _pending_spawns:
		if warning.get_meta("kind") == ENEMY_SCRIPT.Kind.FLAME_WISP:
			wisps += 1
	if wisps >= mode + 1:
		kinds.erase(ENEMY_SCRIPT.Kind.FLAME_WISP)
	if kind_override >= 0 and not kind_override in kinds:
		return null
	var selected_kind: int = kinds[rng.randi_range(0, kinds.size() - 1)] if kind_override < 0 else kind_override
	var candidates := PackedVector2Array()
	for cell in walkable_cells:
		var point := tiles.to_global(tiles.map_to_local(cell)) + Vector2(0, 3.5)
		if point.distance_to(player.global_position) < 96.0:
			continue
		var occupied := false
		for enemy in enemies + _pending_spawns:
			if point.distance_to(enemy.global_position) < 24.0:
				occupied = true
				break
		if not occupied:
			candidates.append(point)
	if candidates.is_empty():
		return null
	var warning := SPAWN_WARNING.instantiate()
	warning.set_meta("kind", selected_kind)
	$Effects.add_child(warning)
	warning.global_position = candidates[rng.randi_range(0, candidates.size() - 1)]
	warning.get_node("Sparks").restart()
	_pending_spawns.append(warning)
	spawned += 1
	_update_hud()
	await warning.get_node("SpawnTimer").timeout
	var point: Vector2 = warning.global_position
	_pending_spawns.erase(warning)
	warning.queue_free()
	if finished:
		return null
	var enemy := ENEMY.instantiate()
	enemy.kind = selected_kind
	if enemy.kind == enemy.Kind.BOMB_WALKER:
		enemy.pattern.assign([SIMPLE_PATTERNS[rng.randi_range(0, SIMPLE_PATTERNS.size() - 1)]])
	else:
		enemy.pattern = generate_pattern()
	enemy.reward = 100 * enemy.pattern.size()
	for symbol: StringName in enemy.pattern:
		if symbol in HARD_PATTERNS:
			enemy.reward += 100
	enemy.level = self
	enemy.position = $Enemies.to_local(point)
	enemy.removed.connect(_on_enemy_removed)
	enemies.append(enemy)
	$Enemies.add_child(enemy)
	_update_hud()
	return enemy

func _on_gesture_finished(result: Dictionary, _started: int, _completed: int) -> void:
	var pattern_id: StringName = result.get("pattern_id", &"")
	if finished:
		return
	if pattern_id == &"":
		GameRun.fail_gesture()
		hud.update_combo()
		$MagicFailSound.play()
		canvas.result_label.modulate = Color(1, 0.6, 0.55)
		return
	var targets: Array[Node2D] = []
	var kills := 0
	for enemy in enemies.duplicate():
		if not enemy.resolved and not enemy.pattern.is_empty() and enemy.pattern[0] == pattern_id:
			targets.append(enemy)
			if enemy.pattern.size() == 1:
				kills += 1
	# Award the whole gesture's gain first so simultaneous kills share one multiplier.
	GameRun.register_attack(targets.size(), kills)
	for enemy in targets:
		var impact: Vector2 = enemy.hit_position()
		if enemy.consume_pattern(pattern_id):
			player.shake_camera(0.8)
			var bolt := LIGHTNING.instantiate()
			bolt.caster = player
			bolt.target = enemy
			bolt.position = $Effects.to_local(player.global_position + Vector2(0, -12))
			bolt.target_offset = $Effects.to_local(impact) - bolt.position
			$Effects.add_child(bolt)
	_update_hud()
	canvas.result_label.modulate = Color(1, 0.84, 0.48) if not targets.is_empty() else Color(0.85, 0.72, 0.9)
	canvas.detail_label.text = "적 %d마리 적중 · %d마리 처치" % [targets.size(), kills] if not targets.is_empty() else "이 기호로 공격할 적이 없습니다."
	if not targets.is_empty():
		$MagicSuccessSound.play()

func _on_enemy_removed(enemy: Node2D, defeated: bool) -> void:
	enemies.erase(enemy)
	if finished:
		return
	if defeated:
		GameRun.award(enemy.reward)
		GameRun.defeated += 1
	_update_hud()
	if defeated:
		hud.pulse_remaining()
	if spawned == enemy_budget() and enemies.is_empty() and _pending_spawns.is_empty():
		finish_level(true)

func _on_health_changed(current: int, _maximum: int) -> void:
	GameRun.health = current
	_update_hud()

func _update_hud() -> void:
	hud.get_node("%Health").text = "HP  %d / 5" % player.health
	hud.get_node("%Stage").text = "%s  %d / 6  ·  DIFF %d" % [GameRun.MODE_NAMES[mode], level_number, difficulty]
	hud.get_node("%Score").text = "SCORE  %s\n경과 %s · 감점 %s점" % [hud.format_number(GameRun.total_score), hud.format_duration(GameRun.elapsed_seconds), hud.format_number(-GameRun.time_score())]
	hud.get_node("%Remaining").text = "남은 적  %d" % (enemy_budget() - spawned + enemies.size() + _pending_spawns.size())
	hud.update_combo()

func finish_level(cleared: bool) -> void:
	if finished:
		return
	finished = true
	Music.ducked = true
	get_tree().paused = false
	hud.set_paused(false)
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.get_node("DashParticles").emitting = false
	player.sprite.stop()
	for enemy in enemies:
		enemy.set_physics_process(false)
		enemy.sprite.stop()
	for bullet in $Projectiles.get_children():
		bullet.queue_free()
	for warning in _pending_spawns:
		warning.hide()
	canvas.cancel_stroke()
	canvas.input_enabled = false
	if cleared:
		GameRun.award(250 * difficulty)
		$LevelClearSound.play()
	var final_clear := cleared and level_number == 6
	hud.set_results(cleared, GameRun.total_score - _starting_score)
	if cleared:
		_play_clear_sequence()
	else:
		get_tree().create_timer(0.35, false).timeout.connect(_show_results)
	if not cleared or final_clear:
		GameRun.active = false
		if GameRun.student_id.length() == 5:
			Leaderboard.queue_result(GameRun.ranking_result(cleared))
	_update_hud()

func _play_clear_sequence() -> void:
	var doors := furniture.get_used_cells_by_id(CLOSED_DOOR_SOURCE)
	if doors.is_empty():
		get_tree().create_timer(0.35, false).timeout.connect(_show_results)
		return
	var cell: Vector2i = doors[0]
	var data := furniture.get_cell_tile_data(cell)
	var door_center := furniture.to_global(furniture.map_to_local(cell) - Vector2(data.texture_origin))
	var camera: Camera2D = player.get_node("Camera2D")
	var screen_center := camera.get_screen_center_position()
	camera.position_smoothing_enabled = false
	camera.global_position = screen_center
	var tween := create_tween()
	# Keep the final hit visible, then show the door before the results cover it.
	tween.tween_interval(0.35)
	tween.tween_property(camera, "global_position", door_center, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_open_exit_door.bind(cell))
	tween.tween_interval($DoorOpenSound.stream.get_length() + 0.15)
	tween.tween_callback(_show_results)

func _open_exit_door(cell: Vector2i) -> void:
	furniture.set_cell(cell, OPEN_DOOR_SOURCE, furniture.get_cell_atlas_coords(cell), furniture.get_cell_alternative_tile(cell))
	$DoorOpenSound.play()

func _show_results() -> void:
	canvas.get_node("Panel").hide()
	hud.show_results()

func _toggle_pause() -> void:
	if finished or SceneTransition.transitioning or hud.get_node("%MenuConfirmation").visible:
		return
	var paused := not get_tree().paused
	get_tree().paused = paused
	canvas.cancel_stroke()
	canvas.input_enabled = not paused
	canvas.get_node("Panel").visible = not paused
	hud.set_paused(paused)
	hud.get_node("%Resume" if paused else "%PauseButton").grab_focus()

func _continue() -> void:
	if SceneTransition.transitioning or hud.get_node("%MenuConfirmation").visible:
		return
	GameRun.level_number = level_number + 1
	GameRun.open_level()

func _menu() -> void:
	if SceneTransition.transitioning:
		return
	hud.confirm_menu()

func _confirm_menu() -> void:
	if SceneTransition.transitioning or not hud.get_node("%MenuConfirmation").visible:
		return
	GameRun.active = false
	SceneTransition.change_scene("res://scenes/main_menu.tscn")
