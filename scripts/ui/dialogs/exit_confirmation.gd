extends ColorRect

var _menu_was_paused := false
var _menu_focus: Control

func _ready() -> void:
	%ExitCancel.pressed.connect(cancel)

func open() -> void:
	if visible:
		return
	_menu_was_paused = get_tree().paused
	_menu_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	show()
	%ExitCancel.grab_focus()

func cancel() -> void:
	if SceneTransition.transitioning or not visible:
		return
	hide()
	get_tree().paused = _menu_was_paused
	if is_instance_valid(_menu_focus):
		_menu_focus.grab_focus()
