extends Node

var pickable = preload("res://Actors/Pickable/pickable.tscn")
var crate = preload("res://Actors/Crate/crate.tscn")
var spike = preload("res://Actors/Spikes/spikes.tscn")
var rope = preload("res://Actors/Rope/rope.tscn")
var hook = preload("res://Actors/Hook/hook.tscn")
var grapple = preload("res://Actors/Grapple/grapple.tscn")
var arrow_trap = preload("res://Actors/Arrow Trap/arrow_trap.tscn")
var player_bumper = preload("res://Actors/Player/player_bumper.tscn")
var hook_and_grapple = preload("res://Actors/HookAndGrapple/hook_and_grapple.tscn")

var layers = {
	"collision": 0,
	"objects": 1,
	"decorations": 2,
	"spikes": 3,
	"foreground": 4}

const tile_size = Vector2(8, 8)

var health = 4
var bombs = 4
var chains = 4
var wealth = 0

const treasure_value = [400, 600, 800, 500, 1000]

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



func _process(_delta):
	health = clamp(health, 0, 99)
	bombs = clamp(bombs, 0, 99)
	chains = clamp(chains, 0, 99)
	wealth = clamp(wealth, 0, 999999)


func add_wealth(val):
	var starting_wealth = wealth
	while starting_wealth + val > wealth and starting_wealth + val < 999999:
		wealth = lerp(wealth, wealth+val, 0.05)
		await get_tree().process_frame
	wealth = starting_wealth + val
