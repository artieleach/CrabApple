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
const INERTIA = 48
const JUMP_VELOCITY = -94.0
# 240 velocity.y = damage
var on_tm := false

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var ladder_blocks = []
var detector_list = []
var state = State.FALL  # fall, climb, latch

enum State {
	FALL,
	CLIMB,
	LATCH,
	GRAPPLE
}
var throw := false

var coyote_time := 0.0
var look_timer := 0.0

var ladder_behind := false
var skip_frame := false  # stops the player from being slowed down by objects when standing on them

var possible_held_items = []

var held_item = null
var other_held_item = null

var tm : TileMap

var active_grapple = null

var safe_spikes := []

var skip_tile := []
var next_ground_tile := []

var taking_damage := false
var i_frames := false

signal hit

var dir := Vector2.ZERO

func _ready():
	pass


func _process(_delta):
	ladder_behind = false
	for i in [-3, 0, 2]:
		if tm.get_cell_atlas_coords(Global.layers.decorations, tm.local_to_map(position + Vector2(0, i))) in ladder_tiles:
			ladder_behind = true
			break
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
	dir = Vector2(1, 1) if player_sprite.flip_h == false else Vector2(-1, 1)
	if is_on_floor() or state == State.LATCH:
		coyote_time = 0.0
		detatch_from_grapple()
	
	
	if not ladder_behind and state == State.CLIMB:
		state = State.FALL
	
	if not is_on_floor() and state == State.FALL:
		coyote_time += delta
		player_sprite.animation = "jump"
		velocity.y += gravity * delta

	
	if Input.is_action_just_pressed("jump"):
		look_timer = 0.0
		if state == State.LATCH and Input.is_action_pressed("down"):
			state = State.FALL
		elif is_on_floor() or state in [State.LATCH, State.CLIMB, State.GRAPPLE] or coyote_time < 0.1:
			detatch_from_grapple()
			skip_frame = true
			if coyote_time < 0.1 and not State.GRAPPLE:
				velocity.y = JUMP_VELOCITY
			else:
				velocity.y += JUMP_VELOCITY
			state = State.FALL
		elif len(get_tree().get_nodes_in_group("grapples")) == 0:
			shoot_grapple()
	
	if Input.is_action_just_released("jump"):
		detatch_from_grapple()
	
	if is_on_floor() and velocity == Vector2.ZERO:
		player_sprite.animation = "idle"
	
	
	var direction = Input.get_axis("left", "right")
	if direction and not taking_damage:
		look_timer = 0.0
		if not state == State.LATCH:
			player_sprite.flip_h = direction < 0
		if not state in [State.LATCH, State.CLIMB]:
			velocity.x = lerp(velocity.x , direction * SPEED, 0.045)
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
				state = State.CLIMB
				position.x = tm.map_to_local(tm.local_to_map(position)).x
				position.y -= 60.0 * delta
				velocity.y = 0
				player_sprite.animation = "climb"
				
			if is_on_floor():
				position.y -= 1.0
		else:
			look_timer += delta
			if not state == State.LATCH and not direction:
				player_sprite.animation = "look_up"
	
	
	if Input.is_action_pressed("down"):
		look_timer -= delta
		var just_on_plank = false
		if tm.get_cell_atlas_coords(Global.layers.decorations, tm.local_to_map(position) + Vector2i(0, 1)) == Global.block_data.ladder_top and is_on_floor():
			just_on_plank = true
			position.y += 1
			state = State.CLIMB
			ladder_behind = true
		elif state == State.CLIMB and ladder_behind and ((not is_on_floor()) or just_on_plank):
			position.x = tm.map_to_local(tm.local_to_map(position)).x
			position.y += 60.0 * delta
			velocity.y = 0
			player_sprite.animation = "climb"
		elif state not in [State.LATCH, State.GRAPPLE]:
			player_sprite.animation = "crouch"
			state = State.FALL
		elif state == State.LATCH:
			player_sprite.animation = "latch_look"
	
	
	if Input.is_action_just_released("down") and state == State.LATCH:
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
			cur_bomb.object_type = cur_bomb.PickType.BOMB
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
				if state == State.GRAPPLE: 
					detatch_from_grapple()
				if collision.get_collider().is_in_group("bodies"):
					if is_on_floor():
						if on_tm:
							collision.get_collider().apply_central_impulse(-collision.get_normal() * INERTIA)
					else:
						velocity.x = 0
	else:
		skip_frame = false
	
	if taking_damage:
		player_sprite.animation = 'hurt'
	
	move_and_slide()

func drop_held_item():
	throw = true

func shoot_grapple():
	var cur_grap = Global.hook_and_grapple.instantiate()
	cur_grap.target = self
	active_grapple = cur_grap
	get_parent().add_child(cur_grap)


func detatch_from_grapple():
	if active_grapple != null:
		if active_grapple.state == active_grapple.State.LATCH:
			velocity = active_grapple.player_holder.linear_velocity
		state = State.FALL
		active_grapple.change_state(active_grapple.State.RETRACT)
		active_grapple = null


func _on_ledge_grab_body_shape_entered(_body_rid, body, body_shape_index, _local_shape_index):
	if body_shape_index == 1 and len(detector_list) == 0 and not is_on_floor() and not state == State.CLIMB:
		detatch_from_grapple()
		state = State.LATCH
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
	if state == State.LATCH:
		state = State.FALL


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
