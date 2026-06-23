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
	if seq.is_empty():
		return false
	var d: Array[int] = digits(buffer, facing, window)
	var si: int = 0
	var last_match: int = -1
	for i in range(d.size()):
		if si < seq.size() and d[i] == seq[si]:
			si += 1
			last_match = i
	if si < seq.size():
		return false
	return (d.size() - 1 - last_match) <= recent
