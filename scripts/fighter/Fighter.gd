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
signal move_started(move: MoveData)
signal contact(blocked: bool, move: MoveData)   # this fighter connected an attack
signal got_hit(blocked: bool)                    # this fighter was hit

enum State { INTRO, IDLE, WALK_F, WALK_B, CROUCH, JUMP, ATTACK, HITSTUN, BLOCKSTUN, KNOCKDOWN, KO, WIN }

const GROUND_Y := 0.0
const PUSHBOX_HALF := 0.42
const STUN_FRICTION := 0.82

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

# Combat bookkeeping
var current_move: MoveData = null
var move_connected: bool = false
var stun_timer: int = 0
var launched: bool = false
var hitstop: int = 0
var input_buffer := InputBuffer.new()

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
	if hitstop > 0:
		hitstop -= 1
		return
	state_frame += 1
	var inp := input_buffer.latest()
	match state:
		State.IDLE, State.WALK_F, State.WALK_B, State.CROUCH:
			_step_neutral(inp)
		State.JUMP:
			_step_air(inp)
		State.ATTACK:
			_step_attack(inp)
		State.HITSTUN, State.BLOCKSTUN:
			_step_stun()
		State.KNOCKDOWN:
			_step_knockdown()
		State.KO:
			velocity.x = 0
		State.INTRO, State.WIN:
			velocity = Vector3.ZERO
	_apply_physics(delta)

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
	var move := _select_move(inp)
	if move:
		_start_move(move)
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

func _step_air(_inp: InputFrame) -> void:
	pass   # no air actions in the slice; gravity handled in _apply_physics

# --- attacks ---------------------------------------------------------------

func _select_move(inp: InputFrame) -> MoveData:
	if inp.pressed == 0 or not on_ground:
		return null
	# Supers first (require meter + motion), then specials, then normals.
	for m in character.supers:
		if (inp.pressed & m.button) and meter >= m.meter_cost and _motion_ok(m):
			return m
	for m in character.specials:
		if (inp.pressed & m.button) and _motion_ok(m):
			return m
	var crouching := inp.dir_y < 0
	var fallback: MoveData = null
	for m in character.normals:
		if inp.pressed & m.button:
			if m.crouching == crouching:
				return m
			if fallback == null:
				fallback = m
	return fallback

func _motion_ok(m: MoveData) -> bool:
	if m.motion.is_empty():
		return true
	return MotionParser.completed(input_buffer, facing, m.motion)

func _start_move(m: MoveData) -> void:
	current_move = m
	move_connected = false
	if m.kind == GameConst.MoveKind.SUPER:
		_add_meter(-m.meter_cost)
	_goto(State.ATTACK)
	velocity.x = 0
	move_started.emit(m)

func _step_attack(inp: InputFrame) -> void:
	var m := current_move
	if m == null:
		_goto(State.IDLE)
		return
	# Lunge / advance during start-up + active.
	if m.advance > 0.0 and state_frame < m.startup + m.active:
		velocity.x = facing * m.advance
	else:
		velocity.x = 0
	# Spawn a projectile on the first active frame.
	if m.projectile and state_frame == m.startup:
		pending_projectiles.append(m)
	# Cancel into a follow-up on hit (combos) once this move has connected.
	if move_connected and not m.cancel_into.is_empty() and m.is_recovering(state_frame):
		var nxt := _select_cancel(inp, m)
		if nxt:
			_start_move(nxt)
			return
	if state_frame >= m.total_frames():
		current_move = null
		_goto(State.IDLE)

func _select_cancel(inp: InputFrame, from_move: MoveData) -> MoveData:
	if inp.pressed == 0:
		return null
	var candidate := _select_move(inp)
	if candidate and from_move.cancel_into.has(candidate.id):
		return candidate
	return null

# --- damage / blocking (called by HitResolver) -----------------------------

