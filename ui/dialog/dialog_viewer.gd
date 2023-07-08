extends Control

signal started
signal exited(state)
signal exited_anim(animation)
signal event(id)
signal event_with_source(id, source)
signal pick_item
signal new_contextual_reply
signal control_screen(controlled)

var entered_from := ""

onready var player: PlayerBody = Global.get_player()
var main_speaker: Node
var source_node: Node
var last_speaker: String

var current_item : DialogItem
var sequence: Resource

export(Dictionary) var fonts: Dictionary
export(Dictionary) var colors := {
	"narration": Color.dimgray,
	"you":Color.deeppink,
	"hint":Color.orangered
}

onready var replies := $messages/replies
onready var message_container := $messages/messages
onready var messages := $messages/messages/list

const RESULT_SKIP := {"result":"skip"}
const RESULT_PAUSE := {"result":"pause"}
const RESULT_END := {"result":"end"}
const RESULT_NOSKIP := {"result":"noskip"}

var r_interpolate := RegEx.new()

var otherwise := false
var talked := 0
var skip_reply := false
var discussed: Dictionary
var is_exiting := false
# Stack of IDs for DialogItems
var call_stack: Array
var advance_on_resume := false
var label_conditions : Dictionary

const SECONDS_PER_YEAR := 356*24*3600
const SECONDS_PER_MONTH := 30*24*3600
const SECONDS_PER_DAY := 24*3600
const SECONDS_PER_HOUR := 3600
const SECONDS_PER_MINUTE := 60

const item_fallthrough := "item(_)"
# Dictionary of arrays mapping context to messages
var contextual_replies : Dictionary

var sorted_labels : Array

func _init():
	sorted_labels = []
	fonts = {}
	call_stack = []
	discussed = {}
	label_conditions = {}
	contextual_replies = {}

func _ready():
	var _x = r_interpolate.compile("#\\{([^\\}]+)\\}")
	ui_settings_apply()
	_x = messages.connect("child_entered_tree", self, "_on_message_added", [], CONNECT_DEFERRED)
	end()

func _input(event):
	if event.is_action_pressed("dialog_item"):
		emit_signal("pick_item")
		disable_replies()
	elif event.is_action_pressed("skip_to_next_choice"):
		while current_item.type != DialogItem.Type.REPLY and get_next():
			continue
	elif current_item.type != DialogItem.Type.REPLY and event.is_action_pressed("ui_accept"):
		get_next()

func start(p_source_node: Node, p_sequence: Resource, speaker: Node = null, starting_label:= ""):
	emit_signal("started")
	clear()
	source_node = p_source_node
	sequence = p_sequence.duplicate()
	label_conditions = {}
	sorted_labels = []
	for l in sequence.labels:
		if l.find(":-") >= 0:
			var s = l.split(":-")
			var label = s[0].strip_edges()
			var e = Expression.new()
			var res = e.parse(s[1], ["Global"])
			if res != OK:
				var msg := "Bad expression in %s:%s\n\t %s" % [
					p_sequence.resource_path, label, s[1]]
				insert_label("[Error] "+ msg, "narration")
				print_debug(msg)
			label_conditions[l] = e
	sorted_labels = sequence.labels.keys()
	sorted_labels.sort_custom(self, "_sort_labels")

	if speaker:
		main_speaker = speaker
	else:
		main_speaker = source_node
	talked = Global.stat(get_talked_stat())
	set_process_input(true)
	Global.can_pause = false
	var first_index = INF
	var s: DialogItem
	entered_from = starting_label
	if starting_label != "":
		s = sequence.find_label(starting_label)
		if !s:
			print_debug("No starting label '%s' in file: %s" % [
				starting_label, sequence.resource_path
			])
	if !s:
		for c in sequence.dialog.keys():
			if c < first_index:
				first_index = c
		current_item = sequence.find_index(first_index)
	else:
		current_item = s
	if "friendly_id" in main_speaker and main_speaker.friendly_id != "":
		Global.remember(main_speaker.friendly_id)
	advance()

func clear():
	last_speaker = ""
	is_exiting = false
	discussed = {}
	otherwise = false
	call_stack = []
	contextual_replies = {}
	for c in messages.get_children():
		c.queue_free()
	clear_replies()

func clear_replies():
	for c in replies.get_children():
		c.queue_free()

func _on_message_added(child: Node):
	yield(get_tree(), "idle_frame")
	message_container.scroll_to_child(child)

func get_next():
	var c: DialogItem
	if current_item.type != DialogItem.Type.CONTEXT_REPLY:
		c = sequence.canonical_next(current_item)
	else:
		c = sequence.failed_next(current_item)
	if !c:
		exit()
		return false
	else:
		current_item = c
		advance()
		return true

