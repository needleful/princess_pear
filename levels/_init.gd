extends Node

export(PackedScene) var level_one

func _enter_tree():
	Global.load_sync()

func _ready():
	if Global.has_stat("level"):
		var res = get_tree().change_scene(Global.stat("level"))
		if res != OK:
			print_debug("ERROR: could not load: ", Global.stat("level"))
	else:
		var res = Global.change_level_to(level_one)
		assert(res == OK)
