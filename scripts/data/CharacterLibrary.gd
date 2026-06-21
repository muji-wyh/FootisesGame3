class_name CharacterLibrary
extends RefCounted

## Builds the playable roster in code. The slice ships a single fighter:
##   * Blaze - fiery rushdown shoto (fireball, anti-air uppercut, multi-hit hurricane
##     kick, and a multi-hit super).
## Each move is a small data dictionary, so this file reads like a tuning sheet.

static func ids() -> Array[String]:
	return ["blaze"]

static func display_name(id: String) -> String:
	match id:
		"blaze": return "Blaze"
	return id

static func create(_id: String) -> CharacterData:
	return _blaze()

## --- helpers --------------------------------------------------------------

static func _move(props: Dictionary) -> MoveData:
	var m := MoveData.new()
	for key in props.keys():
		# Typed-array properties (Array[String]/Array[int]) must be filled with assign():
		# Object.set() silently drops an untyped Array source, leaving the property empty.
		if key == "cancel_into":
			m.cancel_into.assign(props[key])
		elif key == "motion":
			m.motion.assign(props[key])
		else:
			m.set(key, props[key])
	return m

## Adds a full set of 6-button normals in three stances (standing / crouching / air) to a
## character, mapped to Kubold clips. Shared "system" normals keep each character's data
## focused on its specials. `dmg_scale` weights damage by class; light/medium normals
## cancel into `cancels` (the character's special ids).
static func _add_standard_normals(c: CharacterData, dmg_scale: float, cancels: Array) -> void:
	var heavy_cancels := cancels.duplicate()
	var defs := [
		# Standing
		{"id": "st_lp", "display_name": "Stand LP", "button": GameConst.Btn.LP, "stance": GameConst.Stance.STAND,
			"anim_clip": "KB_p_Jab_R_1", "startup": 4, "active": 3, "recovery": 8, "damage": 28,
			"hitstun": 14, "blockstun": 9, "hitstop": 6, "guard": GameConst.Guard.MID, "knockback": 1.1,
			"cancel_into": ["st_lp", "st_mp", "st_hp"] + cancels},
		{"id": "st_mp", "display_name": "Stand MP", "button": GameConst.Btn.MP, "stance": GameConst.Stance.STAND,
			"anim_clip": "KB_m_Uppercut_L", "startup": 6, "active": 3, "recovery": 12, "damage": 50,
			"hitstun": 17, "blockstun": 11, "hitstop": 8, "guard": GameConst.Guard.MID, "knockback": 1.6,
			"cancel_into": ["st_hp"] + cancels},
		{"id": "st_hp", "display_name": "Stand HP", "button": GameConst.Btn.HP, "stance": GameConst.Stance.STAND,
			"anim_clip": "KB_m_Overhand_R", "startup": 9, "active": 4, "recovery": 18, "damage": 82,
			"hitstun": 21, "blockstun": 13, "hitstop": 10, "guard": GameConst.Guard.MID, "knockback": 2.4,
			"cancel_into": heavy_cancels},
		{"id": "st_lk", "display_name": "Stand LK", "button": GameConst.Btn.LK, "stance": GameConst.Stance.STAND,
			"anim_clip": "KB_p_LowKick_R_1", "startup": 5, "active": 3, "recovery": 9, "damage": 30,
			"hitstun": 14, "blockstun": 9, "hitstop": 6, "guard": GameConst.Guard.MID, "knockback": 1.2,
			"cancel_into": ["st_mk"] + cancels},
		{"id": "st_mk", "display_name": "Stand MK", "button": GameConst.Btn.MK, "stance": GameConst.Stance.STAND,
			"anim_clip": "KB_m_MidKick_R", "startup": 7, "active": 4, "recovery": 14, "damage": 54,
			"hitstun": 18, "blockstun": 11, "hitstop": 8, "guard": GameConst.Guard.MID, "knockback": 1.8,
			"cancel_into": cancels},
		{"id": "st_hk", "display_name": "Stand HK", "button": GameConst.Btn.HK, "stance": GameConst.Stance.STAND,
			"anim_clip": "KB_m_HighKickRound_R_1", "startup": 11, "active": 4, "recovery": 20, "damage": 88,
			"hitstun": 22, "blockstun": 12, "hitstop": 10, "guard": GameConst.Guard.MID, "knockback": 3.0,
			"launch": true, "launch_velocity": 7.0},
		# Crouching
		{"id": "cr_lp", "display_name": "Crouch LP", "button": GameConst.Btn.LP, "stance": GameConst.Stance.CROUCH,
			"anim_clip": "KB_crouch_p_Jab_L", "startup": 4, "active": 3, "recovery": 8, "damage": 26,
			"hitstun": 13, "blockstun": 9, "hitstop": 6, "guard": GameConst.Guard.MID, "knockback": 1.0,
			"cancel_into": ["cr_lp", "cr_mp", "cr_mk"] + cancels},
		{"id": "cr_mp", "display_name": "Crouch MP", "button": GameConst.Btn.MP, "stance": GameConst.Stance.CROUCH,
			"anim_clip": "KB_crouch_p_Jab_R", "startup": 6, "active": 3, "recovery": 12, "damage": 48,
			"hitstun": 16, "blockstun": 10, "hitstop": 8, "guard": GameConst.Guard.MID, "knockback": 1.4,
			"cancel_into": cancels},
		{"id": "cr_hp", "display_name": "Crouch HP", "button": GameConst.Btn.HP, "stance": GameConst.Stance.CROUCH,
			"anim_clip": "KB_crouch_p_Uppercut_R", "startup": 7, "active": 5, "recovery": 22, "damage": 78,
			"hitstun": 22, "blockstun": 12, "hitstop": 10, "guard": GameConst.Guard.MID, "knockback": 1.4,
			"launch": true, "launch_velocity": 9.0, "hit_offset": Vector3(0.6, 1.5, 0.0), "hit_size": Vector3(0.8, 1.3, 0.7)},
		{"id": "cr_lk", "display_name": "Crouch LK", "button": GameConst.Btn.LK, "stance": GameConst.Stance.CROUCH,
			"anim_clip": "KB_crouch_p_LowKick_L", "startup": 5, "active": 3, "recovery": 9, "damage": 28,
			"hitstun": 13, "blockstun": 9, "hitstop": 6, "guard": GameConst.Guard.LOW, "knockback": 1.0,
			"cancel_into": ["cr_mk"] + cancels},
		{"id": "cr_mk", "display_name": "Crouch MK", "button": GameConst.Btn.MK, "stance": GameConst.Stance.CROUCH,
			"anim_clip": "KB_crouch_p_LowKickRound_R", "startup": 7, "active": 4, "recovery": 14, "damage": 52,
			"hitstun": 17, "blockstun": 11, "hitstop": 8, "guard": GameConst.Guard.LOW, "knockback": 1.6,
			"cancel_into": cancels},
		{"id": "cr_hk", "display_name": "Sweep", "button": GameConst.Btn.HK, "stance": GameConst.Stance.CROUCH,
			"anim_clip": "KB_crouch_p_LowKickRound_R", "startup": 9, "active": 4, "recovery": 22, "damage": 80,
			"hitstun": 20, "blockstun": 12, "hitstop": 10, "guard": GameConst.Guard.LOW, "knockback": 2.0,
			"launch": true, "launch_velocity": 5.5},
		# Air (jump-ins; overheads that must be stand-blocked)
		# Air (jump-ins; overheads). Long active windows so the hitbox stays out through the
		# fall; hitboxes sit low/large to reach a grounded opponent. Distinct L/M/H clips.
		{"id": "air_lp", "display_name": "Air LP", "button": GameConst.Btn.LP, "stance": GameConst.Stance.AIR,
			"anim_clip": "KB_JumpPunch", "startup": 3, "active": 16, "recovery": 4, "damage": 28,
			"hitstun": 16, "blockstun": 10, "hitstop": 6, "guard": GameConst.Guard.OVERHEAD, "knockback": 1.0,
			"hit_offset": Vector3(0.6, 0.4, 0.0), "hit_size": Vector3(0.9, 1.1, 0.7)},
		{"id": "air_mp", "display_name": "Air MP", "button": GameConst.Btn.MP, "stance": GameConst.Stance.AIR,
			"anim_clip": "KB_m_Hook_R", "startup": 5, "active": 15, "recovery": 5, "damage": 50,
			"hitstun": 18, "blockstun": 11, "hitstop": 8, "guard": GameConst.Guard.OVERHEAD, "knockback": 1.4,
			"hit_offset": Vector3(0.7, 0.5, 0.0), "hit_size": Vector3(1.0, 1.1, 0.7)},
		{"id": "air_hp", "display_name": "Air HP", "button": GameConst.Btn.HP, "stance": GameConst.Stance.AIR,
			"anim_clip": "KB_m_Overhand_R", "startup": 7, "active": 15, "recovery": 6, "damage": 80,
			"hitstun": 20, "blockstun": 12, "hitstop": 10, "guard": GameConst.Guard.OVERHEAD, "knockback": 2.0,
			"hit_offset": Vector3(0.7, 0.5, 0.0), "hit_size": Vector3(1.0, 1.2, 0.7)},
		{"id": "air_lk", "display_name": "Air LK", "button": GameConst.Btn.LK, "stance": GameConst.Stance.AIR,
			"anim_clip": "KB_JumpKick", "startup": 4, "active": 16, "recovery": 4, "damage": 30,
			"hitstun": 16, "blockstun": 10, "hitstop": 6, "guard": GameConst.Guard.OVERHEAD, "knockback": 1.1,
			"hit_offset": Vector3(0.6, 0.3, 0.0), "hit_size": Vector3(0.9, 1.2, 0.7)},
		{"id": "air_mk", "display_name": "Air MK", "button": GameConst.Btn.MK, "stance": GameConst.Stance.AIR,
			"anim_clip": "KB_m_HighKickRound_R_1", "startup": 6, "active": 15, "recovery": 5, "damage": 54,
			"hitstun": 18, "blockstun": 11, "hitstop": 8, "guard": GameConst.Guard.OVERHEAD, "knockback": 1.6,
			"hit_offset": Vector3(0.7, 0.4, 0.0), "hit_size": Vector3(1.0, 1.2, 0.7)},
		{"id": "air_hk", "display_name": "Air HK", "button": GameConst.Btn.HK, "stance": GameConst.Stance.AIR,
			"anim_clip": "KB_AxeKick", "startup": 8, "active": 15, "recovery": 6, "damage": 86,
			"hitstun": 20, "blockstun": 12, "hitstop": 10, "guard": GameConst.Guard.OVERHEAD, "knockback": 2.2,
			"hit_offset": Vector3(0.7, 0.2, 0.0), "hit_size": Vector3(1.0, 1.4, 0.7)},
	]
	for d in defs:
		var props: Dictionary = d.duplicate()
		props["kind"] = GameConst.MoveKind.NORMAL
		props["damage"] = int(round(float(props["damage"]) * dmg_scale))
		c.add_move(_move(props))

