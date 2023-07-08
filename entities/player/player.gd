extends KinematicBody
class_name PlayerBody

enum State {
	Ground,
	Jump,
	Fall,
	Locked
}
const GRAVITY := Vector3.DOWN*15
const TERMINAL_VELOCITY := -80.0
const INPUT_EPSILON := 0.1

onready var ground_area:Area = $ground_area
onready var cam := $cam_rig

var state:int = State.Ground
var velocity := Vector3.ZERO
var ground_normal := Vector3.UP

var accel_start := 45.0
var accel_continue := 20.0
var accel_steer := 30.0
var decel_against := 45.0
var decel_with := 10.0

var speed_low := 2.0
var speed_max := 7.0

var timers := PoolRealArray()
var input_buffer := {
	"mv_jump":INF
}

func _input(event):
	for e in input_buffer.keys():
		if event.is_action_pressed(e):
			input_buffer[e] = 0.0
	if state != State.Locked:
		if event.is_action_pressed("aim_toggle"):
			cam.set_aiming(!cam.aiming)

func _ready():
	set_state(state)

func _physics_process(delta):
	for e in input_buffer.keys():
		input_buffer[e] += delta
	if velocity.y < TERMINAL_VELOCITY:
		velocity.y = TERMINAL_VELOCITY
	for i in range(timers.size()):
		timers[i] += delta

	match state:
		State.Ground:
			if pressed("mv_jump"):
				set_state(State.Jump)
			elif after(0.1, empty(ground_area)):
				set_state(State.Fall)
		State.Fall:
			if is_on_floor():
				set_state(State.Ground)
		State.Jump:
			if after(0.1):
				set_state(State.Fall)
	var movement := Input.get_vector("mv_left", "mv_right", "mv_up", "mv_down")
	$debug/stats/a2.text = "Input: {%.3f, %.3f}" % [movement.x, movement.y]
	var desired_velocity: Vector3 = speed_max*(
		cam.yaw.global_transform.basis.x * movement.x
		+ cam.yaw.global_transform.basis.z * movement.y)
	match state:
		State.Ground:
			if is_on_floor():
				ground_normal = get_floor_normal()
			move(delta, desired_velocity)
		State.Fall, State.Jump:
			move_air(delta, desired_velocity)

func move(delta:float, desired_velocity: Vector3):
	var gravity = GRAVITY
	if ground_normal != Vector3.ZERO:
		var axis = Vector3.UP.cross(ground_normal).normalized()
		var angle = Vector3.UP.angle_to(ground_normal)
		if axis.is_normalized():
			desired_velocity = desired_velocity.rotated(axis, angle)
		gravity = GRAVITY.project(ground_normal)
	var hvel := velocity
	if gravity != Vector3.ZERO:
		hvel = hvel.slide(gravity.normalized())
	else:
		hvel.y = 0
	var hdir := hvel.normalized()
	
	if hvel.length() > speed_low and desired_velocity != Vector3.ZERO:
		var charge_accel = accel_continue
		# Direction parellel to current (horizontal) velocity
		var charge := desired_velocity.project(hdir)
		# Direction perpendicular to (horizontal) velocity
		var steer := desired_velocity.slide(hdir)
		if charge.dot(hvel) > 0:
			if charge.length() < velocity.length():
				charge_accel = decel_with
			else:
				charge_accel = accel_continue
		else:
			charge_accel = decel_against
		velocity += delta*(
			(charge - hvel)/speed_max*charge_accel 
			+ (steer*accel_steer) 
			+ gravity )
	else:
		if desired_velocity.length_squared() < 0.05:
			hvel = hvel.move_toward(desired_velocity, decel_against)
		else:
			hvel = hvel.move_toward(desired_velocity, accel_start)
		
		var vvel := Vector3.ZERO
		if gravity != Vector3.ZERO:
			vvel = velocity.project(gravity.normalized())
		velocity =  vvel + hvel + delta*gravity

	velocity = move_and_slide_with_snap(velocity, Vector3.DOWN*0.06125, Vector3.UP)

func move_air(delta:float, desired_velocity:Vector3):
	var hvel := Vector3(velocity.x, 0, velocity.z).move_toward(desired_velocity, accel_continue)
	velocity.x = hvel.x
	velocity.z = hvel.z
	velocity += GRAVITY*delta
	var pre_slide_vel := velocity
	velocity = move_and_slide(velocity, Vector3.UP)

func set_state(new_state):
	$debug/stats/a1.text = "State: " + State.keys()[new_state]
	match new_state:
		State.Ground:
			accel_start = 45.0
			accel_continue = 20.0
			accel_steer = 30.0
			decel_against = 45.0
			decel_with = 10.0
		State.Fall:
			accel_continue = 20.0
		State.Jump:
			velocity += Vector3.UP*7.0
			accel_continue = 200.0
		State.Locked:
			pass
	state = new_state

# State Methods
func after(time: float, condition := true, id := 0):
	if id >= timers.size():
		timers.resize(id+1)
		timers[id] = 0
	if !condition:
		timers[id] = 0
	return timers[id] >= time

func pressed(action:String):
	if action in input_buffer:
		var res = input_buffer[action] < INPUT_EPSILON
		input_buffer[action] = INF
		return res
	else:
		return Input.is_action_just_pressed(action)

func released(action:String):
	return Input.is_action_just_released(action)

func holding(action:String):
	return Input.is_action_pressed(action)

func empty(area: Area):
	return area.get_overlapping_bodies().size() == 0
	
# Public API
func lock():
	set_state(State.Locked)

func unlock():
	set_state(State.Ground)

func is_grounded() -> bool:
	return state == State.Ground

func is_locked() -> bool:
	return state == State.Locked
