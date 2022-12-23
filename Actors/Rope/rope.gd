extends RigidBody2D

signal peaked
var lifetime = 0.0

var has_peaked = false

func _physics_process(delta):
	lifetime += delta
	if linear_velocity.y > 0:
		if not has_peaked:
			emit_signal('peaked', self)
			$AnimatedSprite2D.hide()
			linear_velocity = Vector2(0, 100)
		has_peaked = true
	if lifetime > 0.5:
		queue_free()
