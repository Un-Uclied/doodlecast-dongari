extends Node

enum Mode { EASY, NORMAL, HARD }

const MODE_FOLDERS := ["easy", "normal", "hard"]
const MODE_NAMES := ["EASY", "NORMAL", "HARD"]
const REWARD_MULTIPLIERS := [0.75, 1.0, 1.25]
const SPAWN_MULTIPLIERS := [0.9, 1.0, 1.15]
const COMBO_RANKS := ["D", "C", "B", "A", "S"]
const COMBO_MULTIPLIERS := [1.0, 1.1, 1.2, 1.3, 1.4]
const COMBO_DECAY := [2.0, 3.0, 4.0, 5.5, 7.0]

var mode: Mode = Mode.NORMAL
var level_number := 1
var combat_score := 0
var elapsed_seconds := 0.0
var combo_meter := 0.0
var combo_rank: int:
	get:
		return clampi(int(combo_meter / 20.0), 0, 4)
var combo_multiplier: float:
	get:
		return COMBO_MULTIPLIERS[combo_rank]
var total_score: int:
	get:
		return maxi(0, combat_score + time_score())
var health := 5
var hits_taken := 0
var defeated := 0
var active := false
var debug_run := false
var mode_name: String:
	get:
		return "DEBUG" if debug_run else MODE_NAMES[mode]
var student_id := ""
var masked_name := ""
var run_id := ""
var tutorial_required := false

func set_player_info(identifier: String, full_name: String) -> void:
	student_id = identifier.strip_edges()
	var entered_name := full_name.strip_edges()
	match entered_name.length():
		0:
			masked_name = ""
		1:
			masked_name = "*"
		2:
			masked_name = entered_name.left(1) + "*"
		_:
			masked_name = entered_name.left(1) + "*".repeat(entered_name.length() - 2) + entered_name.right(1)

func begin_run(selected_mode: int, debug := false) -> void:
	assert(selected_mode >= Mode.EASY and selected_mode <= Mode.HARD)
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	mode = selected_mode as Mode
	debug_run = debug
	level_number = 6 if debug else 1
	combat_score = 0
	elapsed_seconds = 0.0
	combo_meter = 0.0
	health = 5
	hits_taken = 0
	defeated = 0
	active = true

func ranking_result(cleared: bool) -> Dictionary:
	return {
		"run_id": run_id,
		"participant_key": student_id.sha256_text(),
		"display_name": "학번 " + student_id + (" · " + masked_name.left(12) if not masked_name.is_empty() else ""),
		"status": "finished", "schema_version": 1,
		"score": total_score, "combat_score": combat_score, "time_penalty": -time_score(),
		"duration_ms": floori(elapsed_seconds * 1000.0 + 0.000001),
		"kills": defeated, "hits": hits_taken,
		"character": "마법사", "difficulty": MODE_NAMES[mode],
		"level": level_number, "cleared": int(cleared),
	}

func level_path() -> String:
	return "res://scenes/levels_%s/level_%02d.tscn" % [MODE_FOLDERS[mode], level_number]

func open_level() -> void:
	SceneTransition.change_scene(level_path())

func award(base_score: int) -> int:
	var points := roundi(base_score * REWARD_MULTIPLIERS[mode] * combo_multiplier)
	combat_score += points
	return points

func register_attack(hits: int, kills: int) -> void:
	assert(hits >= kills and kills >= 0)
	combo_meter = minf(100.0, combo_meter + hits * 3.0 + kills * 4.0 + hits * (hits - 1) * 0.75)

func fail_gesture() -> void:
	combo_meter = maxf(0.0, combo_meter - 12.0)

func decay_combo(delta: float) -> void:
	combo_meter = maxf(0.0, combo_meter - COMBO_DECAY[combo_rank] * delta)

func time_score() -> int:
	# Keep the time penalty outside the mode multiplier; the total has a zero floor.
	return -floori(elapsed_seconds * 10.0 + 0.000001)
