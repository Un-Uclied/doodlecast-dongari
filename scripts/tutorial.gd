extends "res://scripts/level.gd"

enum Lesson { MOVE, SPELLS, HEART, DONE }
const PRACTICE_PATTERNS := [[&"horizontal", &"vertical"], [&"horizontal", &"chevron_up", &"chevron_down"], [&"star", &"spiral"]]

var _lesson := Lesson.MOVE
var _walked := 0.0
var _dashed := false
var _previous_position := Vector2.ZERO
var _example := PackedVector2Array()
var _example_time := 0.0
var _example_id: StringName = &""

func _ready() -> void:
	# Reuse the non-ranking run guard; tutorial results must never reach Firestore.
	GameRun.begin_run(GameRun.Mode.EASY, true)
	super._ready()
	_previous_position = player.global_position
	canvas.get_node("Panel").hide()
	canvas.input_enabled = false
	%TutorialExit.pressed.connect(_menu)
	_dialogue("발부터 풀어 볼까?", "반가워, 꼬마 마법사! 마왕성은 처음이지?\nWASD로 움직이고, Shift로 슝! 대시해 봐.\n여긴 연습장! 부딪혀도, 틀려도 괜찮아♪")

func _process(delta: float) -> void:
	if _lesson == Lesson.MOVE:
		_walked += _previous_position.distance_to(player.global_position)
		_previous_position = player.global_position
		_dashed = _dashed or player.dash_time_left > 0.0
		%LessonGoal.text = "이동 %s  ·  대시 %s" % ["완료!" if _walked >= 24.0 else "WASD", "완료!" if _dashed else "Shift"]
		if _walked >= 24.0 and _dashed and navigation_ready:
			_start_spells()
	if not _example.is_empty():
		_example_time = fmod(_example_time + delta, 2.6)
		%Example.points = _example.slice(0, clampi(int(_example_time / 1.8 * _example.size()) + 1, 2, _example.size()))

func enemy_budget() -> int:
	return PRACTICE_PATTERNS.size()

func _start_spells() -> void:
	_lesson = Lesson.SPELLS
	canvas.input_enabled = true
	_dialogue("낙서가 곧 마법!", "왼쪽 마우스를 꾹! 빈 공간에 기호를 그려 봐.\n맨 왼쪽부터 지우면 펑! 같은 기호는 한꺼번에!\n선·체크·별·회오리까지, 천천히 해도 좋아♪")
	spawned = enemy_budget()
	for index in range(PRACTICE_PATTERNS.size()):
		var enemy := ENEMY.instantiate()
		enemy.kind = [ENEMY_SCRIPT.Kind.SOLDIER, ENEMY_SCRIPT.Kind.ORC, ENEMY_SCRIPT.Kind.FLOATING_EYE][index]
		enemy.pattern.assign(PRACTICE_PATTERNS[index])
		enemy.reward = enemy.pattern.size() * 100
		enemy.level = self
		enemy.collision_layer = 0
		enemy.get_node("Contact").monitoring = false
		enemy.position = $Enemies.to_local(_practice_point(player.global_position + Vector2((index - 1) * 56.0, -32)))
		enemy.removed.connect(_on_enemy_removed)
		enemies.append(enemy)
		$Enemies.add_child(enemy)
		enemy.set_physics_process(false)
	_refresh_spell_hint()
	_update_hud()

func _practice_point(desired: Vector2) -> Vector2:
	var nearest: Vector2 = player.global_position
	var best := INF
	for cell in walkable_cells:
		var point: Vector2 = tiles.to_global(tiles.map_to_local(cell)) + Vector2(0, 3.5)
		if point.distance_to(player.global_position) < 24.0:
			continue
		var occupied := false
		for enemy in enemies:
			if point.distance_to(enemy.global_position) < 32.0:
				occupied = true
		if not occupied and point.distance_squared_to(desired) < best:
			best = point.distance_squared_to(desired)
			nearest = point
	assert(is_finite(best), "Tutorial requires free reachable floor for its practice targets")
	return nearest

func _remaining_symbols() -> int:
	var remaining := 0
	for enemy in enemies:
		remaining += enemy.pattern.size()
	return remaining

