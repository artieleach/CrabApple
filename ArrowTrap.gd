extends Node2D
@export var ray : RayCast2D
@export var arrow : RigidBody2D

signal fire_arrow
var has_fired = false

var skip = false
var map_pos : Vector2i
var direction = 'right'

func _physics_process(_delta):
	if ray.is_colliding() and not has_fired:
		var cur_hit = ray.get_collider()
		if cur_hit.owner != null and not cur_hit.owner.get("linear_velocity") == null:
			if cur_hit.owner.linear_velocity == Vector2.ZERO or (cur_hit.owner.get("can_trigger") != null and not cur_hit.owner.can_trigger):
				ray.add_exception(cur_hit)
				skip = true
		if cur_hit.is_in_group("spikes"):
			skip = true
			ray.add_exception(cur_hit)
		if not skip:
			emit_signal("fire_arrow", position, direction)
			queue_free()
		skip = false

func figure_range(tm : TileMap):
	var visible_to_trap = Global.tile_size.x
	if direction == 'right':
		for i in range(1, 8):
			if tm.get_cell_atlas_coords(Global.layers.collision, Vector2i(map_pos.x + i, map_pos.y)) == Vector2i(-1, -1):
				visible_to_trap += Global.tile_size.x
			else:
				break
		ray.target_position.x = visible_to_trap - 9 
	else:
		for i in range(1, 8):
			if tm.get_cell_atlas_coords(Global.layers.collision, Vector2i(map_pos.x - i, map_pos.y)) == Vector2i(-1, -1):
				visible_to_trap += Global.tile_size.x
			else:
				break
		ray.target_position.x = -visible_to_trap + 9
		
