extends Resource
class_name GameState

export(Dictionary) var stats: Dictionary
export(Dictionary) var inventory: Dictionary
export(Transform) var checkpoint_position: Transform
export(Array, NodePath) var picked_items: Array

func _init():
	inventory = {}
	stats = {}
	resource_name = "GameState"
