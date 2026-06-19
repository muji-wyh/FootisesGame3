class_name FighterRig
extends Node3D

## A blockout humanoid built from primitive meshes, posed procedurally from a Fighter's
## state each visual tick. It is intentionally swappable: replace build()/pose() with a
## Mixamo glTF model driven by an AnimationTree and the rest of the game is unchanged
## (the rig only reads Fighter state; it never drives gameplay).

var _facing_pivot: Node3D
var _torso: MeshInstance3D
var _head: MeshInstance3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D

func build(character: CharacterData) -> void:
	_facing_pivot = Node3D.new()
	add_child(_facing_pivot)

	var body_mat := _mat(character.color)
	var accent_mat := _mat(character.accent)

	_torso = _box(Vector3(0.5, 0.62, 0.3), Vector3(0, 1.2, 0), body_mat)
	_facing_pivot.add_child(_torso)
	var hip := _box(Vector3(0.46, 0.22, 0.3), Vector3(0, 0.92, 0), accent_mat)
	_facing_pivot.add_child(hip)

	_head = _sphere(0.17, Vector3(0, 1.66, 0), accent_mat)
	_facing_pivot.add_child(_head)

	_arm_l = _limb(Vector3(0.15, 0.66, 0.15), Vector3(-0.33, 1.45, 0.0), body_mat)
	_arm_r = _limb(Vector3(0.15, 0.66, 0.15), Vector3(0.33, 1.45, 0.0), body_mat)
	_leg_l = _limb(Vector3(0.2, 0.9, 0.2), Vector3(-0.15, 0.9, 0.0), accent_mat)
	_leg_r = _limb(Vector3(0.2, 0.9, 0.2), Vector3(0.15, 0.9, 0.0), accent_mat)
	for l in [_arm_l, _arm_r, _leg_l, _leg_r]:
		_facing_pivot.add_child(l)

## --- per-visual-tick posing -----------------------------------------------

func pose(f: Fighter) -> void:
	# Whole-body facing: model is authored looking toward +x.
	_facing_pivot.rotation.y = 0.0 if f.facing >= 0 else PI
	_facing_pivot.position = Vector3.ZERO
	_facing_pivot.rotation.z = 0.0
	_facing_pivot.scale = Vector3.ONE
	var t := float(f.state_frame)

	# Reset limbs to a relaxed rest pose each tick.
	_arm_l.rotation.z = 0.12
	_arm_r.rotation.z = -0.12
	_leg_l.rotation.z = 0.0
	_leg_r.rotation.z = 0.0

	match f.state:
		Fighter.State.IDLE:
			var b := sin(t * 0.12) * 0.04
			_torso.position.y = 1.2 + b
		Fighter.State.WALK_F, Fighter.State.WALK_B:
			var s := sin(t * 0.35)
			_leg_r.rotation.z = s * 0.5
			_leg_l.rotation.z = -s * 0.5
			_arm_r.rotation.z = -0.12 - s * 0.3
			_arm_l.rotation.z = 0.12 + s * 0.3
		Fighter.State.CROUCH:
			_facing_pivot.scale.y = 0.65
		Fighter.State.JUMP:
			_leg_l.rotation.z = 0.6
			_leg_r.rotation.z = -0.6
		Fighter.State.ATTACK:
			_pose_attack(f)
		Fighter.State.BLOCKSTUN:
			_arm_l.rotation.z = 1.1
			_arm_r.rotation.z = 1.1
			_facing_pivot.rotation.x = -0.1
		Fighter.State.HITSTUN:
			_facing_pivot.rotation.x = 0.35
			_arm_l.rotation.z = -0.6
			_arm_r.rotation.z = 0.6
		Fighter.State.KNOCKDOWN, Fighter.State.KO:
			_facing_pivot.rotation.z = PI * 0.5
			_facing_pivot.position.y = 0.2
		Fighter.State.WIN:
			_arm_l.rotation.z = 2.2
			_arm_r.rotation.z = -2.2

func _pose_attack(f: Fighter) -> void:
	var m: MoveData = f.current_move
	if m == null:
		return
	var e := _attack_envelope(m, f.state_frame) * clampf(m.anim_extend + 0.5, 0.5, 1.6)
	var swing := (PI * 0.5) * e
	match m.anim_limb:
		"arm_r":
			_arm_r.rotation.z = swing
		"arm_l":
			_arm_l.rotation.z = swing
		"leg_r":
			_leg_r.rotation.z = swing
		"leg_l":
			_leg_l.rotation.z = swing
		_:
			_arm_r.rotation.z = swing
	# Lean into the strike.
	_facing_pivot.rotation.x = -0.12 * e

func _attack_envelope(m: MoveData, sf: int) -> float:
	if sf < m.startup:
		return (float(sf) / maxf(1.0, m.startup)) * 0.5
	if sf < m.startup + m.active:
		return 1.0
	var r := float(sf - m.startup - m.active) / maxf(1.0, m.recovery)
	return lerpf(1.0, 0.0, clampf(r, 0.0, 1.0))

## --- mesh factory ----------------------------------------------------------

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	return mat

func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi

func _sphere(radius: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi

## A limb is a pivot Node3D at the joint with a mesh hanging downward, so rotating the
## pivot about Z swings the limb forward/back.
func _limb(size: Vector3, joint: Vector3, mat: StandardMaterial3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = joint
	var mesh := _box(size, Vector3(0, -size.y * 0.5, 0), mat)
	pivot.add_child(mesh)
	return pivot