func _refresh_spell_hint() -> void:
	%LessonGoal.text = "남은 기호 %d개 · 빈 공간에 크게 그려도 명중!" % _remaining_symbols()
	for enemy in enemies:
		if not enemy.pattern.is_empty():
			_show_example(enemy.pattern[0])
			return
	_show_example(&"")

func _on_gesture_finished(result: Dictionary, started: int, completed: int) -> void:
	if _lesson not in [Lesson.SPELLS, Lesson.HEART]:
		return
	var before := _remaining_symbols()
	super._on_gesture_finished(result, started, completed)
	if _lesson == Lesson.HEART and not is_instance_valid(_heart):
		_lesson = Lesson.DONE
		canvas.input_enabled = false
		_show_example(&"")
		_dialogue("기초 마법 수료!", "움직이고, 그리고, 회복하고. 벌써 다 배웠네!\n잘 그리면 콤보도 D → S! 여러 적을 함께 맞혀 봐.\n이제 난이도를 고르고 진짜 모험을 시작하자♪")
		%LessonGoal.text = "연습 완료! · 연습 기록은 순위에 올라가지 않아요."
		%TutorialExit.text = "모험하러!"
		_update_hud()
	elif _lesson == Lesson.SPELLS and _remaining_symbols() < before:
		_refresh_spell_hint()
	elif result.get("pattern_id", &"") == &"":
		%LessonGoal.text = "앗, 살짝 삐끗! 예시처럼 크게, 한 번에 이어서 그려 봐♪"
	else:
		%LessonGoal.text = "모양은 좋아! %s" % ("이번엔 하트를 그려 보자♪" if _lesson == Lesson.HEART else "적 머리 위 맨 왼쪽 기호를 골라 보자♪")

func finish_level(cleared: bool) -> void:
	if cleared and _lesson == Lesson.SPELLS:
		call_deferred("_start_healing")
	elif not cleared:
		GameRun.active = false
		SceneTransition.change_scene("res://scenes/main_menu.tscn")

func _start_healing() -> void:
	_lesson = Lesson.HEART
	player.health = player.MAX_HEALTH - 1
	GameRun.health = player.health
	_heart = HEALING_HEART.instantiate()
	_heart.position = $Pickups.to_local(_practice_point(player.global_position + Vector2(48, -24)))
	$Pickups.add_child(_heart)
	_heart_spawned = true
	_show_example(&"heart")
	_dialogue("하트도 그려야 꿀꺽!", "마법 연습하느라 배고프지? 하트 한 입!\n몸으로 닿는 대신, 하트 모양을 그려서 회복해 봐.\n체력이 한 칸 비어 있어. 지금 채워 주면 딱이야♪")
	%LessonGoal.text = "하트 기호를 그려 체력 4 → 5로 회복하기"
	_update_hud()

func _dialogue(title: String, text: String) -> void:
	%LessonTitle.text = "지팡이 선배 · " + title
	%LessonStep.text = "%d / 3" % mini(_lesson + 1, 3)
	%LessonText.text = text

func _show_example(id: StringName) -> void:
	if id == _example_id:
		return
	_example_id = id
	_example_time = 0.0
	_example.clear()
	%Example.clear_points()
	%ExampleBox.visible = id != &""
	for definition in canvas.catalog.patterns:
		if definition.id != id:
			continue
		%ExampleName.text = definition.display_name
		var sample: PackedVector2Array = definition.samples[0]
		var bounds := Rect2(sample[0], Vector2.ZERO)
		for point in sample:
			bounds = bounds.expand(point)
		var factor := 56.0 / maxf(bounds.size.x, bounds.size.y)
		for index in range(sample.size() - 1):
			for step in range(12):
				_example.append((sample[index].lerp(sample[index + 1], step / 12.0) - bounds.get_center()) * factor)
		_example.append((sample[-1] - bounds.get_center()) * factor)
		return

func _update_hud() -> void:
	super._update_hud()
	hud.get_node("%Stage").text = "마법 입문 · %d / 3" % mini(_lesson + 1, 3)
	hud.get_node("%Score").hide()
	hud.get_node("%Remaining").hide()

func _toggle_pause() -> void:
	super._toggle_pause()
	%LessonPanel.visible = not get_tree().paused
	canvas.get_node("Panel").hide()
	canvas.input_enabled = not get_tree().paused and _lesson in [Lesson.SPELLS, Lesson.HEART]
	hud.get_node("%PauseStage").text = "마법 입문 · 연습 중"
