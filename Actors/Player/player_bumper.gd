extends RigidBody2D
@export var timer : Timer

var target 


func _physics_process(_delta):
	target.position = position
	target.velocity = linear_velocity
	var collision_info = move_and_collide(Vector2.ZERO, false, 0.001)
	if collision_info:
		if abs(linear_velocity.x) > 0.01:
			linear_velocity = linear_velocity.bounce(collision_info.get_normal()) * 0.5
	if linear_velocity.distance_to(Vector2.ZERO) > 5:
		timer.start(1)


func _on_timer_timeout():
	target.taking_damage = false
	queue_free()
