extends KinematicBody

enum State {
	Idle,
	Locked,
	Moving,
	Chase,
	Patrol
}
export(State) var state: int = State.Idle

export(String) var visual_name
export(String) var friendly_id := ""
export(String) var custom_entry := ""
export(Array, NodePath) var nav_points
export(float) var speed := 6.5
export(float) var chase_speed := 7.5
export(NodePath) var mesh_path
export(bool) var start_tethered := false

const GRAVITY := Vector3.DOWN*15.0
const MAX_DIST := 15.0
var velocity := Vector3.ZERO
var point := 0

onready var mesh := get_node(mesh_path)
onready var nav:NavigationAgent = $NavigationAgent
onready var tree := $AnimationTree
onready var player := Global.get_player()
onready var awareness:Area = mesh.get_node("awareness")
var target_node : Spatial
var tethered := false

func _ready():
	$interaction.custom_entry = custom_entry
	$interaction.friendly_id = friendly_id
	$interaction.visual_name = visual_name
	var _x = mesh.get_node("capture").connect("body_entered", self, "on_player_captured")
	if nav and !nav.get_navigation() is Navigation:
		for g in get_tree().get_nodes_in_group("navigation"):
			nav.set_navigation(g)
			break
	var point_stat := "at/"+friendly_id
	if Global.has_stat(point_stat):
		point = Global.stat(point_stat)
		var p = get_current_point()
		if p:
			global_transform = p.global_transform
	if start_tethered:
		tether()

func _physics_process(delta):
	match state:
		State.Chase:
			if !target_node:
				state = State.Idle
			else:
				track_target()
			move(nav.get_next_location() , delta)
		State.Patrol:
			if complete():
				next_point()
			move(nav.get_next_location() , delta)
			for b in awareness.get_overlapping_bodies():
				var ds := PhysicsServer.space_get_direct_state(get_world().space)
				var ray := ds.intersect_ray(global_transform.origin, b.global_transform.origin, [self], 3)
				if ray and ray.collider == b:
					state = State.Chase
					target_node = b
					print("the chase is on!!")
		State.Moving:
			if tethered:
				tether_check()
			if complete():
				if friendly_id != "":
					Global.set_stat("at/"+friendly_id, point)
				state = State.Idle
				velocity = Vector3.ZERO
				if target_node:
					rotate_mesh(target_node.global_transform.basis.z)
			else:
				if nav and nav.get_navigation() is Navigation:
					move(nav.get_next_location(), delta)
				else:
					move(target_node.global_transform.origin, delta)
		State.Idle:
			if tethered:
				tether_check()
			else:
				set_physics_process(false)
	
	tree["parameters/Walk/blend_amount"] = velocity.length()/speed
	if velocity.length_squared() > 0.01:
		rotate_mesh(velocity)

func tether_check():
	var d2:float = (player.global_transform.origin - global_transform.origin).length_squared()
	if d2 > MAX_DIST*MAX_DIST:
		state = State.Chase
		target_node = player
		set_physics_process(true)

func complete():
	if nav:
		return !nav.is_target_reachable() or nav.is_navigation_finished() or nav.is_target_reached()
	else:
		return !target_node or ( target_node.global_transform.origin 
			- global_transform.origin).length_squared() < 4

func move(target: Vector3, delta:float):
	var dir := (target - global_transform.origin).normalized()
	var hvel = velocity
	hvel.y = 0
	var s := speed if state != State.Chase else chase_speed
	hvel = hvel.move_toward(dir*s, 60.0*delta)
	hvel.y = velocity.y
	velocity = move_and_slide_with_snap(hvel + GRAVITY*delta, Vector3.DOWN*0.25, Vector3.UP)

func track_target():
	var loc := target_node.global_transform.origin
	if (loc - nav.get_target_location()).length_squared() > 0.25:
		nav.set_target_location(loc)

func on_player_captured(b):
	if state == State.Chase and b == target_node:
		b.on_capture()
		tree["parameters/Capture/active"] = true
		state = State.Idle
		tethered = false
		velocity = Vector3.ZERO
		rotate_mesh(b.global_transform.origin - global_transform.origin)

func tether():
	set_physics_process(true)
	tethered = true

func rotate_mesh(dir:Vector3):
	dir.y = 0
	dir = dir.normalized()
	if !dir.is_normalized():
		return
	var f:Vector3 = mesh.global_transform.basis.z
	var axis := f.cross(dir).normalized()
	if !axis.is_normalized():
		return
	var angle = f.angle_to(dir)
	mesh.global_rotate(axis, angle)

func disable_dialog():
	$interaction.queue_free()

func next_point():
	point += 1
	if point > nav_points.size():
		point = 1
	var path:NodePath = nav_points[point - 1]
	if !has_node(path):
		print_debug("No target:", path)
		return false
	target_node = get_node(path)
	if nav:
		nav.set_target_location(target_node.global_transform.origin)
	if state == State.Idle:
		state = State.Moving
	set_physics_process(true)

func at(p: int):
	return state == State.Idle and p == point

func get_current_point():
	return get_node(nav_points[point - 1]) if point > 0 else null
