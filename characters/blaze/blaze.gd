extends RefCounted

## Blaze - fiery rushdown fighter (Ken-inspired normals): grounded pressure, jump-ins,
## Drive Rush, and a multi-hit super. Self-contained character module: stats, moves,
## frame data and rig config live here; registered in CharacterLibrary.REGISTRY.
## Each move is a small data dictionary, so this file reads like a tuning sheet.

const ID := "blaze"
const DISPLAY_NAME := "Blaze"

## Where this character's model + animation + texture assets live. (The licensed FBX/textures
## are gitignored; see assets/README.md.)
const ASSETS := "res://characters/blaze/assets/"

## Per-normal animation clips (the shared CharacterKit supplies the frame data).
const NORMAL_CLIPS := {
	"st_lp": "KB_p_Jab_R_1", "st_mp": "KB_m_Uppercut_R", "st_hp": "KB_m_Overhand_R",
	"st_lk": "KB_p_LowKick_R_1", "st_mk": "KB_m_MidKick_R", "st_hk": "KB_m_MidKickRoud_R_1",
	"cr_lp": "KB_crouch_p_Jab_L", "cr_mp": "KB_crouch_p_Jab_R", "cr_hp": "KB_crouch_p_Uppercut_R",
	"cr_lk": "KB_crouch_p_LowKick_L", "cr_mk": "KB_crouch_p_LowKickRound_R", "cr_hk": "KB_crouch_m_LowKickRound_R",
	"air_lp": "KB_JumpPunch", "air_mp": "KB_m_Hook_R", "air_hp": "KB_m_Overhand_R",
	"air_lk": "KB_JumpKick", "air_mk": "KB_p_MidKickFront_L", "air_hk": "KB_p_HighKick_R_1",
}
const NORMAL_TUNING := {
	"st_lp": {"startup": 4, "active": 3, "recovery": 9, "damage": 27, "hitstun": 16, "blockstun": 9, "hitstop": 9, "guard": GameConst.Guard.MID, "knockback": 3.2, "hit_offset": Vector3(0.57, 1.0, 0.0), "hit_size": Vector3(0.37, 0.36, 0.55), "cancel_into": []},
	"st_mp": {"startup": 7, "active": 3, "recovery": 16, "damage": 48, "hitstun": 18, "blockstun": 11, "hitstop": 10, "guard": GameConst.Guard.MID, "knockback": 3.8, "advance": 1.0, "hit_offset": Vector3(0.58, 1.0, 0.0), "hit_size": Vector3(0.38, 0.42, 0.62), "cancel_into": []},
	"st_hp": {"startup": 9, "active": 4, "recovery": 18, "damage": 78, "hitstun": 21, "blockstun": 13, "hitstop": 12, "guard": GameConst.Guard.MID, "knockback": 5.0, "advance": 1.4, "hit_offset": Vector3(0.59, 1.02, 0.0), "hit_size": Vector3(0.39, 0.50, 0.68), "cancel_into": []},
	"st_lk": {"startup": 5, "active": 3, "recovery": 9, "damage": 29, "hitstun": 14, "blockstun": 9, "hitstop": 9, "guard": GameConst.Guard.MID, "knockback": 3.0, "hit_offset": Vector3(0.60, 0.72, 0.0), "hit_size": Vector3(0.40, 0.34, 0.62), "cancel_into": []},
	"st_mk": {"startup": 7, "active": 4, "recovery": 14, "damage": 51, "hitstun": 18, "blockstun": 11, "hitstop": 10, "guard": GameConst.Guard.MID, "knockback": 4.2, "hit_offset": Vector3(0.61, 0.86, 0.0), "hit_size": Vector3(0.41, 0.40, 0.68), "cancel_into": []},
	"st_hk": {"startup": 11, "active": 4, "recovery": 20, "damage": 84, "hitstun": 22, "blockstun": 12, "hitstop": 12, "guard": GameConst.Guard.MID, "knockback": 5.6, "hit_offset": Vector3(0.62, 0.98, 0.0), "hit_size": Vector3(0.42, 0.46, 0.72), "launch": true, "launch_velocity": 7.0},
	"cr_lp": {"startup": 4, "active": 3, "recovery": 9, "damage": 25, "hitstun": 13, "blockstun": 9, "hitstop": 9, "guard": GameConst.Guard.MID, "knockback": 3.1, "hit_offset": Vector3(0.58, 0.78, 0.0), "hit_size": Vector3(0.37, 0.34, 0.55), "cancel_into": []},
	"cr_mp": {"startup": 6, "active": 3, "recovery": 12, "damage": 46, "hitstun": 16, "blockstun": 10, "hitstop": 10, "guard": GameConst.Guard.MID, "knockback": 3.5, "cancel_into": []},
	"cr_hp": {"startup": 7, "active": 5, "recovery": 22, "damage": 74, "hitstun": 22, "blockstun": 12, "hitstop": 12, "guard": GameConst.Guard.MID, "knockback": 3.8, "launch": true, "launch_velocity": 9.0, "hit_offset": Vector3(0.6, 1.5, 0.0), "hit_size": Vector3(0.8, 1.3, 0.7)},
	"cr_lk": {"startup": 5, "active": 3, "recovery": 9, "damage": 27, "hitstun": 13, "blockstun": 9, "hitstop": 9, "guard": GameConst.Guard.LOW, "knockback": 2.7, "hit_offset": Vector3(0.56, 0.26, 0.0), "hit_size": Vector3(0.38, 0.32, 0.60), "cancel_into": []},
	"cr_mk": {"startup": 7, "active": 4, "recovery": 14, "damage": 49, "hitstun": 17, "blockstun": 11, "hitstop": 10, "guard": GameConst.Guard.LOW, "knockback": 4.0, "hit_offset": Vector3(0.66, 0.24, 0.0), "hit_size": Vector3(0.48, 0.34, 0.64), "cancel_into": []},
	"cr_hk": {"startup": 9, "active": 4, "recovery": 22, "damage": 76, "hitstun": 20, "blockstun": 12, "hitstop": 12, "guard": GameConst.Guard.LOW, "knockback": 4.8, "hit_offset": Vector3(0.76, 0.22, 0.0), "hit_size": Vector3(0.60, 0.36, 0.68), "launch": true, "launch_velocity": 5.5},
	"air_lp": {"startup": 3, "active": 10, "recovery": 4, "damage": 27, "hitstun": 16, "blockstun": 10, "hitstop": 9, "guard": GameConst.Guard.OVERHEAD, "knockback": 2.8, "hit_offset": Vector3(0.45, 0.35, 0.0), "hit_size": Vector3(0.55, 0.45, 0.65)},
	"air_mp": {"startup": 5, "active": 8, "recovery": 5, "damage": 48, "hitstun": 18, "blockstun": 11, "hitstop": 10, "guard": GameConst.Guard.OVERHEAD, "knockback": 3.8, "hit_offset": Vector3(0.52, 0.38, 0.0), "hit_size": Vector3(0.65, 0.50, 0.65)},
	"air_hp": {"startup": 7, "active": 8, "recovery": 6, "damage": 76, "hitstun": 20, "blockstun": 12, "hitstop": 12, "guard": GameConst.Guard.OVERHEAD, "knockback": 5.0, "hit_offset": Vector3(0.58, 0.42, 0.0), "hit_size": Vector3(0.75, 0.55, 0.7)},
	"air_lk": {"startup": 4, "active": 10, "recovery": 4, "damage": 29, "hitstun": 16, "blockstun": 10, "hitstop": 9, "guard": GameConst.Guard.OVERHEAD, "knockback": 2.9, "hit_offset": Vector3(0.48, 0.18, 0.0), "hit_size": Vector3(0.65, 0.55, 0.65)},
	"air_mk": {"startup": 7, "active": 6, "recovery": 5, "damage": 51, "hitstun": 18, "blockstun": 11, "hitstop": 10, "guard": GameConst.Guard.OVERHEAD, "knockback": 4.1, "hit_offset": Vector3(0.25, 0.18, 0.0), "hit_size": Vector3(0.95, 0.55, 0.7)},
	"air_hk": {"startup": 8, "active": 8, "recovery": 6, "damage": 82, "hitstun": 20, "blockstun": 12, "hitstop": 12, "guard": GameConst.Guard.OVERHEAD, "knockback": 5.3, "hit_offset": Vector3(0.55, 0.18, 0.0), "hit_size": Vector3(0.85, 0.65, 0.7)},
}