## Decide whether this fighter would block `m` given current input, then apply.
## Returns true if the attack was blocked.
func receive_attack(m: MoveData, attacker_facing: int) -> bool:
	var blocked := _is_blocking(m, attacker_facing)
	if blocked:
		_apply_block(m, attacker_facing)
	else:
		_apply_hit(m, attacker_facing)
	apply_hitstop(m.hitstop)
	got_hit.emit(blocked)
	return blocked

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
	return state in [State.HITSTUN, State.BLOCKSTUN, State.KNOCKDOWN, State.KO, State.INTRO, State.WIN]

func _apply_block(m: MoveData, attacker_facing: int) -> void:
	current_move = null
	move_connected = false
	stun_timer = m.blockstun
	_goto(State.BLOCKSTUN)
	if m.chip > 0:
		_damage(m.chip)
	velocity.x = attacker_facing * (m.knockback * 0.5)
	launched = false

func _apply_hit(m: MoveData, attacker_facing: int) -> void:
	current_move = null
	move_connected = false
	_damage(m.damage)
	if health <= 0:
		return   # KO handled by RoundManager observing health
	if m.launch:
		launched = true
		velocity.y = m.launch_velocity
		velocity.x = attacker_facing * m.knockback
		on_ground = false
		stun_timer = m.hitstun
		_goto(State.HITSTUN)
	else:
		launched = false
		stun_timer = m.hitstun
		velocity.x = attacker_facing * m.knockback
		_goto(State.HITSTUN)

func _step_stun() -> void:
	velocity.x *= STUN_FRICTION
	if not on_ground:
		return   # airborne: wait until landing (handled in _apply_physics)
	stun_timer -= 1
	if stun_timer <= 0:
		_goto(State.IDLE)

func _step_knockdown() -> void:
	velocity.x *= 0.7
	stun_timer -= 1
	if stun_timer <= 0:
		_goto(State.IDLE)

# --- physics ---------------------------------------------------------------

func _apply_physics(delta: float) -> void:
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

func _on_landed() -> void:
	match state:
		State.JUMP:
			_goto(State.IDLE)
		State.HITSTUN:
			if launched:
				launched = false
				stun_timer = 24
				velocity.x = 0
				_goto(State.KNOCKDOWN)

# --- hit / hurt boxes ------------------------------------------------------

## World-space hurtboxes. Empty while knocked down or KO'd (invulnerable).
func hurtboxes() -> Array[AABB]:
	var boxes: Array[AABB] = []
	if state in [State.KNOCKDOWN, State.KO]:
		return boxes
	var crouching := state == State.CROUCH or (current_move != null and current_move.crouching and state == State.ATTACK)
	var height := 1.15 if crouching else 1.75
	var center := position + Vector3(0, height * 0.5, 0)
	boxes.append(AABB(center - Vector3(0.42, height * 0.5, 0.35), Vector3(0.84, height, 0.7)))
	return boxes

## The live melee hitbox this tick, or null. Projectiles are handled separately.
func active_hitbox() -> AABB:
	if state != State.ATTACK or current_move == null or move_connected:
		return AABB()
	if current_move.projectile:
		return AABB()
	if not current_move.is_active(state_frame):
		return AABB()
	var off := current_move.hit_offset
	var center := position + Vector3(off.x * facing, off.y, off.z)
	return AABB(center - current_move.hit_size * 0.5, current_move.hit_size)

func has_active_hitbox() -> bool:
	return active_hitbox().size != Vector3.ZERO

# --- helpers ---------------------------------------------------------------

func _goto(s: int) -> void:
	if s != state:
		state = s
		state_frame = 0

func _damage(amount: int) -> void:
	health = max(0, health - amount)
	health_changed.emit(health, character.max_health)

func _add_meter(amount: int) -> void:
	meter = clamp(meter + amount, 0, character.max_meter)
	meter_changed.emit(meter, character.max_meter)

func gain_meter(amount: int) -> void:
	_add_meter(amount)

func mark_connected(blocked: bool, m: MoveData) -> void:
	move_connected = true
	hitstop = m.hitstop
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

func is_dead() -> bool:
	return health <= 0
