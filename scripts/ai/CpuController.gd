class_name CpuController
extends InputController

## AI opponent. Implemented as an InputController so the simulation treats it exactly
## like a human: it emits one InputFrame per tick. Decisions are range-based (approach,
## poke, special, reactive block) and a small action queue lets it perform multi-frame
## motion inputs (fireballs, etc.) just like a player rolling the stick.

var difficulty: int = 1
var _queue: Array[InputFrame] = []
var _think_cd: int = 0

func _init(p_difficulty: int = 1) -> void:
	difficulty = clampi(p_difficulty, 0, 3)

func poll(self_fighter: Object, opponent: Object) -> InputFrame:
	var me := self_fighter as Fighter
	var opp := opponent as Fighter
	if me == null or opp == null:
		return InputFrame.new()

	if not _queue.is_empty():
		return _queue.pop_front()

	var dx: float = opp.position.x - me.position.x
	var dist: float = absf(dx)
	var toward: int = 1 if dx >= 0 else -1
	var facing: int = me.facing

	# Reactive block: if the opponent is attacking nearby, hold away for a few frames.
	if dist < 2.1 and _is_threat(opp) and randf() < _block_chance():
		_hold(-toward, 0, 0, 8)
		return _queue.pop_front()

	_think_cd -= 1
	if _think_cd > 0:
		return _approach(toward, dist)

	_think_cd = _think_interval()
	_decide(me, opp, dist, facing)
	if not _queue.is_empty():
		return _queue.pop_front()
	return _approach(toward, dist)

# --- decision making -------------------------------------------------------

func _decide(me: Fighter, opp: Fighter, dist: float, facing: int) -> void:
	var roll := randf()
	if dist < 1.35:
		# In range: poke, occasionally special / super.
		if me.meter >= me.character.max_meter and roll < 0.35 and not me.character.supers.is_empty():
			_motion(MotionParser.QCF_QCF, me.character.supers[0].button, facing)
		elif roll < _special_chance() and not me.character.specials.is_empty():
			var sp: MoveData = me.character.specials[randi() % me.character.specials.size()]
			_special(sp, facing)
		else:
			_poke(roll)
	elif dist < 3.2:
		# Mid range: close in, sometimes hop or zone with a projectile.
		if roll < 0.3 and _has_projectile(me):
			_motion(MotionParser.QCF, _projectile_button(me), facing)
		elif roll < 0.45:
			_hold(facing, 1, 0, 2)        # short hop forward
		else:
			_hold(facing, 0, 0, 10)       # advance
	else:
		# Far: zone or approach.
		if roll < 0.45 and _has_projectile(me):
			_motion(MotionParser.QCF, _projectile_button(me), facing)
		else:
			_hold(facing, 0, 0, 14)

func _poke(roll: float) -> void:
	# Pick a normal; crouching low pokes mixed in.
	if roll < 0.3:
		_press(GameConst.Btn.LP, false)
	elif roll < 0.55:
		_press(GameConst.Btn.LK, true)    # crouching low kick
	elif roll < 0.8:
		_press(GameConst.Btn.HP, false)
	else:
		_press(GameConst.Btn.HK, false)

func _special(sp: MoveData, facing: int) -> void:
	if sp.motion.is_empty():
		return
	_motion(sp.motion, sp.button, facing)

func _approach(toward: int, dist: float) -> InputFrame:
	if dist > 1.15:
		return InputFrame.new(toward, 0)
	return InputFrame.new()

# --- input queue builders --------------------------------------------------

## Enqueue a single attack press (optionally crouching) plus a short gap afterwards.
func _press(button: int, crouch: bool) -> void:
	var dy := -1 if crouch else 0
	_queue.append(InputFrame.new(0, dy, button, button))
	_queue.append(InputFrame.new(0, dy, 0, 0))
	_queue.append(InputFrame.new(0, 0, 0, 0))

## Enqueue a numpad motion in facing-relative terms, pressing `button` on the last input.
func _motion(seq: Array[int], button: int, facing: int) -> void:
	for i in range(seq.size()):
		var digit: int = seq[i]
		var dir := _digit_to_dir(digit, facing)
		var last := i == seq.size() - 1
		var press := button if last else 0
		# Hold each direction for two ticks so the parser registers it reliably.
		_queue.append(InputFrame.new(dir.x, dir.y, press, press))
		if not last:
			_queue.append(InputFrame.new(dir.x, dir.y, 0, 0))
	_queue.append(InputFrame.new(0, 0, 0, 0))

func _hold(dir_x: int, dir_y: int, button: int, frames: int) -> void:
	for i in range(frames):
		var press := button if i == 0 else 0
		_queue.append(InputFrame.new(dir_x, dir_y, button, press))

## Convert a facing-relative numpad digit back to a world-space direction.
func _digit_to_dir(digit: int, facing: int) -> Vector2i:
	var rel_x := ((digit - 1) % 3) - 1     # -1,0,1 for columns 1..3
	@warning_ignore("integer_division")
	var dy := ((digit - 1) / 3) - 1        # -1,0,1 for rows (bottom..top)
	return Vector2i(rel_x * facing, dy)

# --- helpers ---------------------------------------------------------------

func _is_threat(opp: Fighter) -> bool:
	return opp.state == Fighter.State.ATTACK

func _has_projectile(me: Fighter) -> bool:
	for sp in me.character.specials:
		if sp.projectile:
			return true
	return false

func _projectile_button(me: Fighter) -> int:
	for sp in me.character.specials:
		if sp.projectile:
			return sp.button
	return GameConst.Btn.LP

func _think_interval() -> int:
	return clampi(34 - difficulty * 7, 10, 40)

func _block_chance() -> float:
	return clampf(0.2 + difficulty * 0.18, 0.0, 0.85)

func _special_chance() -> float:
	return clampf(0.18 + difficulty * 0.06, 0.0, 0.6)
