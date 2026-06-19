class_name CharacterData
extends Resource

## A playable fighter's stats and move list. Built by CharacterLibrary (in code) so the
## compiler validates everything; could also be authored as a .tres later.

@export var id: String = ""
@export var display_name: String = ""
@export var color: Color = Color(0.8, 0.8, 0.8)
@export var accent: Color = Color(0.2, 0.2, 0.2)
@export var blurb: String = ""

## Movement / vitals (units are metres and metres-per-second; gravity m/s^2).
@export var max_health: int = 1000
@export var max_meter: int = 100
@export var walk_speed: float = 3.2
@export var back_speed: float = 2.6
@export var jump_velocity: float = 9.5
@export var jump_h_speed: float = 3.2
@export var gravity: float = 28.0

## Optional model-backed rig. If model_path points to an importable scene (FBX/glTF),
## MatchScene builds an AnimatedFighterRig; otherwise it uses the procedural blockout.
## These default to the Kubold/Maskman orientation (3ds Max Z-up -> stand upright).
@export var model_path: String = ""
@export var model_euler_deg: Vector3 = Vector3.ZERO
@export var model_scale: float = 1.0
@export var model_face_deg: float = 0.0   # extra yaw so the model faces its opponent

## Move tables, filled via add_move().
var moves: Dictionary = {}            # id -> MoveData
var normals: Array[MoveData] = []     # button-triggered
var specials: Array[MoveData] = []    # motion + button
var supers: Array[MoveData] = []      # motion + button, costs meter

func add_move(m: MoveData) -> CharacterData:
	moves[m.id] = m
	match m.kind:
		GameConst.MoveKind.NORMAL:
			normals.append(m)
		GameConst.MoveKind.SPECIAL:
			specials.append(m)
		GameConst.MoveKind.SUPER:
			supers.append(m)
	return self

func get_move(move_id: String) -> MoveData:
	return moves.get(move_id, null)