## --- Blaze ----------------------------------------------------------------
## Aggressive fiery shoto (Ken-style archetype): a fireball, a rising flame uppercut, a
## multi-hit hurricane kick and a multi-hit super. Original names and assets only.

static func _blaze() -> CharacterData:
	var c := CharacterData.new()
	c.id = "blaze"
	c.display_name = "Blaze"
	c.color = Color(0.9, 0.33, 0.13)
	c.accent = Color(1.0, 0.8, 0.25)
	c.blurb = "Fiery rushdown. Fireball, anti-air uppercut, and a spinning multi-hit kick."
	c.max_health = 950
	c.walk_speed = 3.6
	c.back_speed = 2.9
	c.jump_velocity = 9.8
	c.model_path = "res://assets/models/maskman.fbx"
	c.model_face_deg = 90.0

	_add_standard_normals(c, 0.95, ["fireball", "uppercut", "hurricane", "super_inferno"])

	c.add_move(_move({"id": "fireball", "display_name": "Flare Bolt", "kind": GameConst.MoveKind.SPECIAL,
		"button": GameConst.Btn.LP, "motion": MotionParser.QCF, "startup": 11, "active": 2, "recovery": 24,
		"damage": 55, "hitstun": 18, "blockstun": 12, "hitstop": 4, "guard": GameConst.Guard.MID,
		"knockback": 1.5, "meter_gain": 12, "projectile": true, "projectile_speed": 8.0,
		"projectile_life": 100, "sfx": "fire", "anim_limb": "arm_r", "anim_extend": 0.7,
		"anim_clip": "KB_Projectile_4", "hit_size": Vector3(0.6, 0.6, 0.6)}))

	# Rising uppercut: 2-hit anti-air launcher.
	c.add_move(_move({"id": "uppercut", "display_name": "Blaze Rise", "kind": GameConst.MoveKind.SPECIAL,
		"button": GameConst.Btn.HP, "motion": MotionParser.DP, "startup": 5, "active": 10, "recovery": 30,
		"damage": 60, "hits": 2, "hit_gap": 5, "hitstun": 22, "blockstun": 14, "hitstop": 9,
		"guard": GameConst.Guard.MID, "knockback": 1.2, "launch": true, "launch_velocity": 10.0,
		"meter_gain": 8, "sfx": "rising", "anim_limb": "arm_r", "anim_extend": 0.9, "anim_clip": "KB_crouch_m_Uppercut_R_2",
		"rises": true, "rise_height": 1.3, "hit_offset": Vector3(0.7, 1.0, 0.0), "hit_size": Vector3(0.8, 1.7, 0.7)}))

	# Hurricane kick: advancing 3-hit. Low knockback per hit so the victim stays in range.
	c.add_move(_move({"id": "hurricane", "display_name": "Cyclone Kick", "kind": GameConst.MoveKind.SPECIAL,
		"button": GameConst.Btn.LK, "motion": MotionParser.QCB, "startup": 9, "active": 20, "recovery": 22,
		"damage": 35, "hits": 3, "hit_gap": 6, "hitstun": 16, "blockstun": 12, "hitstop": 6,
		"guard": GameConst.Guard.MID, "knockback": 1.0, "advance": 5.0, "meter_gain": 8,
		"sfx": "spin", "anim_limb": "leg_r", "anim_extend": 0.95, "anim_clip": "KB_m_RoundhouseKickRight",
		"hit_offset": Vector3(0.9, 1.0, 0.0), "hit_size": Vector3(1.0, 1.1, 0.7)}))

	# Super: advancing 5-hit flaming rush.
	c.add_move(_move({"id": "super_inferno", "display_name": "Inferno Rush", "kind": GameConst.MoveKind.SUPER,
		"button": GameConst.Btn.HP, "motion": MotionParser.QCF_QCF, "meter_cost": 100,
		"startup": 8, "active": 22, "recovery": 44, "damage": 52, "hits": 5, "hit_gap": 4,
		"hitstun": 18, "blockstun": 16, "chip": 6, "hitstop": 8, "guard": GameConst.Guard.MID,
		"knockback": 1.3, "advance": 7.0, "launch": true, "launch_velocity": 7.0, "meter_gain": 0,
		"sfx": "super", "anim_limb": "leg_r", "anim_extend": 1.0, "anim_clip": "KB_Superpunch",
		"hit_offset": Vector3(1.0, 1.1, 0.0), "hit_size": Vector3(1.1, 1.3, 0.8)}))
	return c
