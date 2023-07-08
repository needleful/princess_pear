extends Node
class_name ControlsSettings

export(float, 0.1, 4.0, 0.2) var camera_sensitivity := 1.0
export(bool) var invert_x := false
export(bool) var invert_y := false

func get_name() -> String:
	return "Controls"
