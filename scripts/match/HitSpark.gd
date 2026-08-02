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
const RING_RINGS := 16
const RING_SEGMENTS := 8

## Every spark has the same two meshes -- only node scale and material colour differ -- so they
## are built once and shared. Building them per spark regenerated the torus on the main thread on
## the frame the hit connects, which cost ~100ms in the Web build and read as dropped frames.
## TorusMesh also defaults to a 64x32 tessellation, far more than this thumb-sized fading ring
## needs; the sphere was already cut down to 8x4 for the same reason.
static var _core_mesh: SphereMesh
static var _ring_mesh: TorusMesh

static func core_mesh() -> SphereMesh:
	if _core_mesh == null:
		_core_mesh = SphereMesh.new()
		_core_mesh.radius = CORE_RADIUS
		_core_mesh.height = CORE_HEIGHT
		_core_mesh.radial_segments = 8
		_core_mesh.rings = 4
	return _core_mesh

static func ring_mesh() -> TorusMesh:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = RING_INNER_RADIUS
		_ring_mesh.outer_radius = RING_OUTER_RADIUS
		_ring_mesh.rings = RING_RINGS
		_ring_mesh.ring_segments = RING_SEGMENTS
	return _ring_mesh

var _t: float = 0.0
var _scale: float = 1.0
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _fx_mat: StandardMaterial3D
var _fx_quad: MeshInstance3D
var _fx_scene: Node3D
var _fx_path: String = ""

## Instancing one of the particle VFX costs ~80ms in the Web build, and it lands on the frame
## the hit connects, so every single hit read as a run of dropped frames. The instances are
## interchangeable between hits, so keep them and restart them instead of building new ones.
## MatchScene owns the lifetime and clears this when the match tears down.
static var _fx_pool := {}   # scene path -> Array[Node3D] of idle instances

static func _take_fx(path: String, scene: PackedScene) -> Node3D:
	var idle: Array = _fx_pool.get(path, [])
	if not idle.is_empty():
		var pooled: Node3D = idle.pop_back()
		_restart_particles(pooled)
		return pooled
	return scene.instantiate() as Node3D

static func _restart_particles(node: Node) -> void:
	if node is GPUParticles3D:
		(node as GPUParticles3D).restart()
	for child in node.get_children():
		_restart_particles(child)

## Free every idle instance. Pooled nodes sit outside the tree, so without this they would
## outlive the match that made them.
static func clear_fx_pool() -> void:
	for path in _fx_pool:
		for node in _fx_pool[path]:
			node.free()
	_fx_pool.clear()

static func fx_pool_size() -> int:
	var total := 0
	for path in _fx_pool:
		total += (_fx_pool[path] as Array).size()
	return total

func setup(color: Color, spark_scale: float, fx_path: String = "") -> void:
	_scale = spark_scale

	_core = MeshInstance3D.new()
	_core.mesh = core_mesh()
	_core_mat = _flash_material(color, 5.0)
	_core.material_override = _core_mat
	add_child(_core)

	_ring = MeshInstance3D.new()
	_ring.mesh = ring_mesh()
	_ring.rotation_degrees = Vector3(90, 0, 0)   # face the side-view camera
	_ring_mat = _flash_material(color.lerp(Color.WHITE, 0.3), 3.0)
	_ring.material_override = _ring_mat
	add_child(_ring)

	if fx_path != "" and ResourceLoader.exists(fx_path):
		var fx_resource := load(fx_path)
		if fx_resource is PackedScene:
			_fx_scene = _take_fx(fx_path, fx_resource as PackedScene)
			if _fx_scene != null:
				_fx_path = fx_path
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
		_release_fx()
		queue_free()

## Hand the particle instance back before this spark is destroyed, so the next hit can reuse it.
func _exit_tree() -> void:
	_release_fx()

func _release_fx() -> void:
	if _fx_scene == null:
		return
	if _fx_scene.get_parent() == self:
		remove_child(_fx_scene)
	if not _fx_pool.has(_fx_path):
		_fx_pool[_fx_path] = []
	_fx_pool[_fx_path].append(_fx_scene)
	_fx_scene = null

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
