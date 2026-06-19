class_name MoveData
extends Resource

## A single attacking move: its trigger, frame data, hitbox, and on-hit effects.
## All timing is in TICKS (60 per second). This is the data designers tune to balance
## the game; keeping it in a Resource means no code changes are needed to rebalance.

@export var id: String = ""
@export var display_name: String = ""
@export var kind: int = GameConst.MoveKind.NORMAL

## Trigger. Normals fire on a button press; specials/supers also require `motion`.
@export var button: int = GameConst.Btn.LP
@export var motion: Array[int] = []          # numpad motion, e.g. MotionParser.QCF
@export var crouching: bool = false          # must be crouching to perform
@export var meter_cost: int = 0              # meter required (supers)

## Frame data (ticks).
@export var startup: int = 4                 # frames before the hitbox appears
@export var active: int = 3                  # frames the hitbox is live
@export var recovery: int = 10               # frames after, locked in place

## On contact.
@export var damage: int = 40
@export var hitstun: int = 16                # defender stun on hit
@export var blockstun: int = 10              # defender stun on block
@export var chip: int = 0                    # damage dealt even on block
@export var hitstop: int = 8                 # impact freeze for both fighters
@export var guard: int = GameConst.Guard.MID
@export var knockback: float = 2.0           # horizontal pushback applied to victim
@export var pushback_self: float = 0.4       # pushback applied to attacker on block
@export var advance: float = 0.0             # forward self-movement while performing (lunges)
@export var launch: bool = false             # sends victim airborne (juggle)
@export var launch_velocity: float = 7.0
@export var meter_gain: int = 8              # attacker meter gained on hit

## Multi-hit: a move can connect `hits` times, with `hit_gap` ticks between connections.
@export var hits: int = 1
@export var hit_gap: int = 8

## Optional sound effect name (in AudioManager) played when the move starts; "" -> whoosh.
@export var sfx: String = ""

## Optional animation clip name (Kubold) for the model-backed rig; "" -> a default.
@export var anim_clip: String = ""

## Hitbox geometry, facing-relative (+x points toward the opponent). Live during the
## active window. Expressed as a centre offset and half-extents-ish size box.
@export var hit_offset: Vector3 = Vector3(0.9, 1.0, 0.0)
@export var hit_size: Vector3 = Vector3(0.9, 0.5, 0.7)

## Moves this can be cancelled into on hit/block (enables combos).
@export var cancel_into: Array[String] = []

## Projectile: if true, instead of a melee hitbox the move spawns a travelling shot.
@export var projectile: bool = false
@export var projectile_speed: float = 7.0
@export var projectile_life: int = 90

## Presentation hints for the procedural rig.
@export var anim_limb: String = "arm_r"      # arm_r, arm_l, leg_r, leg_l
@export var anim_extend: float = 0.6

func total_frames() -> int:
	return startup + active + recovery

func is_active(state_frame: int) -> bool:
	return state_frame >= startup and state_frame < startup + active

func is_recovering(state_frame: int) -> bool:
	return state_frame >= startup + active
