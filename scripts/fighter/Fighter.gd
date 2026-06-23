class_name Fighter
extends Node3D

## One fighter's full simulation: input-driven state machine, movement, attacks,
## blocking, hitstun/knockdown, and hit/hurt boxes. Everything runs on the fixed
## 60 Hz tick driven by the Match (never in _process), so combat is deterministic.
##
## Update order per tick (orchestrated by Match):
##   1. poll_input()    - controller -> InputBuffer
##   2. advance(delta)  - state machine + physics integration
##   3. (Match resolves pushboxes / stage bounds)
##   4. (HitResolver applies hits -> may call receive_hit())
##   5. update_facing() - turn to face opponent when actionable
##   6. update_visual() - pose the rig

signal health_changed(current: int, maximum: int)
signal meter_changed(current: int, maximum: int)
signal drive_changed(current: int, maximum: int)
signal move_started(move: MoveData)
signal contact(blocked: bool, move: MoveData)   # this fighter connected an attack
signal got_hit(blocked: bool)                    # this fighter was hit
signal countered(kind: int)                      # this fighter was hit as a Counter/Punish
signal jumped()
signal combo_changed(hits: int, damage: int)     # this fighter's combo on its opponent changed

enum State { INTRO, IDLE, WALK_F, WALK_B, CROUCH, JUMP, ATTACK, DASH_F, DASH_B, HITSTUN, BLOCKSTUN, KNOCKDOWN, KO, WIN, WAKEUP, DRIVE_RUSH }

const GROUND_Y := 0.0
const PUSHBOX_HALF := 0.35
const STUN_FRICTION := 0.90
const DASH_WINDOW := 12      # ticks within which a second tap triggers a dash
const DASH_DURATION := 12
const DASH_SPEED := 6.0
const BACKDASH_SPEED := 5.6
const COUNTER_BONUS_HITSTUN := 6    # extra hitstun on a Counter Hit
const PUNISH_BONUS_HITSTUN := 14    # extra hitstun on a Punish Counter (combo window)
const KNOCKDOWN_TICKS := 40         # time spent on the ground after a hard knockdown
const WAKEUP_TICKS := 34            # get-up duration (invulnerable) before returning to idle
const CANCEL_BUFFER := 6            # advancing ticks a buffered attack press stays cancel-eligible
const DRC_INPUT_BUFFER := 30        # real ticks a two-punch DRC input can wait before/after contact
const DRC_CHORD_BUFFER := 8         # ticks to complete a slightly staggered two-punch DRC input
const GREEN_RUSH_CHORD_BUFFER := 5  # ticks to complete a slightly staggered two-punch input
const DRIVE_RUSH_SPEED := 9.8       # forward speed while in a Drive Rush
const DRIVE_RUSH_START_SPEED := 0.22 # initial crawl before the rush fully engages
const DRIVE_RUSH_STARTUP_TICKS := 12 # startup frames before normals can be cancelled from rush
const DRIVE_RUSH_STARTUP_ANIM_TICKS := 14 # visual startup/wind-up before the run clip takes over
const DRIVE_RUSH_ACCEL_TICKS := 20  # acceleration frames from startup speed to full speed
const DRIVE_RUSH_ATTACK_SPEED := 8.4 # carried momentum for the first normal out of Drive Rush
const DRIVE_RUSH_DURATION := 42     # ticks a Drive Rush advances before returning to neutral
const DRIVE_RUSH_HITSTUN_BONUS := 5 # +hitstun/blockstun on the first normal out of a Drive Rush
const RAW_DRIVE_RUSH_COST := 1000    # Drive spent by a neutral two-punch green rush (1 bar)
const DRC_COST := 3000              # Drive spent by a Drive Rush Cancel (3 bars of 1000)
const CORNER_PUSHBACK_X := 6.0      # near-corner threshold for attacker recoil on hit
const INPUT_BUFFER := 4             # ticks a buffered attack press waits to fire on the first actionable frame
const DRIVE_RUSH_CARRY := 6.2       # forward slide speed granted to the first normal out of a Drive Rush
const DRIVE_RUSH_CARRY_TICKS := 10  # ticks that carry momentum lasts
const BURNOUT_TICKS := 90           # ticks Drive regen is suspended after the gauge empties (SF6 Burnout)
const DRC_PUNCH_MASK := GameConst.Btn.LP | GameConst.Btn.MP | GameConst.Btn.HP

## Combo damage scaling (SF6-style): the n-th hit of a combo deals this fraction of its
## damage. Gentle and only kicks in past hit 3 so single moves / short strings are unscaled.
const COMBO_SCALING := [1.0, 1.0, 1.0, 0.9, 0.8, 0.7, 0.7, 0.6]

# Configuration
var character: CharacterData
var controller: InputController
var side: int = GameConst.Side.P1
var opponent: Fighter

# Runtime state
var state: int = State.IDLE
var state_frame: int = 0
var facing: int = 1                 # +1 faces right, -1 faces left
var health: int = 1000
var meter: int = 0
var velocity := Vector3.ZERO
var on_ground: bool = true
var active: bool = false            # round running? set by RoundManager
var allow_zero_health_hit_reactions: bool = false

