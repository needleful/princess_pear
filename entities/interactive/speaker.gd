extends Node
class_name Speaker

export(Resource) var sequence: Resource
export(String) var visual_name: String
export(String) var friendly_id: String
export(String) var custom_entry: String
export(Dictionary) var custom_fonts
export(Dictionary) var custom_colors

func interact(player: PlayerBody):
	player.ui.start_dialog(self, get_parent())
