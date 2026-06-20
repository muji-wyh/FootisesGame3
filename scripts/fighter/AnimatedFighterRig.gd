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
## Hit-reaction clips are resolved per-hit by direction/height/strength (see
## _resolve_hit_clip); knockdown + get-up clips by cause (see _knockdown_clip/_wakeup_clip).
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
		_play(STATE_CLIP["idle"], 0.0, 1.0, true)   # idle must loop

## --- per-visual-tick posing -----------------------------------------------

func pose(f: Fighter) -> void:
	if not ok:
		return
	# Ground using the real (animated) idle pose - but only once the rig is in the tree and
	# the AnimationPlayer has actually posed the skeleton (not during the early build call).
	if not _grounded and is_inside_tree() and f.state == Fighter.State.IDLE:
		_grounded = true
		_reground_to_pose()
	_facing_pivot.rotation.y = 0.0 if f.facing >= 0 else PI

	if f.state == Fighter.State.ATTACK:
		_pose_attack(f)
		return
	_cur_move = null

	# Knockdown and get-up are one-shot clips fitted to their state's tick budget, so the
	# (much longer) mocap fall / rise reads as a single complete motion in the time the
	# fighter is actually down / standing up.
	if f.state == Fighter.State.KNOCKDOWN:
		var kd := _knockdown_clip(f)
		if kd != _cur_clip:
			_play_fitted(kd, Fighter.KNOCKDOWN_TICKS, 0.06)
		return
	if f.state == Fighter.State.WAKEUP:
		var wu := _wakeup_clip(f)
		if wu != _cur_clip:
			_play_fitted(wu, Fighter.WAKEUP_TICKS, 0.08)
		return

	var target := _state_clip(f)
	if target != _cur_clip:
		_play(target, 0.12, 1.0, target in LOOPED)

func _pose_attack(f: Fighter) -> void:
	if f.current_move != _cur_move:
		_cur_move = f.current_move
		var clip := _move_clip(f.current_move)
		_play_fitted(clip, f.current_move.total_frames(), 0.05)

## Play a one-shot clip time-scaled to span `ticks` simulation frames (so a long mocap
## clip fits the move/knockdown/wake-up window). Speed is clamped to stay readable.
func _play_fitted(clip: String, ticks: int, blend: float) -> void:
	var dur := maxf(0.1, float(ticks) / GameConst.TICK_RATE)
	var len := _length(clip)
	var spd := clampf(len / dur, 0.4, 4.0)
	_play(clip, blend, spd, false)

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
			return _resolve_hit_clip(f)
		Fighter.State.KNOCKDOWN:
			return _knockdown_clip(f)
		Fighter.State.WAKEUP:
			return _wakeup_clip(f)
		Fighter.State.KO:
			return STATE_CLIP["ko"]
		Fighter.State.WIN:
			return STATE_CLIP["win"]
	return STATE_CLIP["idle"]

## --- directional hit-reaction resolution ----------------------------------

## Resolve a directional hit-reaction clip from the victim's hit context (height, strength,
## stance, air, cross-up). Builds a prioritised candidate list and returns the first clip
## that was actually grafted, degrading gracefully where the Kubold set has gaps (e.g. Low
## has no Front or Stagger variant).
func _resolve_hit_clip(f: Fighter) -> String:
	var tier: int = clampi(f.hit_strength, 0, 2)
	# Crouching victims use the dedicated (light, mid-height) crouch-hit set.
	if f.hit_crouch and f.on_ground:
		var cdirs: Array[String]
		if f.hit_from_back:
			cdirs = ["Right", "Left", "Front"]
		else:
			cdirs = ["Front", "Left", "Right"]
		var cc: Array[String] = []
		for d in cdirs:
			cc.append("KB_crouch_Hit_p_Mid%s_Weak" % d)
		return _first_existing(cc, "KB_Hit_p_MidFront_Weak")
	var height := _height_token(f)
	var dirs: Array[String]
	if f.hit_from_back:
		dirs = ["Back", "Right", "Left", "Front"]
	else:
		dirs = ["Front", "Left", "Right"]
	var cands: Array[String] = []
	for h in [height, "Mid", "High"]:
		for d in dirs:
			cands.append_array(_tier_names(h, d, tier))
	return _first_existing(cands, "KB_Hit_p_MidFront_Weak")

func _height_token(f: Fighter) -> String:
	if not f.on_ground or f.hit_air:
		return "High"
	match f.hit_height:
		GameConst.HitHeight.HIGH:
			return "High"
		GameConst.HitHeight.LOW:
			return "Low"
	return "Mid"

## Strength tiers: requested strength first, then progressively lighter fallbacks. The 'p'
## (light) set only has Weak; the 'm' set carries Weak / Med / Stagger.
func _tier_names(h: String, d: String, tier: int) -> Array[String]:
	match tier:
		2:
			return ["KB_Hit_m_%s%s_Stagger" % [h, d], "KB_Hit_m_%s%s_Med" % [h, d], "KB_Hit_m_%s%s_Weak" % [h, d], "KB_Hit_p_%s%s_Weak" % [h, d]]
		1:
			return ["KB_Hit_m_%s%s_Med" % [h, d], "KB_Hit_m_%s%s_Weak" % [h, d], "KB_Hit_p_%s%s_Weak" % [h, d]]
		_:
			return ["KB_Hit_p_%s%s_Weak" % [h, d], "KB_Hit_m_%s%s_Weak" % [h, d]]

