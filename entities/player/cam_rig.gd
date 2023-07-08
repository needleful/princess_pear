extends Node

onready var player: PlayerBody = get_parent()
onready var yaw : Spatial = $yaw
onready var pitch : Spatial = $yaw/pitch
onready var spring : SpringArm = $yaw/pitch/SpringArm
onready var camera:Camera = $yaw/pitch/Camera

const MIN_CAMERA_DIFF := -1.0
const MAX_CAMERA_DIFF := 1.0
const CORRECTION_VELOCITY := 4.0
const CORRECTION_VELOCITY_GROUND := 8.0
const MIN_FLOOR_HEIGHT := 0.5
const H_CORRECTION := 30.0
const H_SLOW_CORRECTION := 15.0
const H_LOCKED_CORRECTION := 1.0
const H_DIFF_BOUND := 2.5

const SIT_DROP := 0.75

const SPRING_DEFAULT := 5.0
const SPRING_AIM := 3.0
const SPRING_AIM_CLOSE := 0.9
const SPRING_DIALOG := 2.5
const SPRING_CLOSE := 1.2
const ANGLE_DEFAULT := Vector3(-6, 0, 0)
const ANGLE_AIM := Vector3(-10, -20, 0)
const ANGLE_AIM_CLOSE := Vector3(-10, -45, 0)
const ANGLE_DIALOG := Vector3(-0, 20, 0)
const ANGLE_CLOSE := Vector3(-20, -15, 0)

const TWEEN_TIME_AIM := 0.4
const TWEEN_TIME_AIM_RESET := 0.6
const TWEEN_TIME_DIALOG := 2.0
const TWEEN_TIME_WARDROBE := 1.5
const TWEEN_TIME_CLOSE := 2.0

const TWEEN_TIME_FOV := 0.2
onready var fov_normal:float = camera.fov
const FOV_ZOOMED := 10.0

var mouse_accum := Vector2.ZERO
var mouse_sns := 0.5*Vector2(0.01, 0.01)
var analog_sns := Vector2(-0.1, 0.1)
var zoomed_sns_factor := 0.3

var cv := CORRECTION_VELOCITY
var hv := H_CORRECTION
var aiming := false
var locked := false
var zoomed := false
var fov_tween := Tween.new()
var tween := Tween.new()
var close_cam := false
var dialog_locked := false

onready var cam_basis = camera.transform.basis

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_child(fov_tween)
	add_child(tween)

func _input(event):
	if event is InputEventMouseMotion:
		if (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			or Input.is_mouse_button_pressed(BUTTON_LEFT)
		): 
			mouse_accum += event.relative

func _physics_process(delta):
	if locked:
		# Look at player, return
		camera.global_transform = camera.global_transform.looking_at(player.global_transform.origin, Vector3.UP)
		return
	var floor_v: Vector3
	if player.is_on_floor():
		floor_v = player.get_floor_velocity()
	yaw.global_translate(delta*floor_v*0.8)
	#Camera Movement
	var target: Vector3 = player.global_transform.origin
	var pos: Vector3 = yaw.global_transform.origin
	
	if player.is_grounded():
		cv = lerp(cv, CORRECTION_VELOCITY_GROUND, 0.1)
	else:
		cv = lerp(cv, CORRECTION_VELOCITY, 0.1)
	
	
	if player.is_locked():
		hv = lerp(hv, H_LOCKED_CORRECTION, 0.1)
	else:
		hv = lerp(hv, H_CORRECTION, 0.1)
	
	var diff := target - pos
	var movement := Vector3(
		diff.x*min(delta*hv, 1),
		diff.y*min(delta*cv, 1),
		diff.z*min(delta*hv, 1)
	)
	
	pos += movement
	
	pos.y = clamp(
		pos.y,
		target.y + MIN_CAMERA_DIFF,
		target.y + MAX_CAMERA_DIFF)
	
	var hT = Vector3(target.x, 0, target.z)
	var hP = Vector3(pos.x, 0, pos.z)
	var hDiff = hP - hT
	if hDiff.length() > H_DIFF_BOUND:
		var dir = H_DIFF_BOUND*hDiff.normalized()
		
		hP = hT + dir
		pos.x = hP.x
		pos.z = hP.z
	yaw.global_transform.origin = pos

