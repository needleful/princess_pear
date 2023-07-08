extends VBoxContainer

# warning-ignore:unused_signal
signal item_focused(item)
# warning-ignore:unused_signal
signal item_pressed(item)

onready var list:Container = $ScrollContainer.container
onready var sort_label := $sort/Label

enum Sort {
	Chronological,
	Name,
	Recency
}

var sort = Sort.Chronological
var sort_func := [
	"sort_by_chronological",
	"sort_by_name",
	"sort_by_recency"
]
var key_sort_func := [
	"sort_by_chronological",
	"key_sort_by_name",
	"key_sort_by_recency"
]

var buttons: Dictionary
var inventory: Dictionary

func _init():
	buttons = {}
	inventory = {}

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process_input(is_visible_in_tree())

func _input(event):
	if !is_visible_in_tree():
		set_process_input(false)
		return
	if event.is_action_pressed("ui_sort"):
		sort += 1
		sort = sort % Sort.size()
		$sort/Label.text = "Sorting by: " + Sort.keys()[sort]
		redraw()

func clear():
	buttons = {}
	inventory = {}
	Util.clear(list)

func insert_item(id:String, item: ItemDescription):
	var button := Button.new()
	buttons[id] = button
	inventory[id] = item
	button.text = item.full_name.capitalize()
	if item.custom_icon:
		button.icon = item.custom_icon
	var _y = button.connect("focus_entered", self, "emit_signal", ["item_focused", item])
	_y = button.connect("pressed", self, "emit_signal", ["item_pressed", item])
	list.add_child(button)

func view_items(items: Dictionary):
	sort_label.text = "Sorting by: " + Sort.keys()[sort]
	for id in items:
		items[id].id = id
	var sorted_items = items.values()
	sorted_items.sort_custom(self, sort_func[sort])
	
	for item in sorted_items:
		insert_item(item.id, item)
	
	if list.get_child_count() > 0:
		list.get_child(0).grab_focus()

func sort_by_chronological(a: ItemDescription, b:ItemDescription):
	return sort_by_recency(b, a)

func sort_by_name(a: ItemDescription, b: ItemDescription):
	return a.full_name < b.full_name

func sort_by_recency(a: ItemDescription, b: ItemDescription):
	return key_sort_by_recency(a.id, b.id)

func key_sort_by_chronological(a: String, b: String):
	return sort_by_chronological(inventory[a], inventory[b])

func key_sort_by_name(a: String, b: String):
	return sort_by_name(inventory[a], inventory[b])

func key_sort_by_recency(a: String, b: String):
	return Global.get_item_recency(a) > Global.get_item_recency(b)

func redraw():
	var old_focus = get_focus_owner()
	for c in buttons.values():
		list.remove_child(c)
	var keys = buttons.keys()
	keys.sort_custom(self, key_sort_func[sort])
	for k in keys:
		list.add_child(buttons[k])
	if old_focus:
		old_focus.grab_focus()