# Combat bookkeeping
var current_move: MoveData = null
var move_hits_done: int = 0
var move_hit_cooldown: int = 0
var stun_timer: int = 0
var launched: bool = false
var hitstop: int = 0
var hit_strength: int = 0    # 0=light, 1=medium, 2=heavy (for hit-reaction animation)
var hit_height: int = GameConst.HitHeight.MID  # vertical zone struck (reaction height)
var hit_crouch: bool = false       # victim was crouching when struck
var hit_air: bool = false          # victim was airborne when struck
var hit_from_back: bool = false    # victim was struck from behind (cross-up)
var hit_reaction_clip: String = "" # per-move victim reaction override, if the move authored one
var last_counter: int = GameConst.Counter.NONE   # counter kind of the most recent hit taken
var knockdown_kind: int = GameConst.Knockdown.NONE  # how the current knockdown was caused
var input_buffer := InputBuffer.new()

# Drive (SF6-style gauge, separate from the Super meter).
var drive: int = 0
var drive_rush_pending: bool = false   # first normal out of a Drive Rush gets a one-time advantage
var _dr_carry: int = 0                  # ticks of forward slide momentum left on a Drive Rush normal
var _burnout_timer: int = 0             # ticks Drive regen stays suspended after the gauge empties

# Combo state (tracked on the victim; the attacker is this fighter's opponent). Used for
# combo damage scaling and the HUD combo counter.
var combo_count: int = 0               # consecutive hits taken before recovering
var combo_damage: int = 0              # cumulative (post-scaling) damage of the current combo
# Cancel buffer: most-recent attack press, ageing only on advancing ticks (survives hitstop).
var _cancel_btn: int = 0
var _cancel_age: int = 999
var _cancel_frame := InputFrame.new()

# Dash double-tap tracking
var _tick: int = 0
var _prev_fwd: bool = false
var _prev_back: bool = false
var _fwd_tap: int = -100
var _back_tap: int = -100
var _dash_req: int = 0
var _drc_input_buffer: int = 0
var _drc_input_buffer_age: int = 999

# Presentation (optional; null in headless tests)
var rig: Node = null

# Projectiles requested this tick are queued for the Match to spawn.
var pending_projectiles: Array[MoveData] = []

func setup(p_character: CharacterData, p_controller: InputController, p_side: int, start_x: float) -> void:
	character = p_character
	controller = p_controller
	side = p_side
	health = character.max_health
	meter = 0
	drive = character.max_drive
	facing = 1 if side == GameConst.Side.P1 else -1
	position = Vector3(start_x, 0, 0)
	state = State.IDLE
	state_frame = 0

# --- per-tick API ----------------------------------------------------------

func poll_input() -> void:
	var inp: InputFrame
	if active and not _is_locked_out():
		inp = controller.poll(self, opponent)
	else:
		inp = InputFrame.new()
	input_buffer.push(inp)

func advance(delta: float) -> void:
	pending_projectiles.clear()
	# Cancel buffer: capture the latest attack press every tick (even during hitstop) so a
	# pre-pressed/mashed follow-up survives the freeze; it only AGES on advancing ticks.
	var lf := input_buffer.latest()
	var pressed_now := lf.pressed != 0
	if pressed_now:
		_remember_cancel_input(lf)
	_tick += 1
	_update_dash_taps(input_buffer.latest())
	if hitstop > 0:
		_update_drc_input_buffer(input_buffer.latest(), false)
		hitstop -= 1
		return
	_update_drc_input_buffer(input_buffer.latest(), true)
	if not pressed_now:
		_cancel_age += 1
	_regen_drive()
	state_frame += 1
	var inp := input_buffer.latest()
	match state:
		State.IDLE, State.WALK_F, State.WALK_B, State.CROUCH:
			_step_neutral(inp)
		State.JUMP:
			_step_air(inp)
		State.ATTACK:
			_step_attack(inp)
		State.DASH_F:
			_step_dash(inp, true)
		State.DASH_B:
			_step_dash(inp, false)
		State.DRIVE_RUSH:
			_step_drive_rush(inp)
		State.HITSTUN, State.BLOCKSTUN:
			_step_stun()
		State.KNOCKDOWN:
			_step_knockdown()
		State.WAKEUP:
			_step_wakeup()
		State.KO:
			velocity.x = 0
		State.INTRO:
			velocity = Vector3.ZERO
		State.WIN:
			velocity.x = 0
	_apply_physics(delta)

## Track facing-relative forward/back taps to detect dash double-taps.
func _update_dash_taps(inp: InputFrame) -> void:
	_dash_req = 0
	var fwd := inp.dir_x * facing > 0 and inp.dir_y == 0
	var back := inp.dir_x * facing < 0 and inp.dir_y == 0
	if fwd and not _prev_fwd:
		if _tick - _fwd_tap <= DASH_WINDOW:
			_dash_req = 1
		_fwd_tap = _tick
	if back and not _prev_back:
		if _tick - _back_tap <= DASH_WINDOW:
			_dash_req = -1
		_back_tap = _tick
	_prev_fwd = fwd
	_prev_back = back

func _remember_cancel_input(inp: InputFrame) -> void:
	_cancel_btn = inp.pressed
	_cancel_frame = inp.duplicate_frame()
	_cancel_age = 0

