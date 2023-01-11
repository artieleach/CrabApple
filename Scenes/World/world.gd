extends Node

@export var shaker : Node
@export var tm : TileMap
@export var player : CharacterBody2D
@export var background : ColorRect
@export var cam : Camera2D
@export var player_bumper : RigidBody2D

const order = ['u', 'd', 'l', 'r']

var all_special_blocks = []  # automatically filled when the game runs

const order_add = {
	'u': Vector2(0, -1), 
	'd': Vector2(0, 1), 
	'l': Vector2(-1, 0), 
	'r': Vector2(1, 0)}

const enter_tiles = [1, 3, 5, 7, 9, 11, 13]

const exit_tiles = [4, 5, 6, 7, 12, 13, 14]

var datums
var map_dimensions = Vector2(4, 4)
var interior_ground_coords := []
var ground_coords := []
var active_hook = null

const block_data = {
	'floor': Vector2i(2, 7),
	'treasure': Vector2i(25, 30),
	'enterance': Vector2i(31, 37),
	'exit': Vector2i(29, 35),
	'nill': Vector2i(-1 ,-1),
	'air': Vector2i(-1, 0),
	'spikes': Vector2i(28, 21),
	'ladder': Vector2i(10,28),
	'ladder_top': Vector2i(10, 27),
	'rope': Vector2i(31, 32),
	'collision': Vector2i(2, 7),
	'arrow_trap_right': Vector2i(22, 14),
	'arrow_trap_left': Vector2i(21, 14)}


func _ready():
	if block_data != Global.block_data:
		print('WARNING: BLOCK DATA MISMATCH')
	for i in Global.block_data.keys():
		all_special_blocks.append(Global.block_data[i])
	datums = JSON.parse_string(load_map_data())
	generate_map()
	player.tm = tm
	cam.limit_right = map_dimensions.x * 80
	cam.limit_bottom = map_dimensions.y * 64
	$LevelBounds/Right.position.x = map_dimensions.x * 80
	$LevelBounds/Bottom.position.y = map_dimensions.y * 64
	cam.position = player.position
	background.size = map_dimensions * Vector2(80, 64)
	check_spikes()

func _process(delta):
	cam.position = lerp(cam.position, player.camera_center.global_position, 18*delta)

func _rumble_gamepad(weak_magnitude: float, strong_magnitude: float) -> void:
	var gamepads : Array = Input.get_connected_joypads()
	if gamepads.size() > 0:
		Input.stop_joy_vibration(0)
		Input.start_joy_vibration(0, weak_magnitude, strong_magnitude, 1.0)


func _on_player_hit():
	player.detatch_from_grapple()
	if not player.i_frames:
		player.i_frames = true
		player.i_frame_timer.start()
		var pb = Global.player_bumper.instantiate()
		pb.target = player
		pb.position = player.position
		pb.linear_velocity = player.velocity
		call_deferred("add_child", pb)
		player.taking_damage = true
		if player.held_item != null:
			player.throw = true


class block:
	var pos : Vector2
	var u : bool
	var d : bool
	var l : bool
	var r : bool
	var val : int
	var block_rep
	var been_here = false
	var special = ''
	func set_b(_u: bool, _d : bool, _l : bool, _r: bool):
		been_here = true
		u = _u
		d = _d
		l = _l
		r = _r
	func update_display():
		block_rep.set_vars(u, d, l, r)
	func get_b():
		return [u, d, l, r]
	func get_bin():
		return int(!u) + int(!r)*2 + int(!d)*4 + int(!l)*8
	func print_b():
		return '\tU: %s\nL: %s\tR: %s\n\tD: %s\nPos: %s' % [u, l, r, d, pos]

func load_map_data():
	var file = FileAccess.open("res://Scenes/World/map_data.json", FileAccess.READ)
	var content = file.get_as_text()
	return content

func set_chunk(chunk_pos: Vector2i, chunk_ID: int, variation: int):
	var interior_ground = []
	var offset = chunk_pos * Vector2i(10, 8)
	for layer in range(2):
		var cur_chunk = datums.layers[layer].chunks[chunk_ID+(16*variation)].data
		for y in range(8):
			for x in range(10):
				var cur_atlas = Vector2i(int(cur_chunk[y * 10 + x]) % 33 - 1, floor(cur_chunk[y * 10 + x] / 33))
				match cur_atlas:
					block_data.air:
						pass
					block_data.floor:
						if y > 0 and y < 7 and x > 0 and x < 9:
							interior_ground.append(Vector2i(x, y) + offset)
						else:
							ground_coords.append(Vector2i(x, y) + offset)
						tm.set_cell(layer, Vector2i(x, y) + offset, 1, cur_atlas)
					block_data.treasure:
						if randi_range(0, 100) < 80:
							var cur_treasure = Global.pickable.instantiate()
							cur_treasure.position = (Vector2(x, y) + Vector2(offset.x, offset.y)) * Global.tile_size + Vector2(4, 4)
							add_child(cur_treasure)
					block_data.enterance:
						player.position = (Vector2(x, y) + Vector2(offset.x, offset.y)) * Global.tile_size
						tm.set_cell(layer, Vector2i(x, y) + offset, 1, cur_atlas)
					block_data.spikes:
						var cur_spike = Global.spike.instantiate()
						cur_spike.position = (Vector2(x, y) + Vector2(offset.x, offset.y)) * Global.tile_size + Vector2(4, 4)
						add_child(cur_spike)
					block_data.ladder:
						tm.set_cell(Global.layers.decorations, Vector2i(x, y) + offset, 1, cur_atlas)
					block_data.ladder_top:
						tm.set_cell(Global.layers.decorations, Vector2i(x, y) + offset, 1, cur_atlas)
					_:
						tm.set_cell(layer, Vector2i(x, y) + offset, 1, cur_atlas)
	interior_ground_coords.append(interior_ground)
	#tm.set_cells_terrain_connect(4, interior_ground, 0, 0)

