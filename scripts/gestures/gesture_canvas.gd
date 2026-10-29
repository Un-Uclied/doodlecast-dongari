extends Control

signal gesture_finished(result: Dictionary, started_at_usec: int, completed_at_usec: int)

const MAX_POINTS := 4096
const INK := Color(0.82, 0.55, 1.0, 0.85)
const SUCCESS := Color(1.0, 0.84, 0.48, 0.85)
const FAILURE := Color(1.0, 0.5, 0.45, 0.85)

@export var catalog: PatternCatalog
@export var show_recognition_details := true
## 그린 모양의 가로·세로 중 긴 길이가 화면의 짧은 변에서 차지해야 하는 최소 비율입니다.
@export_range(1.0, 100.0, 0.5, "suffix:%") var min_stroke_size_percent := 2.0

@onready var result_label: Label = $Panel/Margin/Rows/Result
@onready var detail_label: Label = $Panel/Margin/Rows/Detail

var recognizer: GestureRecognizer
var last_result: Dictionary = {}
var drawing := false
var input_enabled := true
var points := PackedVector2Array()
var _started_at_usec := 0
var _previous_accumulation := true
var _ink_color := INK
var _ink_time_left := 0.0
var _trail_dirty := false

func _ready() -> void:
	recognizer = GestureRecognizer.new(catalog)
	if not recognizer.configuration_error.is_empty():
		input_enabled = false
		result_label.text = "패턴 설정 오류"
		detail_label.text = recognizer.configuration_error
		push_error(recognizer.configuration_error)
	get_window().focus_exited.connect(cancel_stroke)
	get_window().mouse_exited.connect(cancel_stroke)
	get_viewport().size_changed.connect(cancel_stroke)

func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and not get_tree().paused and not drawing and event is InputEventMouseButton and event.is_action_pressed("draw_pattern"):
		drawing = true
		points = PackedVector2Array([event.position])
		$CursorParticles.position = event.position
		$CursorParticles.emitting = true
		_started_at_usec = Time.get_ticks_usec()
		_previous_accumulation = Input.use_accumulated_input
		Input.use_accumulated_input = false
		_ink_color = INK
		result_label.text = "그리는 중…"
		result_label.modulate = Color(0.9, 0.73, 1)
		detail_label.text = "마우스를 놓으면 판정합니다."
		_trail_dirty = true
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not drawing:
		return
	if get_tree().paused:
		cancel_stroke()
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		cancel_stroke()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_append_point(event.position)
		else:
			cancel_stroke()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.is_action_released("draw_pattern"):
		$CursorParticles.emitting = false
		var completed_at_usec := Time.get_ticks_usec()
		if _append_point(event.position):
			drawing = false
			Input.use_accumulated_input = _previous_accumulation
			var min_extent := minf(size.x, size.y) * min_stroke_size_percent / 100.0
			last_result = recognizer.recognize(points, maxf(1.0, min_extent))
			_show_result()
			_ink_time_left = 0.45
			_trail_dirty = true
			gesture_finished.emit(last_result, _started_at_usec, completed_at_usec)
		get_viewport().set_input_as_handled()

func _append_point(point: Vector2) -> bool:
	if not point.is_finite() or points.size() >= MAX_POINTS:
		cancel_stroke()
		return false
	if points.is_empty() or point.distance_squared_to(points[-1]) > 0.25:
		points.append(point)
		_trail_dirty = true
	$CursorParticles.position = point
	return true

func _show_result() -> void:
	if last_result.pattern_id != &"":
		result_label.text = "인식: " + last_result.display_name
		_ink_color = SUCCESS
	else:
		var reasons := {&"invalid_input": "너무 짧거나 작은 입력", &"no_match": "일치하는 패턴 없음", &"ambiguous": "두 패턴 사이에서 모호함"}
		result_label.text = "인식 실패: " + reasons.get(last_result.reason, "패턴 설정 오류")
		_ink_color = FAILURE
	if not show_recognition_details:
		detail_label.text = "한 번에 이어서, 기호를 또렷하게 그려 보세요."
	elif last_result.candidate_id == &"":
		detail_label.text = "최소 크기: 화면 짧은 변의 %.1f%% 이상" % min_stroke_size_percent
	else:
		detail_label.text = "후보 %s · 오차 %.3f · 2위 %.3f" % [last_result.candidate_id, last_result.error, last_result.runner_up_error]

func cancel_stroke() -> void:
	if drawing:
		Input.use_accumulated_input = _previous_accumulation
		drawing = false
		result_label.text = "그리기 취소"
		result_label.modulate = Color.WHITE
		detail_label.text = "좌클릭을 누르고 새로 그리세요."
	points.clear()
	_ink_time_left = 0.0
	$CursorParticles.emitting = false
	for line: Line2D in [$GlowStroke, $Stroke, $CoreStroke]:
		line.clear_points()
	_trail_dirty = false

func _on_player_died(_by_falling: bool) -> void:
	cancel_stroke()
	input_enabled = false
	result_label.text = "플레이어가 쓰러졌습니다."
	detail_label.text = ""

func _process(delta: float) -> void:
	if drawing and get_tree().paused:
		cancel_stroke()
	if not drawing and not points.is_empty():
		_ink_time_left -= delta
		if _ink_time_left <= 0.0:
			points.clear()
			_trail_dirty = true
	if _trail_dirty:
		_refresh_trail()
		_trail_dirty = false
	var opacity := 1.0 if drawing else clampf(_ink_time_left / 0.45, 0.0, 1.0)
	$GlowStroke.default_color = Color(_ink_color, 0.15 * opacity)
	$Stroke.default_color = Color(_ink_color, 0.8 * opacity)
	$CoreStroke.default_color = Color(Color(1, 0.91, 0.71).lerp(_ink_color, 0.2), opacity)

func _refresh_trail() -> void:
	var visual_points := points
	if points.size() > 2:
		var curve := Curve2D.new()
		for index in range(points.size()):
			var before := points[maxi(0, index - 1)]
			var after := points[mini(points.size() - 1, index + 1)]
			var tangent := (after - before) * 0.16
			curve.add_point(points[index], -tangent if index > 0 else Vector2.ZERO, tangent if index < points.size() - 1 else Vector2.ZERO)
		visual_points = curve.tessellate(3, 12.0)
	for line: Line2D in [$GlowStroke, $Stroke, $CoreStroke]:
		line.points = visual_points

func _exit_tree() -> void:
	if drawing:
		Input.use_accumulated_input = _previous_accumulation
