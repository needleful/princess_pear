extends KinematicBody

export(String) var id := ""
export(String) var custom_entry := ""
export(Array, NodePath) var nav_points
export(float) var speed := 7.0

const GRAVITY := Vector3.DOWN*15.0
var velocity := Vector3.ZERO
var point := 0

onready var nav:NavigationAgent = $NavigationAgent

enum State {
	Idle,
	Locked,
	Moving
}

var state: int = State.Idle

func _ready():
	$interaction.custom_entry = custom_entry
	$interaction.friendly_id = id
	if !nav.get_navigation() is Navigation:
		for g in get_tree().get_nodes_in_group("navigation"):
			nav.set_navigation(g)
			break

func _physics_process(delta):
	if state == State.Moving:
		if nav.is_navigation_finished() or nav.is_target_reached():
			state = State.Idle
			return
		var dir := (nav.get_next_location() - global_transform.origin).normalized()
		var hvel = velocity
		hvel.y = 0
		
		hvel = hvel.move_toward(dir*speed, 60.0*delta)
		hvel.y = velocity.y
		velocity = move_and_slide_with_snap(hvel + GRAVITY*delta, Vector3.DOWN*0.25, Vector3.UP)
	else:
		set_physics_process(false)

func next_point():
	point += 1
	if point > nav_points.size():
		return false
	var path:NodePath = nav_points[point - 1]
	if !has_node(path):
		print_debug("No target:", path)
		return false
	var target = get_node(path)
	nav.set_target_location(target.global_transform.origin)
	state = State.Moving
	set_physics_process(true)


func at(p: int):
	return state == State.Idle and p == point