func advance():
	if !current_item:
		exit()
		return
	clear_replies()
	var result := false
	var noskip := false
	var font_override := ""
	otherwise = false
	while !result:
		var otherwise_used := false
		if !current_item:
			exit()
			return
		# Conditions on replies are handled in list_replies()
		if current_item.type == DialogItem.Type.REPLY:
			result = true
			break
		result = true
		font_override = ""
		for c in current_item.conditions:
			var r = check_condition(c)
			if r is Dictionary and "_otherwise" in r:
				otherwise_used = true
				r = r["_otherwise"]
			if r is Dictionary:
				if r == RESULT_END:
					return
				elif r == RESULT_SKIP:
					advance()
					return
				elif r == RESULT_NOSKIP:
					noskip = true
				elif "_format" in r:
					font_override = r._format
			elif !r:
				result = false
				break
		if !result:
			current_item = sequence.failed_next(current_item)
			if sequence.went_up:
				otherwise = false
			elif !otherwise_used:
				otherwise = true
		else:
			otherwise = false
			if current_item.type == DialogItem.Type.CONTEXT_REPLY:
				insert_contextual_reply(current_item, current_item.speaker)
				current_item = sequence.failed_next(current_item)
				result = false
			elif current_item.text == "" and !noskip:
				current_item = sequence.canonical_next(current_item)
				result = false
	
	if current_item.text != "":
		match current_item.type:
			DialogItem.Type.MESSAGE:
				show_message(current_item.text, current_item.speaker, font_override)
			DialogItem.Type.REPLY:
				list_replies()
			DialogItem.Type.NARRATION:
				show_narration(font_override)
			_:
				insert_label("[Error: Unknown message type: %s] %s" % [
					DialogItem.Type.keys()[current_item.type], current_item.text
				], "narration")
	
	var context_reply:DialogItem = sequence.canonical_next(current_item)
	otherwise = false
	while context_reply and context_reply.type == DialogItem.Type.CONTEXT_REPLY:
		var otherwise_used := false
		current_item = context_reply
		result = true
		for c in context_reply.conditions:
			var r = check_condition(c)
			if r is Dictionary and "_otherwise" in r:
				r = r["_otherwise"]
				otherwise_used = true
			if !r:
				result = false
				break
		if result:
			otherwise = false
			insert_contextual_reply(context_reply, context_reply.speaker)
		elif !otherwise_used:
			otherwise = true
		context_reply = sequence.failed_next(context_reply)

func list_replies():
	var reply: DialogItem = current_item
	otherwise = false
	while reply and reply.type == DialogItem.Type.REPLY:
		var font_override := ""
		skip_reply = false
		var cond = reply.conditions
		var result := true
		var otherwise_used := false
		for c in cond:
			var r = check_condition(c)
			if r is Dictionary and "_otherwise" in r:
				r = r["_otherwise"]
				otherwise_used = true
			if !r:
				result = false
				break
			elif r is Dictionary and "_format" in r:
				font_override = r._format
		if result:
			otherwise = false
			var f: Font
			if font_override in fonts:
				f = fonts[font_override]
			var b := Util.multiline_button(interpolate(reply.text), f)
			replies.add_child(b)
			var r = reply
			var s = skip_reply
			var _x = b.connect("pressed", self, "choose_reply", [r, s])
		elif !otherwise_used:
			otherwise = true
		reply = sequence.next(reply)
	if replies.get_child_count() == 0:
		print("\tNo replies.")
		current_item = reply
		advance()
	else:
		call_deferred("_resize_replies")
	$input_timer.start()

func _resize_replies():
	Util.resize_buttons(replies.get_children())
	yield(get_tree(), "idle_frame")
	Util.resize_buttons(replies.get_children())
	message_container.scroll_to_end()

func _on_input_timer_timeout():
	replies.get_child(0).grab_focus()

func choose_reply(item: DialogItem, skip: bool):
	if !skip:
		show_message(item.text, "You")
		last_speaker = "You"
	current_item = item
	get_next()

func show_context_reply(item: DialogItem):
	set_process_input(true)
	call_stack.push_back(current_item)
	show_message(item.text, "You")
	last_speaker = "You"
	current_item = sequence.canonical_next(item)
	advance()

# tags is an array of strings
func use_note(tags:Array):
	enable_replies()
	var l := _find_item("note", tags, true)
	if l:
		_call_next(l)
	else:
		_no_label()

func use_item(id:String, desc: ItemDescription = null):
	enable_replies()
	var by_item := _find_item("item", [id], false)
	if by_item:
		_call_next(by_item)
		return
	var by_tag := _find_item("item", desc.tags if desc else [], true)
	if by_tag:
		_call_next(by_tag)
	else:
		_no_label()

