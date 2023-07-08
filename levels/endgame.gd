extends Control

func get_input():
	$VBoxContainer/restart.grab_focus()

func _on_restart_pressed():
	var a = $AnimationPlayer
	a.play("exit")
	yield(a, "animation_finished")
	Global.reset_game()

func _on_quit_pressed():
	var a = $AnimationPlayer
	a.play("exit")
	yield(a, "animation_finished")
	get_tree().quit()
