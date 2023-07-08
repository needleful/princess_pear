extends Control

signal item_pressed(item)
signal item_focused(item)
signal cancelled

onready var item_name := $h/item_properties/label
onready var item_desc := $h/item_properties/ScrollContainer/description
onready var item_viewer := $h/list


func _ready():
	set_active(false)

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_active(is_visible_in_tree())

func set_active(active):
	if active:
		item_viewer.view_items(Global.get_fancy_inventory())
	else:
		item_viewer.clear()
	set_process(active)
	set_process_input(active)

func _on_item_focused(item: ItemDescription):
	item_name.text = item.full_name
	item_desc.text = item.description
	emit_signal("item_focused", item)

func _on_item_pressed(item: ItemDescription):
	emit_signal("item_pressed", item)
	hide()

func cancel():
	emit_signal("cancelled")
	hide()
