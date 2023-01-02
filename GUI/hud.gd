extends Control

@export var health_counter : Label
@export var wealth_counter : Label
@export var bomb_counter : Label
@export var chain_counter : Label

func _process(_delta):
	health_counter.text = '%2d' % Global.health
	bomb_counter.text = '%-2d' % Global.bombs
	chain_counter.text = '%-2d' % Global.chains
	wealth_counter.text = '%-6d' % Global.wealth