func clean_map():
	var map_tile_size = tm.get_used_rect().size
	for y in range(4, map_tile_size.y - 4):
		for x in range(4, map_tile_size.x - 4):
			var cur_spot = 4*floor(y/8)+floor(x/10)
			if tm.get_cell_atlas_coords(Global.layers.collision, Vector2i(x, y)) == block_data.floor:
				if tm.get_cell_atlas_coords(Global.layers.collision, Vector2i(x, y+1)) == block_data.floor and randf() < 0.1:
					tm.set_cell(Global.layers.collision, Vector2i(x, y), 1, block_data.nill)
					var cur_push = Global.crate.instantiate()
					cur_push.position = Vector2(x, y) * Global.tile_size + Vector2(4, 4)
					add_child(cur_push)
					remove_from_grass(Vector2i(x, y))
					
				elif tm.get_cell_atlas_coords(Global.layers.collision, Vector2i(x + 1, y)) == block_data.nill and tm.get_cell_atlas_coords(Global.layers.collision, Vector2i(x + 2, y)) == block_data.nill:
					if randi_range(0, 100) < 3:
						tm.set_cell(4, Vector2i(x, y), 1, block_data.arrow_trap_right)
						var cur_at = Global.arrow_trap.instantiate()
						add_child(cur_at)
						cur_at.position = Vector2(x, y) * Global.tile_size + Vector2(8, 4)
						cur_at.map_pos = Vector2i(x, y)
						cur_at.facing_right = true
						cur_at.figure_range(tm)
						cur_at.connect("fire_arrow", fire_arrow_trap)
						remove_from_grass(Vector2i(x, y))
				elif tm.get_cell_atlas_coords(Global.layers.collision, Vector2i(x - 1, y)) == block_data.nill and tm.get_cell_atlas_coords(Global.layers.collision, Vector2i(x - 2, y)) == block_data.nill:
					if randi_range(0, 100) < 3:
						tm.set_cell(4, Vector2i(x, y), 1, block_data.arrow_trap_left)
						var cur_at = Global.arrow_trap.instantiate()
						add_child(cur_at)
						cur_at.position = Vector2(x, y) * Global.tile_size + Vector2(0, 4)
						cur_at.map_pos = Vector2i(x, y)
						cur_at.facing_right = false
						cur_at.figure_range(tm)
						cur_at.connect("fire_arrow", fire_arrow_trap)
						remove_from_grass(Vector2i(x, y))
	for i in range(map_dimensions.x * map_dimensions.y):
		tm.set_cells_terrain_connect(4, interior_ground_coords[i], 0, 0)
	tm.set_cells_terrain_connect(4, ground_coords, 0, 0)


func remove_from_grass(loc):
	var cur_spot = 4*floor(loc.y/8)+floor(loc.x/10)
	if loc in interior_ground_coords[cur_spot]:
		interior_ground_coords[cur_spot].remove_at(interior_ground_coords[cur_spot].find(loc))
	elif loc in ground_coords:
		ground_coords.remove_at(ground_coords.find(loc))


func fire_arrow_trap(pew, facing_right):
	var arrow = Global.pickable.instantiate()
	arrow.object_type = arrow.PickType.ARROW
	arrow.facing_right = facing_right
	arrow.fired = true
	if facing_right:
		arrow.position = pew + Vector2(8, 0)
	else:
		arrow.position = pew - Vector2(8, 0)
	add_child(arrow)

