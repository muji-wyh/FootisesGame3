class_name CharacterKit
extends RefCounted

## Shared builders for authoring characters in code: the move factory and the standard
## 6-button x 3-stance "system normals". The frame data here is shared across characters;
## each character supplies its own per-normal animation clips via the `clips` map (normal id ->
## clip name), keeping a character's visuals inside its own module.

static func make_move(props: Dictionary) -> MoveData:
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

## Add a full set of 6-button normals in three stances (standing / crouching / air). `dmg_scale`
## weights damage by class; light/medium normals cancel into `cancels` (the character's special
## ids). `clips` maps each normal id to its animation clip name.
static func add_standard_normals(c: CharacterData, dmg_scale: float, cancels: Array, clips: Dictionary) -> void:
	var heavy_cancels := cancels.duplicate()
	var defs := [
		# Standing
		{"id": "st_lp", "display_name": "Stand LP", "button": GameConst.Btn.LP, "stance": GameConst.Stance.STAND,
			"startup": 4, "active": 3, "recovery": 8, "damage": 28,
			"hitstun": 14, "blockstun": 9, "hitstop": 6, "guard": GameConst.Guard.MID, "knockback": 2.5,
			"cancel_into": ["st_lp", "st_mp", "st_hp"] + cancels},
		{"id": "st_mp", "display_name": "Stand MP", "button": GameConst.Btn.MP, "stance": GameConst.Stance.STAND,
			"startup": 6, "active": 3, "recovery": 12, "damage": 50,
			"hitstun": 17, "blockstun": 11, "hitstop": 8, "guard": GameConst.Guard.MID, "knockback": 3.4,
			"cancel_into": ["st_hp"] + cancels},
		{"id": "st_hp", "display_name": "Stand HP", "button": GameConst.Btn.HP, "stance": GameConst.Stance.STAND,
			"startup": 9, "active": 4, "recovery": 18, "damage": 82,
			"hitstun": 21, "blockstun": 13, "hitstop": 10, "guard": GameConst.Guard.MID, "knockback": 5.0,
			"cancel_into": heavy_cancels},
		{"id": "st_lk", "display_name": "Stand LK", "button": GameConst.Btn.LK, "stance": GameConst.Stance.STAND,
			"startup": 5, "active": 3, "recovery": 9, "damage": 30,
			"hitstun": 14, "blockstun": 9, "hitstop": 6, "guard": GameConst.Guard.MID, "knockback": 3.0,
			"cancel_into": ["st_mk"] + cancels},
		{"id": "st_mk", "display_name": "Stand MK", "button": GameConst.Btn.MK, "stance": GameConst.Stance.STAND,
			"startup": 7, "active": 4, "recovery": 14, "damage": 54,
			"hitstun": 18, "blockstun": 11, "hitstop": 8, "guard": GameConst.Guard.MID, "knockback": 4.2,
			"cancel_into": cancels},
		{"id": "st_hk", "display_name": "Stand HK", "button": GameConst.Btn.HK, "stance": GameConst.Stance.STAND,
			"startup": 11, "active": 4, "recovery": 20, "damage": 88,
			"hitstun": 22, "blockstun": 12, "hitstop": 10, "guard": GameConst.Guard.MID, "knockback": 5.6,
			"launch": true, "launch_velocity": 7.0},
		# Crouching
		{"id": "cr_lp", "display_name": "Crouch LP", "button": GameConst.Btn.LP, "stance": GameConst.Stance.CROUCH,
			"startup": 4, "active": 3, "recovery": 8, "damage": 26,
			"hitstun": 13, "blockstun": 9, "hitstop": 6, "guard": GameConst.Guard.MID, "knockback": 2.6,
			"cancel_into": ["cr_lp", "cr_mp", "cr_mk"] + cancels},
		{"id": "cr_mp", "display_name": "Crouch MP", "button": GameConst.Btn.MP, "stance": GameConst.Stance.CROUCH,
			"startup": 6, "active": 3, "recovery": 12, "damage": 48,
			"hitstun": 16, "blockstun": 10, "hitstop": 8, "guard": GameConst.Guard.MID, "knockback": 3.5,
			"cancel_into": cancels},
		{"id": "cr_hp", "display_name": "Crouch HP", "button": GameConst.Btn.HP, "stance": GameConst.Stance.CROUCH,
			"startup": 7, "active": 5, "recovery": 22, "damage": 78,
			"hitstun": 22, "blockstun": 12, "hitstop": 10, "guard": GameConst.Guard.MID, "knockback": 3.8,
			"launch": true, "launch_velocity": 9.0, "hit_offset": Vector3(0.6, 1.5, 0.0), "hit_size": Vector3(0.8, 1.3, 0.7)},
		{"id": "cr_lk", "display_name": "Crouch LK", "button": GameConst.Btn.LK, "stance": GameConst.Stance.CROUCH,
			"startup": 5, "active": 3, "recovery": 9, "damage": 28,
			"hitstun": 13, "blockstun": 9, "hitstop": 6, "guard": GameConst.Guard.LOW, "knockback": 2.7,
			"cancel_into": ["cr_mk"] + cancels},
		{"id": "cr_mk", "display_name": "Crouch MK", "button": GameConst.Btn.MK, "stance": GameConst.Stance.CROUCH,
			"startup": 7, "active": 4, "recovery": 14, "damage": 52,
			"hitstun": 17, "blockstun": 11, "hitstop": 8, "guard": GameConst.Guard.LOW, "knockback": 4.0,
			"cancel_into": cancels},
		{"id": "cr_hk", "display_name": "Sweep", "button": GameConst.Btn.HK, "stance": GameConst.Stance.CROUCH,
			"startup": 9, "active": 4, "recovery": 22, "damage": 80,
			"hitstun": 20, "blockstun": 12, "hitstop": 10, "guard": GameConst.Guard.LOW, "knockback": 4.8,
			"launch": true, "launch_velocity": 5.5},
		# Air (jump-ins; overheads). Long active windows so the hitbox stays out through the
		# fall; hitboxes sit low/large to reach a grounded opponent.
		{"id": "air_lp", "display_name": "Air LP", "button": GameConst.Btn.LP, "stance": GameConst.Stance.AIR,
			"startup": 3, "active": 16, "recovery": 4, "damage": 28,
			"hitstun": 16, "blockstun": 10, "hitstop": 6, "guard": GameConst.Guard.OVERHEAD, "knockback": 2.8,
			"hit_offset": Vector3(0.6, 0.4, 0.0), "hit_size": Vector3(0.9, 1.1, 0.7)},
		{"id": "air_mp", "display_name": "Air MP", "button": GameConst.Btn.MP, "stance": GameConst.Stance.AIR,
			"startup": 5, "active": 15, "recovery": 5, "damage": 50,
			"hitstun": 18, "blockstun": 11, "hitstop": 8, "guard": GameConst.Guard.OVERHEAD, "knockback": 3.8,
			"hit_offset": Vector3(0.7, 0.5, 0.0), "hit_size": Vector3(1.0, 1.1, 0.7)},
		{"id": "air_hp", "display_name": "Air HP", "button": GameConst.Btn.HP, "stance": GameConst.Stance.AIR,
			"startup": 7, "active": 15, "recovery": 6, "damage": 80,
			"hitstun": 20, "blockstun": 12, "hitstop": 10, "guard": GameConst.Guard.OVERHEAD, "knockback": 5.0,
			"hit_offset": Vector3(0.7, 0.5, 0.0), "hit_size": Vector3(1.0, 1.2, 0.7)},
		{"id": "air_lk", "display_name": "Air LK", "button": GameConst.Btn.LK, "stance": GameConst.Stance.AIR,
			"startup": 4, "active": 16, "recovery": 4, "damage": 30,
			"hitstun": 16, "blockstun": 10, "hitstop": 6, "guard": GameConst.Guard.OVERHEAD, "knockback": 2.9,
			"hit_offset": Vector3(0.6, 0.3, 0.0), "hit_size": Vector3(0.9, 1.2, 0.7)},
		{"id": "air_mk", "display_name": "Air MK", "button": GameConst.Btn.MK, "stance": GameConst.Stance.AIR,
			"startup": 6, "active": 15, "recovery": 5, "damage": 54,
			"hitstun": 18, "blockstun": 11, "hitstop": 8, "guard": GameConst.Guard.OVERHEAD, "knockback": 4.1,
			"hit_offset": Vector3(0.7, 0.4, 0.0), "hit_size": Vector3(1.0, 1.2, 0.7)},
		{"id": "air_hk", "display_name": "Air HK", "button": GameConst.Btn.HK, "stance": GameConst.Stance.AIR,
			"startup": 8, "active": 15, "recovery": 6, "damage": 86,
			"hitstun": 20, "blockstun": 12, "hitstop": 10, "guard": GameConst.Guard.OVERHEAD, "knockback": 5.3,
			"hit_offset": Vector3(0.7, 0.2, 0.0), "hit_size": Vector3(1.0, 1.4, 0.7)},
	]
	for d in defs:
		var props: Dictionary = d.duplicate()
		props["kind"] = GameConst.MoveKind.NORMAL
		props["damage"] = int(round(float(props["damage"]) * dmg_scale))
		props["anim_clip"] = String(clips.get(d["id"], ""))
		c.add_move(make_move(props))
