extends Control

signal exit

onready var modal := $foreground

func _ready():
	generate_menus()
	hide()

func back():
	if modal.mode == 0:
		emit_signal("exit")
	else:
		modal.mode -= 1
		modal.get_child(modal.mode).get_child(0).grab_focus()

func generate_menus():
	var button_template := $foreground/options_panel/button_template
	var top_button := button_template
	for s in Settings.sub_options:
		var button := button_template.duplicate()
		button.text = s
		$foreground/options_panel.add_child_below_node(top_button, button)
		top_button = button
		button.focus_neighbour_left = button.get_path()
		var _x = button.connect("pressed", self, "_on_option_selected", [s])
	button_template.queue_free()

func set_active(active):
	if active:
		modal.mode = 0
		$foreground/main_menu/resume.grab_focus()
	else:
		Settings.save_settings()

func _on_option_selected(submenu: String):
	$foreground/options_template.menu_name = submenu
	modal.mode = 2

func _on_resume_pressed():
	emit_signal("exit")

func _on_options_pressed():
	modal.mode = 1
	$foreground/options_panel.get_child(0).grab_focus()

func _on_reload_pressed():
	Global.get_player().respawn()
	emit_signal("exit")

func _on_quit_pressed():
	Global.save_sync()
	get_tree().quit()

func _on_ui_redraw():
	get_tree().call_group("ui_settings_custom", "ui_settings_apply")

func _on_back_pressed():
	modal.mode = 0
	$foreground/main_menu/options.grab_focus()

func _on_options_back_pressed():
	modal.mode = 1
	$foreground/options_panel.get_child(0).grab_focus()
