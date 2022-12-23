extends Node

const TRANS = Tween.TRANS_SINE
const EASE = Tween.EASE_IN_OUT

var amplitude = 0
var priority = 0

@export var Frequency : Timer

@onready var camera = get_parent()

func start(dur = 0.3, freq = 15.0, amp = 4.0, pri = 0.0):
	if (priority >= self.priority):
		priority = pri
		amplitude = amp
		var duration = get_tree().create_timer(dur)
		duration.connect("timeout", _reset)
		Frequency.wait_time = 1.0 / freq
		Frequency.start()

		_new_shake()

func _new_shake():
	var rand = Vector2()
	rand.x = randi_range(-amplitude, amplitude)
	rand.y = randi_range(-amplitude, amplitude)
	var tweener = get_tree().create_tween()
	tweener.tween_property(camera, "offset", rand, Frequency.wait_time)

func _reset():
	Frequency.stop()
	var reset_tween = get_tree().create_tween()
	reset_tween.tween_property(camera, "offset", Vector2.ZERO, Frequency.wait_time)
	priority = 0
