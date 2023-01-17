extends RigidBody2D

enum State {SHOOT, LATCH, RETRACT}

@export var player_holder : RigidBody2D
@export var spring : DampedSpringJoint2D
@export var chain_texture : TextureRect
@export var collision_detector: Area2D

var dist_to_player := 0.0
var state := 0
var target : Node
var latch_point_position : Vector2

func _ready():
	Engine.time_scale = 0.1
	add_to_group("grapples")
	change_state(State.SHOOT)

# player holder purple, latch point green, collision red
func _physics_process(delta):
	dist_to_player = global_position.distance_to(target.global_position)
	chain_texture.size.y = dist_to_player
	chain_texture.global_position = global_position - Vector2(4, 0)
	chain_texture.rotation = global_position.angle_to_point(player_holder.global_position) - PI / 2
	match state:
		State.SHOOT:
			collision_detector.global_position = global_position
			player_holder.global_position = target.global_position
		State.LATCH:
			linear_velocity = Vector2.ZERO
			target.velocity = Vector2.ZERO
			target.global_position = player_holder.global_position
			if player_holder.linear_velocity.distance_to(Vector2.ZERO) < 1.0:   
				change_state(State.RETRACT)
		State.RETRACT:
			player_holder.global_position = target.global_position
			global_position = global_position.move_toward(target.global_position, delta*400)
			if dist_to_player < 8.0:
				Engine.time_scale = 1.0
				queue_free()



func change_state(new_state: State):
	state = new_state
	print(new_state)
	match state:
		State.SHOOT:
			global_position = target.global_position
			linear_velocity = Vector2(120, -500) * target.dir + target.velocity * Vector2(1, 0.5)
		State.LATCH:
			set_deferred("freeze", true)
			global_position = collision_detector.global_position
			spring.length = dist_to_player
			spring.rest_length = dist_to_player
			printt(spring.length, spring.rest_length)
			player_holder.global_position = target.global_position
			player_holder.linear_velocity = target.velocity
		State.RETRACT:
			pass


func _on_collision_detector_body_entered(body):
	if state == State.SHOOT and not body.is_in_group("Player"):
		print('called')
		change_state(State.LATCH)

