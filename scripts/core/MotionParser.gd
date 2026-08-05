class_name MotionParser
extends RefCounted

## Detects special-move motions in facing-relative numpad notation over an InputBuffer.
## Detection is lenient (subsequence match within a time window) so players don't need
## frame-perfect inputs - exactly how real fighting games feel.

## Common motions, expressed as numpad sequences (forward = toward opponent).
const QCF: Array[int] = [2, 3, 6]        # quarter-circle forward
const QCB: Array[int] = [2, 1, 4]        # quarter-circle back
const DP: Array[int] = [6, 2, 3]         # dragon punch / shoryuken
const QCF_QCF: Array[int] = [2, 3, 6, 2, 3, 6]  # double QCF (super)

## Build the recent numpad-digit history (oldest -> newest) within `window` ticks.
static func digits(buffer: InputBuffer, facing: int, window: int) -> Array[int]:
	var out: Array[int] = []
	var n: int = min(window, buffer.size())
	for i in range(n - 1, -1, -1):
		out.append(buffer.get_frame(i).numpad(facing))
	return out

## True if `seq` appears as a subsequence of the last `window` ticks AND the final
## element landed within the last `recent` ticks (so old motions don't linger).
static func completed(buffer: InputBuffer, facing: int, seq: Array[int],
		window: int = 16, recent: int = 8) -> bool:
	return completion_age(buffer, facing, seq, window, recent) >= 0

## Ticks since the sequence's final direction, or -1 when the motion is incomplete/stale.
## Move selection uses this to prefer the motion completed closest to the button press.
static func completion_age(buffer: InputBuffer, facing: int, seq: Array[int],
		window: int = 16, recent: int = 8) -> int:
	if seq.is_empty():
		return -1
	var effective_window: int = maxi(window, seq.size() * 6)
	var effective_recent: int = maxi(recent, 10)
	var d: Array[int] = digits(buffer, facing, effective_window)
	for end_index in range(d.size() - 1, -1, -1):
		if d[end_index] != seq[seq.size() - 1]:
			continue
		var age := d.size() - 1 - end_index
		if age > effective_recent:
			return -1
		var si := seq.size() - 2
		for i in range(end_index - 1, -1, -1):
			if si >= 0 and d[i] == seq[si]:
				si -= 1
		if si < 0:
			return age
	return -1
