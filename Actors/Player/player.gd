extends CharacterBody2D

@export var player_sprite : AnimatedSprite2D
@export var ledge_grab : Area2D
@export var space_check : Area2D
@export var collision_body : CollisionShape2D
@export var debug_label : Label
@export var camera_center : Node2D
@export var floor_check : Area2D
@export var i_frame_timer : Timer


const ladder_tiles = [Vector2i(10, 28), Vector2i(10, 27), Vector2i(31, 32), Vector2i(31, 31)]

const SPEED = 80.0
const inertia = 48
const JUMP_VELOCITY = -88.0
# 240 velocity.y = damage
var on_tm = false

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var ladder_blocks = []
var detector_list = []
var state = 'fall'  # fall, climb, latch
var throw = false

var coyote_time = 0.0
var look_timer = 0.0

var ladder_behind = false
var on_plank = false
var skip_frame = false  # stops the player from being slowed down by objects when standing on them

var possible_held_items = []

var held_item = null
var other_held_item = null

var tm : TileMap

var map_dimensions = Vector2(0, 0)

var active_grapple = null

var safe_spikes = []
var active_bombs = []

var skip_tile = []
var next_ground_tile = []
var rope_tiles = []

var taking_damage = false

var i_frames = false

var prev_motion : Vector2

signal hit

func _ready():
	pass


func _process(_delta):
	ladder_behind = false
	for i in [-3, 0, 2]:
		if tm.get_cell_atlas_coords(Global.layers.decorations, tm.local_to_map(position + Vector2(0, i))) in ladder_tiles:
			ladder_behind = true
			break
	#on_plank = tm.get_cell_atlas_coords(Global.layers.decorations, tm.local_to_map(position) + Vector2i(0, 1)) == Global.block_data.ladder_top and is_on_floor()
	if abs(look_timer) > 0.8:
		if look_timer > 0:
			camera_center.position.y = lerp(camera_center.position.y, -32.0, 0.2)
		else:
			camera_center.position.y = lerp(camera_center.position.y, 32.0, 0.2)
	else:
		camera_center.position.y = lerp(camera_center.position.y, 0.0, 0.2)
	if Global.health < 1:
		pass
	if i_frames:
		if roundi(i_frame_timer.time_left*100) % 20 >= 10:
			modulate.a = 0
		else:
			modulate.a = 1