func get_speaker_name() -> String:
	if "visual_name" in main_speaker and main_speaker.visual_name != "":
		return main_speaker.visual_name
	elif "friendly_id" in main_speaker and main_speaker.friendly_id != "":
		return main_speaker.friendly_id.capitalize()
	else:
		return main_speaker.name.capitalize()

func show_message(text: String, speaker: String, font_override:= ""):
	if speaker == "":
		speaker = get_speaker_name()

	if speaker != last_speaker:
		text = "%s: %s" % [speaker, text]
	last_speaker = speaker
	
	insert_label(text, speaker.to_lower(), font_override)

func show_narration(font_override: String):
	insert_label(current_item.text, "narration", font_override)

func insert_label(text: String, format: String, font_override := ""):
	var color:Color = colors["default"]
	var font:Font = fonts["default"]
	
	if font_override in fonts:
		font = fonts[font_override]
	elif format in fonts:
		font = fonts[format]
	
	if format in colors:
		color = colors[format]
	
	var label := Label.new()
	label.autowrap = true
	label.text = interpolate(text)
	if color != Color.black:
		label.add_font_override("font", font)
		label.add_color_override("font_color", color)
	messages.add_child(label)

func interpolate(line: String):
	var matches := r_interpolate.search_all(line)
	var text := line
	for m in matches:
		var ex = evaluate(m.get_string(1))
		text = text.replace(m.get_string(), str(ex))
	return text

func evaluate(ex_text: String):
	var expr: Expression = Expression.new()
	var err = expr.parse(ex_text, ["Global"])
	if err != OK:
		var msg := "\tFailed to parse {%s}. Code %d" % [ex_text, err]
		insert_label("[Error] "+ msg, "narration")
		print_debug(msg)
		return true
	
	var r = expr.execute([Global], self)
	
	if expr.has_execute_failed():
		var msg := "\tFailed to execute {%s}.\n\t%s" % [ 
			ex_text, expr.get_error_text()]
		insert_label("[Error] "+ msg, "narration")
		print_debug(msg)
		return true
	return r

func check_condition(cond: String):
	if cond == "otherwise":
		return {"_otherwise": otherwise}
	
	var result = evaluate(cond)
	return result

func end():
	set_process_input(false)
	Global.can_pause = true

func trade_coats():
	if mentioned("_coat"):
		get_next()
		return
	var coat_item: DialogItem = sequence.find_label("_coat")
	if coat_item:
		mention("_coat")
		current_item = coat_item
		advance()
	else:
		insert_label("[You cannot trade coats at this time]", "narration")

func skip_and_exit():
	if !is_exiting:
		fast_exit()
	while get_next():
		continue

func fast_exit():
	if is_exiting:
		get_next()
	else:
		is_exiting = true
		call_stack.push_back(current_item)
		current_item = _find_item("_exit")
		advance()

func get_talked_stat():
	var s: String = speaker_stat()
	return "talked/" + s

func ui_settings_apply():
	if get_theme_default_font():
		for f in fonts.values():
			if f is DynamicFont:
				f.size = get_theme_default_font().size
		fonts["default"] = get_theme_default_font()
	colors["default"] = get_color("font_color", "Label")

func _on_item_context_cancelled():
	enable_replies()
	if current_item and current_item.type == DialogItem.Type.REPLY:
		if replies.get_child_count():
			replies.get_child(0).grab_focus()

func _sort_labels(a: String, b: String):
	return sequence.labels[a] < sequence.labels[b]

func disable_replies():
	set_process_input(false)
	for c in replies.get_children():
		if c is Button:
			c.disabled = true
			c.focus_mode = FOCUS_NONE

func enable_replies():
	set_process_input(true)
	for c in replies.get_children():
		if c is Button:
			c.disabled = false
			c.focus_mode = FOCUS_ALL

func _jump_next(item: DialogItem):
	current_item = item
	advance()

func _call_next(item: DialogItem):
	call_stack.push_back(current_item)
	current_item = item
	advance()

func _find_item(type:String, items = null, fallthrough : bool = true) -> DialogItem:
	var found_label: String
	if items:
		 found_label = "%s(_)" % type if fallthrough else ""
	else:
		found_label = type
	for l in sorted_labels:
		if !l.begins_with(type):
			continue
		if items:
			var found := false
			for item in items:
				if l.begins_with("%s(%s)") % [type, item]:
					found = true
					break
			if !found:
				continue
		if l in label_conditions:
			var ex:Expression = label_conditions[l]
			var res = ex.execute([Global], self)
			if ex.has_execute_failed():
				print_debug("Execution failed for ", l,
					"\n\t", ex.get_error_text())
			if !res:
				continue
		found_label = l
		break
	if found_label != "" and sequence.has(found_label):
		return sequence.find_label(found_label)
	else:
		return null