## Pick the knockdown clip from how the victim went down (uppercut / sweep / air / heavy).
func _knockdown_clip(f: Fighter) -> String:
	match f.knockdown_kind:
		GameConst.Knockdown.UPPER:
			return _first_existing(["KB_UpperKO", "KB_HighKO_Powerful", "KB_MidKO_Powerful"], STATE_CLIP["knockdown"])
		GameConst.Knockdown.LOW:
			return _first_existing(["KB_LowKO_R", "KB_LowKO_L", "KB_MidKO"], STATE_CLIP["knockdown"])
		GameConst.Knockdown.AIR:
			return _first_existing(["KB_HighKO_Air", "KB_HighKO_Powerful", "KB_MidKO"], STATE_CLIP["knockdown"])
		GameConst.Knockdown.HEAVY:
			return _first_existing(["KB_MidKO_Powerful", "KB_MidKO"], STATE_CLIP["knockdown"])
	return STATE_CLIP["knockdown"]

## Get-up clip: rise face-up by default, or face-down when knocked from behind.
func _wakeup_clip(f: Fighter) -> String:
	if f.hit_from_back:
		return _first_existing(["KB_GetUpFace", "KB_GetUpBack"], STATE_CLIP["idle"])
	return _first_existing(["KB_GetUpBack", "KB_GetUpFace"], STATE_CLIP["idle"])

func _first_existing(candidates: Array[String], fallback: String) -> String:
	for c in candidates:
		if _player.has_animation(LIB + "/" + c):
			return c
	return fallback

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
	var lib := build_kb_library()
	if _player.has_animation_library(LIB):
		_player.remove_animation_library(LIB)
	_player.add_animation_library(LIB, lib)

## Build the shared Kubold animation library (clips grafted, root motion cancelled, looping
## clips flagged). Static so the Animation Gallery can build it once and share it across
## many characters.
static func build_kb_library() -> AnimationLibrary:
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
				if clip_name in LOOPED:
					anim.loop_mode = Animation.LOOP_LINEAR
				lib.add_animation(clip_name, anim)
		inst.free()
	return lib

## Cancel the root bone's HORIZONTAL travel (so clips play in place) while keeping its
## vertical height/bob - removing the track entirely would collapse the character.
static func _strip_root_motion(anim: Animation) -> void:
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
	if keep:
		_apply_materials(keep, character)
	# Grounding happens once the idle pose is available (see _reground_to_pose). At
	# position.y = 0 the model is already standing on the floor in its rest pose.

## Apply the (downscaled, web-friendly) Maskman textures per surface, with a gentle
## per-character tint. Falls back to a flat colour if the textures aren't present.
func _apply_materials(mesh: MeshInstance3D, character: CharacterData) -> void:
	apply_maskman_materials(mesh, character.color.lerp(Color.WHITE, 0.55), character.color)

## Static, reusable: texture a Maskman mesh per surface (body/head/mask/eye) with `tint`,
## falling back to `flat` if a texture is missing. Used by the rig and the Animation Gallery.
static func apply_maskman_materials(mesh: MeshInstance3D, tint: Color, flat: Color) -> void:
	var surface_tex := {"Cialo": "body", "Glowa": "head", "Eye": "eye", "MaskM": "mask"}
	for s in range(mesh.mesh.get_surface_count()):
		var smat := mesh.mesh.surface_get_material(s)
		var mname: String = ""
		if smat:
			mname = smat.resource_name
		var tex: Texture2D = null
		for key in surface_tex.keys():
			if key in mname:
				var path: String = "res://assets/models/tex/" + surface_tex[key] + ".png"
				if ResourceLoader.exists(path):
					tex = load(path) as Texture2D
				break
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.7
		if tex:
			mat.albedo_texture = tex
			mat.albedo_color = tint
		else:
			mat.albedo_color = flat
		mesh.set_surface_override_material(s, mat)

## Ground the model so the boot SOLES sit on the floor, using the actual animated idle
## stance. Key insight: the model's REST pose is authored standing on the ground, so the
## lowest foot-bone height at rest equals the bone-above-sole distance. We then place the
## posed lowest foot bone at that same height, putting the sole at y=0. Runs once, on the
## first in-tree idle tick (when the AnimationPlayer has actually posed the skeleton).
const FOOT_BONES := ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"]

func _reground_to_pose() -> void:
	if _skel == null:
		return
	if _player:
		_player.advance(0.0)
	var rest_low := _lowest_foot_height(true)    # sole offset (rest, model grounded)
	var pose_low := _lowest_foot_height(false)   # current animated stance
	if rest_low != INF and pose_low != INF:
		_model.position.y = rest_low - pose_low

## Lowest foot-bone height in rig space (rotation+scale only, ignoring position), using the
## rest pose when `rest` is true, else the current animated pose.
func _lowest_foot_height(rest: bool) -> float:
	var lowest := INF
	for bone in FOOT_BONES:
		var bi := _skel.find_bone(bone)
		if bi < 0:
			continue
		var origin: Vector3 = (_skel.get_bone_global_rest(bi).origin if rest
			else _skel.get_bone_global_pose(bi).origin)
		var y: float = (_model.transform.basis * (_skel.transform.basis * origin)).y
		lowest = minf(lowest, y)
	return lowest

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)

static func _find(node: Node, klass: String) -> Node:
	if node.is_class(klass):
		return node
	for c in node.get_children():
		var r := _find(c, klass)
		if r:
			return r
	return null
