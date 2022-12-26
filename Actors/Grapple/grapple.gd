extends Node2D
@export var player_holder : RigidBody2D
@export var spring : DampedSpringJoint2D
@export var chain_texture : TextureRect


var target
var dist_travelled : float

func _ready():
	print(player_holder.linear_velocity)

func _physics_process(_delta):
	dist_travelled = position.distance_to(target.position)
	chain_texture.size.y = dist_travelled
	chain_texture.rotation = chain_texture.position.angle_to(player_holder.position) + PI / 2