func generate_map():
	var level_map = []
	for y in range(map_dimensions.y):
		level_map.append([])
		for x in range(map_dimensions.x):
			var cur = block.new()
			cur.pos = Vector2(x, y)
			level_map[y].append(cur)
	var cur_pos = Vector2(randi_range(1, map_dimensions.x - 2), 0)
	var starting_spot = level_map[cur_pos.y][cur_pos.x]
	starting_spot.set_b(false, false, cur_pos.x > 0, cur_pos.x < map_dimensions.x)
	starting_spot.special = 'enter'
	var cur_bin = starting_spot.get_b()
	var possible_directions = []
	for item in range(len(cur_bin)):
		if cur_bin[item] and not level_map[cur_pos.y + order_add[order[item]].y][cur_pos.x + order_add[order[item]].x].been_here:
			possible_directions.append(order[item])
	var new_dir = possible_directions[randi_range(0, len(possible_directions) - 1)]
	cur_pos += order_add[new_dir]
	while possible_directions:
		var cb = level_map[cur_pos.y][cur_pos.x]
		cb.set_b(cur_pos.y > 0, cur_pos.y < len(level_map) - 1, cur_pos.x > 0, cur_pos.x < len(level_map[0]) - 1)
		var block_bin = cb.get_b()
		possible_directions.clear()
		for item in range(len(block_bin)):
			if block_bin[item] and not level_map[cur_pos.y + order_add[order[item]].y][cur_pos.x + order_add[order[item]].x].been_here and not order[item] == 'u':
				possible_directions.append(order[item])
		if possible_directions == []:
			cb.special = 'exit'
			break
		var last_dir = new_dir
		new_dir = possible_directions[randi_range(0, len(possible_directions) - 1)]
		
		if new_dir == 'd':
			new_dir = possible_directions[randi_range(0, len(possible_directions) - 1)]
		else:
			cb.d = false
		if last_dir != 'd':
			cb.u = randf() > 0.5
		cur_pos += order_add[new_dir]
	for y in range(map_dimensions.y):
		for x in range(map_dimensions.x):
			var cb = level_map[y][x]
			if not cb.been_here:
				cb.set_b(bool(randi() % 2), bool(randi() % 2), bool(randi() % 2), bool(randi() % 2))
			if y == 0:
				cb.u = false
			if y == map_dimensions.y - 1:
				cb.d = false
			if x == 0:
				cb.l = false
			if x == map_dimensions.x - 1:
				cb.r = false
			if cb.special == '':
				cb.val = cb.get_bin()
				if true:
					set_chunk(Vector2i(x, y), cb.val, randi() % 16)
				else:
					set_chunk(Vector2i(x, y), cb.val, 24)
			else:
				match cb.special:
					'enter':
						set_chunk(Vector2i(x, y), cb.get_bin(), 16 + (randi() % 4))
					'exit':
						set_chunk(Vector2i(x, y), cb.get_bin(), 16 + (randi() % 4)+4)
	
	clean_map()


func add_rope(rope):
	var ladder_pos = tm.local_to_map(rope.position)
	rope.position = Vector2(ladder_pos) * Global.tile_size + Vector2(4, 4)
	var can_place = false
	for x in range(2):
		if tm.get_cell_atlas_coords(x, Vector2i(ladder_pos.x, ladder_pos.y)) == Vector2i(-1, -1):
			can_place = true
		else:
			return
	for i in range(6):
		can_place = false
		for x in range(2):
			if tm.get_cell_atlas_coords(x, Vector2i(ladder_pos.x, ladder_pos.y+i)) == Vector2i(-1, -1):
				can_place = true
			else:
				break
		if can_place:
			tm.set_cell(Global.layers.decorations, Vector2i(ladder_pos.x, ladder_pos.y+i), 1, Global.block_data.rope)
			await get_tree().process_frame
		else:
			break
	pass


func detonate_bomb(bomb_pos : Vector2):
	var exp_factor = clamp(64 - bomb_pos.distance_to(player.position), 8.0, 64.0) / 64.0
	shaker.start(1.4*exp_factor, 24.0*exp_factor, 8.0*exp_factor, 0.0*exp_factor)  # dur freq amp pri
	var bomb_on_map = Vector2(tm.local_to_map(bomb_pos))
	for y in range(-2, 3):
		for x in range(-2, 3):
			if bomb_on_map.distance_to(bomb_on_map +  Vector2(x, y)) < 2.5:
				for i in [Global.layers.collision, Global.layers.foreground]:
					if tm.get_cell_atlas_coords(i, Vector2i(bomb_on_map +  Vector2(x, y))) in [Global.block_data.arrow_trap_right, Global.block_data.arrow_trap_left]:
						for trap in get_tree().get_nodes_in_group("arrow_trap"):
							trap.figure_range(tm)
							if trap.map_pos == Vector2i(bomb_on_map +  Vector2(x, y)):
								trap.queue_free()
					tm.set_cell(i, Vector2i(bomb_on_map +  Vector2(x, y)), -1, Vector2i(-1, -1), -1)
	for trap in get_tree().get_nodes_in_group("arrow_trap"):
		trap.figure_range(tm)
	check_spikes()


func check_spikes():
	var all_spikes = get_tree().get_nodes_in_group("spikes")
	for spike in all_spikes:
		var cur_spike_spot = tm.local_to_map(spike.position) + Vector2i(0, 1)
		if tm.get_cell_atlas_coords(0, cur_spike_spot) != Global.block_data.collision:
			spike.queue_free()


