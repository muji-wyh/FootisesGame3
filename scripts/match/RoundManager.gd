class_name RoundManager
extends Node

## Drives the match flow: intro -> fight -> round end -> next round / match end.
## Owns round timing and scoring; tells the Arena when to simulate. Emits signals the
## HUD listens to. Best-of-three: first side to GameConst.ROUNDS_TO_WIN wins the match.

signal announce(text: String)
signal announce_clear()
signal timer_changed(seconds: int)
signal rounds_changed(p1_wins: int, p2_wins: int)
signal match_over(winner_side: int)

enum Phase { INTRO, FIGHT, ROUND_OVER, MATCH_OVER }

const INTRO_TICKS := 120
const FIGHT_BANNER_TICKS := 45
const ROUND_OVER_TICKS := 150

var arena: Arena
var phase: int = Phase.INTRO
var phase_timer: int = 0
var round_number: int = 1
var p1_wins: int = 0
var p2_wins: int = 0
var time_left_ticks: int = GameConst.ROUND_TIME_SECONDS * GameConst.TICK_RATE
var _round_winner: int = -1
var _deferred_winner_side: int = -1

func start() -> void:
	arena.ko.connect(_on_ko)
	_begin_intro()

func _begin_intro() -> void:
	phase = Phase.INTRO
	phase_timer = INTRO_TICKS
	time_left_ticks = GameConst.ROUND_TIME_SECONDS * GameConst.TICK_RATE
	_round_winner = -1
	_deferred_winner_side = -1
	arena.set_active(false)
	for f in arena.fighters:
		f.set_intro()
	rounds_changed.emit(p1_wins, p2_wins)
	timer_changed.emit(GameConst.ROUND_TIME_SECONDS)
	announce.emit("Round %d" % round_number)

## Called every physics tick by Match.
func tick(delta: float) -> void:
	match phase:
		Phase.INTRO:
			_tick_intro(delta)
		Phase.FIGHT:
			_tick_fight(delta)
		Phase.ROUND_OVER:
			_tick_round_over(delta)
		Phase.MATCH_OVER:
			arena.step_inactive(delta)

func _tick_intro(_delta: float) -> void:
	phase_timer -= 1
	if phase_timer == FIGHT_BANNER_TICKS:
		announce.emit("Fight!")
		arena.set_active(true)
		for f in arena.fighters:
			f._goto(Fighter.State.IDLE)
	if phase_timer <= 0:
		announce_clear.emit()
		phase = Phase.FIGHT

func _tick_fight(delta: float) -> void:
	arena.step(delta)
	time_left_ticks -= 1
	if time_left_ticks % GameConst.TICK_RATE == 0:
		timer_changed.emit(time_left_ticks / GameConst.TICK_RATE)
	if time_left_ticks <= 0 and _round_winner < 0:
		_decide_by_time()

func _tick_round_over(delta: float) -> void:
	arena.step_inactive(delta)
	_finish_deferred_win_if_ready()
	phase_timer -= 1
	if phase_timer <= 0:
		_finish_deferred_win_if_ready(true)
		_advance_after_round()

func _on_ko(loser_side: int) -> void:
	if phase != Phase.FIGHT:
		return
	var f1: Fighter = arena.fighters[0]
	var f2: Fighter = arena.fighters[1]
	if f1.is_dead() and f2.is_dead():
		_round_winner = -1
	else:
		_round_winner = 1 - loser_side
	_end_round()

func _decide_by_time() -> void:
	var f1: Fighter = arena.fighters[0]
	var f2: Fighter = arena.fighters[1]
	if f1.health > f2.health:
		_round_winner = GameConst.Side.P1
	elif f2.health > f1.health:
		_round_winner = GameConst.Side.P2
	else:
		_round_winner = -1
	_end_round()

func _end_round() -> void:
	phase = Phase.ROUND_OVER
	phase_timer = ROUND_OVER_TICKS
	if _round_winner == GameConst.Side.P1:
		p1_wins += 1
	elif _round_winner == GameConst.Side.P2:
		p2_wins += 1
	arena.set_active(false)
	if _round_winner == GameConst.Side.P1 or _round_winner == GameConst.Side.P2:
		var winner: Fighter = arena.fighters[_round_winner]
		var loser: Fighter = arena.fighters[1 - _round_winner]
		if _is_finishing_super(winner):
			_deferred_winner_side = _round_winner
		else:
			winner.set_win()
		loser.set_ko()
	else:
		for f in arena.fighters:
			if f.is_dead():
				f.set_ko()
			else:
				f.velocity = Vector3.ZERO
				f._goto(Fighter.State.IDLE)
	rounds_changed.emit(p1_wins, p2_wins)
	if _round_winner == GameConst.Side.P1 or _round_winner == GameConst.Side.P2:
		var winner: Fighter = arena.fighters[_round_winner]
		announce.emit("%s wins the round" % winner.character.display_name)
	else:
		announce.emit("Draw")

func _is_finishing_super(f: Fighter) -> bool:
	return f.state == Fighter.State.ATTACK and f.current_move != null and f.current_move.kind == GameConst.MoveKind.SUPER

func _finish_deferred_win_if_ready(force: bool = false) -> void:
	if _deferred_winner_side < 0:
		return
	var winner: Fighter = arena.fighters[_deferred_winner_side]
	if force or not _is_finishing_super(winner):
		winner.set_win()
		_deferred_winner_side = -1

func _advance_after_round() -> void:
	if p1_wins >= GameConst.ROUNDS_TO_WIN or p2_wins >= GameConst.ROUNDS_TO_WIN:
		phase = Phase.MATCH_OVER
		var winner_side := GameConst.Side.P1 if p1_wins > p2_wins else GameConst.Side.P2
		announce.emit("%s WINS" % arena.fighters[winner_side].character.display_name)
		match_over.emit(winner_side)
		return
	round_number += 1
	arena.reset_positions()
	for f in arena.fighters:
		f.reset_for_round()
	_begin_intro()
