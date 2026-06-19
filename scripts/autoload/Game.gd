extends Node

## Autoload singleton (registered as "Game"). Holds match configuration that must
## survive scene changes, and registers all input actions in code (so we never have
## to hand-edit the project's InputMap text and risk syntax errors).

var mode: int = GameConst.Mode.LOCAL_2P
var p1_char_id: String = "kael"
var p2_char_id: String = "rho"

func _ready() -> void:
	_register_inputs()

func _register_inputs() -> void:
	# Player 1: left-hand keyboard cluster + gamepad device 0.
	_bind_player("p1",
		{"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D,
		 "lp": KEY_F, "hp": KEY_G, "lk": KEY_C, "hk": KEY_V}, 0)
	# Player 2: arrow keys + J/K/N/M + gamepad device 1.
	_bind_player("p2",
		{"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
		 "lp": KEY_J, "hp": KEY_K, "lk": KEY_N, "hk": KEY_M}, 1)

func _bind_player(prefix: String, keys: Dictionary, device: int) -> void:
	for name in keys.keys():
		var action := "%s_%s" % [prefix, name]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		_add_key(action, keys[name])
	# Gamepad: D-pad for directions, face buttons for attacks.
	_add_joy(prefix + "_up", JOY_BUTTON_DPAD_UP, device)
	_add_joy(prefix + "_down", JOY_BUTTON_DPAD_DOWN, device)
	_add_joy(prefix + "_left", JOY_BUTTON_DPAD_LEFT, device)
	_add_joy(prefix + "_right", JOY_BUTTON_DPAD_RIGHT, device)
	_add_joy(prefix + "_lp", JOY_BUTTON_X, device)
	_add_joy(prefix + "_hp", JOY_BUTTON_Y, device)
	_add_joy(prefix + "_lk", JOY_BUTTON_A, device)
	_add_joy(prefix + "_hk", JOY_BUTTON_B, device)

func _add_key(action: String, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _add_joy(action: String, button_index: int, device: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button_index
	ev.device = device
	InputMap.action_add_event(action, ev)

## Scene helpers -------------------------------------------------------------

func goto_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