static func build() -> CharacterData:
	var c := CharacterData.new()
	c.id = ID
	c.display_name = DISPLAY_NAME
	c.color = Color(0.9, 0.33, 0.13)
	c.accent = Color(1.0, 0.8, 0.25)
	c.blurb = "Fiery rushdown. Ken-inspired normals, jump-ins, Drive Rush pressure, and a multi-hit super."
	c.max_health = 950
	c.walk_speed = 3.6
	c.back_speed = 2.9
	c.jump_velocity = 12.6
	c.model_path = ASSETS + "maskman.fbx"
	c.model_scale = 1.0
	c.model_face_deg = 90.0
	c.rig = _rig()

	CharacterKit.add_standard_normals(c, 0.95, [], NORMAL_CLIPS)
	_apply_move_overrides(c)

	# Super: advancing 5-hit flaming rush.
	c.add_move(CharacterKit.make_move({"id": "super_inferno", "display_name": "Inferno Rush", "kind": GameConst.MoveKind.SUPER,
		"button": GameConst.Btn.HP, "motion": MotionParser.QCF_QCF, "meter_cost": 100,
		"startup": 8, "active": 22, "recovery": 44, "damage": 52, "hits": 5, "hit_gap": 4,
		"hitstun": 18, "blockstun": 16, "chip": 6, "hitstop": 12, "guard": GameConst.Guard.MID,
		"knockback": 1.8, "advance": 7.0, "launch": true, "launch_velocity": 7.0, "meter_gain": 0,
		"sfx": "super", "anim_limb": "leg_r", "anim_extend": 1.0, "anim_clip": "KB_Superpunch",
		"hit_offset": Vector3(1.0, 1.1, 0.0), "hit_size": Vector3(1.1, 1.3, 0.8)}))

	return c

