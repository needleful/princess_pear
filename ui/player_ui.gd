extends Modal

enum Mode {
	Debug,
	Pause
}

var mode_before_pause:int = Mode.Debug

func _input(event):
	if event.is_action_pressed("pause"):
		unpause() if mode == Mode.Pause else pause()
	elif event.is_action_pressed("ui_cancel"):
		if get_child(mode).has_method("back"):
			get_child(mode).back()

func pause():
	mode_before_pause = mode
	get_tree().paused = true
	set_mode(Mode.Pause)

func unpause():
	get_tree().paused = false
	set_mode(mode_before_pause)
