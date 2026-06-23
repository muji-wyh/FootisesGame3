class_name DriveRushFx
extends Node3D

## Cosmetic Drive Rush trail: while a fighter is drive-rushing (or its first Drive Rush
## normal is still armed), it leaves a stream of fading translucent "afterimage" silhouettes
## in the character's accent-tinted Drive colour — the SF6 "绿冲" streak. Purely visual: it
## only READS Fighter state and frees itself, never touching the deterministic sim.

const GHOST_LIFE := 0.18      # seconds each afterimage takes to fade out
const EMIT_INTERVAL := 0.055  # seconds between afterimages while rushing
const GHOST_ALPHA := 0.28
const GHOST_EMISSION := 1.2

var _fighter: Fighter
var _color := Color(0.35, 1.0, 0.65)
var _emit_accum := 0.0
var _ghosts: Array = []        # [{root: Node3D, meshes: Array[MeshInstance3D], mats: Array[StandardMaterial3D], t: float}]

func setup(fighter: Fighter, color: Color) -> void:
	_fighter = fighter
	_color = color

func _process(delta: float) -> void:
	if _fighter == null or not is_instance_valid(_fighter):
		queue_free()
		return
	var rushing := _fighter.state == Fighter.State.DRIVE_RUSH or _fighter.drive_rush_pending
	if rushing:
		_emit_accum += delta
		while _emit_accum >= EMIT_INTERVAL:
			_emit_accum -= EMIT_INTERVAL
			_spawn_ghost()
	_age_ghosts(delta)
	if not rushing and _ghosts.is_empty():
		queue_free()

func _spawn_ghost() -> void:
	if _fighter.rig != null and is_instance_valid(_fighter.rig) and _fighter.rig is Node3D:
		var source := _fighter.rig as Node3D
		var snapshot_transform := _safe_global_transform(source)
		var root := (_fighter.rig as Node3D).duplicate(0) as Node3D
		if root != null:
			var mats: Array[StandardMaterial3D] = []
			var meshes: Array[MeshInstance3D] = []
			_style_ghost_tree(root, mats, meshes)
			if not meshes.is_empty():
				add_child(root)
				root.top_level = true
				_apply_transform(root, snapshot_transform)
				_disable_runtime(root)
				_ghosts.append({"root": root, "meshes": meshes, "mats": mats, "t": 0.0})
				return
			root.queue_free()
	_spawn_fallback_ghost()

func _spawn_fallback_ghost() -> void:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 1.55, 0.34)
	mi.mesh = box
	mi.position = Vector3(0.0, 0.82, 0.0)
	var mat := _ghost_mat()
	mi.material_override = mat
	root.add_child(mi)
	add_child(root)
	root.top_level = true
	_apply_transform(root, _safe_global_transform(_fighter))
	_ghosts.append({"root": root, "meshes": [mi], "mats": [mat], "t": 0.0})

func _safe_global_transform(n: Node3D) -> Transform3D:
	if n.is_inside_tree():
		return n.global_transform
	var parent := n.get_parent()
	if parent is Node3D and (parent as Node3D).is_inside_tree():
		return (parent as Node3D).global_transform * n.transform
	return n.transform

func _apply_transform(n: Node3D, xform: Transform3D) -> void:
	if n.is_inside_tree():
		n.global_transform = xform
	else:
		n.transform = xform

func _style_ghost_tree(n: Node, mats: Array[StandardMaterial3D], meshes: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.visible and mi.mesh != null:
			var mat := _ghost_mat()
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mats.append(mat)
			meshes.append(mi)
	for child in n.get_children():
		_style_ghost_tree(child, mats, meshes)

func _ghost_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(_color.r, _color.g, _color.b, GHOST_ALPHA)
	mat.emission_enabled = true
	mat.emission = _color
	mat.emission_energy_multiplier = GHOST_EMISSION
	return mat

func _disable_runtime(n: Node) -> void:
	n.set_process(false)
	n.set_physics_process(false)
	if n is AnimationPlayer:
		(n as AnimationPlayer).stop()
	for child in n.get_children():
		_disable_runtime(child)

func _age_ghosts(delta: float) -> void:
	var survivors: Array = []
	for g in _ghosts:
		g["t"] += delta
		var p: float = clampf(g["t"] / GHOST_LIFE, 0.0, 1.0)
		var fade: float = 1.0 - p
		for mat: StandardMaterial3D in g["mats"]:
			mat.albedo_color.a = GHOST_ALPHA * fade
			mat.emission_energy_multiplier = GHOST_EMISSION * fade
		var root: Node3D = g["root"]
		if p >= 1.0:
			root.queue_free()
		else:
			survivors.append(g)
	_ghosts = survivors
