extends AudioStreamPlayer

const MENU_TRACK := preload("res://sounds/Eric Skiff - A Night Of Dizzy Spells ♫ NO COPYRIGHT 8-bit Music + Background.mp3")
const GAME_TRACK := preload("res://sounds/Eric Skiff - Underclocked ♫ NO COPYRIGHT 8-bit Music + Background.mp3")
const NORMAL_DB := -10.0
const DUCKED_DB := -13.0

var ducked := false
var _target_db := NORMAL_DB
var _fade: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func play_track(track: AudioStream) -> void:
	ducked = false
	if stream == track and playing:
		return
	stream = track
	volume_db = -60.0
	play()
	_fade_to(NORMAL_DB, 1.2)

func _process(_delta: float) -> void:
	var target := DUCKED_DB if ducked or get_tree().paused else NORMAL_DB
	if target != _target_db:
		_fade_to(target, 0.3)

func _fade_to(target: float, duration: float) -> void:
	if _fade != null:
		_fade.kill()
	_target_db = target
	_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(self, "volume_db", target, duration)
