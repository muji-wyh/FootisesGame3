class_name FightCamera
extends Camera3D

## Side-view camera that keeps both fighters framed. Each visual tick it centres on the
## midpoint between the fighters and pulls back as they separate - the classic 2D fighter
## "rubber-band" framing.

const MIN_Z := 6.5
const MAX_Z := 11.0
const SEP_SCALE := 0.6
const HEIGHT := 1.7
const LOOK_HEIGHT := 1.25
const FOLLOW := 0.18

var _target := Vector3(0, HEIGHT, MIN_Z)

func _ready() -> void:
	fov = 48.0
	position = Vector3(0, HEIGHT, MIN_Z)
	look_at(Vector3(0, LOOK_HEIGHT, 0), Vector3.UP)

func track(a: Vector3, b: Vector3) -> void:
	var mid_x := (a.x + b.x) * 0.5
	var sep: float = absf(a.x - b.x)
	var z := clampf(MIN_Z + sep * SEP_SCALE, MIN_Z, MAX_Z)
	var bound: float = Arena.STAGE_HALF_WIDTH - 2.0
	mid_x = clampf(mid_x, -bound, bound)
	_target = Vector3(mid_x, HEIGHT, z)
	position = position.lerp(_target, FOLLOW)
	look_at(Vector3(position.x, LOOK_HEIGHT, 0), Vector3.UP)