func _physics_process(delta):
	var dir = Vector2(1, 1) if player_sprite.flip_h == false else Vector2(-1, 1)
	if is_on_floor() or state == 'latch':
		coyote_time = 0.0
	
	
	if not ladder_behind and state == 'climb':
		state = 'fall'
	
	
	if not is_on_floor() and state == "fall":
		coyote_time += delta
		player_sprite.animation = "jump"
		velocity.y += gravity * delta
	
	if active_grapple != null and state == 'grapple':
		position = active_grapple.player_holder.global_position
	
	if Input.is_action_just_pressed("jump"):
		look_timer = 0.0
		if state == 'latch' and Input.is_action_pressed("down"):
			state = 'fall'
		elif state == 'grapple' and Input.is_action_pressed("down"):
			detatch_from_grapple()
		elif is_on_floor() or state in ['latch', 'climb', 'grapple'] or coyote_time < 0.1:
			detatch_from_grapple()
			skip_frame = true
			if coyote_time < 0.1 and not state == 'grapple':
				velocity.y = JUMP_VELOCITY
			else:
				velocity.y += JUMP_VELOCITY
			state = 'fall'
		elif len(get_tree().get_nodes_in_group("hooks")) == 0:
			var cur_hook = Global.hook.instantiate()
			active_grapple = null
			cur_hook.position = position
			cur_hook.target = self
			cur_hook.add_to_group("hooks")
			get_parent().add_child(cur_hook)
			cur_hook.connect("hooked", add_hook)
			cur_hook.linear_velocity = Vector2(120, -300) * dir + velocity * Vector2(1, 0.5)
	
	
	if is_on_floor() and velocity == Vector2.ZERO:
		player_sprite.animation = "idle"
	
	
	var direction = Input.get_axis("left", "right")
	if direction and not taking_damage:
		look_timer = 0.0
		if not state == 'latch':
			player_sprite.flip_h = direction < 0
		if not state in ['latch', 'climb']:
			velocity.x = lerp(velocity.x , direction * SPEED, 0.045)
			if active_grapple:
				active_grapple.player_holder.apply_central_force(Vector2(velocity.x, 0))
			ledge_grab.scale.x = dir.x
			space_check.scale.x = dir.x
			floor_check.scale.x = dir.x
			player_sprite.animation = "run"
			if len(skip_tile) == 0 and len(next_ground_tile) > 0 and is_on_floor() and abs(velocity.x) > 50.0:
				velocity.y -= 40
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	
	if Input.is_action_pressed("up"):
		if ladder_behind and abs(position.x - tm.map_to_local(tm.local_to_map(position)).x) < 3:
			if tm.get_cell_atlas_coords(Global.layers.decorations, tm.local_to_map(position - Vector2(0, 3))) in ladder_tiles or tm.get_cell_atlas_coords(Global.layers.decorations, tm.local_to_map(position + Vector2(0, 4))) == Global.block_data.ladder_top:
				detatch_from_grapple()
				state = 'climb'
				position.x = tm.map_to_local(tm.local_to_map(position)).x
				position.y -= 60.0 * delta
				velocity.y = 0
				player_sprite.animation = "climb"
				
			if is_on_floor():
				position.y -= 1.0
		else:
			look_timer += delta
			if not state == 'latch' and not direction:
				player_sprite.animation = "look_up"
	
	
	if Input.is_action_pressed("down"):
		look_timer -= delta
		var just_on_plank = false
		if tm.get_cell_atlas_coords(Global.layers.decorations, tm.local_to_map(position) + Vector2i(0, 1)) == Global.block_data.ladder_top and is_on_floor():
			just_on_plank = true
			position.y += 1
			state = 'climb'
			ladder_behind = true
			on_plank = false
		elif state == 'climb' and ladder_behind and ((not is_on_floor()) or just_on_plank):
			position.x = tm.map_to_local(tm.local_to_map(position)).x
			position.y += 60.0 * delta
			velocity.y = 0
			player_sprite.animation = "climb"
		elif state not in ["latch", "grapple"]:
			player_sprite.animation = "crouch"
			state = 'fall'
		elif state == 'latch':
			player_sprite.animation = "latch_look"
	
	
	if Input.is_action_just_released("down") and state == 'latch':
		player_sprite.animation = 'latch'
	
	
	if Input.is_action_just_pressed("action") or throw:
		throw = false
		
		if held_item == null:
			if len(possible_held_items) > 0:
				held_item = possible_held_items[0]
				held_item.collision_layer = 0
				held_item.collision_mask = 0
				held_item.z_index = 10
		else:
			held_item.z_index = 0
			held_item.collision_layer = 8
			held_item.collision_mask = 4
			var output = Vector2(0, 0)
			if Input.is_action_pressed("down"):
				if is_on_floor():
					output = velocity + Vector2(80, 0) * dir
				else:
					output = velocity + Vector2(120, 200) * dir
			else:
				if direction:
					output = velocity + Vector2(200, -100) * dir
				else:
					output = velocity + Vector2(180, -140) * dir
				if Input.is_action_pressed("up"):
					output *= Vector2(0.8, 1.4)
			held_item.sprite.flip_h = false
			held_item.linear_velocity = output
			held_item = null
			if other_held_item:
				held_item = other_held_item
				other_held_item = null
	
	if held_item != null:
		held_item.sprite.flip_h = player_sprite.flip_h
		held_item.position = position + dir * Vector2(4, -1)
		held_item.linear_velocity = Vector2.ZERO
	
	if Input.is_action_just_pressed("bomb"):
		if Global.bombs > 0:
			Global.bombs -= 1
			var cur_bomb = Global.pickable.instantiate()
			cur_bomb.object_type = 'bomb'
			cur_bomb.add_to_group("bombs")
			get_parent().add_child(cur_bomb)
			cur_bomb.connect("boom", get_parent().detonate_bomb)
			cur_bomb.position = position
			other_held_item = held_item
			held_item = cur_bomb
			throw = true
			
	
	if Input.is_action_just_pressed("rope"):
		if Global.chains > 0:
			Global.chains -= 1
			if player_sprite.animation == 'crouch':
				var cur_rope = Global.rope.instantiate()
				cur_rope.position = position + (Vector2(8, 0)*dir)
				get_parent().add_child(cur_rope)
				cur_rope.connect("peaked", get_parent().add_rope)
				cur_rope.linear_velocity = Vector2.ZERO
			else:
				var cur_rope = Global.rope.instantiate()
				cur_rope.position = position - Vector2(0, 4)
				get_parent().add_child(cur_rope)
				cur_rope.connect("peaked", get_parent().add_rope)
	
	
	if Input.is_action_just_released("up") or Input.is_action_just_released("down"):
		look_timer = 0.0
	
	
	if not skip_frame:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			if collision.get_collider() == null:
				pass
			else:
				if state == 'grapple': 
					detatch_from_grapple()
				if collision.get_collider().is_in_group("bodies"):
					if is_on_floor():
						if on_tm:
							collision.get_collider().apply_central_impulse(-collision.get_normal() * inertia)
					else:
						velocity.x = 0
	else:
		skip_frame = false
	
	if taking_damage:
		player_sprite.animation = 'hurt'
	
	move_and_slide()

