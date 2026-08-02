class_name FrameMeter
extends Control

## SF6-style frame meter for training mode: one cell per simulation tick per fighter, coloured
## by what that fighter's action was doing on that tick, with each segment's length printed on
## the strip and startup / total / advantage summarised beside it.
##
## Pure observer. It only reads Fighter state after the tick has been resolved, so it can never
## change a combat result -- a meter that perturbs the thing it measures is worse than none.
##
## Cell counts line up 1:1 with the tuning data in characters/<id>/<id>.gd: a move with
## "startup": 11 draws 11 startup cells, because the hitbox goes live on state_frame 11 and the
## press tick is state_frame 0. Hitstop is drawn in its own colour rather than folded into the
## active run: those ticks are real time both players spend frozen, but no move frame advanced
## during them, so counting them would report a 35F move as 50F.
##
## Neutral ticks are not recorded. The strip is a record of one exchange -- it fills left to
## right while anyone is acting, freezes when everyone is actionable again so the numbers can
## still be read, and is wiped by the next action.

enum Phase { NONE, STARTUP, ACTIVE, RECOVERY, STUN, FREEZE }

const CAPACITY := 72                    ## ticks one exchange can show before it stops filling
const CELL := Vector2(15.0, 15.0)
const CELL_STEP := 17.0
const ORIGIN := Vector2(28.0, 634.0)    ## top-left of P1's strip in the 1280x720 viewport
const ROW_STEP := 18.0
const LABEL_MIN_CELLS := 2              ## one cell has no room for its number

const PHASE_COLORS := [
	Color(0.10, 0.11, 0.14),  # NONE      - idle / actionable
	Color(0.20, 0.85, 0.55),  # STARTUP   - green
	Color(0.93, 0.16, 0.40),  # ACTIVE    - magenta
	Color(0.16, 0.58, 0.90),  # RECOVERY  - blue
	Color(0.95, 0.78, 0.20),  # STUN      - amber (hitstun / blockstun / knockdown)
	Color(0.72, 0.74, 0.80),  # FREEZE    - grey (hitstop: real time, but no frame advanced)
]

var _cells: Array = [PackedByteArray(), PackedByteArray()]
var _prev: Array = [Phase.NONE, Phase.NONE]
var _prev_move: Array = [null, null]
var _prev_frame: Array = [-1, -1]
var _counts: Array = [[0, 0, 0], [0, 0, 0]]   # startup / active / recovery of the live action
var _startup_f: Array = [0, 0]
var _total_f: Array = [0, 0]
var _adv: Array = [0, 0]
var _adv_shown: Array = [false, false]
var _free_tick: Array = [0, 0]
var _attacker: int = -1
var _recording: bool = false
var _tick: int = 0

func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func reset() -> void:
	_cells = [PackedByteArray(), PackedByteArray()]
	_prev = [Phase.NONE, Phase.NONE]
	_prev_move = [null, null]
	_prev_frame = [-1, -1]
	_counts = [[0, 0, 0], [0, 0, 0]]
	_startup_f = [0, 0]
	_total_f = [0, 0]
	_adv = [0, 0]
	_adv_shown = [false, false]
	_free_tick = [0, 0]
	_attacker = -1
	_recording = false
	_tick = 0
	queue_redraw()

## Record one simulation tick. Call after the arena has stepped, so the cell describes the
## state the fighters were actually in when hits were resolved.
func sample(fighters: Array) -> void:
	_tick += 1
	var phases := [_phase(fighters[0]), _phase(fighters[1])]
	# The strip records one exchange, not a rolling window: it fills left to right and then stays
	# put so the numbers can still be read after the action. Someone acting again once both are
	# neutral starts a new exchange, which wipes it and refills from the left.
	var acting: bool = phases[0] != Phase.NONE or phases[1] != Phase.NONE
	if acting and not _recording:
		_cells = [PackedByteArray(), PackedByteArray()]
	_recording = acting
	for i in range(2):
		var f: Fighter = fighters[i]
		var ph: int = phases[i]
		# Hitstop returns from advance() before touching state_frame, so an unchanged frame is
		# exactly "this fighter did not advance this tick". Every tick still gets a cell, or the
		# two rows would drift apart and could no longer be read as one timeline.
		var advanced: bool = f.state_frame != _prev_frame[i]
		_prev_frame[i] = f.state_frame
		var mv: MoveData = f.current_move if f.state == Fighter.State.ATTACK else null
		# A cancel swaps moves without passing through NONE, so close the old action here.
		if mv != _prev_move[i] and _prev_move[i] != null:
			_publish(i)
		if ph == Phase.NONE and _prev[i] != Phase.NONE:
			_free_tick[i] = _tick
			if _prev[i] != Phase.STUN:
				_publish(i)
		# Startup is final the moment the hitbox goes live, so report it then rather than making
		# the reader wait for the whole move to finish.
		if ph == Phase.ACTIVE and _prev[i] != Phase.ACTIVE:
			_startup_f[i] = _counts[i][0]
		if advanced and (ph == Phase.STARTUP or ph == Phase.ACTIVE or ph == Phase.RECOVERY):
			var c: Array = _counts[i]
			c[ph - 1] += 1
		if ph == Phase.STUN and _prev[i] != Phase.STUN:
			var atk := 1 - i
			_attacker = atk
			_adv_shown[atk] = false
			# A fireball owner may already be idle when it connects; that is their free tick.
			if phases[atk] == Phase.NONE:
				_free_tick[atk] = _tick
		_prev[i] = ph
		_prev_move[i] = mv
		var row: PackedByteArray = _cells[i]
		# Once the strip is full the exchange has outrun the display; keep the readable prefix
		# rather than scrolling, and let the next exchange start clean.
		if acting and row.size() < CAPACITY:
			row.append(Phase.FREEZE if (not advanced and ph != Phase.NONE) else ph)
			_cells[i] = row
	if _attacker >= 0 and phases[0] == Phase.NONE and phases[1] == Phase.NONE:
		var d := 1 - _attacker
		_adv[_attacker] = _free_tick[d] - _free_tick[_attacker]
		_adv_shown[_attacker] = true
		_attacker = -1
	queue_redraw()

