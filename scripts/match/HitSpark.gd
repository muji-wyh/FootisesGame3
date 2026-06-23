class_name HitSpark
extends Node3D

## A short-lived impact flash spawned at the contact point of a hit: an emissive core that
## pops outward plus an expanding shockwave ring, both fading out. Bigger / brighter on
## heavy and counter hits. Purely cosmetic - it reads Fighter state via the spawner and
## frees itself, so it never touches the deterministic combat sim.

const LIFE := 0.16   # seconds
const CORE_RADIUS := 0.11
const CORE_HEIGHT := 0.22
const RING_INNER_RADIUS := 0.12
const RING_OUTER_RADIUS := 0.18
const CORE_SCALE_START := 0.25
const CORE_SCALE_END := 1.10
const RING_SCALE_START := 0.45
const RING_SCALE_END := 1.70

var _t: float = 0.0
var _scale: float = 1.0
var _core_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _ring: MeshInstance3D

func setup(color: Color, spark_scale: float) -> void:
	_scale = spark_scale

	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = CORE_RADIUS
	sphere.height = CORE_HEIGHT
	sphere.radial_segments = 8
	sphere.rings = 4
	core.mesh = sphere
	_core_mat = _flash_material(color, 5.0)
	core.material_override = _core_mat
	add_child(core)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RING_INNER_RADIUS
	torus.outer_radius = RING_OUTER_RADIUS
	_ring.mesh = torus
	_ring.rotation_degrees = Vector3(90, 0, 0)   # face the side-view camera
	_ring_mat = _flash_material(color.lerp(Color.WHITE, 0.3), 3.0)
	_ring.material_override = _ring_mat
	add_child(_ring)

func _process(delta: float) -> void:
	_t += delta
	var p: float = clampf(_t / LIFE, 0.0, 1.0)
	var fade: float = 1.0 - p
	# Core pops out fast then fades.
	var s: float = _scale * lerpf(CORE_SCALE_START, CORE_SCALE_END, p)
	scale = Vector3(s, s, s)
	_core_mat.albedo_color.a = fade
	_core_mat.emission_energy_multiplier = 5.0 * fade
	# Ring expands faster as a shockwave.
	var rs: float = lerpf(RING_SCALE_START, RING_SCALE_END, p)
	_ring.scale = Vector3(rs, rs, rs)
	_ring_mat.albedo_color.a = fade * 0.8
	if _t >= LIFE:
		queue_free()

func _flash_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat
