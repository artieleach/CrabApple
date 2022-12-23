extends RigidBody2D
@export var chain_texture : TextureRect


signal hooked

var target
var dist_travelled : float

	
func _physics_process(_delta):
	dist_travelled = position.distance_to(target.position)
	chain_texture.size.y = dist_travelled
	chain_texture.rotation = position.angle_to_point(target.position) - PI / 2

func _on_area_2d_body_entered(body):
	if not body.is_in_group("Player"):
		emit_signal("hooked", position)
		queue_free()
