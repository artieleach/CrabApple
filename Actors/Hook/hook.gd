extends RigidBody2D
@export var chain_texture : TextureRect


signal hooked

var target
var dist_travelled : float
var extend = true

func _ready():
	if not extend:
		collision_mask = 0
		linear_velocity = Vector2.ZERO
		gravity_scale = 0

func _physics_process(delta):
	dist_travelled = position.distance_to(target.position)
	chain_texture.size.y = dist_travelled
	chain_texture.rotation = position.angle_to_point(target.position) - PI / 2
	if not extend:
		position = position.move_toward(target.position, delta*400)
		if dist_travelled < 8:
			queue_free()
	else:
		if dist_travelled > 45:
			queue_free()

func _on_area_2d_body_entered(body):
	if extend:
		if not body.is_in_group("Player"):
			emit_signal("hooked", position)
			queue_free()

