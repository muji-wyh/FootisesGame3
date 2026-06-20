class_name AnimatedFighterRig
extends Node3D

## A model-backed rig: instances an imported FBX/glTF character, grafts the Kubold mocap
## animation clips onto its (compatible) skeleton, and plays the right clip each visual
## tick based on Fighter state. Drop-in replacement for FighterRig (same build()/pose()).
##
## The combat sim is unaffected — the rig only READS Fighter state. If the (licensed,
## gitignored) model is missing, MatchScene uses the procedural FighterRig instead.

## Kubold animation FBX whose clips are grafted onto the model. Same skeleton family,
## so the clips play directly. Stored under assets/models/anims (gitignored).
const ANIM_FILES := [
	"res://assets/models/anims/KB_Movement.fbx",
	"res://assets/models/anims/KB_Crouched.fbx",
	"res://assets/models/anims/KB_Jumping.fbx",
	"res://assets/models/anims/KB_Punches.fbx",
	"res://assets/models/anims/KB_Kicks.fbx",
	"res://assets/models/anims/KB_Blocks.fbx",
	"res://assets/models/anims/KB_Hits.fbx",
	"res://assets/models/anims/KB_KOs.fbx",
	"res://assets/models/anims/KB_Specials.fbx",
]

const LIB := "kb"
const SKIP := ["BindPose", "tpose", "Take 001"]
const ROOT_BONES := ["Hips", "Root"]

## Default state -> clip. Per-move clips come from MoveData.anim_clip.
const STATE_CLIP := {
	"idle": "KB_Idle_1",
	"walk_f": "KB_WalkFwd1",
	"walk_b": "KB_WalkBwd",
	"crouch": "KB_crouch_Idle",
	"jump": "KB_Jump",
	"dash_f": "KB_SkipFwd_1",
	"dash_b": "KB_SkipBwd_1",
	"block": "KB_Block_Single",
	"hit": "KB_Hit_p_MidFront_Weak",
	"knockdown": "KB_MidKO",
	"ko": "KB_HighKO_Powerful",
	"win": "KB_Idle_3",
}
const LOOPED := ["KB_Idle_1", "KB_Idle_3", "KB_WalkFwd1", "KB_WalkBwd", "KB_crouch_Idle"]

var ok: bool = false
var _facing_pivot: Node3D
var _model: Node3D
var _player: AnimationPlayer
var _cur_clip: String = ""
var _cur_move: MoveData = null
var _grounded: bool = false
var _skel: Skeleton3D

func build(character: CharacterData) -> void:
	_facing_pivot = Node3D.new()
	add_child(_facing_pivot)

	var ps := load(character.model_path) as PackedScene
	if ps == null:
		return
	_model = ps.instantiate() as Node3D
	if _model == null:
		return
	_facing_pivot.add_child(_model)
	_model.rotation_degrees = character.model_euler_deg + Vector3(0, character.model_face_deg, 0)
	_model.scale = Vector3.ONE * character.model_scale

	_player = _find(_model, "AnimationPlayer") as AnimationPlayer
	if _player == null:
		return
	_skel = _find(_model, "Skeleton3D") as Skeleton3D

	_graft_animations()
	_ground_and_tint(character)
	ok = _player.has_animation(LIB + "/" + STATE_CLIP["idle"])
	if ok:
		_play(STATE_CLIP["idle"], 0.0)

## --- per-visual-tick posing -----------------------------------------------

func pose(f: Fighter) -> void:
	if not ok:
		return
	if not _grounded:
		_grounded = true
		_reground_to_pose()
	_facing_pivot.rotation.y = 0.0 if f.facing >= 0 else PI

	if f.state == Fighter.State.ATTACK:
		if f.current_move != _cur_move:
			_cur_move = f.current_move
			var clip := _move_clip(f.current_move)
			var dur := maxf(0.1, float(f.current_move.total_frames()) / GameConst.TICK_RATE)
			var len := _length(clip)
			var spd := clampf(len / dur, 0.4, 3.0)
			_play(clip, 0.05, spd, false)
		return

	_cur_move = null
	var target := _state_clip(f)
	if target != _cur_clip:
		_play(target, 0.12, 1.0, target in LOOPED)

func _state_clip(f: Fighter) -> String:
	match f.state:
		Fighter.State.IDLE, Fighter.State.INTRO:
			return STATE_CLIP["idle"]
		Fighter.State.WALK_F:
			return STATE_CLIP["walk_f"]
		Fighter.State.WALK_B:
			return STATE_CLIP["walk_b"]
		Fighter.State.CROUCH:
			return STATE_CLIP["crouch"]
		Fighter.State.JUMP:
			return STATE_CLIP["jump"]
		Fighter.State.DASH_F:
			return STATE_CLIP["dash_f"]
		Fighter.State.DASH_B:
			return STATE_CLIP["dash_b"]
		Fighter.State.BLOCKSTUN:
			return STATE_CLIP["block"]
		Fighter.State.HITSTUN:
			return STATE_CLIP["hit"]
		Fighter.State.KNOCKDOWN:
			return STATE_CLIP["knockdown"]
		Fighter.State.KO:
			return STATE_CLIP["ko"]
		Fighter.State.WIN:
			return STATE_CLIP["win"]
	return STATE_CLIP["idle"]

