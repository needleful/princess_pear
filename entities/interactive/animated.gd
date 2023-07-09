extends Spatial

var active := false

func activate():
	set_active(true)

func fail_activate():
	if !active:
		$AnimationPlayer.play("FailedActivate")

func set_active(a):
	if active == a:
		return
	if a:
		$AnimationPlayer.play("Activate")
	else:
		$AnimationPlayer.play_backwards("Activate")
