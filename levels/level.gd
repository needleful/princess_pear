extends Spatial

export(PackedScene) var next_level

func _ready():
	Global.save_async()

func _on_event(event):
	match event:
		"next_level":
			var a = Global.get_player().get_fade_animation()
			a.play("fade_to_black")
			yield(a, "animation_finished")
			var _x = Global.change_level_to(next_level)
