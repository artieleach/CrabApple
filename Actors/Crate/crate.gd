extends RigidBody2D

@export var collision_body : CollisionShape2D
@export var crate_sprite : AnimatedSprite2D


var colliding_player = false

var my_collider

func _ready():
	my_collider = shape_owner_get_shape(0, 0)

func _integrate_forces(_state):
	if linear_velocity.y > 20:
		linear_velocity.x = 0
	linear_velocity.x = clamp(linear_velocity.x, -20, 20)


func _on_l_body_entered(body):
	if body.is_in_group("Player") and body.is_on_floor():
		my_collider.size = Vector2(7, 7)


func _on_l_body_exited(body):
	if body.is_in_group("Player") and body.is_on_floor():
		my_collider.size = Vector2(7.95, 8)
		position = position.round()


func _on_explosion_detector_area_entered(area):
	if area.is_in_group("bomb_radius"):
		queue_free()
