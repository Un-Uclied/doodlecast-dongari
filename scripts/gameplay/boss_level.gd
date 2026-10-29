extends "res://scripts/gameplay/level.gd"

enum State { INTRO, READY, ATTACK, WINDOW, RECOVER, DEAD }
enum AttackKind { GRID, SECTORS, METEORS, DASH, SPIRAL, ROSE, SWEEP, FAN }
const ATTACK := preload("res://scenes/effects/boss_attack.tscn")
const EXPLOSION := preload("res://scenes/effects/boss_explosion.tscn")
const DIRECTIONS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const PROJECTILE := preload("res://scenes/gameplay/enemies/boss_projectile.tscn")
const MAX_BOSS_HEALTH := 200
const WINDOW_DAMAGE := 20
const WINDOW_SECONDS := [14.0, 12.0, 10.0]
const WARNING_SECONDS := [1.1, 1.0, 0.9]
const SECTOR_WARNING_SECONDS := [1.8, 1.6, 1.4]
const ATTACKS_PER_CYCLE := [2, 2, 3]
const BULLET_SPEED := [240.0, 260.0, 290.0]
const FIRE_VOLUME_DB := -5.0
const GOLD := Color(1.0, 0.78, 0.35)
const VIOLET := Color(0.85, 0.45, 1.0)
const ASSET_PATH := "res://image_assets/enemies/E_Bros_Assets_TopDownEnemy/Enemy-Melee-%s-%s.png"

var state := State.INTRO
var boss_health := MAX_BOSS_HEALTH
var phase: int:
	get:
		return 1 if boss_health > MAX_BOSS_HEALTH * 0.66 else (2 if boss_health > MAX_BOSS_HEALTH * 0.33 else 3)
var window_left := 0.0
var attack_sequence: Array[StringName] = []
var arena := Rect2()
var boss: AnimatedSprite2D
var _center := Vector2.ZERO
var _age := 0.0
var _attacks: Array[int] = []
var _attack_bag: Array[int] = []
var _attack_kind := 0
var _attack_age := 0.0
var _attack_duration := 0.0
var _wave_index: int = 0
var _wave_left: float = 0.0
var _waves_total: int = 0
var _wave_interval: float = 0.0
var _pattern_angle: float = 0.0
var _dash_origin := Vector2.ZERO
var _dash_target := Vector2.ZERO
var _motion_age: float = 0.0
var _hover_tween: Tween
var _aura: Node2D
var _volley_fired := false
var _intro: Control
var _timer: Label
var _window: Control
var _window_bar: ProgressBar
var _phase_label: Label
var _facing := "S"
var _health_root: Control
var _health_bar: ProgressBar
var _health_trail: ProgressBar
var _health_tween: Tween
var _strip: Control
var _warning_sound: AudioStreamPlayer
var _fire_sound: AudioStreamPlayer
var _rush_sound: AudioStreamPlayer
var _hit_sound: AudioStreamPlayer
var _cast_sparks: CPUParticles2D
var _impact_left := 0.0

func _ready() -> void:
	super._ready()
	var bounds := tiles.get_used_rect()
	var unit := Vector2(tiles.tile_set.tile_size)
	arena = Rect2(tiles.to_global(Vector2(bounds.position) * unit), Vector2(bounds.size) * unit)
	_center = tiles.to_global(tiles.map_to_local(walkable_cells[0])) + Vector2(0, 3.5)
	for cell in walkable_cells:
		var point := tiles.to_global(tiles.map_to_local(cell)) + Vector2(0, 3.5)
		if point.distance_squared_to(arena.get_center()) < _center.distance_squared_to(arena.get_center()):
			_center = point
	Music.play_track(Music.BOSS_TRACK)
	_setup_boss()
	_setup_boss_hud()
	_setup_intro()
	hud.status.hide()
	_update_hud()
	canvas.get_node("Panel").hide()
	canvas.get_node("Panel").position.y = 104.0
	canvas.result_label.text = "아래 기호를 왼쪽부터 그리세요."
	canvas.detail_label.text = "공격 시간에 기호 7개를 완성하세요."
	canvas.input_enabled = false
	player.set_physics_process(false)

