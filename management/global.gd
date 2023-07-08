extends Node

signal inventory_changed
signal item_changed(item, change, count)
signal stat_changed(tag, value)

var using_gamepad := false

var game_state : GameState

const save_path := "user://autosave.tres"
const old_save_backup := "user://autosave.backup.tres"
var valid_game_state := false setget set_valid_game_state, get_valid_game_state
var player_spawned := false
var can_pause := true

var save_thread := Thread.new()
var player : Node
var stats_temp: Dictionary

var render_distance := 1.0
var show_lowres := true

func _init():
	game_state = GameState.new()
	stats_temp = {}
	pause_mode = Node.PAUSE_MODE_PROCESS

func _input(event):
	var ogg := using_gamepad
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		using_gamepad = true
	elif event is InputEventMouse or event is InputEventKey:
		using_gamepad = false
	
	if ogg != using_gamepad:
		get_tree().call_group("input_prompt", "_refresh")

func change_level_to(scene: PackedScene):
	set_stat("level", scene.resource_path)
	return get_tree().change_scene_to(scene)

func get_mouse_zoom_axis() -> float:
	return 15*( float(Input.is_action_just_released("mouse_zoom_in"))
			- float(Input.is_action_just_released("mouse_zoom_out")) )

func get_action_input_string(action: String, override = null):
	var gamepad
	if override != null:
		gamepad = override
	else:
		gamepad = using_gamepad
		
	var input: InputEvent
	for event in InputMap.get_action_list(action):
		if gamepad and (
			event is InputEventJoypadButton
			or event is InputEventJoypadMotion
		):
			input = event
			break

		elif !gamepad and (
			event is InputEventKey
			or event is InputEventMouseButton
		):
			input = event
			break
	
	if input is InputEventKey:
		var scancode = input.physical_scancode
		if !scancode:
			scancode = input.scancode
		var key_str = OS.get_scancode_string(scancode)
		if key_str == "":
			key_str = "<unbound>"
		return key_str

	return get_input_string(input)

func get_input_string(input:InputEvent):
	if input is InputEventJoypadButton:
		return "gamepad"+str(input.button_index)
	elif input is InputEventMouseButton:
		return "mouse"+str(input.button_index)
	elif input is InputEventJoypadMotion:
		return "axis"+str(input.axis)
	return str(input)

func get_player() -> Node:
	for n in get_tree().get_nodes_in_group("player"):
		return n
	return null

func set_valid_game_state(state):
	valid_game_state = state and game_state

func get_valid_game_state():
	if !game_state:
		valid_game_state = false
	return valid_game_state

func count(item: String) -> int:
	if item in game_state.inventory:
		return game_state.inventory[item]
	else:
		return 0

func add_item(item: String, amount:= 1) -> int:
	if item in game_state.inventory:
		game_state.inventory[item] += amount
	else:
		game_state.inventory[item] = amount
	var _x = Global.set_item_recency(item)
	emit_signal("inventory_changed")
	emit_signal("item_changed", item, amount, game_state.inventory[item])
	return game_state.inventory[item]

func remove_item(item: String, amount := 1) -> bool:
	if count(item) >= amount:
		var _x = add_item(item, -amount)
		return true
	else:
		return false

func set_item_count(item: String, amount: int) -> bool:
	var old_amount = count(item)
	game_state.inventory[item] = amount
	emit_signal("inventory_changed")
	emit_signal("item_changed", item, amount - old_amount, amount)
	return true

func set_item_recency(item: String):
	return set_stat("pick_time/"+item, OS.get_unix_time())

func get_item_recency(item: String):
	return stat("pick_time/"+item)

func node_stat(node: Node) -> String:
	 return node.name + "." + str(hash(node.get_path()))

func has_stat(index: String) -> bool:
	return index in game_state.stats

func stat(index: String):
	if index in game_state.stats:
		return game_state.stats[index]
	else:
		return 0

func stats(ids: Array) -> bool:
	for e in ids:
		if !stat(e):
			return false
	return true

func set_stat(tag: String, value):
	game_state.stats[tag] = value
	emit_signal("stat_changed", tag, value)
	return value

func add_stat(tag: String, amount := 1) -> int:
	if tag in game_state.stats:
		game_state.stats[tag] += amount
	else:
		game_state.stats[tag] = amount
	var value =  game_state.stats[tag]
	emit_signal("stat_changed", tag, value)
	return value

func remove_stat(tag: String) -> bool:
	return game_state.stats.erase(tag)
	
func temp_stat(index: String):
	if index in stats_temp:
		return stats_temp[index]
	else:
		return 0

func set_temp_stat(tag: String, value):
	stats_temp[tag] = value
	emit_signal("stat_changed", tag, value)
	return value

func add_temp_stat(tag: String, amount := 1) -> int:
	if tag in stats_temp:
		stats_temp[tag] += amount
	else:
		stats_temp[tag] = amount
	var value =  stats_temp[tag]
	emit_signal("stat_changed", tag, value)
	return value

func mark_picked(path: NodePath):
	game_state.picked_items.append(path)

func is_picked(path: NodePath) -> bool:
	return path in game_state.picked_items

#Saving and loading

func reset_game():
	valid_game_state = false
	player_spawned = false
	game_state = GameState.new()
	stats_temp = {}
	print("New game...")
	var dir := Directory.new()
	if dir.file_exists(save_path):
		print("Backing up save...")
		# copy as a backup
		var _x = dir.rename(save_path, old_save_backup)
	var _x = get_tree().reload_current_scene()

func save_checkpoint(pos: Transform, sleeping := false):
	set_stat("player_sleeping", sleeping)
	game_state.checkpoint_position = pos
	save_async()

func save_game():
	save_async()

func load_sync():
	print("loading save")
	if save_thread.is_active():
		save_thread.wait_to_finish()
	if ResourceLoader.exists(save_path):
		game_state = ResourceLoader.load(save_path, "", true)
		valid_game_state = true
	else:
		print_debug("Tried to load with no save at ", save_path)
		valid_game_state = false

func save_async():
	if save_thread.is_active():
		return
	get_tree().call_group_flags(SceneTree.GROUP_CALL_REALTIME, "pre_save_object", "prepare_save")
	var res = save_thread.start(self, "_save_sync", game_state.duplicate(false))
	if res != OK:
		print_debug("ERROR: Save failed with error code ", res)

func save_sync():
	if save_thread.is_active():
		save_thread.wait_to_finish()
	get_tree().call_group_flags(SceneTree.GROUP_CALL_REALTIME, "pre_save_object", "prepare_save")
	var res = ResourceSaver.save(save_path, game_state)
	save_complete(res)

func save_complete(result):
	# Investigate: could the player accidentally save again before post_save_object groups are updated?
	if save_thread.is_active():
		save_thread.wait_to_finish()
	if result == OK:
		valid_game_state = true
	get_tree().call_group_flags(SceneTree.GROUP_CALL_REALTIME, "post_save_object", "complete_save")

func _save_sync(p_state : GameState):
	var r = ResourceSaver.save(save_path, p_state)
	call_deferred("save_complete", r)