static func _apply_move_overrides(c: CharacterData) -> void:
	for move_id in NORMAL_TUNING.keys():
		var m := c.get_move(move_id)
		var props: Dictionary = NORMAL_TUNING[move_id]
		for key in props.keys():
			if key == "cancel_into":
				m.cancel_into.assign(props[key])
			else:
				m.set(key, props[key])

## Blaze's rig configuration: the Kubold "Maskman" model's animation sources, clip maps,
## materials and directional hit-reaction templates.
static func _rig() -> RigConfig:
	var r := RigConfig.new()
	r.anim_files = [
		ASSETS + "anims/KB_Movement.fbx",
		ASSETS + "anims/KB_Crouched.fbx",
		ASSETS + "anims/KB_Jumping.fbx",
		ASSETS + "anims/KB_Punches.fbx",
		ASSETS + "anims/KB_Kicks.fbx",
		ASSETS + "anims/KB_Blocks.fbx",
		ASSETS + "anims/KB_Hits.fbx",
		ASSETS + "anims/KB_KOs.fbx",
		ASSETS + "anims/KB_Specials.fbx",
	]
	r.lib_name = "kb"
	r.skip_clips = ["BindPose", "tpose", "Take 001"]
	r.root_bones = ["Hips", "Root"]
	r.grounded_clips = []
	r.foot_bones = ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"]
	r.state_clips = {
		"idle": "KB_Idle_1", "walk_f": "KB_WalkFwd1", "walk_b": "KB_WalkBwd",
		"crouch": "KB_crouch_Idle", "jump": "KB_Jump", "dash_f": "KB_SkipFwd_1",
		"dash_b": "KB_SkipBwd_1", "drive_rush": "KB_SkipFwd_2", "block": "KB_Block_Single",
		"hit": "KB_Hit_p_MidFront_Weak", "knockdown": "KB_MidKO", "ko": "KB_HighKO_Powerful",
		"win": "KB_Idle_3",
	}
	r.looped_clips = ["KB_Idle_1", "KB_Idle_3", "KB_WalkFwd1", "KB_WalkBwd", "KB_crouch_Idle"]
	r.default_move_clip = "KB_p_Jab_R_1"
	r.drive_rush_clips = ["KB_SkipFwd_2", "KB_SkipFwd_1", "KB_WalkFwd1"]
	r.surface_textures = {"Cialo": "body", "Glowa": "head", "Eye": "eye", "MaskM": "mask"}
	r.tex_dir = ASSETS + "tex/"
	r.material_roughness = 0.7
	r.lod_keep = "LOD1"
	r.hit_fallback = "KB_Hit_p_MidFront_Weak"
	r.crouch_hit_template = "KB_crouch_Hit_p_Mid%s_Weak"
	r.hit_templates_heavy = ["KB_Hit_m_%s%s_Stagger", "KB_Hit_m_%s%s_Med", "KB_Hit_m_%s%s_Weak", "KB_Hit_p_%s%s_Weak"]
	r.hit_templates_medium = ["KB_Hit_m_%s%s_Med", "KB_Hit_m_%s%s_Weak", "KB_Hit_p_%s%s_Weak"]
	r.hit_templates_light = ["KB_Hit_p_%s%s_Weak", "KB_Hit_m_%s%s_Weak"]
	r.ko_upper = ["KB_UpperKO", "KB_HighKO_Powerful", "KB_MidKO_Powerful"]
	r.ko_low = ["KB_LowKO_R", "KB_LowKO_L", "KB_MidKO"]
	r.ko_air = ["KB_HighKO_Air", "KB_HighKO_Powerful", "KB_MidKO"]
	r.ko_heavy = ["KB_MidKO_Powerful", "KB_MidKO"]
	r.ko_default = "KB_MidKO"
	r.getup_front = ["KB_GetUpBack", "KB_GetUpFace"]
	r.getup_back = ["KB_GetUpFace", "KB_GetUpBack"]
	return r
