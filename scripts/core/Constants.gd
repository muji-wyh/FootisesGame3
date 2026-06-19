class_name GameConst
extends RefCounted

## Shared constants and enums for Brawl Arena.
## Fighting games must be deterministic: all gameplay runs at this fixed tick rate
## inside _physics_process. Timers are counted in TICKS (frames), never seconds.

const TICK_RATE: int = 60
const ROUND_TIME_SECONDS: int = 60
const ROUNDS_TO_WIN: int = 2

## Attack button bit flags. A 4-button layout: two punches, two kicks.
## (Named "Btn" because "Button" is a built-in Godot UI class.)
enum Btn {
	LP = 1,  # light punch
	HP = 2,  # heavy punch
	LK = 4,  # light kick
	HK = 8,  # heavy kick
}

## Maps each attack button to the suffix of its input action (e.g. LP -> "p1_lp").
## Defined here (same class as Btn) so the enum keys constant-fold correctly.
const BUTTON_SUFFIX := {
	Btn.LP: "_lp",
	Btn.HP: "_hp",
	Btn.LK: "_lk",
	Btn.HK: "_hk",
}

## How an attack must be guarded by the defender.
enum Guard {
	MID,       # block by holding back (standing OR crouching)
	LOW,       # block only by holding down-back (crouch block)
	OVERHEAD,  # block only by holding back while standing
}

## Move categories, used for cancel rules and meter.
enum MoveKind {
	NORMAL,
	SPECIAL,
	SUPER,
}

## Match modes.
enum Mode {
	LOCAL_2P,
	VS_CPU,
}

## Which side a fighter starts on.
enum Side {
	P1 = 0,
	P2 = 1,
}