func _phase(f: Fighter) -> int:
	if f.state == Fighter.State.ATTACK and f.current_move != null:
		var m := f.current_move
		if m.is_active(f.state_frame):
			return Phase.ACTIVE
		return Phase.STARTUP if f.state_frame < m.startup else Phase.RECOVERY
	if f.state in [Fighter.State.HITSTUN, Fighter.State.BLOCKSTUN,
			Fighter.State.KNOCKDOWN, Fighter.State.WAKEUP]:
		return Phase.STUN
	return Phase.NONE

func _publish(side: int) -> void:
	var c: Array = _counts[side]
	var total: int = c[0] + c[1] + c[2]
	if total > 0:
		_startup_f[side] = c[0]
		_total_f[side] = total
	_counts[side] = [0, 0, 0]

# --- readouts (also the test surface) --------------------------------------

func phase_count(side: int, phase: int) -> int:
	var row: PackedByteArray = _cells[side]
	var n := 0
	for k in range(row.size()):
		if row[k] == phase:
			n += 1
	return n

func cell_count(side: int) -> int:
	var row: PackedByteArray = _cells[side]
	return row.size()

func startup_frames(side: int) -> int:	return _startup_f[side]

func total_frames(side: int) -> int:
	return _total_f[side]

func has_advantage(side: int) -> bool:
	return _adv_shown[side]

func advantage(side: int) -> int:
	return _adv[side]

# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var strip := CAPACITY * CELL_STEP
	draw_rect(Rect2(ORIGIN - Vector2(12.0, 28.0),
		Vector2(strip + 24.0, ROW_STEP + CELL.y + 62.0)), Color(0.0, 0.0, 0.0, 0.55))
	for i in range(2):
		var top: float = ORIGIN.y + float(i) * ROW_STEP
		var row: PackedByteArray = _cells[i]
		for k in range(CAPACITY):
			draw_rect(Rect2(Vector2(ORIGIN.x + k * CELL_STEP, top), CELL), PHASE_COLORS[Phase.NONE])
		for k in range(row.size()):
			if row[k] != Phase.NONE:
				draw_rect(Rect2(Vector2(ORIGIN.x + k * CELL_STEP, top), CELL), PHASE_COLORS[row[k]])
		_draw_segment_labels(font, row, top)
		var ty: float = top - 8.0 if i == 0 else top + CELL.y + 20.0
		var head := "Startup %s / Total %s / Advantage %s" % [
			_fmt(_startup_f[i]), _fmt(_total_f[i]),
			("%+d" % _adv[i]) if _adv_shown[i] else "--"]
		draw_string(font, Vector2(ORIGIN.x, ty), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(0.86, 0.93, 1.0))
		draw_string(font, Vector2(ORIGIN.x, ty), "P%d" % (i + 1), HORIZONTAL_ALIGNMENT_RIGHT,
			strip, 16, Color(0.86, 0.93, 1.0))

## Each phase run is labelled with its own length, right-aligned at the run's end, exactly as
## the strip reads: 11 green cells marked "11" is the same 11 the character data declares.
func _draw_segment_labels(font: Font, row: PackedByteArray, top: float) -> void:
	var k := 0
	while k < row.size():
		var j := k
		while j < row.size() and row[j] == row[k]:
			j += 1
		var run := j - k
		if row[k] != Phase.NONE and row[k] != Phase.FREEZE and run >= LABEL_MIN_CELLS:
			draw_string(font, Vector2(ORIGIN.x + k * CELL_STEP, top + CELL.y - 3.0), str(run),
				HORIZONTAL_ALIGNMENT_RIGHT, run * CELL_STEP - 3.0, 12, Color.WHITE)
		k = j

func _fmt(frames: int) -> String:
	return "--" if frames <= 0 else "%dF" % frames
