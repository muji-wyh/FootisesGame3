class_name PlayerController
extends InputController

## Reads a human player's mapped keyboard/gamepad actions and produces an InputFrame.
## `prefix` selects which action set to read ("p1" or "p2").

var prefix: String

func _init(p_prefix: String) -> void:
	prefix = p_prefix

func poll(_self_fighter: Object, _opponent: Object) -> InputFrame:
	var f := InputFrame.new()
	var right := Input.is_action_pressed(prefix + "_right")
	var left := Input.is_action_pressed(prefix + "_left")
	var up := Input.is_action_pressed(prefix + "_up")
	var down := Input.is_action_pressed(prefix + "_down")
	f.dir_x = int(right) - int(left)
	f.dir_y = int(up) - int(down)
	for button in GameConst.BUTTON_SUFFIX.keys():
		var action: String = prefix + GameConst.BUTTON_SUFFIX[button]
		if Input.is_action_pressed(action):
			f.held |= button
		if Input.is_action_just_pressed(action):
			f.pressed |= button
	return f
