extends Modal

enum Mode {
	Debug,
	Pause,
	Dialog
}

var mode_before_pause:int = Mode.Debug

func _input(event):
	if event.is_action_pressed("pause"):
		if mode == Mode.Pause:
			unpause()
		else:
			pause()
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

func start_dialog(speaker):
	var p := Global.get_player()
	if p:
		p.dialog_lock()
	set_mode(Mode.Dialog)
	$dialog/viewer.start(speaker, speaker.sequence, speaker, speaker.custom_entry)

func end_dialog():
	var p := Global.get_player()
	if p:
		p.unlock()
	set_mode(Mode.Debug)

func _on_dialog_exited(_state):
	end_dialog()
	
