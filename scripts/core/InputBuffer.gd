class_name InputBuffer
extends RefCounted

## Rolling history of recent InputFrames. Used both for input leniency and for the
## MotionParser to detect special-move motions (e.g. quarter-circle forward).

const SIZE: int = 40

var _frames: Array[InputFrame] = []

func push(frame: InputFrame) -> void:
	_frames.push_back(frame)
	if _frames.size() > SIZE:
		_frames.pop_front()

func latest() -> InputFrame:
	if _frames.is_empty():
		return InputFrame.new()
	return _frames[_frames.size() - 1]

## get_frame(0) is the most recent frame; get_frame(1) the one before, etc.
func get_frame(ago: int) -> InputFrame:
	var idx: int = _frames.size() - 1 - ago
	if idx < 0 or idx >= _frames.size():
		return InputFrame.new()
	return _frames[idx]

func size() -> int:
	return _frames.size()

func clear() -> void:
	_frames.clear()

## True if `button` was pressed (rising edge) within the last `window` ticks.
## Enables small input buffering so attacks feel responsive.
func pressed_within(button: int, window: int) -> bool:
	var n: int = min(window, _frames.size())
	for i in range(n):
		if get_frame(i).is_pressed(button):
			return true
	return false
