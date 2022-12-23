extends Control

@export var health_counter : Label
@export var wealth_counter : Label
@export var bomb_counter : Label
@export var chain_counter : Label

func _process(delta):
	health_counter.text = str(Global.health)
	bomb_counter.text = str(Global.bombs)
	chain_counter.text = str(Global.chains)
	wealth_counter.text = '%-6d' % Global.wealth