func _clear_cancel_buffer() -> void:
	_cancel_btn = 0
	_cancel_age = 999
	_cancel_frame = InputFrame.new()

func _update_drc_input_buffer(inp: InputFrame, age_buffer: bool) -> void:
	if _is_drc_input(inp) and state == State.ATTACK:
		_drc_input_buffer = 1
		_drc_input_buffer_age = 0
		return
	if _drc_input_buffer == 0:
		return
	if not age_buffer:
		return
	_drc_input_buffer_age += 1
	if _drc_input_buffer_age > DRC_INPUT_BUFFER:
		_clear_drc_input_buffer()

func _is_drc_input(inp: InputFrame) -> bool:
	var held_punches := inp.held & DRC_PUNCH_MASK
	var pressed_punches := inp.pressed & DRC_PUNCH_MASK
	if _is_live_two_punch_chord(inp):
		return true
	return pressed_punches != 0 and _bit_count(_recent_punch_mask(DRC_CHORD_BUFFER)) >= 2

func _is_live_two_punch_chord(inp: InputFrame) -> bool:
	return (inp.pressed & DRC_PUNCH_MASK) != 0 and _bit_count(inp.held & DRC_PUNCH_MASK) >= 2

func _recent_punch_mask(window: int) -> int:
	var mask := 0
	for button in [GameConst.Btn.LP, GameConst.Btn.MP, GameConst.Btn.HP]:
		if input_buffer.pressed_within(button, window):
			mask |= button
	return mask

func _recent_punch_count(window: int) -> int:
	return _bit_count(_recent_punch_mask(window))

func _is_green_rush_chord(inp: InputFrame) -> bool:
	if _is_drc_input(inp):
		return true
	var held_punches := inp.held & DRC_PUNCH_MASK
	var pressed_punches := inp.pressed & DRC_PUNCH_MASK
	var recent_punches := _recent_punch_mask(GREEN_RUSH_CHORD_BUFFER)
	if _bit_count(held_punches) >= 2 and _bit_count(recent_punches) >= 2:
		return true
	return pressed_punches != 0 and _bit_count(recent_punches) >= 2

func _can_confirm_raw_green_rush_from_attack(inp: InputFrame) -> bool:
	if drive_rush_pending or current_move == null:
		return false
	if current_move.kind != GameConst.MoveKind.NORMAL:
		return false
	if (current_move.button & DRC_PUNCH_MASK) == 0:
		return false
	if move_hits_done > 0 or state_frame > GREEN_RUSH_CHORD_BUFFER:
		return false
	return _is_green_rush_chord(inp)

func _consume_drc_input() -> bool:
	if _drc_input_buffer > 0 and _drc_input_buffer_age <= DRC_INPUT_BUFFER:
		_clear_drc_input_buffer()
		return true
	return false

func _clear_drc_input_buffer() -> void:
	_drc_input_buffer = 0
	_drc_input_buffer_age = 999

func update_facing() -> void:
	if not _is_actionable():
		return
	if opponent and is_instance_valid(opponent):
		var want := 1 if opponent.position.x >= position.x else -1
		facing = want

func update_visual() -> void:
	if rig and rig.has_method("pose"):
		rig.call("pose", self)

# --- neutral / movement ----------------------------------------------------

func _step_neutral(inp: InputFrame) -> void:
	if _is_green_rush_chord(inp) and spend_drive(RAW_DRIVE_RUSH_COST):
		_start_drive_rush()
		return
	# A pressed move (special/super/normal) takes priority over a dash on the same tick,
	# so motion inputs whose path crosses forward (e.g. double-QCF super) are not
	# eaten by an accidental double-tap. A press buffered a few frames early (INPUT_BUFFER)
	# still fires on this first actionable frame, for SF6-style responsiveness.
	var move := _select_move(inp)
	if move == null:
		move = _buffered_move(inp)
	if move:
		_start_move(move)
		return
	if _dash_req > 0:
		_start_dash(true)
		return
	if _dash_req < 0:
		_start_dash(false)
		return
	if inp.dir_y > 0 and on_ground:
		_start_jump(inp)
		return
	var fwd := inp.dir_x * facing       # +1 toward opponent
	if inp.dir_y < 0:
		_goto(State.CROUCH)
		velocity.x = 0
	elif fwd > 0:
		_goto(State.WALK_F)
		velocity.x = facing * character.walk_speed
	elif fwd < 0:
		_goto(State.WALK_B)
		velocity.x = -facing * character.back_speed
	else:
		_goto(State.IDLE)
		velocity.x = 0

func _start_jump(inp: InputFrame) -> void:
	_goto(State.JUMP)
	velocity.y = character.jump_velocity
	velocity.x = float(inp.dir_x) * character.jump_h_speed
	on_ground = false
	jumped.emit()

func _step_air(inp: InputFrame) -> void:
	# Air normals: attack while airborne keeps momentum; gravity continues.
	var move := _select_move(inp)
	if move:
		_start_move(move)

func _start_dash(forward: bool) -> void:
	if forward:
		_goto(State.DASH_F)
		velocity.x = facing * DASH_SPEED
	else:
		_goto(State.DASH_B)
		velocity.x = -facing * BACKDASH_SPEED
	state_frame = 0

