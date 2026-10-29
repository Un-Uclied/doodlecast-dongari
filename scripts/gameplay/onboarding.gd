extends Node

const LESSONS := [
	{"kind": 0, "patterns": [&"horizontal", &"vertical"]},
	{"kind": 1, "patterns": [&"chevron_up", &"chevron_down"]},
	{"kind": 2, "patterns": [&"horizontal"]},
	{"kind": 3, "patterns": [&"square", &"triangle"]},
	{"kind": 4, "patterns": [&"star"]},
	{"kind": 5, "patterns": [&"spiral"]},
]

var elapsed := 0.0
var dashed := false
var lesson := 0
var phase := 0
var _spawning := false
var _hint := Label.new()
var _example := Line2D.new()
var _example_points := PackedVector2Array()
var _example_id := &""
var _example_time := 0.0
@onready var level = get_parent()

func _ready() -> void:
	level.player.practice_invulnerable = true
	level.player.get_node("Camera2D").zoom = Vector2(1.8, 1.8)
	level.canvas.get_node("Panel").hide()
	level.canvas.input_enabled = false
	level.hud.get_node("Root/Top/%Score").hide()
	level.hud.get_node("Root/Top/%Remaining").hide()
	level.hud.get_node("Root/Top/%ComboRank").get_parent().hide()
	level.hud.get_node("Root/CombatFeedback/%FeedbackText").hide()
	level.hud.get_node("Root/Top/%Stage").text = "마법 입문"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.z_index = -1
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_constant_override("outline_size", 7)
	_hint.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.05))
	_hint.text = "WASD 이동   ·   SHIFT 무적 대시\n대시 중에는 공격 피해를 받지 않음"
	level.hud.get_node("Root").add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -92
	_hint.offset_bottom = -24
	_example.width = 4.0
	_example.z_index = -1
	_example.default_color = Color(1.0, 0.86, 0.4)
	_example.antialiased = true
	level.hud.get_node("Root").add_child(_example)
	level.canvas.gesture_finished.connect(_on_gesture)

func _process(delta: float) -> void:
	if phase == 2 or level.finished:
		return
	elapsed += delta
	dashed = dashed or level.player.dash_time_left > 0.0
	if phase == 0 and elapsed >= 5.0 and dashed and level.navigation_ready:
		phase = 1
		level.canvas.input_enabled = true
	if phase == 1 and not _spawning and level.enemies.is_empty() and lesson < LESSONS.size():
		_spawn_lesson()
	if not _example_points.is_empty():
		_example_time = fmod(_example_time + delta, 2.6)
		_example.points = _example_points.slice(0, maxi(2, int(_example_time / 1.8 * _example_points.size())))
		_example.position = Vector2(level.get_viewport_rect().size.x * 0.5, level.get_viewport_rect().size.y - 140)

func _spawn_lesson() -> void:
	_spawning = true
	var enemy = await level.spawn_enemy(LESSONS[lesson].kind)
	if enemy != null:
		enemy.pattern.assign(LESSONS[lesson].patterns)
		enemy.reward = 0
		enemy.queue_redraw()
		lesson += 1
		if lesson == 5:
			level.player.health = level.player.MAX_HEALTH - 1
			GameRun.health = level.player.health
			level.spawn_heart()
			level._update_hud()
		_refresh_example()
	_spawning = false

func _on_gesture(_result: Dictionary, _started: int, _completed: int) -> void:
	_refresh_example()

func _refresh_example() -> void:
	if phase == 2:
		return
	var id: StringName
	if is_instance_valid(level._heart):
		id = &"heart"
		_hint.text = "하트 문양을 그려 회복하기\n하트는 회복 아이템 전용"
	elif not level.enemies.is_empty() and not level.enemies[0].pattern.is_empty():
		id = level.enemies[0].pattern[0]
		_hint.text = "좌클릭을 누른 채 한 번에 그리기\n화살표가 가리키는 왼쪽 문양부터  ·  %d / 6" % lesson
	else:
		if lesson == LESSONS.size():
			complete()
		return
	if id == _example_id:
		return
	_example_id = id
	_example_time = 0.0
	_example_points.clear()
	for definition in level.canvas.catalog.patterns:
		if definition.id != id:
			continue
		var sample: PackedVector2Array = definition.samples[0]
		var bounds := Rect2(sample[0], Vector2.ZERO)
		for point in sample:
			bounds = bounds.expand(point)
		for index in range(sample.size() - 1):
			for step in range(8):
				_example_points.append((sample[index].lerp(sample[index + 1], step / 8.0) - bounds.get_center()) * 64.0 / maxf(bounds.size.x, bounds.size.y))
		return

func complete() -> void:
	if phase == 2 or is_instance_valid(level._heart):
		return
	phase = 2
	level.canvas.cancel_stroke()
	level.canvas.input_enabled = false
	Leaderboard.complete_tutorial(GameRun.student_id)
	GameRun.tutorial_required = false
	GameRun.begin_run(level.mode)
	GameRun.open_level()