func _move_clip(m: MoveData) -> String:
	if m != null and m.anim_clip != "" and _player.has_animation(LIB + "/" + m.anim_clip):
		return m.anim_clip
	return "KB_p_Jab_R_1"

func _play(clip: String, blend: float, speed: float = 1.0, loop: bool = false) -> void:
	var full := LIB + "/" + clip
	if not _player.has_animation(full):
		return
	var anim := _player.get_animation(full)
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_player.play(full, blend, speed)
	_cur_clip = clip

func _length(clip: String) -> float:
	var full := LIB + "/" + clip
	if _player.has_animation(full):
		return _player.get_animation(full).length
	return 0.5

## --- setup helpers ---------------------------------------------------------

func _graft_animations() -> void:
	var lib := AnimationLibrary.new()
	for path in ANIM_FILES:
		var ps := load(path) as PackedScene
		if ps == null:
			continue
		var inst := ps.instantiate()
		var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
		if ap:
			for clip_name in ap.get_animation_list():
				if clip_name in SKIP or lib.has_animation(clip_name):
					continue
				var anim: Animation = ap.get_animation(clip_name).duplicate(true)
				_strip_root_motion(anim)
				lib.add_animation(clip_name, anim)
		inst.free()
	if _player.has_animation_library(LIB):
		_player.remove_animation_library(LIB)
	_player.add_animation_library(LIB, lib)

## Cancel the root bone's HORIZONTAL travel (so clips play in place) while keeping its
## vertical height/bob - removing the track entirely would collapse the character.
func _strip_root_motion(anim: Animation) -> void:
	for i in range(anim.get_track_count()):
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var p := anim.track_get_path(i)
		var sub: String = ""
		if p.get_subname_count() > 0:
			sub = String(p.get_subname(p.get_subname_count() - 1))
		if not (sub in ROOT_BONES):
			continue
		var kc := anim.track_get_key_count(i)
		if kc == 0:
			continue
		var first: Vector3 = anim.track_get_key_value(i, 0)
		for k in range(kc):
			var v: Vector3 = anim.track_get_key_value(i, k)
			anim.track_set_key_value(i, k, Vector3(first.x, v.y, first.z))

func _ground_and_tint(character: CharacterData) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = character.color
	mat.roughness = 0.6
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_model, meshes)
	# Keep a single LOD visible.
	var keep: MeshInstance3D = null
	for m in meshes:
		if "LOD1" in m.name:
			keep = m
	if keep == null and not meshes.is_empty():
		keep = meshes[0]
	for m in meshes:
		m.visible = (m == keep)
		m.material_override = mat
	# Drop so the feet sit on the ground (y = 0). Skinned-mesh AABBs are unreliable, so use
	# the skeleton's foot-bone rest positions instead.
	var skel := _find(_model, "Skeleton3D") as Skeleton3D
	if skel:
		var lowest := INF
		var lowest_origin := Vector3.ZERO
		for bone in ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"]:
			var bi := skel.find_bone(bone)
			if bi >= 0:
				var o: Vector3 = skel.get_bone_global_rest(bi).origin
				if o.y < lowest:
					lowest = o.y
					lowest_origin = o
		if lowest != INF:
			var foot_in_rig: Vector3 = _model.transform.basis * lowest_origin
			_model.position.y -= foot_in_rig.y

## Refine grounding using the ACTUAL animated (idle stance) pose, not the rest pose - the
## boxing stance bends the knees so the feet sit lower than rest. Runs once, on the first
## visual tick (when the rig is in the tree and the pose can be evaluated).
func _reground_to_pose() -> void:
	if _skel == null:
		return
	if _player:
		_player.advance(0.0)
	var lowest := INF
	var lowest_origin := Vector3.ZERO
	for bone in ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"]:
		var bi := _skel.find_bone(bone)
		if bi >= 0:
			var o: Vector3 = _skel.get_bone_global_pose(bi).origin
			if o.y < lowest:
				lowest = o.y
				lowest_origin = o
	if lowest != INF:
		var foot_in_rig: Vector3 = _model.transform * (_skel.transform * lowest_origin)
		_model.position.y -= foot_in_rig.y

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)

func _find(node: Node, klass: String) -> Node:
	if node.is_class(klass):
		return node
	for c in node.get_children():
		var r := _find(c, klass)
		if r:
			return r
	return null
