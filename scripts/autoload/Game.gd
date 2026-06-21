extends Node

## Autoload singleton (registered as "Game"). Holds match configuration that must
## survive scene changes, and registers all input actions in code (so we never have
## to hand-edit the project's InputMap text and risk syntax errors).

var mode: int = GameConst.Mode.LOCAL_2P
var p1_char_id: String = "blaze"
var p2_char_id: String = "blaze"

## Set by the match when it ends, read by the results screen.
var last_winner_side: int = 0
var last_winner_name: String = ""

func _ready() -> void:
	_register_inputs()

func _register_inputs() -> void:
	if not InputMap.has_action("ui_move_list"):
		InputMap.add_action("ui_move_list")
		_add_key("ui_move_list", KEY_TAB)
	# Single-player keyboard: left hand on WASD to move, right hand on U/I/O (punches) and
	# J/K/L (kicks) for the six attacks. A gamepad on device 0 mirrors it.
	_bind_player("p1",
		{"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D,
		 "lp": KEY_U, "mp": KEY_I, "hp": KEY_O,
		 "lk": KEY_J, "mk": KEY_K, "hk": KEY_L}, 0)
	# Player 2 has no keyboard keys (single-player focus). Its actions are still registered
	# for an optional gamepad on device 1, so Local-2P / polling never hits a missing action.
	_bind_player("p2", {}, 1)

func _bind_player(prefix: String, keys: Dictionary, device: int) -> void:
	for name in keys.keys():
		var action := "%s_%s" % [prefix, name]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		_add_key(action, keys[name])
	# Gamepad: D-pad for directions; face buttons + shoulders for the 6 attacks.
	_add_joy(prefix + "_up", JOY_BUTTON_DPAD_UP, device)
	_add_joy(prefix + "_down", JOY_BUTTON_DPAD_DOWN, device)
	_add_joy(prefix + "_left", JOY_BUTTON_DPAD_LEFT, device)
	_add_joy(prefix + "_right", JOY_BUTTON_DPAD_RIGHT, device)
	_add_joy(prefix + "_lp", JOY_BUTTON_X, device)
	_add_joy(prefix + "_mp", JOY_BUTTON_Y, device)
	_add_joy(prefix + "_hp", JOY_BUTTON_RIGHT_SHOULDER, device)
	_add_joy(prefix + "_lk", JOY_BUTTON_A, device)
	_add_joy(prefix + "_mk", JOY_BUTTON_B, device)
	_add_joy(prefix + "_hk", JOY_BUTTON_LEFT_SHOULDER, device)

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