func _process(delta):
	camera.global_transform.origin = spring.global_transform*(spring.get_hit_length()*Vector3.BACK)
	# Camera Rotation
	var mouse_aim = -mouse_accum*mouse_sns
	mouse_accum = Vector2.ZERO
	
	var analog_aim = Input.get_vector("cam_left", "cam_right", "cam_down", "cam_up")
	analog_aim *= analog_sns
	
	var sensitivity = Settings.sub_options["Controls"].camera_sensitivity
	var aim : Vector2 = sensitivity*(mouse_aim + delta*60*analog_aim)
	if zoomed:
		aim *= zoomed_sns_factor

	if Settings.sub_options["Controls"].invert_x:
		aim.x *= -1
	if Settings.sub_options["Controls"].invert_y:
		aim.y *= -1
	
	yaw.rotate_y(aim.x)
	if !dialog_locked:
		pitch.rotate_x(aim.y)
		if pitch.rotation_degrees.x > 80:
			pitch.rotation_degrees.x = 80
		elif pitch.rotation_degrees.x < -80:
			pitch.rotation_degrees.x = -80

func reset():
	camera.transform.basis = cam_basis
	locked = false
	set_aiming(false)

func lock_follow():
	locked = true

func set_aiming(aim: bool):
	if aiming == aim:
		return
	aiming = aim
	if aiming:
		if close_cam:
			tween_to(ANGLE_AIM_CLOSE, SPRING_AIM_CLOSE, TWEEN_TIME_AIM)
		else:
			tween_to(ANGLE_AIM, SPRING_AIM, TWEEN_TIME_AIM)
	elif close_cam:
		tween_to(ANGLE_CLOSE, SPRING_CLOSE, TWEEN_TIME_AIM_RESET) 
	else:
		tween_to(ANGLE_DEFAULT, SPRING_DEFAULT, TWEEN_TIME_AIM_RESET)

func start_dialog():
	dialog_locked = true
	tween_to(ANGLE_DIALOG, SPRING_DIALOG, TWEEN_TIME_DIALOG, true)

func end_dialog():
	dialog_locked = false
	if close_cam:
		tween_to(ANGLE_CLOSE, SPRING_CLOSE, TWEEN_TIME_DIALOG)
	else:
		tween_to(ANGLE_DEFAULT, SPRING_DEFAULT, TWEEN_TIME_DIALOG)

func set_close_cam(c):
	close_cam = c
	if close_cam:
		if aiming:
			tween_to(ANGLE_AIM_CLOSE, SPRING_AIM_CLOSE, TWEEN_TIME_CLOSE)
		else:
			tween_to(ANGLE_CLOSE, SPRING_CLOSE, TWEEN_TIME_CLOSE)
	elif aiming:
		tween_to(ANGLE_AIM, SPRING_AIM, TWEEN_TIME_CLOSE)
	else:
		tween_to(ANGLE_DEFAULT, SPRING_DEFAULT, TWEEN_TIME_CLOSE)

func tween_to(angle: Vector3, distance: float, time: float, reset_pitch := false):
		var _x = tween.remove_all()
		_x = tween.interpolate_property(spring, "rotation_degrees",
			spring.rotation_degrees, angle,
			time,
			Tween.TRANS_CUBIC, Tween.EASE_OUT)
		_x = tween.interpolate_property(spring, "spring_length",
			spring.spring_length, distance,
			time,
			Tween.TRANS_CUBIC, Tween.EASE_OUT)
		if reset_pitch:
			_x = tween.interpolate_property(pitch, "rotation_degrees",
				pitch.rotation_degrees, Vector3(-10,0,0),
				time,
				Tween.TRANS_CUBIC, Tween.EASE_OUT)
		_x = tween.start()
