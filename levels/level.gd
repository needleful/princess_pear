extends Spatial

export(PackedScene) var next_level

func _ready():
	Global.save_async()
	Global.set_stat("level", filename)
	if !is_in_group("dialog_event_reciever"):
		add_to_group("dialog_event_reciever")
	if has_node("player"):
		var _x = $player.connect("captured", self, "_on_player_captured")

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

func _on_player_captured():
	Global.add_stat("mention_capture")
	var m := $makau
	var respawn:Spatial
	var p:Spatial = m.get_current_point()
	if !p:
		respawn = $main_path/player_start
	else:
		respawn = p.get_node("player_respawn")
	Global.save_checkpoint(respawn.global_transform)
	yield(Global, "save_completed")
	var _x = get_tree().reload_current_scene()
