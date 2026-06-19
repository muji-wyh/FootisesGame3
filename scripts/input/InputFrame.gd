class_name InputFrame
extends RefCounted

## A single tick's worth of input for one fighter, in WORLD space.
## Directions: dir_x = -1 (left) / 0 / +1 (right); dir_y = -1 (down) / 0 / +1 (up).
## held    = bitmask of GameConst.Btn currently held.
## pressed = bitmask of GameConst.Btn that went down THIS tick (rising edge).

var dir_x: int = 0
var dir_y: int = 0
var held: int = 0
var pressed: int = 0

func _init(p_dir_x: int = 0, p_dir_y: int = 0, p_held: int = 0, p_pressed: int = 0) -> void:
	dir_x = p_dir_x
	dir_y = p_dir_y
	held = p_held
	pressed = p_pressed

func is_held(button: int) -> bool:
	return (held & button) != 0

func is_pressed(button: int) -> bool:
	return (pressed & button) != 0

func any_pressed() -> bool:
	return pressed != 0

## Facing-relative numpad notation (1-9), the standard fighting-game format:
##   7 8 9        where 6 = toward opponent (forward), 4 = away (back),
##   4 5 6        8 = up, 2 = down. `facing` is +1 (looking right) or -1 (left).
##   1 2 3
func numpad(facing: int) -> int:
	var rel_x: int = dir_x * facing  # +1 forward, -1 back
	return 5 + rel_x + (dir_y * 3)

func duplicate_frame() -> InputFrame:
	return InputFrame.new(dir_x, dir_y, held, pressed)