func _setup_boss() -> void:
	boss = AnimatedSprite2D.new()
	boss.name = "ShadowKnight"
	boss.sprite_frames = SpriteFrames.new()
	for direction in DIRECTIONS:
		for action in ["Idle", "Attack"]:
			var texture := load(ASSET_PATH % [action, direction]) as Texture2D
			var animation: String = action + direction
			boss.sprite_frames.add_animation(animation)
			boss.sprite_frames.set_animation_speed(animation, 12.0)
			for index in range(texture.get_width() / 256):
				var frame := AtlasTexture.new()
				frame.atlas = texture
				frame.region = Rect2(index * 256, 0, 256, 256)
				boss.sprite_frames.add_frame(animation, frame)
	var death := load("res://image_assets/enemies/E_Bros_Assets_TopDownEnemy/Enemy-Melee-Death.png") as Texture2D
	boss.sprite_frames.add_animation("Death")
	boss.sprite_frames.set_animation_loop("Death", false)
	boss.sprite_frames.set_animation_speed("Death", 12)
	for index in range(death.get_width() / 256):
		var frame := AtlasTexture.new()
		frame.atlas = death
		frame.region = Rect2(index * 256, 0, 256, 256)
		boss.sprite_frames.add_frame("Death", frame)
	boss.scale = Vector2.ONE * 0.48
	boss.position = _center
	boss.offset.y = -34
	boss.z_index = 2
	add_child(boss)
	boss.play("IdleS")
	_hover_tween = create_tween().set_loops()
	_hover_tween.tween_property(boss, "offset:y", -46.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hover_tween.tween_property(boss, "offset:y", -34.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_aura = preload("res://scenes/effects/boss_aura.tscn").instantiate()
	_aura.scale = Vector2.ONE / boss.scale.x
	_aura.position = boss.offset
	boss.add_child(_aura)
	_cast_sparks = preload("res://scenes/effects/magic_sparks.tscn").instantiate()
	_cast_sparks.one_shot = true
	_cast_sparks.explosiveness = 1
	_cast_sparks.amount = 36
	_cast_sparks.emission_sphere_radius = 16
	_cast_sparks.initial_velocity_min = 35
	_cast_sparks.initial_velocity_max = 85
	_cast_sparks.position = Vector2(0, -34)
	boss.add_child(_cast_sparks)

func _face_player() -> void:
	var target: Vector2 = player.sprite.to_global(player.sprite.offset)
	var origin: Vector2 = boss.to_global(boss.offset)
	var offset: Vector2 = target - origin
	if offset.length_squared() > 0.01:
		_facing = DIRECTIONS[posmod(roundi(offset.angle() / (PI * 0.25)), 8)]
	var animation := ("Attack" if state == State.ATTACK else "Idle") + _facing
	if boss.animation == animation:
		return
	var same_action := String(boss.animation).begins_with("Attack") == (state == State.ATTACK)
	var frame := boss.frame
	var progress := boss.frame_progress
	boss.play(animation)
	if same_action:
		boss.set_frame_and_progress(frame, progress)

func _setup_boss_hud() -> void:
	_health_root = preload("res://scenes/ui/hud/boss_hud.tscn").instantiate()
	hud.status.add_child(_health_root)
	hud.status.move_child(_health_root, 1)
	hud.status.get_node("%Stage").hide()
	hud.status.get_node("RemainingSlot").hide()
	_health_bar = _health_root.get_node("%HealthBar")
	_health_trail = _health_root.get_node("%HealthTrail")
	for bar: ProgressBar in [_health_bar, _health_trail]:
		bar.max_value = MAX_BOSS_HEALTH
		bar.value = boss_health
	_phase_label = _health_root.get_node("%BossPhase")
	_warning_sound = _health_root.get_node("Audio/Warning")
	_fire_sound = _health_root.get_node("Audio/Fire")
	_rush_sound = _health_root.get_node("Audio/Rush")
	_hit_sound = _health_root.get_node("Audio/Hit")
	_window = preload("res://scenes/ui/hud/boss_window.tscn").instantiate()
	hud.get_node("Root").add_child(_window)
	_timer = _window.get_node("%Timer")
	_strip = _window.get_node("%Patterns")
	_window_bar = _window.get_node("%TimeBar")
	_window.hide()

func _setup_intro() -> void:
	Music.ducked = true
	_intro = preload("res://scenes/ui/screens/boss_intro.tscn").instantiate()
	hud.get_node("Root").add_child(_intro)

func enemy_budget() -> int:
	return 0

func is_boss_fight() -> bool:
	return true

func _process(delta: float) -> void:
	if finished:
		return
	_age += delta
	_motion_age += delta
	_impact_left = maxf(0.0, _impact_left - delta)
	if state == State.INTRO:
		if _age >= _intro.duration:
			_intro.queue_free()
			Music.ducked = false
			hud.status.show()
			player.set_physics_process(true)
			canvas.input_enabled = true
			canvas.get_node("Panel").show()
			state = State.READY
			_age = 0.0
		return
	_update_motion(delta)
	_face_player()
	if state == State.READY:
		if _age >= 2.0:
			_begin_cycle()
		return
	super._process(delta)
	match state:
		State.ATTACK:
			_update_attack(delta)
		State.WINDOW:
			window_left = maxf(0.0, window_left - delta)
			_timer.text = "%.1f초" % window_left
			_window_bar.value = window_left
			if window_left <= 0.0:
				_end_window(false)
		State.RECOVER:
			if _age >= 0.8:
				_begin_cycle()

func _update_motion(delta: float) -> void:
	_aura.position = boss.offset
	_cast_sparks.position = boss.offset
	if state in [State.READY, State.WINDOW, State.RECOVER]:
		var toward: Vector2 = (player.global_position - _center).normalized()
		var side: Vector2 = toward.orthogonal()
		var target: Vector2 = _center + side * sin(_motion_age * 1.5) * 28.0 - toward * cos(_motion_age * 0.9) * 12.0
		if not is_floor_segment(_center, target):
			target = _center
		boss.global_position = boss.global_position.lerp(target, 1.0 - exp(-delta * 2.8))

func _begin_cycle() -> void:
	if finished:
		return
	_clear_attacks()
	state = State.ATTACK
	_attacks.clear()
	for slot in range(ATTACKS_PER_CYCLE[mode] + mini(phase - 1, 1)):
		if _attack_bag.is_empty():
			_attack_bag.assign(range(AttackKind.size()))
			for index in range(_attack_bag.size() - 1, 0, -1):
				var other: int = rng.randi_range(0, index)
				var value: int = _attack_bag[index]
				_attack_bag[index] = _attack_bag[other]
				_attack_bag[other] = value
		_attacks.append(_attack_bag.pop_front())
	_start_next_attack()

func _start_next_attack() -> void:
	if _attacks.is_empty():
		_begin_window()
		return
	_attack_kind = _attacks.pop_front()
	_attack_age = 0.0
	_wave_index = 0
	_waves_total = 0
	_wave_interval = 0.0
	_wave_left = 0.0
	var warning: float = _warning_seconds()
	_timer.text = ""
	_face_player()
	_cast_sparks.restart()
	_warning_sound.play()
	match _attack_kind:
		AttackKind.GRID:
			var spacing: int = 84 - mode * 6
			var shift: int = rng.randi_range(16, 48)
			var width: float = 12.0 + mode + phase * 1.5
			for x in range(int(arena.position.x) + shift, int(arena.end.x), spacing):
				_hazard(_rect(Rect2(x, arena.position.y, width, arena.size.y)))
			for y in range(int(arena.position.y) + shift, int(arena.end.y), spacing):
				_hazard(_rect(Rect2(arena.position.x, y, arena.size.x, width)))
			_attack_duration = warning + 0.9
		AttackKind.SECTORS:
			var direction: int = rng.randi_range(0, 3)
			_sector(direction)
			if phase >= 2:
				_sector((direction + rng.randi_range(1, 3)) % 4)
			_attack_duration = warning + 0.9
		AttackKind.METEORS:
			_waves_total = 6 + phase
			_wave_interval = 0.42 - phase * 0.04
			_attack_duration = (_waves_total - 1) * _wave_interval + warning + 0.9
		AttackKind.DASH:
			_dash_origin = boss.global_position
			_dash_target = player.global_position
			_volley_fired = false
			_attack_duration = warning + 1.3
			var marker: Node2D = preload("res://scenes/effects/attack_telegraph.tscn").instantiate()
			marker.points = _circle(_dash_target, 28)
			marker.duration = warning
			$Projectiles.add_child(marker)
			marker.charged.connect(marker.queue_free)
		AttackKind.SPIRAL:
			_waves_total = 30
			_wave_interval = 0.13
		AttackKind.ROSE:
			_waves_total = 4 + phase
			_wave_interval = 0.95 - phase * 0.05
		AttackKind.SWEEP:
			_waves_total = 4 + phase
			_wave_interval = 0.36 - phase * 0.04
			_pattern_angle = PI * (0.25 if rng.randf() < 0.5 else 0.75)
			_attack_duration = (_waves_total - 1) * _wave_interval + warning + 0.9
		AttackKind.FAN:
			_waves_total = 8 + phase
			_wave_interval = 0.75 - phase * 0.05
	if _attack_kind in [AttackKind.SPIRAL, AttackKind.ROSE, AttackKind.FAN]:
		_wave_left = warning
		_pattern_angle = (player.global_position - boss.global_position).angle()
		_attack_duration = warning + (_waves_total - 1) * _wave_interval + 0.7
		var core: Node2D = _hazard(_circle(boss.global_position, 30))
		if core != null:
			core.active_duration = _attack_duration - warning

func _update_attack(delta: float) -> void:
	var previous_age: float = _attack_age
	_attack_age += delta
	var warning: float = _warning_seconds()
	if _waves_total > 0:
		_wave_left -= delta
		while _wave_left <= 0.0 and _wave_index < _waves_total:
			_emit_attack_wave()
			_wave_index += 1
			_wave_left += _wave_interval
	if _attack_kind == AttackKind.DASH:
		if previous_age < warning and _attack_age >= warning:
			_rush_sound.play()
		var elapsed: float = _attack_age - warning
		if elapsed >= 0.0 and elapsed < 0.22:
			boss.global_position = _dash_origin.lerp(_dash_target, elapsed / 0.22)
		elif elapsed >= 0.22 and not _volley_fired:
			boss.global_position = _dash_target
			_volley_fired = true
			_fire_boss_volley()
		elif elapsed >= 0.5:
			boss.global_position = _dash_target.lerp(_dash_origin, clampf((elapsed - 0.5) / 0.4, 0.0, 1.0))
	if _attack_age >= _attack_duration:
		_start_next_attack()

func _emit_attack_wave() -> void:
	var speed: float = BULLET_SPEED[mode] + (phase - 1) * 15.0
	var origin: Vector2 = boss.global_position
	match _attack_kind:
		AttackKind.METEORS:
			_hazard(_circle(player.global_position, 26.0 + phase * 2.0), true)
		AttackKind.SWEEP:
			var across: Vector2 = Vector2.from_angle(_pattern_angle).orthogonal()
			var offset: float = (float(_wave_index) / (_waves_total - 1) - 0.5) * arena.size.length() * 0.6
			var center: Vector2 = _center + across * offset
			var along: Vector2 = Vector2.from_angle(_pattern_angle) * arena.size.length()
			var edge: Vector2 = across * (7.0 + phase)
			_hazard(PackedVector2Array([center - along - edge, center + along - edge, center + along + edge, center - along + edge]))
		AttackKind.SPIRAL:
			var arms: int = 3
			var spin: float = _pattern_angle + _wave_index * 0.19
			for arm in range(arms):
				_spawn_bullet(origin, spin + TAU * arm / arms, speed, 0.32, GOLD)
				if phase == 3:
					_spawn_bullet(origin, -spin + TAU * arm / arms, speed * 0.92, -0.28, VIOLET)
			if _wave_index % 6 == 0:
				_shot_impact(1.2)
		AttackKind.ROSE:
			var count: int = 24 + phase * 6
			for index in range(count):
				var angle: float = TAU * index / count + _wave_index * 0.22
				var petal_speed: float = speed * (0.85 + 0.15 * cos(angle * 5.0))
				_spawn_bullet(origin, angle, petal_speed, 0.32 * sin(angle * 3.0), GOLD if _wave_index % 2 == 0 else VIOLET)
			_shot_impact(1.8)
		AttackKind.FAN:
			var aim: float = (player.global_position - origin).angle() + sin(_wave_index * 0.55) * 0.2
			var count: int = 7 + phase
			for index in range(count):
				var spread: float = lerpf(-0.65, 0.65, float(index) / (count - 1))
				_spawn_bullet(origin, aim + spread, speed, 0.4 if _wave_index % 2 == 0 else -0.4, VIOLET if _wave_index % 2 == 0 else GOLD)
			if _wave_index % 2 == 0:
				_shot_impact(1.6)

func _spawn_bullet(origin: Vector2, angle: float, speed: float, turn: float, tint: Color) -> void:
	play_projectile_sound(0.0)
	var bullet = PROJECTILE.instantiate()
	var direction: Vector2 = Vector2.from_angle(angle)
	bullet.level = self
	bullet.velocity = direction * speed
	bullet.turn_rate = turn
	bullet.tint = tint
	bullet.position = $Projectiles.to_local(origin + direction * 24.0)
	$Projectiles.add_child(bullet)

func _fire_boss_volley() -> void:
	_shot_impact(3.0)
	_explode(boss.global_position, 32.0)
	_cast_sparks.restart()
	var count: int = 24 + (phase - 1) * 6
	var speed: float = BULLET_SPEED[mode] + (phase - 1) * 15.0
	for index in range(count):
		var angle: float = TAU * index / count + _age * 0.2
		_spawn_bullet(boss.global_position, angle, speed * (0.9 + 0.1 * cos(angle * 6.0)), 0.45 if index % 2 == 0 else -0.45, GOLD if index % 2 == 0 else VIOLET)

func _shot_impact(strength: float = 1.2) -> void:
	player.shake_camera(strength)

func _attack_impact(strength := 2.6) -> void:
	if _impact_left > 0.0 or finished:
		return
	_impact_left = 0.08
	_warning_sound.stop()
	_fire_sound.volume_db = FIRE_VOLUME_DB
	_fire_sound.pitch_scale = rng.randf_range(0.98, 1.02)
	_fire_sound.play()
	player.shake_camera(strength)

func _warning_seconds() -> float:
	return SECTOR_WARNING_SECONDS[mode] if _attack_kind == AttackKind.SECTORS else WARNING_SECONDS[mode]

func _sector(direction: int) -> void:
	var origin: Vector2 = boss.global_position
	var polygon := PackedVector2Array([origin])
	for index in range(25):
		polygon.append(origin + Vector2.from_angle(direction * PI * 0.5 - PI * 0.25 + index * PI * 0.5 / 24.0) * arena.size.length())
	_hazard(polygon)

func _hazard(polygon: PackedVector2Array, explosive := false) -> Node2D:
	var clipped := Geometry2D.intersect_polygons(polygon, _rect(arena))
	if clipped.is_empty():
		return null
	polygon = clipped[0]
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	var center := bounds.get_center()
	var hazard := ATTACK.instantiate()
	hazard.level = self
	hazard.charge_duration = _warning_seconds()
	hazard.explosive = explosive
	hazard.top_level = true
	hazard.position = center
	var local_polygon := PackedVector2Array()
	for point in polygon:
		local_polygon.append(point - center)
	hazard.polygon = local_polygon
	$Projectiles.add_child(hazard)
	return hazard

func _explode(point: Vector2, radius: float) -> void:
	var blast := EXPLOSION.instantiate()
	blast.radius = radius
	blast.position = $Effects.to_local(point)
	$Effects.add_child(blast)

func _stop_fire() -> void:
	_fire_sound.stop()

func _rect(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for index in range(32):
		polygon.append(center + Vector2.from_angle(TAU * index / 32.0) * radius)
	return polygon

func _clear_attacks() -> void:
	for attack in $Projectiles.get_children():
		attack.set_physics_process(false)
		attack.hide()
		attack.queue_free()

func _toggle_pause() -> void:
	super._toggle_pause()
	_window.visible = not finished and state == State.WINDOW and not get_tree().paused
	canvas.get_node("Panel").visible = not finished and state != State.INTRO and not get_tree().paused
	if state == State.INTRO:
		canvas.input_enabled = false
		hud.status.hide()

func finish_level(cleared: bool) -> void:
	if finished:
		return
	_warning_sound.stop()
	_stop_fire()
	_rush_sound.stop()
	$ProjectileSound.stop()
	if _hover_tween != null:
		_hover_tween.kill()
	_aura.hide()
	_clear_attacks()
	for control in [_timer, _strip, _window, _health_root, _intro]:
		if is_instance_valid(control):
			control.hide()
	if cleared:
		_explode(boss.global_position + Vector2(0, -16), 68.0)
		boss.play("Death")
	else:
		boss.stop()
	super.finish_level(cleared)

func _begin_window() -> void:
	_clear_attacks()
	_warning_sound.stop()
	_stop_fire()
	_window.show()
	state = State.WINDOW
	window_left = WINDOW_SECONDS[mode]
	attack_sequence.clear()
	var pool: Array = PatternCatalog.COMBAT_POOL
	if mode >= GameRun.Mode.NORMAL:
		pool += PatternCatalog.TIER_3 + PatternCatalog.TIER_3
	if mode == GameRun.Mode.HARD:
		pool = PatternCatalog.INTERMEDIATE_PATTERNS + PatternCatalog.INTERMEDIATE_PATTERNS + PatternCatalog.TIER_3 + PatternCatalog.TIER_3 + PatternCatalog.TIER_3 + PatternCatalog.TIER_3 + [&"square", &"triangle"]
	for index in range(7):
		attack_sequence.append(pool[rng.randi_range(0, pool.size() - 1)])
	_strip.patterns = attack_sequence.duplicate()
	_timer.text = "%.1f초" % window_left
	_window_bar.max_value = window_left
	_window_bar.value = window_left
	_face_player()
	var warning := preload("res://scenes/effects/attack_telegraph.tscn").instantiate()
	warning.name = "ArenaWarning"
	warning.points = _rect(arena.grow(48))
	warning.duration = window_left
	warning.modulate.a = 0.2
	$Projectiles.add_child(warning)

func _on_gesture_finished(result: Dictionary, started: int, completed: int) -> void:
	super._on_gesture_finished(result, started, completed)
	if finished or result.get("pattern_id", &"") == &"heart" or state != State.WINDOW or attack_sequence.is_empty():
		return
	if result.get("pattern_id", &"") != attack_sequence[0]:
		return
	attack_sequence.pop_front()
	_strip.patterns = attack_sequence.duplicate()
	GameRun.register_attack(1, 0)
	hud.feedback(&"hit")
	$MagicSuccessSound.play()
	player.shake_camera(2.2)
	_hit_burst()
	var bolt := LIGHTNING.instantiate()
	bolt.caster = player
	bolt.position = $Effects.to_local(player.global_position + Vector2(0, -12))
	bolt.target_offset = $Effects.to_local(boss.to_global(boss.offset)) - bolt.position
	$Effects.add_child(bolt)
	if attack_sequence.is_empty():
		_end_window(true)

func _end_window(success: bool) -> void:
	if state != State.WINDOW:
		return
	_clear_attacks()
	canvas.cancel_stroke()
	state = State.RECOVER
	_age = 0
	attack_sequence.clear()
	_strip.patterns = attack_sequence.duplicate()
	_timer.text = ""
	_window.hide()
	if success:
		boss_health = maxi(0, boss_health - WINDOW_DAMAGE)
		GameRun.award(500)
		_damage_health_bar()
		_hit_sound.play()
		player.shake_camera(6.0)
		_hit_burst(48)
		boss.modulate = Color(2, 1, 2)
		create_tween().tween_property(boss, "modulate", Color.WHITE, 0.3)
		if boss_health <= 0:
			GameRun.defeated += 1
			state = State.DEAD
			finish_level(true)
	else:
		player.take_damage(true)
		_attack_impact(5.0)
		_explode(_center, maxf(arena.size.x, arena.size.y) * 0.65)

func _hit_burst(amount: int = 28) -> void:
	var sparks: CPUParticles2D = preload("res://scenes/effects/magic_sparks.tscn").instantiate()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = amount
	sparks.initial_velocity_min = 45.0
	sparks.initial_velocity_max = 110.0
	sparks.position = $Effects.to_local(boss.to_global(boss.offset))
	$Effects.add_child(sparks)
	sparks.finished.connect(sparks.queue_free)
	sparks.restart()

func _damage_health_bar() -> void:
	_aura.rage = float(phase - 1) * 0.5
	_health_bar.value = boss_health
	if _health_tween != null:
		_health_tween.kill()
	_phase_label.text = "%d페이즈" % phase
	_health_bar.modulate = Color(2.5, 2.5, 2.5)
	_health_tween = create_tween().set_parallel()
	_health_tween.tween_property(_health_trail, "value", float(boss_health), 0.5).set_delay(0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_health_tween.tween_property(_health_bar, "modulate", Color.WHITE, 0.22)

func _update_hud() -> void:
	super._update_hud()
	hud.get_node("Root/Top/%Stage").text = "DEBUG · BOSS TEST" if GameRun.debug_run else "%s  ·  FINAL BOSS" % GameRun.mode_name
	hud.get_node("Root/Top/%Remaining").text = "%d페이즈" % phase
	if is_instance_valid(_phase_label):
		_phase_label.text = "%d페이즈" % phase