func _step_dash(inp: InputFrame, forward: bool) -> void:
	# A forward dash can be cancelled into an attack.
	if forward:
		var move := _select_move(inp)
		if move:
			_start_move(move)
			return
	if state_frame >= DASH_DURATION:
		velocity.x = 0
		_goto(State.IDLE)

## Drive Rush: a forward-advancing rush (Raw from neutral, or a Cancel out of a connected
## normal) that can itself be cancelled into a grounded normal. The first normal performed
## out of it gets a one-time advantage bonus (see drive_rush_hit_bonus), enabling links.
func _start_drive_rush() -> void:
	_goto(State.DRIVE_RUSH)
	state_frame = 0
	current_move = null
	move_hits_done = 0
	move_hit_cooldown = 0
	_clear_cancel_buffer()
	_clear_drc_input_buffer()
	velocity.x = 0.0

func _drive_rush_speed() -> float:
	if state_frame <= DRIVE_RUSH_STARTUP_TICKS:
		return DRIVE_RUSH_START_SPEED
	var t := clampf(float(state_frame - DRIVE_RUSH_STARTUP_TICKS) / float(DRIVE_RUSH_ACCEL_TICKS), 0.0, 1.0)
	return lerpf(DRIVE_RUSH_START_SPEED, DRIVE_RUSH_SPEED, t)

func _step_drive_rush(inp: InputFrame) -> void:
	if inp.dir_x * facing < 0:
		_clear_cancel_buffer()
		velocity.x = facing * _drive_rush_speed()
		return
	if _is_live_two_punch_chord(inp):
		_clear_cancel_buffer()
		velocity.x = facing * _drive_rush_speed()
		return
	# Keep a pre-pressed follow-up alive through the wind-up; the visible startup shouldn't eat inputs.
	if state_frame <= DRIVE_RUSH_STARTUP_TICKS and _cancel_btn != 0:
		_cancel_age = 0
	if state_frame > DRIVE_RUSH_STARTUP_TICKS:
		var move := _select_move(inp)
		if move == null:
			move = _buffered_move(inp)
		if move != null and move.stance != GameConst.Stance.AIR:
			_start_move(move)   # _start_move arms the Drive Rush bonus for normals out of DRIVE_RUSH
			return
	velocity.x = facing * _drive_rush_speed()
	if state_frame >= DRIVE_RUSH_DURATION:
		velocity.x = 0
		drive_rush_pending = false
		_goto(State.IDLE)

# --- attacks ---------------------------------------------------------------

func _current_stance(inp: InputFrame) -> int:
	if not on_ground:
		return GameConst.Stance.AIR
	if inp.dir_y < 0:
		return GameConst.Stance.CROUCH
	return GameConst.Stance.STAND

func _select_move(inp: InputFrame) -> MoveData:
	return _select_move_for(inp.pressed, inp)

## Pick a move from a `pressed` button mask (the live press, or a buffered one) given the
## current directional `inp`. Overdrive (EX) specials are checked first (two buttons + Drive),
## then supers, then regular specials, then stance-matched normals.
func _select_move_for(pressed: int, inp: InputFrame) -> MoveData:
	if pressed == 0:
		return null
	var stance := _current_stance(inp)
	# Specials/supers/overdrives are ground-only here.
	if on_ground:
		var od := _select_overdrive(pressed)
		if od:
			return od
		for m in character.supers:
			if (pressed & m.button) and meter >= m.meter_cost and _motion_ok(m):
				return m
		for m in character.specials:
			if m.drive_cost > 0:
				continue   # Overdrive variants handled above
			if (pressed & m.button) and _motion_ok(m):
				return m
	# Normals: match button and the current stance, with a same-button fallback.
	var fallback: MoveData = null
	for m in character.normals:
		if pressed & m.button:
			if m.stance == stance:
				return m
			if fallback == null:
				fallback = m
	return fallback

## Overdrive (EX) specials: require >=2 buttons of the move's `multi_button` mask pressed at
## once, the move's motion, and enough Drive. Returns the first affordable match, or null.
func _select_overdrive(pressed: int) -> MoveData:
	for m in character.specials:
		if m.drive_cost <= 0:
			continue
		if m.multi_button != 0 and _bit_count(pressed & m.multi_button) < 2:
			continue
		if drive < m.drive_cost:
			continue
		if _motion_ok(m):
			return m
	return null

## A move from the input buffer: the most recent attack press, still fresh (within
## INPUT_BUFFER advancing ticks), fired on the first actionable frame. Gives the SF6 feel
## where a slightly-early press is honoured instead of dropped.
func _buffered_move(inp: InputFrame) -> MoveData:
	if _cancel_btn == 0 or _cancel_age > INPUT_BUFFER:
		return null
	var buffered := _cancel_frame.duplicate_frame()
	if buffered.pressed == 0:
		buffered = inp.duplicate_frame()
	buffered.pressed = _cancel_btn
	return _select_move_for(_cancel_btn, buffered)

func _motion_ok(m: MoveData) -> bool:
	if m.motion.is_empty():
		return true
	return MotionParser.completed(input_buffer, facing, m.motion)

func _cancel_motion_ok(m: MoveData) -> bool:
	if m.motion.is_empty():
		return true
	return MotionParser.completed(input_buffer, facing, m.motion, InputBuffer.SIZE, DRC_INPUT_BUFFER)

