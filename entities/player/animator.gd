extends Spatial

onready var tree := $AnimationTree
onready var state_machine:AnimationNodeStateMachinePlayback = $AnimationTree["parameters/StateMachine/playback"]

func play_state(state: String):
	state_machine.travel(state)

func blend_walk(run_percent):
	ground_set("MoveSpeed/scale", 0.5 + run_percent/2)
	ground_set("RunBlend/blend_amount", run_percent)

func ground_set(param:String, value):
	tree["parameters/StateMachine/Ground/" + param] = value
	
func ground_get(param:String):
	return tree["parameters/StateMachine/Ground/" + param]
