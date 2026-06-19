class_name CharacterLibrary
extends RefCounted

## Builds the playable roster in code. Two distinct fighters for the vertical slice:
##   * Kael - balanced all-rounder with a projectile and a rising anti-air.
##   * Rho  - heavy bruiser who closes distance with lunging attacks.
## Each move is a small data dictionary, so this file reads like a tuning sheet.

static func ids() -> Array[String]:
	return ["kael", "rho"]

static func display_name(id: String) -> String:
	match id:
		"kael": return "Kael"
		"rho": return "Rho"
	return id

static func create(id: String) -> CharacterData:
	match id:
		"kael": return _kael()
		"rho": return _rho()
	return _kael()

## --- helpers --------------------------------------------------------------

static func _move(props: Dictionary) -> MoveData:
	var m := MoveData.new()
	for key in props.keys():
		m.set(key, props[key])
	return m

## --- Kael -----------------------------------------------------------------

static func _kael() -> CharacterData:
	var c := CharacterData.new()
	c.id = "kael"
	c.display_name = "Kael"
	c.color = Color(0.25, 0.55, 0.9)
	c.accent = Color(0.95, 0.85, 0.3)
	c.blurb = "Balanced striker. Fireball zones; rising uppercut swats jumps."
	c.max_health = 1000
	c.walk_speed = 3.3
	c.back_speed = 2.7
	c.jump_velocity = 9.6

	c.add_move(_move({"id": "st_lp", "display_name": "Jab", "kind": GameConst.MoveKind.NORMAL,
		"button": GameConst.Btn.LP, "startup": 4, "active": 3, "recovery": 8,
		"damage": 30, "hitstun": 14, "blockstun": 9, "hitstop": 6, "guard": GameConst.Guard.MID,
		"knockback": 1.2, "anim_limb": "arm_r", "anim_extend": 0.45,
		"cancel_into": ["st_hp", "fireball", "uppercut", "super_beam"]}))

	c.add_move(_move({"id": "st_hp", "display_name": "Strong", "kind": GameConst.MoveKind.NORMAL,
		"button": GameConst.Btn.HP, "startup": 8, "active": 4, "recovery": 16,
		"damage": 80, "hitstun": 20, "blockstun": 12, "hitstop": 9, "guard": GameConst.Guard.MID,
		"knockback": 2.2, "anim_limb": "arm_r", "anim_extend": 0.8,
		"cancel_into": ["fireball", "uppercut", "super_beam"]}))

	c.add_move(_move({"id": "cr_lk", "display_name": "Low Kick", "kind": GameConst.MoveKind.NORMAL,
		"button": GameConst.Btn.LK, "crouching": true, "startup": 5, "active": 3, "recovery": 9,
		"damage": 28, "hitstun": 13, "blockstun": 9, "hitstop": 6, "guard": GameConst.Guard.LOW,
		"knockback": 1.0, "anim_limb": "leg_r", "anim_extend": 0.7,
		"cancel_into": ["fireball", "super_beam"]}))

	c.add_move(_move({"id": "st_hk", "display_name": "Round Kick", "kind": GameConst.MoveKind.NORMAL,
		"button": GameConst.Btn.HK, "startup": 11, "active": 4, "recovery": 20,
		"damage": 90, "hitstun": 22, "blockstun": 12, "hitstop": 10, "guard": GameConst.Guard.MID,
		"knockback": 3.0, "launch": true, "launch_velocity": 7.0,
		"anim_limb": "leg_r", "anim_extend": 0.95}))

	c.add_move(_move({"id": "fireball", "display_name": "Plasma Bolt", "kind": GameConst.MoveKind.SPECIAL,
		"button": GameConst.Btn.LP, "motion": MotionParser.QCF, "startup": 12, "active": 2, "recovery": 26,
		"damage": 60, "hitstun": 20, "blockstun": 12, "hitstop": 4, "guard": GameConst.Guard.MID,
		"knockback": 1.5, "meter_gain": 12, "projectile": true, "projectile_speed": 7.5,
		"projectile_life": 100, "anim_limb": "arm_r", "anim_extend": 0.7,
		"hit_size": Vector3(0.6, 0.6, 0.6)}))

	c.add_move(_move({"id": "uppercut", "display_name": "Rising Fang", "kind": GameConst.MoveKind.SPECIAL,
		"button": GameConst.Btn.HP, "motion": MotionParser.DP, "startup": 5, "active": 8, "recovery": 30,
		"damage": 100, "hitstun": 26, "blockstun": 14, "hitstop": 10, "guard": GameConst.Guard.MID,
		"knockback": 1.5, "launch": true, "launch_velocity": 10.0, "meter_gain": 14,
		"anim_limb": "arm_r", "anim_extend": 0.9, "hit_offset": Vector3(0.7, 1.6, 0.0),
		"hit_size": Vector3(0.8, 1.2, 0.7)}))

	c.add_move(_move({"id": "super_beam", "display_name": "Nova Cannon", "kind": GameConst.MoveKind.SUPER,
		"button": GameConst.Btn.HP, "motion": MotionParser.QCF_QCF, "meter_cost": 100,
		"startup": 9, "active": 3, "recovery": 44, "damage": 260, "hitstun": 34, "blockstun": 20,
		"chip": 30, "hitstop": 14, "guard": GameConst.Guard.MID, "knockback": 4.5,
		"projectile": true, "projectile_speed": 9.5, "projectile_life": 120,
		"anim_limb": "arm_r", "anim_extend": 1.0, "hit_size": Vector3(1.0, 1.4, 0.8)}))
	return c