func drop_held_item():
	throw = true

func add_hook(hook_pos):
	active_grapple = null
	for grap in get_tree().get_nodes_in_group("grapples"):
		grap.queue_free()
	var distance_to_player = hook_pos.distance_to(position)
	if distance_to_player > 10:
		var cur_grapple = Global.grapple.instantiate()
		cur_grapple.add_to_group("grapples")
		cur_grapple.target = self
		get_parent().call_deferred("add_child", cur_grapple)
		cur_grapple.position = hook_pos
		cur_grapple.rotation = cur_grapple.position.angle_to_point(position) - (PI / 2)
		cur_grapple.spring.length = distance_to_player / 2
		cur_grapple.spring.rest_length = distance_to_player / 2
		cur_grapple.player_holder.global_position = position
		cur_grapple.player_holder.linear_velocity = velocity
		state = 'grapple'
		active_grapple = cur_grapple
		if distance_to_player > 44:
			detatch_from_grapple()
		
	

func detatch_from_grapple():
	if active_grapple != null:
		velocity = active_grapple.player_holder.linear_velocity
		state = 'fall'
		var cur_chain = Global.hook.instantiate()
		cur_chain.target = self
		cur_chain.extend = false
		cur_chain.add_to_group("hooks")
		cur_chain.position = active_grapple.position
		get_parent().call_deferred("add_child", cur_chain)
		active_grapple.queue_free()
		active_grapple = null


func _on_ledge_grab_body_shape_entered(_body_rid, body, body_shape_index, _local_shape_index):
	if body_shape_index == 1 and len(detector_list) == 0 and not is_on_floor() and not state == 'climb':
		detatch_from_grapple()
		state = 'latch'
		velocity = Vector2.ZERO
		position.y = snapped(position.y - 4, 8) + 4
		if body == tm:
			position.x = tm.map_to_local(tm.local_to_map(position)).x
		else:
			if body.position.x < position.x:
				position.x = body.position.x + 8
			else:
				position.x = body.position.x - 8
		player_sprite.animation = "latch"


func _on_ledge_grab_body_shape_exited(_body_rid, _body, _body_shape_index, _local_shape_index):
	if state == 'latch':
		state = 'fall'


func _on_space_detector_body_entered(body):
	detector_list.append(body)


func _on_space_detector_body_exited(body):
	if body in detector_list:
		detector_list.remove_at(detector_list.find(body))


func _on_spike_detector_area_entered(area):
	if area.is_in_group("spikes"):
		safe_spikes.append(area)


func _on_interact_area_entered(area):
	if area.is_in_group("spikes"):
		if area in safe_spikes:
			pass
		else:
			Global.health -= 99


func _on_interact_area_exited(_area):
	pass


func _on_spike_detector_area_exited(area):
	if area in safe_spikes:
		safe_spikes.remove_at(safe_spikes.find(area))



func _on_floor_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):
	if local_shape_index == 0:
		next_ground_tile.append(body)
	if local_shape_index > 0:
		skip_tile.append(body)


func _on_floor_body_shape_exited(_body_rid, body, _body_shape_index, local_shape_index):
	if local_shape_index == 0 and body in next_ground_tile:
		next_ground_tile.remove_at(next_ground_tile.find(body))
	if local_shape_index > 0 and body in skip_tile:
		skip_tile.remove_at(skip_tile.find(body))



func _on_interact_body_entered(body):
	if body.is_in_group("map"):
		on_tm = true
	if body.is_in_group("object"):
		possible_held_items.append(body)


func _on_interact_body_exited(body):
	if body.is_in_group("map"):
		on_tm = false
	if body in possible_held_items:
		possible_held_items.remove_at(possible_held_items.find(body))


func _on_space_detector_area_entered(area):
	if area.is_in_group("bomb_radius"):
		var bomb_point = area.get_owner().position
		var cur_angle = bomb_point.angle_to_point(position)
		velocity = Vector2(cos(cur_angle), sin(cur_angle)) * (1-(bomb_point.distance_to(position)/32)) * 400
		Global.health -= 99
		emit_signal("hit")



func _on_i_frames_timeout():
	i_frames = false
