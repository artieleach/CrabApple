class_name RumbleControl
extends Control
# A control node for testing a rumble configuration.
# Both a gamepad and handheld variant of a particular rumble can be implemented.
# This provides a simple, single rumble - but may be overridden to do more.

func _ready() -> void:
	var gamepads : Array = Input.get_connected_joypads()
	if gamepads.size() > 0:
		for device_index in gamepads:
			Input.stop_joy_vibration(device_index)
			_rumble_gamepad(device_index, 0.1, 0.2)

