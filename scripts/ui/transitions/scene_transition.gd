extends CanvasLayer

signal finished

const FADE_DURATION := 0.22
var transitioning := false
var _fade: Tween

func change_scene(path: String) -> void:
	if transitioning:
		return
	transitioning = true
	var was_paused := get_tree().paused
	var next_focus := get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	$Fade.show()
	$Fade.grab_focus()
	_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property($Fade, "color:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _fade.finished
	var error := get_tree().change_scene_to_file(path)
	if error == OK:
		await get_tree().scene_changed
		await get_tree().process_frame
		next_focus = get_viewport().gui_get_focus_owner()
		$Fade.grab_focus()
	else:
		push_error("Cannot open scene: %s (error %d)" % [path, error])
	_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property($Fade, "color:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _fade.finished
	$Fade.hide()
	get_tree().paused = was_paused if error != OK else false
	if is_instance_valid(next_focus) and next_focus != $Fade and next_focus.is_visible_in_tree():
		next_focus.grab_focus()
	transitioning = false
	finished.emit()
