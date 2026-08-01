class_name HitSpark
extends Node3D

## A short-lived impact flash spawned at the contact point of a hit: an emissive core that
## pops outward plus an expanding shockwave ring, both fading out. Bigger / brighter on
## heavy and counter hits. Purely cosmetic - it reads Fighter state via the spawner and
## frees itself, so it never touches the deterministic combat sim.

const LIFE := 0.34   # seconds
const CORE_RADIUS := 0.11
const CORE_HEIGHT := 0.22
const RING_INNER_RADIUS := 0.12
const RING_OUTER_RADIUS := 0.18
const CORE_SCALE_START := 0.25
const CORE_SCALE_END := 1.10
const RING_SCALE_START := 0.65
const RING_SCALE_END := 2.20
const FX_QUAD_SIZE := 1.35
const FX_SCALE_START := 0.90
const FX_SCALE_END := 2.35
const VFX_SCENE_LIFE := 0.65
const VFX_SCENE_SCALE := 0.18

var _t: float = 0.0
var _scale: float = 1.0
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _fx_mat: StandardMaterial3D
var _fx_quad: MeshInstance3D
var _fx_scene: Node3D

func setup(color: Color, spark_scale: float, fx_path: String = "") -> void:
	_scale = spark_scale

	_core = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = CORE_RADIUS
	sphere.height = CORE_HEIGHT
	sphere.radial_segments = 8
	sphere.rings = 4
	_core.mesh = sphere
	_core_mat = _flash_material(color, 5.0)
	_core.material_override = _core_mat
	add_child(_core)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RING_INNER_RADIUS
	torus.outer_radius = RING_OUTER_RADIUS
	_ring.mesh = torus
	_ring.rotation_degrees = Vector3(90, 0, 0)   # face the side-view camera
	_ring_mat = _flash_material(color.lerp(Color.WHITE, 0.3), 3.0)
	_ring.material_override = _ring_mat
	add_child(_ring)

	if fx_path != "" and ResourceLoader.exists(fx_path):
		var fx_resource := load(fx_path)
		if fx_resource is PackedScene:
			_fx_scene = (fx_resource as PackedScene).instantiate() as Node3D
			if _fx_scene != null:
				_fx_scene.scale = Vector3.ONE * spark_scale * VFX_SCENE_SCALE
				add_child(_fx_scene)
		elif fx_resource is Texture2D:
			_fx_quad = MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(FX_QUAD_SIZE, FX_QUAD_SIZE)
			_fx_quad.mesh = quad
			_fx_quad.rotation_degrees = Vector3(0, 0, 25)
			_fx_mat = _flash_material(color.lerp(Color.WHITE, 0.45), 4.0)
			_fx_mat.albedo_texture = fx_resource as Texture2D
			_fx_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			_fx_quad.material_override = _fx_mat
			add_child(_fx_quad)

func _process(delta: float) -> void:
	_t += delta
	var p: float = clampf(_t / LIFE, 0.0, 1.0)
	var fade: float = 1.0 - p
	# Core pops out fast then fades.
	var s: float = _scale * lerpf(CORE_SCALE_START, CORE_SCALE_END, p)
	_core.scale = Vector3(s, s, s)
	_core_mat.albedo_color.a = fade
	_core_mat.emission_energy_multiplier = 5.0 * fade
	# Ring expands faster as a shockwave.
	var rs: float = _scale * lerpf(RING_SCALE_START, RING_SCALE_END, p)
	_ring.scale = Vector3(rs, rs, rs)
	_ring_mat.albedo_color.a = fade * 0.8
	if _fx_quad != null:
		var fs: float = _scale * lerpf(FX_SCALE_START, FX_SCALE_END, p)
		_fx_quad.scale = Vector3(fs, fs, fs)
		_fx_mat.albedo_color.a = minf(1.0, fade * 1.25)
		_fx_mat.emission_energy_multiplier = 4.0 * fade
	var total_life := VFX_SCENE_LIFE if _fx_scene != null else LIFE
	if _t >= total_life:
		queue_free()

func _flash_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.no_depth_test = true
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat
