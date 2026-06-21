class_name FightCamera
extends Camera3D

## Side-view camera that keeps both fighters framed SF6-style. Each visual tick it centres
## on the midpoint and sizes the pull-back to *fit both fighters with a horizontal margin*,
## while anchoring the floor line near the bottom of the screen (so the fighters' feet stay
## put and their heads rise into frame as the camera pulls back).

const FOV := 45.0
const FEET_FRAC := 0.95        # screen fraction (from top) at which the fighters' feet sit
const MARGIN := 0.90           # world metres kept beyond each fighter, horizontally
const MIN_Z := 3.45            # closest pull-in ≈ the round-start framing (most zoomed-in)
const MAX_Z := 4.5             # farthest pull-out (keeps both framed corner-to-corner)
const HEIGHT := 1.0           # camera height (constant; pitch is what tracks the floor)
const AIR_LIFT := 0.45         # how much the camera lifts to follow airborne fighters
const FOLLOW := 0.2

var _base := Vector3(0, HEIGHT, MIN_Z)
var _shake_amp: float = 0.0
var _shake_t: int = 0
var _shake_frames: int = 1

func _ready() -> void:
	fov = FOV
	position = Vector3(0, HEIGHT, MIN_Z)
	_aim(0.0, MIN_Z, HEIGHT)

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
	var lift := clampf(maxf(a.y, b.y) * AIR_LIFT, 0.0, 2.4)
	# Zoom to fit both fighters (plus a margin) across the screen's horizontal half-extent.
	var z := clampf((sep * 0.5 + MARGIN) / _half_width_tan(), MIN_Z, MAX_Z)
	var bound: float = Arena.FIGHT_BOUNDS_HALF_WIDTH - 1.0
	mid_x = clampf(mid_x, -bound, bound)
	_base = _base.lerp(Vector3(mid_x, HEIGHT + lift, z), FOLLOW)
	position = _base + _shake_offset()
	_aim(_base.x, _base.z, _base.y)

## Half of the screen's horizontal extent (in tan units) at the subject plane, accounting for
## the live viewport aspect (vertical FOV is fixed, so width follows the aspect).
func _half_width_tan() -> float:
	var aspect := 16.0 / 9.0
	var vp := get_viewport()
	if vp:
		var s: Vector2 = vp.get_visible_rect().size
		if s.y > 0.0:
			aspect = s.x / s.y
	return tan(deg_to_rad(FOV) * 0.5) * aspect

## Aim so the fighters' feet (world y = 0) sit at FEET_FRAC of the screen height. Solving the
## pitch from that constraint keeps the floor line anchored as z changes: when the camera
## pulls back the heads simply rise into frame, instead of the fighters floating upward.
func _aim(x: float, z: float, cam_y: float) -> void:
	var half := FOV * 0.5
	var feet_deg := -rad_to_deg(atan(cam_y / maxf(0.1, z)))
	var center_deg := half * (2.0 * FEET_FRAC - 1.0) + feet_deg
	var look_y := cam_y + z * tan(deg_to_rad(center_deg))
	look_at_from_position(position, Vector3(x, look_y, 0.0), Vector3.UP)

func _shake_offset() -> Vector3:
	if _shake_t <= 0:
		return Vector3.ZERO
	_shake_t -= 1
	var decay: float = _shake_amp * float(_shake_t) / float(_shake_frames)
	if _shake_t <= 0:
		_shake_amp = 0.0
	return Vector3(randf_range(-decay, decay), randf_range(-decay, decay), 0.0)
