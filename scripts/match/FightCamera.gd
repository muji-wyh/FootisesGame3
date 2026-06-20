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
var _base := Vector3(0, HEIGHT, MIN_Z)
var _shake_amp: float = 0.0
var _shake_t: int = 0
var _shake_frames: int = 1

func _ready() -> void:
	fov = 48.0
	position = Vector3(0, HEIGHT, MIN_Z)
	look_at(Vector3(0, LOOK_HEIGHT, 0), Vector3.UP)

## Request a screen shake (impact feedback). Stronger requests win; decays over `frames`.
func shake(amp: float, frames: int) -> void:
	if amp <= _shake_amp and _shake_t > 0:
		return
	_shake_amp = amp
	_shake_t = frames
	_shake_frames = maxi(1, frames)

func track(a: Vector3, b: Vector3) -> void:
	var mid_x := (a.x + b.x) * 0.5
	var sep: float = absf(a.x - b.x)
	var z := clampf(MIN_Z + sep * SEP_SCALE, MIN_Z, MAX_Z)
	var bound: float = Arena.STAGE_HALF_WIDTH - 2.0
	mid_x = clampf(mid_x, -bound, bound)
	_target = Vector3(mid_x, HEIGHT, z)
	_base = _base.lerp(_target, FOLLOW)
	position = _base + _shake_offset()
	look_at(Vector3(_base.x, LOOK_HEIGHT, 0), Vector3.UP)

func _shake_offset() -> Vector3:
	if _shake_t <= 0:
		return Vector3.ZERO
	_shake_t -= 1
	var decay: float = _shake_amp * float(_shake_t) / float(_shake_frames)
	if _shake_t <= 0:
		_shake_amp = 0.0
	return Vector3(randf_range(-decay, decay), randf_range(-decay, decay), 0.0)
