class_name DriveRushFx
extends Node3D

## Cosmetic Drive Rush trail: while a fighter is drive-rushing (or its first Drive Rush
## normal is still armed), it leaves a stream of fading translucent "afterimage" silhouettes
## in the character's accent-tinted Drive colour — the SF6 "绿冲" streak. Purely visual: it
## only READS Fighter state and frees itself, never touching the deterministic sim.

const GHOST_LIFE := 0.24      # seconds each afterimage takes to fade out
const EMIT_INTERVAL := 0.03   # seconds between afterimages while rushing

var _fighter: Fighter
var _color := Color(0.35, 1.0, 0.65)
var _emit_accum := 0.0
var _ghosts: Array = []        # [{mi: MeshInstance3D, mat: StandardMaterial3D, t: float}]

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
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 1.55, 0.34)
	mi.mesh = box
	mi.position = _fighter.position + Vector3(0.0, 0.82, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(_color.r, _color.g, _color.b, 0.5)
	mat.emission_enabled = true
	mat.emission = _color
	mat.emission_energy_multiplier = 2.5
	mi.material_override = mat
	add_child(mi)
	_ghosts.append({"mi": mi, "mat": mat, "t": 0.0})

func _age_ghosts(delta: float) -> void:
	var survivors: Array = []
	for g in _ghosts:
		g["t"] += delta
		var p: float = clampf(g["t"] / GHOST_LIFE, 0.0, 1.0)
		var fade: float = 1.0 - p
		var mat: StandardMaterial3D = g["mat"]
		mat.albedo_color.a = 0.5 * fade
		mat.emission_energy_multiplier = 2.5 * fade
		var mi: MeshInstance3D = g["mi"]
		# Squash slightly as it fades so the streak reads as motion, not a clone.
		mi.scale = Vector3(1.0 - 0.4 * p, 1.0, 1.0)
		if p >= 1.0:
			mi.queue_free()
		else:
			survivors.append(g)
	_ghosts = survivors