func _start_move(m: MoveData) -> void:
	_clear_drc_input_buffer()
	# Arm the one-time Drive Rush advantage when a normal is performed out of a Drive Rush,
	# and grant it a brief forward slide so it closes the gap (SF6 Drive Rush momentum).
	var from_dr := (state == State.DRIVE_RUSH and m.kind == GameConst.MoveKind.NORMAL)
	drive_rush_pending = from_dr
	_dr_carry = DRIVE_RUSH_CARRY_TICKS if from_dr else 0
	current_move = m
	move_hits_done = 0
	move_hit_cooldown = 0
	_cancel_age = 999   # a fresh press is required to cancel this new move
	if m.kind == GameConst.MoveKind.SUPER:
		_add_meter(-m.meter_cost)
	if m.drive_cost > 0:
		spend_drive(m.drive_cost)   # Overdrive (EX): affordability was checked on selection
	_goto(State.ATTACK)
	state_frame = 0   # ensure a fresh attack even when cancelling ATTACK -> ATTACK
	# Air attacks keep their jump momentum (arc); grounded attacks stop in place, except a
	# Drive Rush normal which slides forward for its carry window.
	if m.stance != GameConst.Stance.AIR:
		velocity.x = facing * DRIVE_RUSH_CARRY if from_dr else 0.0
	move_started.emit(m)

func _step_attack(_inp: InputFrame) -> void:
	var m := current_move
	if m == null:
		_goto(State.IDLE)
		return
	if _can_confirm_raw_green_rush_from_attack(_inp) and spend_drive(RAW_DRIVE_RUSH_COST):
		_start_drive_rush()
		return
	if move_hit_cooldown > 0:
		move_hit_cooldown -= 1
	var is_air := m.stance == GameConst.Stance.AIR
	if is_air:
		# Air normals keep horizontal momentum; gravity + landing end the move.
		if on_ground:
			current_move = null
			_goto(State.IDLE)
			return
	elif drive_rush_pending and state_frame < m.startup + m.active:
		velocity.x = facing * maxf(DRIVE_RUSH_ATTACK_SPEED, m.advance)
	elif m.advance > 0.0 and state_frame < m.startup + m.active:
		velocity.x = facing * m.advance   # ground lunge/advance
	elif _dr_carry > 0:
		# Drive Rush normal: keep sliding forward (decaying) so it closes the gap.
		_dr_carry -= 1
		velocity.x = facing * DRIVE_RUSH_CARRY * (float(_dr_carry) / float(DRIVE_RUSH_CARRY_TICKS))
	else:
		velocity.x = 0
	# Rising attacks (DP-style): leap along a scripted vertical arc within the move's frames.
	# on_ground stays true, so _apply_physics does not fight the curve (see design D9).
	if m.rises:
		var t := float(state_frame) / float(maxi(1, m.total_frames()))
		position.y = m.rise_height * 4.0 * t * (1.0 - t)
	# Spawn a projectile on the first active frame.
	if m.projectile and state_frame == m.startup:
		pending_projectiles.append(m)
	# Once connected (hit or block), a normal can always DRC on a two-punch input. Authored
	# cancel routes are optional and live in cancel_into; Blaze currently leaves them empty.
	if move_hits_done > 0:
		if not m.cancel_into.is_empty():
			var special_cancel := _select_cancel(m, false)
			if special_cancel:
				_start_move(special_cancel)
				return
		if m.kind == GameConst.MoveKind.NORMAL and _consume_drc_input() and spend_drive(DRC_COST):
			_start_drive_rush()
			return
		if not m.cancel_into.is_empty():
			var nxt := _select_cancel(m)
			if nxt:
				_start_move(nxt)
				return
	if state_frame >= m.total_frames():
		current_move = null
		drive_rush_pending = false
		_goto(State.IDLE if on_ground else State.JUMP)

## Choose a buffered cancel target. Uses the hitstop-aware cancel buffer (a press within the
## last CANCEL_BUFFER advancing ticks) rather than a frame-fresh press, and only allows moves
## listed in the source move's cancel_into. Specials/supers validate their motion over the buffer.
func _select_cancel(from_move: MoveData, allow_normals: bool = true) -> MoveData:
	if _cancel_btn == 0 or _cancel_age > CANCEL_BUFFER:
		return null
	var btn := _cancel_btn
	if on_ground:
		# Overdrive (EX) cancels first: two buttons + motion + Drive, listed in cancel_into.
		for m in character.specials:
			if m.drive_cost > 0 and from_move.cancel_into.has(m.id) \
					and m.multi_button != 0 and _bit_count(btn & m.multi_button) >= 2 \
					and drive >= m.drive_cost and _cancel_motion_ok(m):
				return m
		for m in character.supers:
			if (btn & m.button) and from_move.cancel_into.has(m.id) and meter >= m.meter_cost and _cancel_motion_ok(m):
				return m
		for m in character.specials:
			if m.drive_cost > 0:
				continue
			if (btn & m.button) and from_move.cancel_into.has(m.id) and _cancel_motion_ok(m):
				return m
	if not allow_normals:
		return null
	var stance := _current_stance(_cancel_frame)
	var fallback: MoveData = null
	for m in character.normals:
		if (btn & m.button) and from_move.cancel_into.has(m.id):
			if m.stance == stance:
				return m
			if fallback == null:
				fallback = m
	return fallback

