extends RigidBody2D
@export var sprite : AnimatedSprite2D
@export var standard_body : CollisionShape2D
@export var blast_radius : CollisionShape2D
@export var timer : Timer
@export var explosion : GPUParticles2D
@export var debug : Label

var held = false
var object_type = ''
var fired = false
var direction = 'right'
var about_to_throw = false
var can_shatter = false

signal boom

func _ready():
	if object_type == '':
		object_type = ['container', 'standard', 'treasure'].pick_random()
	sprite.animation = object_type
	blast_radius.position = Vector2(-1000, -1000)
	match object_type:
		'arrow':
			pass
		'bomb':
			timer.start()
			timer.connect("timeout", detonate)
			sprite.play()
		'container':
			can_shatter = true
			sprite.frame = randi_range(0, sprite.frames.get_frame_count(object_type) - 1)
		'standard':
			sprite.frame = randi_range(0, sprite.frames.get_frame_count(object_type) - 1)
		'treasure':
			sprite.frame = randi_range(0, sprite.frames.get_frame_count(object_type) - 1)
		'breakable':
			can_shatter = true
			sprite.frame = randi_range(0, sprite.frames.get_frame_count(object_type) - 1)
	if fired:
		gravity_scale = 0.0


func _physics_process(_delta):
	if not fired:
		var collision_info = move_and_collide(Vector2.ZERO, false, 0.001)
		if object_type == 'arrow':
			sprite.rotation = atan2(linear_velocity.y, linear_velocity.x)
		if collision_info:
			if abs(linear_velocity.x) > 0.01:
				linear_velocity = linear_velocity.bounce(collision_info.get_normal()) * 0.5
			if can_shatter and linear_velocity.distance_to(Vector2.ZERO) > 50.0:
				shatter()
	if fired:
		sprite.rotation = atan2(linear_velocity.y, linear_velocity.x)
		linear_velocity.y = 0


func shatter():
	var interior = randi_range(0, 10)
	if object_type == 'breakable':
		interior = 0
	match interior:
		0, 1, 2, 3:
			pass
		4, 5, 6:
			var new_treasure = Global.pickable.instantiate()
			new_treasure.object_type = 'treasure'
			new_treasure.position = position
			get_parent().add_child(new_treasure)
		7, 8, 9, 10:
			var new_treasure = Global.pickable.instantiate()
			new_treasure.object_type = 'standard'
			new_treasure.position = position
			get_parent().add_child(new_treasure)
	queue_free()

func _integrate_forces(_state):
	if fired:
		if direction == 'right':
			linear_velocity = Vector2(230, 0)
		else:
			linear_velocity = Vector2(-230, 0)


func _on_detector_area_entered(area):
	if area.is_in_group("bomb_radius"):
		var bomb_point = area.get_owner().position
		var cur_angle = bomb_point.angle_to_point(position)
		apply_central_impulse(Vector2(cos(cur_angle), sin(cur_angle)) * (1-(bomb_point.distance_to(position)/32)) * 400)


func _on_detector_body_entered(body):
	if body.is_in_group("Player"):
		if object_type == 'treasure':
			Global.add_wealth(Global.treasure_value[sprite.frame])
			queue_free()
		if linear_velocity.distance_to(Vector2.ZERO) > 100:
			body.detatch_from_grapple()
			body.velocity += -linear_velocity
			if object_type == 'arrow':
				Global.health -= 2
			else:
				Global.health -= 1
			body.emit_signal('hit')
	if fired:
		gravity_scale = 1.0
		apply_torque_impulse(25.0)
		fired = false


func detonate():
	emit_signal("boom", position)
	sprite.hide()
	explosion.emitting = true
	blast_radius.position = Vector2.ZERO
	await get_tree().process_frame
	blast_radius.position = Vector2(-1000, -1000)
	collision_layer = 0
	collision_mask = 0
	await get_tree().create_timer(1.2).timeout
	queue_free()


func _on_affected_by_blast_radius_area_entered(_area):
	sleeping = false
