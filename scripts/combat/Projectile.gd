class_name Projectile
extends Node3D

## A travelling attack (fireball / beam). Spawned by a Fighter, owned by one side,
## moves forward each tick and hits the opposing fighter once. The Match updates and
## hit-tests it alongside the fighters so all combat goes through one code path.

var move: MoveData
var owner_side: int = 0
var facing: int = 1
var life: int = 90
var speed: float = 7.0
var connected: bool = false
var size: Vector3 = Vector3(0.6, 0.6, 0.6)

var _mesh: MeshInstance3D

func setup(p_move: MoveData, p_owner_side: int, p_facing: int, start: Vector3, color: Color) -> void:
	move = p_move
	owner_side = p_owner_side
	facing = p_facing
	speed = p_move.projectile_speed
	life = p_move.projectile_life
	size = p_move.hit_size
	position = start
	_build_mesh(color)

func _build_mesh(color: Color) -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size.x * 0.5
	sphere.height = size.y
	_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	_mesh.material_override = mat
	add_child(_mesh)

## Advance one tick. Returns false when the projectile should be removed.
func advance(delta: float) -> bool:
	position.x += facing * speed * delta
	life -= 1
	if _mesh:
		_mesh.rotate_y(0.4)
	return life > 0 and not connected

func aabb() -> AABB:
	return AABB(position - size * 0.5, size)