# --- damage / blocking (called by HitResolver) -----------------------------

## Decide whether this fighter would block `m` given current input, then apply.
## Returns true if the attack was blocked.
func receive_attack(m: MoveData, attacker_facing: int, bonus_hitstun: int = 0) -> bool:
	var blocked := _is_blocking(m, attacker_facing)
	if blocked:
		_apply_block(m, attacker_facing, bonus_hitstun)
	else:
		_apply_hit(m, attacker_facing, bonus_hitstun)
	var stop := m.hitstop
	if not blocked:
		stop += _hitstop_bonus()
	apply_hitstop(stop)
	got_hit.emit(blocked)
	return blocked

## Extra impact freeze (frames) for heavier and counter hits, layered on a move's base
## hitstop so big / counter blows land harder. Read from this victim's just-set context.
func _hitstop_bonus() -> int:
	var b := 0
	match hit_strength:
		1:
			b = 1
		2:
			b = 3
	match last_counter:
		GameConst.Counter.COUNTER:
			b += 3
		GameConst.Counter.PUNISH:
			b += 6
	return b

func _is_blocking(m: MoveData, attacker_facing: int) -> bool:
	if not _can_block():
		return false
	var inp := input_buffer.latest()
	# Must hold away from the attacker. Attacker faces `attacker_facing`; "away" for the
	# defender is the same sign as the attacker's facing (i.e. being pushed back).
	var holding_back := inp.dir_x == attacker_facing
	if not holding_back:
		return false
	var crouch_block := inp.dir_y < 0
	match m.guard:
		GameConst.Guard.MID:
			return true
		GameConst.Guard.LOW:
			return crouch_block
		GameConst.Guard.OVERHEAD:
			return not crouch_block
	return false

func _can_block() -> bool:
	return on_ground and state in [State.IDLE, State.WALK_F, State.WALK_B, State.CROUCH, State.BLOCKSTUN]

func _is_actionable() -> bool:
	return state in [State.IDLE, State.WALK_F, State.WALK_B, State.CROUCH]

func _is_locked_out() -> bool:
	return state in [State.HITSTUN, State.BLOCKSTUN, State.KNOCKDOWN, State.WAKEUP, State.KO, State.INTRO, State.WIN]

func _apply_block(m: MoveData, attacker_facing: int, bonus_hitstun: int = 0) -> void:
	current_move = null
	move_hits_done = 0
	move_hit_cooldown = 0
	_end_combo()   # a block drops any combo this fighter was being hit by
	stun_timer = m.blockstun + bonus_hitstun
	_goto(State.BLOCKSTUN)
	if m.chip > 0:
		_damage(m.chip)
	velocity.x = attacker_facing * (m.knockback * 0.5)
	launched = false

func _apply_hit(m: MoveData, attacker_facing: int, bonus_hitstun: int = 0) -> void:
	var counter := _counter_kind()   # read before current_move is cleared
	# Combo bookkeeping: a hit taken while already stunned/airborne extends the combo,
	# otherwise it starts a fresh one. Damage is then scaled by the combo length (SF6-style).
	var continuing := state == State.HITSTUN or not on_ground or launched
	combo_count = combo_count + 1 if continuing else 1
	if not continuing:
		combo_damage = 0
	current_move = null
	move_hits_done = 0
	move_hit_cooldown = 0
	last_counter = counter
	_record_hit_context(m, attacker_facing)
	# Counter hits force a heavier reaction and add hitstun (a combo window on Punish).
	var bonus_stun := 0
	match counter:
		GameConst.Counter.PUNISH:
			hit_strength = 2
			bonus_stun = PUNISH_BONUS_HITSTUN
		GameConst.Counter.COUNTER:
			hit_strength = maxi(hit_strength, 1)
			bonus_stun = COUNTER_BONUS_HITSTUN
	if counter != GameConst.Counter.NONE:
		countered.emit(counter)
	var dealt := _scaled_damage(m.damage, combo_count)
	combo_damage += dealt
	combo_changed.emit(combo_count, combo_damage)
	_damage(dealt)
	if health <= 0 and not allow_zero_health_hit_reactions:
		return   # KO handled by RoundManager observing health
	if m.launch:
		launched = true
		knockdown_kind = _classify_knockdown(m)
		velocity.y = m.launch_velocity
		velocity.x = attacker_facing * m.knockback
		on_ground = false
		stun_timer = m.hitstun + bonus_stun + bonus_hitstun
		_goto(State.HITSTUN)
	else:
		launched = false
		stun_timer = m.hitstun + bonus_stun + bonus_hitstun
		velocity.x = attacker_facing * m.knockback
		_goto(State.HITSTUN)

## Combo damage scaling: the n-th hit (1-based) of a combo deals COMBO_SCALING[n-1] of its
## listed damage (clamped to the last, smallest entry), so long combos taper instead of
## deleting the health bar. Single hits and short strings (<=3) are unscaled.
func _scaled_damage(base: int, n: int) -> int:
	var idx := clampi(n - 1, 0, COMBO_SCALING.size() - 1)
	return int(round(float(base) * COMBO_SCALING[idx]))

