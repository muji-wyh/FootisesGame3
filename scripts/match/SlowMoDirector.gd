class_name SlowMoDirector
extends RefCounted

## Drives brief slow-motion beats (SF6 "critical" / finish feel) by producing a `scale`
## that the match applies to Engine.time_scale each tick. Counting is in fixed ticks, so
## it is independent of the dip itself: `tick()` is called once per physics frame whatever
## the current time scale. A short cooldown stops dips from chaining; a KO can override it.

const RESTORE_COOLDOWN := 30   # ticks after a dip before another may auto-trigger

var scale: float = 1.0
var _timer: int = 0
var _cd: int = 0

## Ask for a dip to `s` for `ticks` frames. Ignored while a dip or cooldown is active,
## unless `force` (used for KO) is set.
func request(s: float, ticks: int, force: bool = false) -> void:
	if not force and (_timer > 0 or _cd > 0):
		return
	scale = s
	_timer = ticks

## Advance one fixed tick; restore normal speed (and start the cooldown) when a dip ends.
func tick() -> void:
	if _cd > 0:
		_cd -= 1
	if _timer > 0:
		_timer -= 1
		if _timer <= 0:
			scale = 1.0
			_cd = RESTORE_COOLDOWN

func active() -> bool:
	return _timer > 0

## Cancel any dip immediately (e.g. on leaving the match) and restore normal speed.
func reset() -> void:
	scale = 1.0
	_timer = 0
	_cd = 0