## --- Rho ------------------------------------------------------------------

static func _rho() -> CharacterData:
	var c := CharacterData.new()
	c.id = "rho"
	c.display_name = "Rho"
	c.color = Color(0.85, 0.3, 0.28)
	c.accent = Color(0.95, 0.8, 0.5)
	c.blurb = "Heavy bruiser. Lunges through fireballs to bully up close."
	c.max_health = 1100
	c.walk_speed = 2.9
	c.back_speed = 2.3
	c.jump_velocity = 9.2

	c.add_move(_move({"id": "st_lp", "display_name": "Hook Jab", "kind": GameConst.MoveKind.NORMAL,
		"button": GameConst.Btn.LP, "startup": 5, "active": 3, "recovery": 9,
		"damage": 34, "hitstun": 14, "blockstun": 9, "hitstop": 7, "guard": GameConst.Guard.MID,
		"knockback": 1.3, "anim_limb": "arm_l", "anim_extend": 0.5,
		"cancel_into": ["st_hp", "shoulder", "super_rush"]}))

	c.add_move(_move({"id": "st_hp", "display_name": "Heavy Hook", "kind": GameConst.MoveKind.NORMAL,
		"button": GameConst.Btn.HP, "startup": 9, "active": 4, "recovery": 18,
		"damage": 95, "hitstun": 22, "blockstun": 13, "hitstop": 10, "guard": GameConst.Guard.MID,
		"knockback": 2.6, "anim_limb": "arm_r", "anim_extend": 0.85,
		"cancel_into": ["shoulder", "super_rush"]}))

	c.add_move(_move({"id": "cr_lk", "display_name": "Shin Kick", "kind": GameConst.MoveKind.NORMAL,
		"button": GameConst.Btn.LK, "crouching": true, "startup": 6, "active": 3, "recovery": 10,
		"damage": 30, "hitstun": 13, "blockstun": 9, "hitstop": 6, "guard": GameConst.Guard.LOW,
		"knockback": 1.0, "anim_limb": "leg_r", "anim_extend": 0.7,
		"cancel_into": ["shoulder"]}))

	c.add_move(_move({"id": "st_hk", "display_name": "Spin Kick", "kind": GameConst.MoveKind.NORMAL,
		"button": GameConst.Btn.HK, "startup": 12, "active": 4, "recovery": 22,
		"damage": 95, "hitstun": 22, "blockstun": 12, "hitstop": 10, "guard": GameConst.Guard.MID,
		"knockback": 3.2, "launch": true, "launch_velocity": 6.8,
		"anim_limb": "leg_r", "anim_extend": 0.95}))

	c.add_move(_move({"id": "shoulder", "display_name": "Bull Rush", "kind": GameConst.MoveKind.SPECIAL,
		"button": GameConst.Btn.LK, "motion": MotionParser.QCF, "startup": 10, "active": 6, "recovery": 24,
		"damage": 80, "hitstun": 22, "blockstun": 14, "hitstop": 10, "guard": GameConst.Guard.MID,
		"knockback": 2.5, "advance": 6.5, "meter_gain": 12, "anim_limb": "arm_l", "anim_extend": 0.8,
		"hit_offset": Vector3(1.0, 1.0, 0.0), "hit_size": Vector3(1.0, 0.9, 0.7)}))

	c.add_move(_move({"id": "headbutt", "display_name": "Sky Headbutt", "kind": GameConst.MoveKind.SPECIAL,
		"button": GameConst.Btn.HP, "motion": MotionParser.DP, "startup": 6, "active": 8, "recovery": 32,
		"damage": 95, "hitstun": 24, "blockstun": 14, "hitstop": 10, "guard": GameConst.Guard.MID,
		"knockback": 1.5, "launch": true, "launch_velocity": 9.0, "meter_gain": 14,
		"anim_limb": "arm_r", "anim_extend": 0.6, "hit_offset": Vector3(0.6, 1.7, 0.0),
		"hit_size": Vector3(0.8, 1.1, 0.7)}))

	c.add_move(_move({"id": "super_rush", "display_name": "Titan Charge", "kind": GameConst.MoveKind.SUPER,
		"button": GameConst.Btn.HK, "motion": MotionParser.QCF_QCF, "meter_cost": 100,
		"startup": 8, "active": 6, "recovery": 46, "damage": 280, "hitstun": 36, "blockstun": 20,
		"chip": 34, "hitstop": 14, "guard": GameConst.Guard.MID, "knockback": 5.0, "advance": 9.0,
		"launch": true, "launch_velocity": 8.0, "anim_limb": "arm_l", "anim_extend": 0.9,
		"hit_offset": Vector3(1.1, 1.0, 0.0), "hit_size": Vector3(1.2, 1.2, 0.8)}))
	return c