## End the current combo (victim recovered, blocked, was knocked down, or round reset) and
## notify listeners so the HUD combo counter can begin its fade.
func _end_combo() -> void:
	if combo_count == 0 and combo_damage == 0:
		return
	combo_count = 0
	combo_damage = 0
	combo_changed.emit(0, 0)

## Classify how a launching hit knocks the victim down, selecting the knockdown/get-up
## animation: a juggle out of the air, a sweep off the legs, an uppercut launch, or a
## generic heavy slam.
func _classify_knockdown(m: MoveData) -> int:
	if not on_ground:
		return GameConst.Knockdown.AIR
	if m.effective_hit_height() == GameConst.HitHeight.LOW:
		return GameConst.Knockdown.LOW
	if m.launch_velocity >= 9.0:
		return GameConst.Knockdown.UPPER
	return GameConst.Knockdown.HEAVY

## Counter classification from this fighter's state at the instant of being hit: being
## struck during the start-up/active frames of one's own attack is a Counter; during its
## recovery is the harsher Punish Counter. Must be read before current_move is cleared.
func _counter_kind() -> int:
	if state == State.ATTACK and current_move != null:
		if current_move.is_recovering(state_frame):
			return GameConst.Counter.PUNISH
		return GameConst.Counter.COUNTER
	return GameConst.Counter.NONE

func _step_stun() -> void:
	velocity.x *= STUN_FRICTION
	if not on_ground:
		return   # airborne: wait until landing (handled in _apply_physics)
	stun_timer -= 1
	if stun_timer <= 0:
		_end_combo()
		_goto(State.IDLE)

## Capture the context of an incoming hit (strength, height, stance, direction) so the
## rig can pick a matching directional reaction. Read at the moment of impact, before the
## state transition to HITSTUN.
func _record_hit_context(m: MoveData, attacker_facing: int) -> void:
	hit_strength = _strength_of(m)
	hit_height = m.effective_hit_height()
	hit_air = not on_ground
	hit_crouch = on_ground and (state == State.CROUCH or input_buffer.latest().dir_y < 0)
	hit_reaction_clip = m.hit_reaction_clip
	# attacker_facing points from the attacker toward this fighter; if we face the same
	# way, our back is to the attacker -> struck from behind (a cross-up).
	hit_from_back = facing == attacker_facing

## Classify an attack's strength for the hit-reaction animation.
func _strength_of(m: MoveData) -> int:
	if m.kind != GameConst.MoveKind.NORMAL:
		return 2   # specials / supers hit hard
	if m.button & (GameConst.Btn.LP | GameConst.Btn.LK):
		return 0
	if m.button & (GameConst.Btn.MP | GameConst.Btn.MK):
		return 1
	return 2       # HP / HK

func _step_knockdown() -> void:
	velocity.x *= 0.7
	stun_timer -= 1
	if stun_timer <= 0:
		_start_wakeup()

## Begin the get-up. Brief, invulnerable, then back to neutral - the SF6 wake-up beat.
func _start_wakeup() -> void:
	velocity.x = 0
	stun_timer = WAKEUP_TICKS
	_goto(State.WAKEUP)

func _step_wakeup() -> void:
	velocity.x = 0
	stun_timer -= 1
	if stun_timer <= 0:
		knockdown_kind = GameConst.Knockdown.NONE
		_goto(State.IDLE)

# --- physics ---------------------------------------------------------------

func _apply_physics(delta: float) -> void:
	if on_ground and position.y > GROUND_Y + 0.001 and not _scripted_rise_active():
		on_ground = false
	if not on_ground:
		velocity.y -= character.gravity * delta
	position.x += velocity.x * delta
	position.y += velocity.y * delta
	if position.y <= GROUND_Y:
		position.y = GROUND_Y
		var was_air := not on_ground
		on_ground = true
		velocity.y = 0
		if was_air:
			_on_landed()

func _scripted_rise_active() -> bool:
	return state == State.ATTACK and current_move != null and current_move.rises

func _on_landed() -> void:
	match state:
		State.JUMP:
			_goto(State.IDLE)
		State.ATTACK:
			# Landed during an air normal -> recover.
			current_move = null
			_goto(State.IDLE)
		State.HITSTUN:
			if launched:
				launched = false
				stun_timer = KNOCKDOWN_TICKS
				velocity.x = 0
				_end_combo()   # juggle ends when the victim hits the floor
				_goto(State.KNOCKDOWN)

# --- hit / hurt boxes ------------------------------------------------------

## World-space hurtboxes. Empty while knocked down or KO'd (invulnerable).
func hurtboxes() -> Array[AABB]:
	var boxes: Array[AABB] = []
	if state in [State.KNOCKDOWN, State.KO, State.WAKEUP]:
		return boxes
	var crouching := state == State.CROUCH or (current_move != null and current_move.stance == GameConst.Stance.CROUCH and state == State.ATTACK)
	var height := 1.15 if crouching else 1.75
	var center := position + Vector3(0, height * 0.5, 0)
	boxes.append(AABB(center - Vector3(0.42, height * 0.5, 0.35), Vector3(0.84, height, 0.7)))
	return boxes

