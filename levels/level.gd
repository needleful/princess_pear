extends Spatial

export(PackedScene) var next_level

func _ready():
	Global.save_async()
	if !is_in_group("dialog_event_reciever"):
		add_to_group("dialog_event_reciever")

func _on_event(event):
	match event:
		"next_level":
			if !next_level:
				print_debug("No next level!")
				return
			var a = Global.get_player().get_fade_animation()
			a.play("fade_to_black")
			yield(a, "animation_finished")
			var res = Global.change_level_to(next_level)
			if res != OK:
				print_debug("Could not go to next level: ", next_level.resource_path)
