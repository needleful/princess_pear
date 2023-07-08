tool
extends Control
class_name Modal

export(int) var mode setget set_mode

func set_mode(m):
	if m < 0:
		m = 0
	if m >= get_child_count():
		m = get_child_count() - 1
	for i in get_child_count():
		var c = get_child(i)
		c.visible = i == m
		if c.has_method("set_active"):
			c.set_active(i == m)
	mode = m