## The live melee hitbox this tick, or null. Projectiles are handled separately.
func active_hitbox() -> AABB:
	if state != State.ATTACK or current_move == null:
		return AABB()
	if move_hits_done >= current_move.hits or move_hit_cooldown > 0:
		return AABB()
	if current_move.projectile:
		return AABB()
	if not current_move.is_active(state_frame):
		return AABB()
	var off := current_move.hit_offset
	var center := position + Vector3(off.x * active_attack_facing(), off.y, off.z)
	return AABB(center - current_move.hit_size * 0.5, current_move.hit_size)

func has_active_hitbox() -> bool:
	return active_hitbox().size != Vector3.ZERO

func active_attack_facing(target: Fighter = null) -> int:
	if current_move != null and current_move.stance == GameConst.Stance.AIR:
		var t := target if target != null else opponent
		if t != null and is_instance_valid(t) and absf(t.position.x - position.x) > 0.001:
			return 1 if t.position.x >= position.x else -1
	return facing

# --- helpers ---------------------------------------------------------------

func _goto(s: int) -> void:
	if s != state:
		state = s
		state_frame = 0

## Count set bits in a button mask (no native popcount in GDScript). Used to detect a
## two-button Overdrive (EX) press.
func _bit_count(mask: int) -> int:
	var n := 0
	while mask != 0:
		n += mask & 1
		mask >>= 1
	return n

func _damage(amount: int) -> void:
	health = max(0, health - amount)
	health_changed.emit(health, character.max_health)

func _add_meter(amount: int) -> void:
	meter = clamp(meter + amount, 0, character.max_meter)
	meter_changed.emit(meter, character.max_meter)

func gain_meter(amount: int) -> void:
	_add_meter(amount)

# --- drive gauge -----------------------------------------------------------

func _add_drive(amount: int) -> void:
	drive = clampi(drive + amount, 0, character.max_drive)
	drive_changed.emit(drive, character.max_drive)

func _regen_drive() -> void:
	if not active:
		return
	# Burnout: after the gauge empties, Drive regen is suspended for a short window (SF6).
	if _burnout_timer > 0:
		_burnout_timer -= 1
		return
	if drive < character.max_drive:
		_add_drive(character.drive_regen)

## Spend `cost` Drive if affordable; returns whether the spend succeeded. Emptying the gauge
## triggers Burnout (a brief regen pause).
func spend_drive(cost: int) -> bool:
	if drive < cost:
		return false
	_add_drive(-cost)
	if drive <= 0:
		_burnout_timer = BURNOUT_TICKS
	return true

## In Burnout: the Drive gauge is empty and still recovering (no Drive actions available).
func is_burnout() -> bool:
	return _burnout_timer > 0 or drive <= 0

## One-time hitstun/blockstun bonus for the first normal performed out of a Drive Rush,
## consumed on contact (read by HitResolver and passed to the victim).
func drive_rush_hit_bonus() -> int:
	if drive_rush_pending:
		drive_rush_pending = false
		return DRIVE_RUSH_HITSTUN_BONUS
	return 0

func mark_connected(blocked: bool, m: MoveData) -> void:
	move_hits_done += 1
	move_hit_cooldown = m.hit_gap
	var stop := m.hitstop
	if not blocked and opponent != null and is_instance_valid(opponent):
		stop += opponent._hitstop_bonus()   # match the victim's heavier/counter freeze
	hitstop = stop
	var self_push := 0.0
	if blocked:
		self_push = m.pushback_self
	elif opponent != null and is_instance_valid(opponent):
		self_push = m.pushback_self * 0.15
		if absf(opponent.position.x) >= CORNER_PUSHBACK_X:
			self_push = maxf(self_push, m.pushback_self * 0.65)
	position.x -= facing * self_push
	if not blocked:
		_add_meter(m.meter_gain)
	contact.emit(blocked, m)

func apply_hitstop(frames: int) -> void:
	hitstop = max(hitstop, frames)

func set_ko() -> void:
	_goto(State.KO)
	velocity = Vector3.ZERO

func set_win() -> void:
	active = false
	_goto(State.WIN)

func set_intro() -> void:
	_goto(State.INTRO)

func reset_for_round() -> void:
	health = character.max_health
	velocity = Vector3.ZERO
	current_move = null
	move_hits_done = 0
	move_hit_cooldown = 0
	stun_timer = 0
	launched = false
	hitstop = 0
	hit_strength = 0
	hit_height = GameConst.HitHeight.MID
	hit_crouch = false
	hit_air = false
	hit_from_back = false
	hit_reaction_clip = ""
	last_counter = GameConst.Counter.NONE
	knockdown_kind = GameConst.Knockdown.NONE
	drive = character.max_drive
	drive_rush_pending = false
	_dr_carry = 0
	_burnout_timer = 0
	combo_count = 0
	combo_damage = 0
	_clear_cancel_buffer()
	_clear_drc_input_buffer()
	on_ground = true
	position.y = 0
	input_buffer.clear()
	_goto(State.IDLE)
	health_changed.emit(health, character.max_health)
	meter_changed.emit(meter, character.max_meter)
	drive_changed.emit(drive, character.max_drive)
	combo_changed.emit(0, 0)

func is_dead() -> bool:
	return health <= 0