func _no_label():
	insert_label("[Nothing happened]", "narration")
	if replies.get_child_count():
		replies.get_child(0).grab_focus()

func insert_contextual_reply(message: DialogItem, context := ""):
	var key := "--never-remove--"
	if context != "":
		mention(context)
		key = context
	if key in contextual_replies:
		contextual_replies[key].append(message)
	else:
		contextual_replies[key] = [message]
	emit_signal("new_contextual_reply")

########################################
## Dialog functions
########################################

func exiting():
	is_exiting = true
	return true

func track_conversation_time():
	Global.set_stat("talk_time"+get_speaker_name(), OS.get_unix_time())
	return true

func seconds_since_conversation() -> int:
	var prev: int = Global.stat("talk_time"+get_speaker_name())
	var now: int = OS.get_unix_time()
	return now - prev

func format(style: String):
	return {"_format":style}

func event(tag: String):
	emit_signal("event", tag)
	emit_signal("event_with_source", tag, main_speaker)
	if main_speaker.has_method(tag):
		main_speaker.call(tag)
	return true

func exit_event(tag: String):
	event(tag)
	return exit()

func goto(label: String):
	var item := _find_item(label)
	if item:
		current_item = item
		return RESULT_SKIP
	else:
		return false

func skip():
	skip_reply = true
	# Ironic how skip() does not return RESULT_SKIP
	return true

func noskip():
	return RESULT_NOSKIP

func exit(state := PlayerBody.State.Ground):
	var stat: String = get_talked_stat()
	var _x = Global.add_stat(stat)
	emit_signal("exited", state)
	if main_speaker.has_method("exit_dialog"):
		main_speaker.exit_dialog()
	set_process_input(false)
	return RESULT_END

func exit_anim(animation:String):
	var stat: String = get_talked_stat()
	var _x = Global.add_stat(stat)
	emit_signal("exited_anim", animation)
	set_process_input(false)
	return RESULT_END

func mention(topic):
	discussed[topic] = true
	return true

func mentioned(topic):
	return topic in discussed

func forget(topic):
	var _x = contextual_replies.erase(topic)
	return discussed.erase(topic)

func subtopic(label: String):
	call_stack.push_back(current_item)
	return goto(label)

func back():
	# If there's nothing on the call stack, we just continue
	if call_stack.empty():
		return true
	var caller = call_stack.pop_back()
	if caller.type == DialogItem.Type.REPLY:
		current_item = caller
	elif caller.type == DialogItem.Type.CONTEXT_REPLY:
		current_item = sequence.failed_next(caller)
	else:
		current_item = sequence.canonical_next(caller)
	return RESULT_SKIP

func speaker_stat() -> String:
	if !main_speaker:
		return "_NO_SPEAKER_"
	if "friendly_id" in main_speaker and main_speaker.friendly_id != "":
		return main_speaker.friendly_id
	else:
		return Global.node_stat(main_speaker)

func general_time(late_morning := false) -> String:
	var s = get_tree().current_scene
	if s.has_method("get_time"):
		var t:float = s.get_time()
		if t > 19 or t < 2.5:
			return "evening"
		elif t > 12:
			return "afternoon"
		elif t > 9.75:
			return "day" if !late_morning else "morning"
		else:
			return "morning"
	return "day"

func exact_time() -> String:
	var s = get_tree().current_scene
	if s.has_method("get_time"):
		return NumberToString.say_time(s.get_time())
	return "noon"

func say_number(v: float) -> String:
	return NumberToString.verbose(v)

func can_discuss(stat: String) -> bool:
	return Global.stat(stat) and !Global.stat("discussed/" + speaker_stat() + "/" + stat)

func mark_discussed(stat: String) -> bool:
	var _x = Global.add_stat("discussed/" + speaker_stat() + "/" + stat)
	return true

func remember(note: String, subject: String = ""):
	if subject == "":
		subject = speaker_stat()
	Global.remember(subject)
	Global.add_note(note, [subject])
	return true

func knows(person: String):
	return Global.has_note(person)

func task_exists(id):
	return Global.task_exists(id)

func task_is_active(id):
	return Global.task_is_active(id)

func task_is_complete(id):
	return Global.task_is_complete(id)

func stat(s: String):
	return Global.stat(s)

func control_screen(val := true):
	emit_signal("control_screen", val)
	return true

func note(stat: String, text: String, tags: Array):
	if stat != "":
		var _x = Global.add_stat(stat)
		tags.append(stat)
	return Global.add_note(text, tags)

func note_once(stat: String, text:String, tags: Array):
	if Global.stat(stat):
		return false
	return note(stat, text, tags)
