extends SceneTree

## Headless test harness for the combat simulation. Run with:
##   godot --headless --script res://tools/run_tests.gd
## Scripts inputs into the Arena and asserts outcomes (movement, hits, blocking,
## hitstun, projectiles, meter, supers, KO). Prints a PASS/FAIL summary.

const DELTA := 1.0 / 60.0

class Manual extends InputController:
	var frame := InputFrame.new()
	func poll(_s: Object, _o: Object) -> InputFrame:
		return frame.duplicate_frame()

class SpyRig extends Node:
	var pose_count := 0
	func pose(_fighter: Object) -> void:
		pose_count += 1

var _passed := 0
var _failed := 0

func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  PASS: ", label)
	else:
		_failed += 1
		print("  FAIL: ", label)

func _mk(dx: int, dy: int, press: int = 0, held: int = -1) -> InputFrame:
	if held == -1:
		held = press
	return InputFrame.new(dx, dy, held, press)

func _build(id1: String = "blaze", id2: String = "blaze") -> Dictionary:
	var arena := Arena.new()
	root.add_child(arena)
	var c1 := Manual.new()
	var c2 := Manual.new()
	var f1 := Fighter.new()
	var f2 := Fighter.new()
	f1.setup(CharacterLibrary.create(id1), c1, GameConst.Side.P1, -2.4)
	f2.setup(CharacterLibrary.create(id2), c2, GameConst.Side.P2, 2.4)
	arena.setup_fighters(f1, f2)
	arena.set_active(true)
	return {"arena": arena, "f1": f1, "f2": f2, "c1": c1, "c2": c2}

func _step(ctx: Dictionary, p1: InputFrame, p2: InputFrame, n: int) -> void:
	for i in range(n):
		ctx["c1"].frame = p1
		ctx["c2"].frame = p2
		ctx["arena"].step(DELTA)

func _step_round(ctx: Dictionary, rm: RoundManager, p1: InputFrame, p2: InputFrame, n: int) -> void:
	for i in range(n):
		ctx["c1"].frame = p1
		ctx["c2"].frame = p2
		rm.tick(DELTA)

func _neutral() -> InputFrame:
	return _mk(0, 0)

func _find_move(ch: CharacterData, id: String) -> MoveData:
	for m in ch.normals:
		if m.id == id:
			return m
	for m in ch.specials:
		if m.id == id:
			return m
	for m in ch.supers:
		if m.id == id:
			return m
	return null

## Tip reach of a grounded normal (button identity tests). Uses the same metric as the
## existing range tests: hitbox centre offset plus half its width.
func _reach(m: MoveData) -> float:
	return m.hit_offset.x + m.hit_size.x * 0.5

## True if P1 pressing `button` (with optional `dy` for crouch/jump) connects on an idle,
## non-blocking P2 standing `separation` apart. Builds and tears down its own arena.
func _hits_at(button: int, dy: int, separation: float) -> bool:
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -separation * 0.5
	f2.position.x = separation * 0.5
	var hp_before: int = f2.health
	_step(ctx, _mk(0, dy, button), _neutral(), 1)
	_step(ctx, _neutral(), _neutral(), 24)
	var hit := f2.health < hp_before
	ctx["arena"].queue_free()
	return hit

## Feed P1 a quarter-circle-forward then `button` (down, down-forward, forward+button),
## P2 neutral. `button == 0` performs the motion only (for chaining a double-QCF super).
func _p1_qcf(ctx: Dictionary, button: int) -> void:
	_step(ctx, _mk(0, -1), _neutral(), 2)
	_step(ctx, _mk(1, -1), _neutral(), 2)
	_step(ctx, _mk(1, 0, button), _neutral(), 1)

func _initialize() -> void:
	print("=== Brawl Arena combat tests ===")
	_test_walk()
	_test_pushbox_spacing()
	_test_visible_spacing_limit()
	_test_stage_width_split()
	_test_normal_hit()
	_test_lp_whiff_range()
	_test_blaze_mp_hp_range()
	_test_blaze_button_roles()
	_test_footsies_scenarios()
	_test_block()
	_test_lp_pushout()
	_test_corner_hit_pushback()
	_test_pushback_scaling()
	_test_specials_removed()
	_test_super()
	_test_ko()
	_test_round_flow()
	_test_airborne_winner_lands()
	_test_airborne_match_winner_lands()
	_test_timeout_draw()
	_test_cpu_ai()
	_test_training_mode()
	_test_blaze_roster()
	_test_animation_ownership()
	_test_move_list_overlay()
	_test_multihit()
	_test_move_sfx()
	_test_animated_rig()
	_test_six_buttons()
	_test_dash()
	_test_air_attack()
	_test_jump_in()
	_test_jump_crossup()
	_test_air_hitbox_tuning()
	_test_air_clips_distinct()
	_test_hit_strength()
	_test_kb_library()
	_test_counter()
	_test_punish_counter()
	_test_counter_clean_hit()
	_test_knockdown_kinds()
	_test_wakeup()
	_test_reaction_clips()
	_test_hitstop_tiers()
	_test_impact_fx_smoke()
	_test_slowmo_director()
	_test_combo()
	_test_blaze_combo_expansion()
	_test_drive_gauge()
	_test_drive_rush()
	_test_uppercut_rise()
	_test_camera()
	_test_input_buffer()
	_test_overdrive()
	_test_combo_scaling()
	_test_burnout()
	_test_drive_rush_carry()
	_test_system_amplifies_neutral()
	_test_hud_combo_and_fx()
	print("=== Results: %d passed, %d failed ===" % [_passed, _failed])
	if _failed == 0:
		print("ALL TESTS PASSED")
	else:
		print("THERE WERE FAILURES")
	quit()

func _test_walk() -> void:
	print("[walk]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var start_x: float = f1.position.x
	# P1 holds forward (toward P2 on the right).
	_step(ctx, _mk(1, 0), _neutral(), 30)
	_check("P1 walks forward", f1.position.x > start_x + 0.5)
	ctx["arena"].queue_free()

func _test_pushbox_spacing() -> void:
	print("[pushbox spacing]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = 0.0
	f2.position.x = 0.0
	_step(ctx, _neutral(), _neutral(), 1)
	_check("fighters can stand closer than the old wide pushbox", f2.position.x - f1.position.x <= 0.72)
	ctx["arena"].queue_free()

func _test_visible_spacing_limit() -> void:
	print("[visible spacing clamp]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -Arena.FIGHT_BOUNDS_HALF_WIDTH
	f2.position.x = Arena.FIGHT_BOUNDS_HALF_WIDTH
	_step(ctx, _neutral(), _neutral(), 1)
	_check("arena clamps fighter separation to the camera-safe max", f2.position.x - f1.position.x <= Arena.MAX_VISIBLE_SEPARATION + 0.01)
	ctx["arena"].queue_free()

func _test_stage_width_split() -> void:
	print("[stage width split]")
	_check("visual stage wider than playable fighter bounds", Arena.VISUAL_STAGE_HALF_WIDTH > Arena.FIGHT_BOUNDS_HALF_WIDTH)

func _test_normal_hit() -> void:
	print("[normal hit]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	# Place them within jab range.
	f1.position.x = -0.38
	f2.position.x = 0.38
	var hp_before: int = f2.health
	_step(ctx, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)
	_step(ctx, _neutral(), _neutral(), 20)
	_check("P2 took jab damage", f2.health < hp_before)
	_check("P1 gained meter on hit", f1.meter > 0)
	ctx["arena"].queue_free()

func _test_lp_whiff_range() -> void:
	print("[lp whiff range]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.8
	f2.position.x = 0.8
	var hp_before: int = f2.health
	_step(ctx, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)
	_step(ctx, _neutral(), _neutral(), 20)
	_check("stand LP whiffs outside fist range", f2.health == hp_before)
	ctx["arena"].queue_free()

func _test_blaze_mp_hp_range() -> void:
	print("[blaze mp/hp range]")
	var blaze := CharacterLibrary.create("blaze")
	var st_mp := blaze.get_move("st_mp")
	var st_hp := blaze.get_move("st_hp")
	var st_lk := blaze.get_move("st_lk")
	var st_mk := blaze.get_move("st_mk")
	var st_hk := blaze.get_move("st_hk")
	var cr_lk := blaze.get_move("cr_lk")
	var cr_mk := blaze.get_move("cr_mk")
	var cr_hk := blaze.get_move("cr_hk")
	_check("stand MP hitbox is tighter than the stock default", st_mp.hit_offset.x < 0.9 and st_mp.hit_size.x < 0.9)
	_check("stand HP hitbox is tighter than the stock default", st_hp.hit_size.x < 0.9)
	_check("stand HP still reaches farther than stand MP", st_hp.hit_offset.x + st_hp.hit_size.x * 0.5 > st_mp.hit_offset.x + st_mp.hit_size.x * 0.5)
	_check("stand LK/MK/HK ranges scale up light -> medium -> heavy",
		st_lk.hit_offset.x + st_lk.hit_size.x * 0.5 < st_mk.hit_offset.x + st_mk.hit_size.x * 0.5
		and st_mk.hit_offset.x + st_mk.hit_size.x * 0.5 < st_hk.hit_offset.x + st_hk.hit_size.x * 0.5)
	_check("crouch LK/MK/HK ranges scale up light -> medium -> heavy",
		cr_lk.hit_offset.x + cr_lk.hit_size.x * 0.5 < cr_mk.hit_offset.x + cr_mk.hit_size.x * 0.5
		and cr_mk.hit_offset.x + cr_mk.hit_size.x * 0.5 < cr_hk.hit_offset.x + cr_hk.hit_size.x * 0.5)

## Footsies-first button identity (see docs/footsies-design.md). Asserts the *role*
## relationships between Blaze's grounded normals, not only raw frame/range numbers, so a
## tuning pass that quietly erases a button's job fails here. Roles:
##   st.MK = mid-range ruler; st.MP / cr.MK = variations; st.HP / st.HK / cr.HK = commit reads.
func _test_blaze_button_roles() -> void:
	print("[blaze button roles]")
	var blaze := CharacterLibrary.create("blaze")
	var st_mp := blaze.get_move("st_mp")
	var st_mk := blaze.get_move("st_mk")
	var cr_mk := blaze.get_move("cr_mk")
	var st_hp := blaze.get_move("st_hp")
	var st_hk := blaze.get_move("st_hk")
	var cr_hk := blaze.get_move("cr_hk")
	# Ruler: st.MK out-reaches every other medium grounded normal.
	_check("st.MK is the longest-reaching medium (the spacing ruler)",
		_reach(st_mk) > _reach(st_mp) and _reach(st_mk) > _reach(cr_mk))
	# st.MK is a pure neutral poke: other buttons are tuned around it, so it has no cancels.
	_check("st.MK has no cancel routes (a pure neutral poke)", st_mk.cancel_into.is_empty())
	# st.MP is a closer, forward-pressure variation, kept distinct from the ruler.
	_check("st.MP is closer than st.MK (step-in variation)", _reach(st_mp) < _reach(st_mk))
	_check("st.MP walks forward (advance) where st.MK holds its ground",
		st_mp.advance > st_mk.advance)
	_check("st.MP feeds pressure/combo routes that st.MK does not",
		not st_mp.cancel_into.is_empty())
	# cr.MK is a low-threat variation, not a second ruler: it must not out-range st.MK.
	_check("cr.MK is a low", cr_mk.guard == GameConst.Guard.LOW)
	_check("cr.MK does not out-range st.MK (variation, not ruler)", _reach(cr_mk) < _reach(st_mk))
	# Heavies: more reward, but clearly more committal than the medium pokes.
	var max_medium_recovery: int = maxi(st_mk.recovery, maxi(st_mp.recovery, cr_mk.recovery))
	var min_medium_damage: int = mini(st_mk.damage, mini(st_mp.damage, cr_mk.damage))
	for heavy in [st_hp, st_hk, cr_hk]:
		_check("%s hits harder than the medium pokes" % heavy.id, heavy.damage > min_medium_damage)
		_check("%s is more committal (longer recovery) than the mediums" % heavy.id,
			heavy.recovery > max_medium_recovery)
	# st.HK is the longest grounded callout / whiff-punish button.
	_check("st.HK is the longest-reaching grounded read button",
		_reach(st_hk) > _reach(st_hp) and _reach(st_hk) > _reach(cr_hk) and _reach(st_hk) > _reach(st_mk))

## Live footsies scenarios (the automatable part of the targeted playtest pass): the ruler
## out-spaces its variation, the low variation beats a standing guard, and a committal heavy
## is whiff-punishable. The subjective "feel" pass is a manual checklist in docs/footsies-design.md.
func _test_footsies_scenarios() -> void:
	print("[footsies scenarios]")
	# 1. st.MK-led neutral: there is a spacing where st.MK connects but st.MP whiffs.
	var ruler_out_spaces := false
	var step := 8
	while step <= 24:
		var sep := step * 0.1
		if _hits_at(GameConst.Btn.MK, 0, sep) and not _hits_at(GameConst.Btn.MP, 0, sep):
			ruler_out_spaces = true
			break
		step += 1
	_check("st.MK reaches a spacing where st.MP whiffs (ruler out-spaces the closer variation)",
		ruler_out_spaces)

	# 2. cr.MK low threat: it beats a STANDING guard where the mid ruler st.MK is blocked.
	var low := _build()
	var la: Fighter = low["f1"]
	var lb: Fighter = low["f2"]
	la.position.x = -0.45
	lb.position.x = 0.45
	var lb_hp0: int = lb.health
	var low_hit := false
	for i in range(24):
		# P1 throws cr.MK (down + MK) on frame 0; P2 holds back while STANDING (dir_y 0).
		low["c1"].frame = _mk(0, -1, GameConst.Btn.MK) if i == 0 else _mk(0, -1)
		low["c2"].frame = _mk(1, 0)
		low["arena"].step(DELTA)
		if lb.state == Fighter.State.HITSTUN:
			low_hit = true
	_check("cr.MK (low) beats a standing guard", low_hit and lb.health < lb_hp0)
	low["arena"].queue_free()

	var mid := _build()
	var ma: Fighter = mid["f1"]
	var mb: Fighter = mid["f2"]
	ma.position.x = -0.45
	mb.position.x = 0.45
	var mb_hp0: int = mb.health
	var mid_blocked := false
	for i in range(24):
		# Same standing guard stops st.MK because it is a mid, not a low.
		mid["c1"].frame = _mk(0, 0, GameConst.Btn.MK) if i == 0 else _neutral()
		mid["c2"].frame = _mk(1, 0)
		mid["arena"].step(DELTA)
		if mb.state == Fighter.State.BLOCKSTUN:
			mid_blocked = true
	_check("st.MK (mid) is stopped by the same standing guard", mid_blocked and mb.health == mb_hp0)
	mid["arena"].queue_free()

	# 3. Heavy whiff punishability: a whiffed st.HK is stuck long enough to be jab-punished.
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	var kinds := [GameConst.Counter.NONE]
	f2.countered.connect(func(k): kinds[0] = k)
	f1.position.x = -3.0
	f2.position.x = 0.0
	var f2_hp0: int = f2.health
	_step(ctx, _neutral(), _mk(0, 0, GameConst.Btn.HK), 1)
	_step(ctx, _neutral(), _neutral(), 16)
	_check("whiffed heavy (st.HK) is stuck in recovery",
		f2.state == Fighter.State.ATTACK and f2.current_move != null and f2.current_move.is_recovering(f2.state_frame))
	f1.position.x = -0.84
	f2.position.x = 0.0
	_step(ctx, _mk(0, 0, GameConst.Btn.LP), _neutral(), 7)
	_check("a fast normal whiff-punishes the committal heavy", f2.health < f2_hp0)
	_check("the heavy whiff punish registers as a punish counter", kinds[0] == GameConst.Counter.PUNISH)
	ctx["arena"].queue_free()


func _test_block() -> void:
	print("[block]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.45
	f2.position.x = 0.45
	var hp_before: int = f2.health
	var start_sep: float = f2.position.x - f1.position.x
	var saw_blockstun := false
	# P2 holds back (away from P1, i.e. to the right = +1) while P1 jabs.
	for i in range(20):
		ctx["c1"].frame = _mk(0, 0, GameConst.Btn.LP) if i == 0 else _mk(0, 0)
		ctx["c2"].frame = _mk(1, 0)
		ctx["arena"].step(DELTA)
		if f2.state == Fighter.State.BLOCKSTUN:
			saw_blockstun = true
	_check("blocked jab deals no life damage (chip 0)", f2.health == hp_before)
	_check("P2 entered blockstun", saw_blockstun)
	_check("blocked jab creates spacing", f2.position.x - f1.position.x > start_sep + 0.35)
	ctx["arena"].queue_free()

func _test_pushback_scaling() -> void:
	print("[pushback tuning]")
	var b := CharacterLibrary.create("blaze")
	_check("stand jab knockback increased", b.get_move("st_lp").knockback >= 3.2)
	_check("stand jab recovery slowed slightly", b.get_move("st_lp").recovery >= 9)
	_check("stand medium pushes farther than jab", b.get_move("st_mp").knockback > b.get_move("st_lp").knockback)
	_check("stand heavy pushes farther than medium", b.get_move("st_hp").knockback > b.get_move("st_mp").knockback)
	_check("crouch medium pushes farther than crouch jab", b.get_move("cr_mk").knockback > b.get_move("cr_lp").knockback)
	_check("stand MP routes into Ken-like target combo", b.get_move("st_mp").cancel_into.has("st_hp"))
	_check("lights route into Flame Step L", b.get_move("st_lp").cancel_into.has("flame_step_l") and b.get_move("cr_lp").cancel_into.has("flame_step_l"))
	_check("kick lights route into Flame Step L", b.get_move("st_lk").cancel_into.has("flame_step_l") and b.get_move("cr_lk").cancel_into.has("flame_step_l"))
	_check("heavies route into corner carry specials", b.get_move("st_hp").cancel_into.has("ember_wheel") and b.get_move("st_hp").cancel_into.has("cinder_lash"))
	_check("kick heavies route into corner carry specials", b.get_move("st_hk").cancel_into.has("flame_step_h") and b.get_move("st_hk").cancel_into.has("ember_wheel"))
	_check("crouch heavies route into combo enders", b.get_move("cr_hp").cancel_into.has("ember_wheel") and b.get_move("cr_hk").cancel_into.has("super_inferno"))

func _test_lp_pushout() -> void:
	print("[lp pushout]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.38
	f2.position.x = 0.38
	var hits := 0
	var prev_hp := f2.health
	for i in range(84):
		ctx["c1"].frame = _mk(0, 0, GameConst.Btn.LP) if i % 12 == 0 else _neutral()
		ctx["c2"].frame = _neutral()
		ctx["arena"].step(DELTA)
		if f2.health < prev_hp:
			hits += 1
			prev_hp = f2.health
	_check("repeated stand LP pushes out within 3 hits", hits <= 3)
	ctx["arena"].queue_free()

func _test_corner_hit_pushback() -> void:
	print("[corner hit pushback]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = 5.55
	f2.position.x = 6.45
	var start_x: float = f1.position.x
	_step(ctx, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)
	_step(ctx, _neutral(), _neutral(), 20)
	_check("attacker recoils on a cornered hit", f1.position.x < start_x - 0.08)
	ctx["arena"].queue_free()

func _test_specials_removed() -> void:
	print("[specials removed]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	var arena: Arena = ctx["arena"]
	var hp_before: int = f2.health
	# QCF + LP used to be fireball. It should now stay in the normal system and never spawn
	# a projectile or a special move.
	_step(ctx, _mk(0, -1), _neutral(), 3)
	_step(ctx, _mk(1, -1), _neutral(), 3)
	_step(ctx, _mk(1, 0, GameConst.Btn.LP), _neutral(), 1)
	_step(ctx, _neutral(), _neutral(), 20)
	_check("QCF+LP no longer starts a fireball special", f1.current_move == null or f1.current_move.id != "fireball")
	_check("removed fireball spawns no projectile", arena.projectiles.is_empty())
	_check("removed fireball deals no projectile damage", f2.health == hp_before)
	ctx["arena"].queue_free()

func _test_super() -> void:
	print("[super]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	var inferno := f1.character.get_move("super_inferno")
	_check("Inferno Rush hitbox matches model scale", inferno.hit_size.x <= 0.3 and inferno.hit_size.y <= 0.6 and inferno.hit_size.z <= 0.4)
	_check("Inferno Rush reach is not oversized", inferno.hit_offset.x + inferno.hit_size.x * 0.5 <= 0.55)
	_check("Inferno Rush has visible hit knockback", inferno.knockback >= 5.5)
	f1.meter = f1.character.max_meter   # grant full meter
	# Corner P2 so Blaze's advancing multi-hit super connects in full.
	f1.position.x = 5.4
	f2.position.x = 6.3
	var hp_before: int = f2.health
	var victim_hit_velocity := [0.0]
	f2.got_hit.connect(func(_blocked): victim_hit_velocity[0] = f2.velocity.x)
	# QCF QCF + HP as P1.
	_step(ctx, _mk(0, -1), _neutral(), 2)
	_step(ctx, _mk(1, -1), _neutral(), 2)
	_step(ctx, _mk(1, 0), _neutral(), 2)
	_step(ctx, _mk(0, -1), _neutral(), 2)
	_step(ctx, _mk(1, -1), _neutral(), 2)
	_step(ctx, _mk(1, 0, GameConst.Btn.HP), _neutral(), 1)
	_check("super consumed meter", f1.meter < f1.character.max_meter)
	_step(ctx, _neutral(), _neutral(), 90)
	_check("Inferno Rush visibly knocks the victim back", victim_hit_velocity[0] > 5.0)
	_check("super dealt heavy damage", hp_before - f2.health >= 200)
	ctx["arena"].queue_free()
	var recoil := _build()
	var ra: Fighter = recoil["f1"]
	var rb: Fighter = recoil["f2"]
	ra.meter = ra.character.max_meter
	ra.position.x = -0.8
	rb.position.x = 0.1
	var recoil_v := [0.0]
	rb.got_hit.connect(func(_blocked): recoil_v[0] = rb.velocity.x)
	_step(recoil, _mk(0, -1), _neutral(), 2)
	_step(recoil, _mk(1, -1), _neutral(), 2)
	_step(recoil, _mk(1, 0), _neutral(), 2)
	_step(recoil, _mk(0, -1), _neutral(), 2)
	_step(recoil, _mk(1, -1), _neutral(), 2)
	_step(recoil, _mk(1, 0, GameConst.Btn.HP), _neutral(), 1)
	for i in range(20):
		if recoil_v[0] > 0.0:
			break
		_step(recoil, _neutral(), _neutral(), 1)
	_check("Inferno Rush non-corner hit has obvious recoil", recoil_v[0] > 5.0)
	recoil["arena"].queue_free()
	var slow := _build()
	var sf1: Fighter = slow["f1"]
	var sf2: Fighter = slow["f2"]
	sf1.meter = sf1.character.max_meter
	sf1.position.x = 5.4
	sf2.position.x = 6.3
	# Human-paced QCF QCF: longer directional holds and the HP press a few frames after 6.
	_step(slow, _mk(0, -1), _neutral(), 4)
	_step(slow, _mk(1, -1), _neutral(), 4)
	_step(slow, _mk(1, 0), _neutral(), 4)
	_step(slow, _mk(0, -1), _neutral(), 4)
	_step(slow, _mk(1, -1), _neutral(), 4)
	_step(slow, _mk(1, 0), _neutral(), 4)
	_step(slow, _neutral(), _neutral(), 5)
	_step(slow, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	_check("human-paced Inferno Rush input starts super", sf1.current_move != null and sf1.current_move.id == "super_inferno")
	_check("human-paced Inferno Rush consumes meter", sf1.meter < sf1.character.max_meter)
	slow["arena"].queue_free()
	var finish := _build()
	var fa: Fighter = finish["f1"]
	var fb: Fighter = finish["f2"]
	var finish_rm := RoundManager.new()
	root.add_child(finish_rm)
	finish_rm.arena = finish["arena"]
	finish_rm.start()
	finish_rm.phase = RoundManager.Phase.FIGHT
	finish["arena"].set_active(true)
	for f in finish["arena"].fighters:
		f._goto(Fighter.State.IDLE)
	fa.meter = fa.character.max_meter
	fa.position.x = 5.4
	fb.position.x = 6.3
	fb.health = 10
	var super_move := fa.character.get_move("super_inferno")
	_step_round(finish, finish_rm, _mk(0, -1), _neutral(), 2)
	_step_round(finish, finish_rm, _mk(1, -1), _neutral(), 2)
	_step_round(finish, finish_rm, _mk(1, 0), _neutral(), 2)
	_step_round(finish, finish_rm, _mk(0, -1), _neutral(), 2)
	_step_round(finish, finish_rm, _mk(1, -1), _neutral(), 2)
	_step_round(finish, finish_rm, _mk(1, 0, GameConst.Btn.HP), _neutral(), 1)
	var ko_during_super := false
	for i in range(super_move.startup + 2):
		_step_round(finish, finish_rm, _neutral(), _neutral(), 1)
		if finish_rm.phase == RoundManager.Phase.ROUND_OVER:
			ko_during_super = true
			break
	_check("KO during Inferno Rush enters round over", ko_during_super)
	_check("Inferno Rush animation is not interrupted by KO", fa.state == Fighter.State.ATTACK and fa.current_move == super_move)
	for i in range(super_move.total_frames() + 8):
		_step_round(finish, finish_rm, _neutral(), _neutral(), 1)
		if fa.state == Fighter.State.WIN:
			break
	_check("winner pose waits until Inferno Rush finishes", fa.state == Fighter.State.WIN)
	finish_rm.queue_free()
	finish["arena"].queue_free()

func _test_ko() -> void:
	print("[ko]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	var arena: Arena = ctx["arena"]
	var ko_side := [-1]
	arena.ko.connect(func(loser): ko_side[0] = loser)
	# Corner P2 against the right wall so knockback can't carry it out of range.
	f1.position.x = 5.4
	f2.position.x = 6.3
	# Mash heavy punch while pressing forward to stay on top of the cornered P2.
	var ticks := 0
	while not f2.is_dead() and ticks < 2500:
		_step(ctx, _mk(1, 0, GameConst.Btn.HP), _mk(0, 0), 1)
		_step(ctx, _mk(1, 0), _mk(0, 0), 16)
		ticks += 17
	_check("P2 was KO'd", f2.is_dead())
	_check("KO signal fired for P2", ko_side[0] == GameConst.Side.P2)
	ctx["arena"].queue_free()

func _test_round_flow() -> void:
	print("[round flow]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	var arena: Arena = ctx["arena"]
	var rm := RoundManager.new()
	root.add_child(rm)
	rm.arena = arena
	var winner := [-1]
	rm.match_over.connect(func(w): winner[0] = w)
	rm.start()

	var reached_fight := false
	var safety := 0
	while rm.phase != RoundManager.Phase.MATCH_OVER and safety < 8000:
		safety += 1
		if rm.phase == RoundManager.Phase.FIGHT:
			reached_fight = true
			if f2.health > 150:
				f2.health = 120           # cap so each round ends quickly
			f1.position.x = f2.position.x - 0.85   # stay in heavy-punch range
			ctx["c1"].frame = _mk(1, 0, GameConst.Btn.HP)
			ctx["c2"].frame = _mk(0, 0)
		else:
			ctx["c1"].frame = _neutral()
			ctx["c2"].frame = _neutral()
		rm.tick(DELTA)

	_check("round flow reached FIGHT phase", reached_fight)
	_check("match ended", rm.phase == RoundManager.Phase.MATCH_OVER)
	_check("P1 won enough rounds", rm.p1_wins == GameConst.ROUNDS_TO_WIN)
	_check("match_over fired for P1", winner[0] == GameConst.Side.P1)
	rm.queue_free()
	arena.queue_free()

func _test_airborne_winner_lands() -> void:
	print("[round-over landing]")
	var ctx := _build()
	var arena: Arena = ctx["arena"]
	var rm := RoundManager.new()
	root.add_child(rm)
	rm.arena = arena
	var winner: Fighter = ctx["f1"]
	winner.position.y = 1.2
	winner.on_ground = false
	winner.velocity = Vector3.ZERO
	rm._round_winner = GameConst.Side.P1
	rm._end_round()
	var landed := false
	for i in range(RoundManager.ROUND_OVER_TICKS):
		rm.tick(DELTA)
		if winner.on_ground and absf(winner.position.y) < 0.01:
			landed = true
			break
	_check("airborne winner lands during round over", landed)
	rm.queue_free()
	arena.queue_free()

func _test_airborne_match_winner_lands() -> void:
	print("[match-over landing]")
	var ctx := _build()
	var arena: Arena = ctx["arena"]
	var rm := RoundManager.new()
	root.add_child(rm)
	rm.arena = arena
	var winner: Fighter = ctx["f1"]
	winner.set_win()
	winner.position.y = 2.8
	winner.on_ground = false
	winner.velocity = Vector3.ZERO
	rm.phase = RoundManager.Phase.MATCH_OVER
	var landed := false
	for i in range(240):
		rm.tick(DELTA)
		if winner.on_ground and absf(winner.position.y) < 0.01:
			landed = true
			break
	_check("airborne winner lands during match over", landed)
	rm.queue_free()
	arena.queue_free()

func _test_timeout_draw() -> void:
	print("[timeout draw]")
	var ctx := _build()
	var arena: Arena = ctx["arena"]
	var rm := RoundManager.new()
	root.add_child(rm)
	rm.arena = arena
	var last_announce := [""]
	rm.announce.connect(func(text: String): last_announce[0] = text)
	rm.start()
	var safety := 0
	while rm.phase != RoundManager.Phase.FIGHT and safety < 300:
		safety += 1
		ctx["c1"].frame = _neutral()
		ctx["c2"].frame = _neutral()
		rm.tick(DELTA)
	rm.time_left_ticks = 1
	ctx["f1"].health = 500
	ctx["f2"].health = 500
	ctx["c1"].frame = _neutral()
	ctx["c2"].frame = _neutral()
	rm.tick(DELTA)
	_check("timeout tie becomes a draw", rm._round_winner == -1)
	_check("timeout draw awards no round", rm.p1_wins == 0 and rm.p2_wins == 0)
	_check("timeout draw announces draw", last_announce[0] == "Draw")
	while rm.phase == RoundManager.Phase.ROUND_OVER and safety < 600:
		safety += 1
		rm.tick(DELTA)
	_check("draw advances to the next round", rm.round_number == 2 and rm.phase == RoundManager.Phase.INTRO)
	rm.queue_free()
	arena.queue_free()

func _test_cpu_ai() -> void:
	print("[cpu ai]")
	seed(20260619)
	var arena := Arena.new()
	root.add_child(arena)
	var human := Manual.new()                 # P1 stands still
	var cpu := CpuController.new(2)            # P2 is the AI (difficulty 2)
	var f1 := Fighter.new()
	var f2 := Fighter.new()
	f1.setup(CharacterLibrary.create("blaze"), human, GameConst.Side.P1, -2.4)
	f2.setup(CharacterLibrary.create("blaze"), cpu, GameConst.Side.P2, 2.4)
	arena.setup_fighters(f1, f2)
	arena.set_active(true)
	var start_x2: float = f2.position.x
	var hp1_before: int = f1.health
	for i in range(600):
		human.frame = _neutral()
		arena.step(DELTA)
	_check("CPU advanced toward the player", f2.position.x < start_x2 - 0.5)
	_check("CPU dealt damage to the idle player", f1.health < hp1_before)
	arena.queue_free()

func _test_training_mode() -> void:
	print("[training mode]")
	var game := root.get_node("Game")
	var old_mode: int = int(game.get("mode"))
	var old_p1: String = String(game.get("p1_char_id"))
	var old_p2: String = String(game.get("p2_char_id"))
	game.set("mode", GameConst.Mode.TRAINING)
	game.set("p1_char_id", "blaze")
	game.set("p2_char_id", "blaze")
	var select = load("res://scripts/ui/CharacterSelect.gd").new()
	_check("training character select routes to training", select._target_scene() == "res://scenes/match/Training.tscn")
	select.free()
	var scene := TrainingScene.new()
	root.add_child(scene)
	scene._build_training(game)
	_check("training scene builds arena", scene.arena != null and scene.f1 != null and scene.f2 != null)
	_check("training uses neutral dummy controller",
		scene.f2.controller is InputController
		and not (scene.f2.controller is CpuController)
		and not (scene.f2.controller is PlayerController))
	_check("training has no round manager", scene.round_manager == null)
	_check("training starts active", scene.f1.active and scene.f2.active)
	scene.f2.health = 1
	scene.f2.receive_attack(scene.f1.character.get_move("st_lp"), scene.f1.facing)
	_check("training dummy HP can stay at zero", scene.f2.health == 0)
	for i in range(TrainingScene.RESET_DELAY_TICKS + 10):
		scene._physics_process(DELTA)
	_check("training dummy does not die or reset at zero HP",
		scene.f2.health == 0 and scene.f2.state != Fighter.State.KO and scene.f2.active)
	scene.f2.receive_attack(scene.f1.character.get_move("st_hp"), scene.f1.facing)
	_check("training dummy still reacts normally at zero HP", scene.f2.health == 0 and scene.f2.state == Fighter.State.HITSTUN)
	for i in range(TrainingScene.HP_RECOVERY_DELAY_TICKS + 40):
		scene._physics_process(DELTA)
	_check("training dummy HP starts recovering gradually after downtime",
		scene.f2.health > 0 and scene.f2.health < scene.f2.character.max_health)
	for i in range(100):
		scene._physics_process(DELTA)
	_check("training dummy HP eventually recovers to full", scene.f2.health == scene.f2.character.max_health)
	scene.f2.health = scene.f2.character.max_health - 100
	scene.f2.health_changed.emit(scene.f2.health, scene.f2.character.max_health)
	for i in range(TrainingScene.HP_RECOVERY_DELAY_TICKS + 1):
		scene._physics_process(DELTA)
	_check("training damaged HP recovers gradually before zero",
		scene.f2.health > scene.f2.character.max_health - 100 and scene.f2.health < scene.f2.character.max_health)
	for i in range(20):
		scene._physics_process(DELTA)
	_check("training damaged HP eventually recovers to full", scene.f2.health == scene.f2.character.max_health)
	_check("training resources stay full", scene.f1.meter == scene.f1.character.max_meter and scene.f1.drive == scene.f1.character.max_drive)
	scene.f2.combo_changed.emit(2, 99)
	_check("training combo HUD updates live", scene.hud._combo_label[0].text.contains("2 HITS") and scene.hud._combo_label[0].modulate.a > 0.9)
	scene.f1.state = Fighter.State.DRIVE_RUSH
	scene.f1.state_frame = 0
	scene._physics_process(DELTA)
	var training_fx_spawned := false
	for child in scene.arena.get_children():
		if child is DriveRushFx:
			training_fx_spawned = true
			break
	_check("training scene spawns Drive Rush ghost trail", training_fx_spawned)
	scene.queue_free()
	game.set("mode", old_mode)
	game.set("p1_char_id", old_p1)
	game.set("p2_char_id", old_p2)

func _test_blaze_roster() -> void:
	print("[blaze roster]")
	_check("roster is exactly [blaze]", CharacterLibrary.ids() == ["blaze"])
	var b := CharacterLibrary.create("blaze")
	_check("blaze display name", b.display_name == "Blaze")
	_check("blaze jump is tuned higher", b.jump_velocity > 12.0)
	_check("blaze model scale is valid", b.model_scale > 0.0)
	_check("blaze has combo specials", b.specials.size() >= 5)
	_check("blaze has 1 super", b.supers.size() == 1)
	for removed in ["fireball", "uppercut", "hurricane", "od_fireball", "od_uppercut", "od_hurricane"]:
		_check("removed move absent: " + removed, b.get_move(removed) == null)
	for added in ["flame_step_l", "flame_step_m", "flame_step_h", "cinder_lash", "ember_wheel"]:
		_check("combo move exists: " + added, b.get_move(added) != null)
	_check("Ken-like stand MP timing", b.get_move("st_mp").startup == 7 and b.get_move("st_mp").active == 3)
	_check("Ken-like cross-up air MK timing", b.get_move("air_mk").startup == 7 and b.get_move("air_mk").active == 6)

func _test_animation_ownership() -> void:
	print("[animation ownership]")
	var src := FileAccess.get_file_as_string("res://scripts/combat/CharacterKit.gd")
	_check("shared CharacterKit has no Blaze KB clip names", not src.contains("KB_"))
	var scratch := CharacterData.new()
	scratch.id = "scratch"
	CharacterKit.add_standard_normals(scratch, 1.0, [], {})
	var owns_no_clips := true
	for m in scratch.normals:
		if m.anim_clip != "" or m.hit_reaction_clip != "":
			owns_no_clips = false
			break
	_check("new characters do not inherit Blaze animations", owns_no_clips)
	var blaze := CharacterLibrary.create("blaze")
	var blaze_has_clips := blaze.rig != null and not blaze.rig.anim_files.is_empty()
	for m in blaze.normals:
		blaze_has_clips = blaze_has_clips and m.anim_clip != ""
	for m in blaze.supers:
		blaze_has_clips = blaze_has_clips and m.anim_clip != ""
	_check("Blaze module owns current animation config", blaze.id == "blaze" and blaze_has_clips)

func _test_move_list_overlay() -> void:
	print("[move list overlay]")
	var hud := HUD.new()
	root.add_child(hud)
	var blaze := CharacterLibrary.create("blaze")
	hud.build(blaze, blaze)
	_check("move list hidden by default", not hud.is_move_list_visible())
	hud.toggle_move_list()
	_check("move list opens on toggle", hud.is_move_list_visible())
	var left: Label = hud._move_list_labels[0]
	_check("move list hides removed specials", not left.text.contains("Flare Bolt") and not left.text.contains("Blaze Rise") and not left.text.contains("Cyclone Kick"))
	_check("move list shows Blaze combo tools", left.text.contains("Flame Step") and left.text.contains("Cinder Lash") and left.text.contains("Ember Wheel"))
	_check("move list still shows super", left.text.contains("Inferno Rush"))
	_check("move list uses numpad super notation", left.text.contains("236236") and left.text.contains("(100% Super)"))
	hud.toggle_move_list()
	_check("move list closes on second toggle", not hud.is_move_list_visible())
	hud.queue_free()

func _test_multihit() -> void:
	print("[multi-hit]")
	var ctx := _build("blaze", "blaze")
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.meter = f1.character.max_meter
	# Corner P2 so Blaze's advancing super keeps connecting after specials are removed.
	f1.position.x = 5.2
	f2.position.x = 6.2
	var hits := [0]
	f1.contact.connect(func(blocked, _m): if not blocked: hits[0] += 1)
	var hp_before: int = f2.health
	# Inferno Rush: QCF QCF + HP.
	_step(ctx, _mk(0, -1), _neutral(), 2)
	_step(ctx, _mk(1, -1), _neutral(), 2)
	_step(ctx, _mk(1, 0), _neutral(), 2)
	_step(ctx, _mk(0, -1), _neutral(), 2)
	_step(ctx, _mk(1, -1), _neutral(), 2)
	_step(ctx, _mk(1, 0, GameConst.Btn.HP), _neutral(), 1)
	_step(ctx, _neutral(), _neutral(), 75)
	_check("super connected multiple times", hits[0] >= 2)
	_check("multi-hit dealt cumulative damage", hp_before - f2.health >= 70)
	ctx["arena"].queue_free()

func _test_move_sfx() -> void:
	print("[per-move sfx]")
	var b := CharacterLibrary.create("blaze")
	var sup := b.get_move("super_inferno")
	_check("super has its own sfx", sup != null and sup.sfx == "super")
	var button_sfx := {
		GameConst.Btn.LP: "lp",
		GameConst.Btn.MP: "mp",
		GameConst.Btn.HP: "hp",
		GameConst.Btn.LK: "lk",
		GameConst.Btn.MK: "mk",
		GameConst.Btn.HK: "hk",
	}
	var seen_sfx := {}
	for m in [b.get_move("st_lp"), b.get_move("st_mp"), b.get_move("st_hp"), b.get_move("st_lk"), b.get_move("st_mk"), b.get_move("st_hk")]:
		_check("%s has fixed button sfx" % m.id, m != null and m.sfx == button_sfx[m.button])
		seen_sfx[m.sfx] = true
	_check("six attack buttons use distinct sfx", seen_sfx.size() == 6)
	for name in AudioManager.SFX:
		_check("base hit-pack sfx " + name, ResourceLoader.exists("res://assets/audio/%s.wav" % name))
	var am := AudioManager.new()
	root.add_child(am)
	am._ensure_initialized()
	_check("BGM uses imported AIGenBGM track", ResourceLoader.exists(AudioManager.BGM_PATH) and am._bgm.stream != null)
	for name in AudioManager.SFX:
		var stream = am._stream_for(name)
		_check(name + " uses imported stream", stream != null)
		_check(name + " resolves to a fixed stream", stream == am._stream_for(name))
	am.queue_free()

func _root_y_delta(anim: Animation) -> float:
	var max_delta := 0.0
	for i in range(anim.get_track_count()):
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var p := anim.track_get_path(i)
		var sub := ""
		if p.get_subname_count() > 0:
			sub = String(p.get_subname(p.get_subname_count() - 1))
		if not (sub in ["Hips", "Root"]):
			continue
		var kc := anim.track_get_key_count(i)
		if kc == 0:
			continue
		var first: Vector3 = anim.track_get_key_value(i, 0)
		for k in range(kc):
			var v: Vector3 = anim.track_get_key_value(i, k)
			max_delta = maxf(max_delta, absf(v.y - first.y))
	return max_delta

func _test_animated_rig() -> void:
	print("[animated rig]")
	var blaze := CharacterLibrary.create("blaze")
	if blaze.model_path == "" or not ResourceLoader.exists(blaze.model_path):
		print("  SKIP: model assets not present (clean clone)")
		return
	var arig := AnimatedFighterRig.new()
	root.add_child(arig)
	arig.build(blaze)
	_check("animated rig built ok", arig.ok)
	_check("grafted idle clip", arig._player != null and arig._player.has_animation("kb/KB_Idle_1"))
	_check("grafted jab clip", arig._player != null and arig._player.has_animation("kb/KB_p_Jab_R_1"))
	_check("grafted stand MP clip", arig._player != null and arig._player.has_animation("kb/KB_m_Uppercut_R"))
	_check("grafted Drive Rush startup clip", arig._player != null and arig._player.has_animation("kb/KB_SkipFwd_1"))
	_check("grafted Drive Rush run clip", arig._player != null and arig._player.has_animation("kb/KB_SkipFwd_1"))
	_check("grafted super clip", arig._player != null and arig._player.has_animation("kb/KB_Superpunch"))
	# Air-attack clips must be grafted so the move animations are visible (not a fallback).
	for clip in ["KB_JumpPunch", "KB_m_Hook_R", "KB_m_Overhand_R", "KB_JumpKick", "KB_p_MidKickFront_L", "KB_p_HighKick_R_1"]:
		_check("grafted air clip " + clip, arig._player.has_animation("kb/" + clip))
	for clip in ["KB_Hit_p_MidFront_Weak", "KB_Hit_m_HighRight_Weak", "KB_Hit_m_MidFront_Med", "KB_Hit_m_MidTop_Med", "KB_Hit_m_HighFront_Stagger", "KB_Hit_m_HighRight_Med"]:
		_check("grafted hit clip " + clip, arig._player.has_animation("kb/" + clip))
	# Idle must be set to loop (otherwise it stops after one play ~3s).
	_check("idle clip loops", arig._player.get_animation("kb/KB_Idle_1").loop_mode == Animation.LOOP_LINEAR)
	var f := Fighter.new()
	f.setup(blaze, Manual.new(), GameConst.Side.P1, 0.0)
	f.state = Fighter.State.DRIVE_RUSH
	f.state_frame = 0
	_check("Drive Rush startup uses startup clip", arig._state_clip(f) == "KB_SkipFwd_1")
	f.state_frame = Fighter.DRIVE_RUSH_STARTUP_ANIM_TICKS + 1
	_check("Drive Rush run uses run clip after startup", arig._state_clip(f) == "KB_SkipFwd_1")
	f.current_move = blaze.get_move("st_lp")
	f.state = Fighter.State.ATTACK
	f.state_frame = 4
	arig.pose(f)
	arig._player.advance(0.18)
	var before_restart: float = arig._player.current_animation_position
	f.hitstop = 6
	arig.pose(f)
	_check("animated rig freezes playback during hitstop", arig._player.speed_scale == 0.0)
	f.hitstop = 0
	arig.pose(f)
	_check("animated rig resumes playback after hitstop", arig._player.speed_scale == 1.0)
	f.state_frame = 0
	arig.pose(f)
	arig._player.advance(0.03)
	_check("same-move cancel restarts the clip", arig._player.current_animation_position < before_restart)
	arig.queue_free()

func _test_six_buttons() -> void:
	print("[six buttons]")
	var k := CharacterLibrary.create("blaze")
	_check("18 normals (6 buttons x 3 stances)", k.normals.size() == 18)
	var st_lp := k.get_move("st_lp")
	_check("standing LP uses authored hit reaction", st_lp != null and st_lp.hit_reaction_clip == "KB_Hit_m_HighRight_Weak")
	var st_hp := k.get_move("st_hp")
	_check("standing HP uses authored hit reaction", st_hp != null and st_hp.hit_reaction_clip == "KB_Hit_m_HighRight_Med")
	var st_mp := k.get_move("st_mp")
	_check("standing MP exists", st_mp != null and st_mp.button == GameConst.Btn.MP and st_mp.stance == GameConst.Stance.STAND)
	var st_hk := k.get_move("st_hk")
	_check("standing HK uses high round kick clip", st_hk != null and st_hk.anim_clip == "KB_m_HighKickRound_R_1")
	_check("standing HK uses authored hit reaction", st_hk != null and st_hk.hit_reaction_clip == "KB_Hit_m_HighRight_Med")
	_check("standing HK does not knock down", st_hk != null and not st_hk.launch)
	var cr_hp := k.get_move("cr_hp")
	_check("crouch HP uses authored hit reaction", cr_hp != null and cr_hp.hit_reaction_clip == "KB_Hit_m_MidTop_Med")
	_check("crouch HP does not knock down", cr_hp != null and not cr_hp.launch)
	var cr_mk := k.get_move("cr_mk")
	_check("crouch MK is a low", cr_mk != null and cr_mk.stance == GameConst.Stance.CROUCH and cr_mk.guard == GameConst.Guard.LOW)
	var cr_hk := k.get_move("cr_hk")
	_check("crouch HK uses medium low round kick clip", cr_hk != null and cr_hk.anim_clip == "KB_crouch_m_LowKickRound_R")
	var air_hp := k.get_move("air_hp")
	_check("air HP is an overhead", air_hp != null and air_hp.stance == GameConst.Stance.AIR and air_hp.guard == GameConst.Guard.OVERHEAD)

func _test_dash() -> void:
	print("[dash]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var start_x: float = f1.position.x
	var drive_before: int = f1.drive
	var saw_dash := false
	# Double-tap forward: tap, release, tap (within the dash window).
	var seq := [_mk(1, 0), _mk(0, 0), _mk(1, 0)]
	for fr in seq:
		ctx["c1"].frame = fr
		ctx["c2"].frame = _neutral()
		ctx["arena"].step(DELTA)
		if f1.state == Fighter.State.DASH_F:
			saw_dash = true
	for i in range(10):
		ctx["c1"].frame = _mk(1, 0)
		ctx["c2"].frame = _neutral()
		ctx["arena"].step(DELTA)
		if f1.state == Fighter.State.DASH_F:
			saw_dash = true
	var dash_dist := f1.position.x - start_x
	_check("forward dash triggered", saw_dash)
	_check("dash is quick but shorter", dash_dist > 0.75 and dash_dist < 1.55)
	_check("forward dash spends no Drive", f1.drive == drive_before)
	ctx["arena"].queue_free()

func _test_air_attack() -> void:
	print("[air attack]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	_step(ctx, _mk(0, 1), _neutral(), 1)   # press up -> jump
	_step(ctx, _mk(0, 0), _neutral(), 5)   # rise
	_check("airborne after jump", not f1.on_ground)
	_step(ctx, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)   # air LP
	_check("air normal started", f1.current_move != null and f1.current_move.stance == GameConst.Stance.AIR)
	_check("still airborne during air attack", not f1.on_ground)
	ctx["arena"].queue_free()

func _test_jump_in() -> void:
	print("[jump-in]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = 1.5
	f2.position.x = 2.4
	var hp_before: int = f2.health
	_step(ctx, _mk(1, 1), _neutral(), 1)    # jump forward (up + toward opponent)
	_step(ctx, _mk(0, 0), _neutral(), 3)    # rise
	_step(ctx, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)   # air punch
	_check("air attack keeps forward momentum (arc, not straight drop)", absf(f1.velocity.x) > 0.5)
	_step(ctx, _neutral(), _neutral(), 35)  # descend onto the opponent
	_check("jump-in connected with the opponent", f2.health < hp_before)
	ctx["arena"].queue_free()

func _test_jump_crossup() -> void:
	print("[jump cross-up]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.45
	f2.position.x = 0.25
	_step(ctx, _mk(1, 1), _neutral(), 1)
	var crossed := false
	for i in range(34):
		_step(ctx, _mk(1, 0), _neutral(), 1)
		if not f1.on_ground and f1.position.x > f2.position.x + 0.05:
			crossed = true
			break
	_check("jump arc can cross over the opponent before landing", crossed)
	ctx["arena"].queue_free()

	var hit_ctx := _build()
	var a: Fighter = hit_ctx["f1"]
	var b: Fighter = hit_ctx["f2"]
	a.position.x = -2.05
	b.position.x = 0.25
	var hp_before: int = b.health
	var kb_x := [0.0]
	var crossed_on_hit := [false]
	b.got_hit.connect(func(_blocked):
		kb_x[0] = b.velocity.x
		crossed_on_hit[0] = a.position.x > b.position.x)
	_step(hit_ctx, _mk(1, 1), _neutral(), 1)
	_step(hit_ctx, _mk(1, 0), _neutral(), 36)
	_step(hit_ctx, _mk(1, 0, GameConst.Btn.MK), _neutral(), 1)
	for i in range(20):
		_step(hit_ctx, _mk(1, 0), _neutral(), 1)
		if b.health < hp_before:
			break
	_check("cross-up air hit connected after passing behind", b.health < hp_before and crossed_on_hit[0])
	_check("cross-up hit pushes defender away from the new attack side", float(kb_x[0]) < 0.0)
	hit_ctx["arena"].queue_free()

func _test_air_hitbox_tuning() -> void:
	print("[air hitbox tuning]")
	var b := CharacterLibrary.create("blaze")
	for id in ["air_lp", "air_mp", "air_hp", "air_lk", "air_mk", "air_hk"]:
		var m := b.get_move(id)
		_check(id + " has a compact vertical attack box", m != null and m.hit_size.y <= 0.75)
		_check(id + " has a bounded active window", m != null and m.active <= 10)
	var mk := b.get_move("air_mk")
	_check("air MK is the cross-up button", mk != null and mk.hit_offset.x < 0.35 and mk.hit_size.x >= 0.85)

func _test_air_clips_distinct() -> void:
	print("[air clip variety]")
	var k := CharacterLibrary.create("blaze")
	var clips := {}
	for id in ["air_lp", "air_mp", "air_hp", "air_lk", "air_mk", "air_hk"]:
		var m := k.get_move(id)
		clips[m.anim_clip] = true
	_check("air normals use 6 distinct clips", clips.size() == 6)

func _hit_with(button: int) -> int:
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.38
	f2.position.x = 0.38
	_step(ctx, _mk(0, 0, button), _neutral(), 1)
	_step(ctx, _neutral(), _neutral(), 10)
	var s: int = f2.hit_strength
	ctx["arena"].queue_free()
	return s

func _test_hit_strength() -> void:
	print("[hit reactions]")
	_check("light hit -> strength 0", _hit_with(GameConst.Btn.LP) == 0)
	_check("medium hit -> strength 1", _hit_with(GameConst.Btn.MP) == 1)
	_check("heavy hit -> strength 2", _hit_with(GameConst.Btn.HP) == 2)

func _test_kb_library() -> void:
	print("[kb library / gallery source]")
	var blaze := CharacterLibrary.create("blaze")
	if not ResourceLoader.exists(blaze.model_path):
		print("  SKIP: model assets not present (clean clone)")
		return
	var lib := AnimatedFighterRig.build_library(blaze.rig)
	_check("kb library exposes 200+ clips for the gallery", lib.get_animation_list().size() > 200)

func _test_counter() -> void:
	print("[counter hit]")
	# Counter: strike the opponent during their attack start-up. P1's fast jab (startup 4)
	# lands while P2's slow Stand HP (startup 9) is still starting up.
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.6
	f2.position.x = 0.6
	var kinds := [GameConst.Counter.NONE]
	f2.countered.connect(func(k): kinds[0] = k)
	_step(ctx, _mk(0, 0, GameConst.Btn.LP), _mk(0, 0, GameConst.Btn.HP), 1)
	_step(ctx, _neutral(), _neutral(), 8)
	_check("counter hit detected", kinds[0] == GameConst.Counter.COUNTER)
	_check("counter forced >= medium reaction", f2.hit_strength >= 1)
	_check("counter recorded on victim", f2.last_counter == GameConst.Counter.COUNTER)
	ctx["arena"].queue_free()

func _test_punish_counter() -> void:
	print("[punish counter]")
	# Punish: strike the opponent during their attack RECOVERY. P2 whiffs a slow Stand HP
	# while P1 is out of range, then P1 steps in and jabs during the recovery.
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	var kinds := [GameConst.Counter.NONE]
	f2.countered.connect(func(k): kinds[0] = k)
	f1.position.x = -3.0
	f2.position.x = 0.0
	_step(ctx, _neutral(), _mk(0, 0, GameConst.Btn.HP), 1)
	_step(ctx, _neutral(), _neutral(), 13)
	_check("f2 is in attack recovery",
		f2.state == Fighter.State.ATTACK and f2.current_move != null and f2.current_move.is_recovering(f2.state_frame))
	# Step into range and punish.
	f1.position.x = -0.84
	f2.position.x = 0.0
	_step(ctx, _mk(0, 0, GameConst.Btn.LP), _neutral(), 7)
	_check("punish counter detected", kinds[0] == GameConst.Counter.PUNISH)
	_check("punish forced heavy reaction", f2.hit_strength == 2)
	ctx["arena"].queue_free()

func _test_counter_clean_hit() -> void:
	print("[no false counter]")
	# A normal hit on a neutral (non-attacking) opponent is NOT a counter.
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.6
	f2.position.x = 0.6
	var kinds := [GameConst.Counter.NONE]
	f2.countered.connect(func(k): kinds[0] = k)
	_step(ctx, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)
	_step(ctx, _neutral(), _neutral(), 10)
	_check("clean hit is not a counter", kinds[0] == GameConst.Counter.NONE)
	_check("victim counter kind stays NONE", f2.last_counter == GameConst.Counter.NONE)
	ctx["arena"].queue_free()

## Launch the opponent with `button` (+ optional crouch) and return how the resulting
## knockdown was classified.
func _knockdown_from(button: int, dir_y: int) -> int:
	var ctx := _build("blaze", "blaze")
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = 5.3
	f2.position.x = 6.2
	_step(ctx, _mk(0, dir_y, button), _neutral(), 1)
	var kind := GameConst.Knockdown.NONE
	for i in range(120):
		_step(ctx, _mk(0, dir_y), _neutral(), 1)
		if f2.knockdown_kind != GameConst.Knockdown.NONE:
			kind = f2.knockdown_kind
			break
	ctx["arena"].queue_free()
	return kind

func _test_knockdown_kinds() -> void:
	print("[knockdown variety]")
	_check("sweep (crouch HK) -> low knockdown", _knockdown_from(GameConst.Btn.HK, -1) == GameConst.Knockdown.LOW)
	_check("crouch HP hit does not knock down", _knockdown_from(GameConst.Btn.HP, -1) == GameConst.Knockdown.NONE)
	_check("stand HK hit does not knock down", _knockdown_from(GameConst.Btn.HK, 0) == GameConst.Knockdown.NONE)
	var ctx := _build("blaze", "blaze")
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = 5.3
	f2.position.x = 6.2
	_step(ctx, _mk(0, -1, GameConst.Btn.HP), _neutral(), 1)
	for i in range(20):
		if f2.hit_reaction_clip != "":
			break
		_step(ctx, _mk(0, -1), _neutral(), 1)
	_check("crouch HP records authored hit reaction", f2.hit_reaction_clip == "KB_Hit_m_MidTop_Med")
	ctx["arena"].queue_free()
	var stlp_ctx := _build("blaze", "blaze")
	var lp1: Fighter = stlp_ctx["f1"]
	var lp2: Fighter = stlp_ctx["f2"]
	lp1.position.x = 5.3
	lp2.position.x = 6.2
	_step(stlp_ctx, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)
	for i in range(20):
		if lp2.hit_reaction_clip != "":
			break
		_step(stlp_ctx, _neutral(), _neutral(), 1)
	_check("standing LP records authored hit reaction", lp2.hit_reaction_clip == "KB_Hit_m_HighRight_Weak")
	stlp_ctx["arena"].queue_free()
	var sthp_ctx := _build("blaze", "blaze")
	var hp1: Fighter = sthp_ctx["f1"]
	var hp2: Fighter = sthp_ctx["f2"]
	hp1.position.x = 5.3
	hp2.position.x = 6.2
	_step(sthp_ctx, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	for i in range(20):
		if hp2.hit_reaction_clip != "":
			break
		_step(sthp_ctx, _neutral(), _neutral(), 1)
	_check("standing HP records authored hit reaction", hp2.hit_reaction_clip == "KB_Hit_m_HighRight_Med")
	sthp_ctx["arena"].queue_free()

func _test_wakeup() -> void:
	print("[knockdown / wakeup flow]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	# Corner P2 and launch with crouch HK, then watch the full down -> get-up -> idle cycle.
	f1.position.x = 5.4
	f2.position.x = 6.2
	_step(ctx, _mk(0, -1, GameConst.Btn.HK), _neutral(), 1)
	var saw_knockdown := false
	var saw_wakeup := false
	for i in range(260):
		_step(ctx, _neutral(), _neutral(), 1)
		if f2.state == Fighter.State.KNOCKDOWN:
			saw_knockdown = true
		if f2.state == Fighter.State.WAKEUP:
			saw_wakeup = true
	_check("victim was knocked down", saw_knockdown)
	_check("victim played a get-up (WAKEUP)", saw_wakeup)
	_check("victim recovered to neutral", f2.state == Fighter.State.IDLE)
	_check("knockdown kind cleared after wake-up", f2.knockdown_kind == GameConst.Knockdown.NONE)
	ctx["arena"].queue_free()

func _test_reaction_clips() -> void:
	print("[reaction clip resolution]")
	var blaze := CharacterLibrary.create("blaze")
	if blaze.model_path == "" or not ResourceLoader.exists(blaze.model_path):
		print("  SKIP: model assets not present (clean clone)")
		return
	var arig := AnimatedFighterRig.new()
	root.add_child(arig)
	arig.build(blaze)
	var f := Fighter.new()
	f.setup(blaze, Manual.new(), GameConst.Side.P1, 0.0)
	f.on_ground = true
	f.hit_air = false
	f.hit_from_back = false
	f.hit_crouch = false
	# Light mid front.
	f.hit_strength = 0
	f.hit_height = GameConst.HitHeight.MID
	_check("light mid front -> p MidFront Weak", arig._resolve_hit_clip(f) == "KB_Hit_p_MidFront_Weak")
	# Heavy high front -> stagger.
	f.hit_strength = 2
	f.hit_height = GameConst.HitHeight.HIGH
	_check("heavy high front -> m HighFront Stagger", arig._resolve_hit_clip(f) == "KB_Hit_m_HighFront_Stagger")
	f.hit_reaction_clip = "KB_Hit_m_HighRight_Med"
	_check("authored st.HK reaction overrides context", arig._resolve_hit_clip(f) == "KB_Hit_m_HighRight_Med")
	f.hit_reaction_clip = ""
	# Low has no Front/Stagger -> degrade to an existing Low clip.
	f.hit_strength = 2
	f.hit_height = GameConst.HitHeight.LOW
	var low_clip: String = arig._resolve_hit_clip(f)
	_check("low hit resolves to an existing Low clip",
		("Low" in low_clip) and arig._player.has_animation("kb/" + low_clip))
	# Crouching victim uses the crouch-hit set.
	f.hit_crouch = true
	f.hit_height = GameConst.HitHeight.MID
	f.hit_strength = 0
	_check("crouch hit -> crouch-hit clip", arig._resolve_hit_clip(f).begins_with("KB_crouch_Hit"))
	f.hit_crouch = false
	# Knockdown by cause.
	f.knockdown_kind = GameConst.Knockdown.UPPER
	_check("upper knockdown -> UpperKO", arig._knockdown_clip(f) == "KB_UpperKO")
	f.knockdown_kind = GameConst.Knockdown.LOW
	_check("low knockdown -> LowKO", arig._knockdown_clip(f).begins_with("KB_LowKO"))
	f.knockdown_kind = GameConst.Knockdown.AIR
	_check("air knockdown -> HighKO_Air", arig._knockdown_clip(f) == "KB_HighKO_Air")
	# Get-up.
	_check("wake-up -> a get-up clip", arig._wakeup_clip(f).begins_with("KB_GetUp"))
	arig.queue_free()

## Land `button` on a neutral opponent and capture the impact-freeze applied to both
## fighters at the moment of contact.
func _peak_hitstop(button: int) -> Dictionary:
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.38
	f2.position.x = 0.38
	var vic := [0]
	var atk := [0]
	f2.got_hit.connect(func(_b): vic[0] = f2.hitstop)
	f1.contact.connect(func(_b, _m): atk[0] = f1.hitstop)
	_step(ctx, _mk(0, 0, button), _neutral(), 1)
	_step(ctx, _neutral(), _neutral(), 12)
	ctx["arena"].queue_free()
	return {"vic": vic[0], "atk": atk[0]}

func _test_hitstop_tiers() -> void:
	print("[hitstop tiers]")
	var light := _peak_hitstop(GameConst.Btn.LP)
	var heavy := _peak_hitstop(GameConst.Btn.HP)
	_check("heavy hit freezes longer than light", int(heavy["vic"]) > int(light["vic"]))
	_check("attacker + victim freeze match (symmetric hitstop)", int(heavy["vic"]) == int(heavy["atk"]))
	_check("light hits have stronger SF6-like impact freeze", int(light["vic"]) >= 9)
	_check("heavy hits have a heavier impact freeze", int(heavy["vic"]) >= 15)

func _test_impact_fx_smoke() -> void:
	print("[impact fx smoke]")
	var cam := FightCamera.new()
	cam.shake(0.2, 8)
	_check("camera shake armed", cam._shake_t == 8 and cam._shake_amp > 0.0)
	var off := cam._shake_offset()
	_check("shake offset finite + bounded", is_finite(off.x) and absf(off.x) <= 0.2)
	cam.free()
	var spark := HitSpark.new()
	root.add_child(spark)
	spark.setup(Color(1.0, 0.5, 0.2), 1.3)
	_check("hit spark built core + ring", spark.get_child_count() == 2)
	var core := spark.get_child(0) as MeshInstance3D
	var ring := spark.get_child(1) as MeshInstance3D
	_check("hit spark core is compact", core != null and core.mesh is SphereMesh and (core.mesh as SphereMesh).radius <= 0.12)
	_check("hit spark ring is compact", ring != null and ring.mesh is TorusMesh and (ring.mesh as TorusMesh).outer_radius <= 0.19)
	spark.free()
	var scene := MatchScene.new()
	var victim := Fighter.new()
	var attacker := Fighter.new()
	var rig := SpyRig.new()
	victim.add_child(rig)
	victim.rig = rig
	victim.opponent = attacker
	attacker.opponent = victim
	victim.hit_strength = 1
	victim.hit_height = GameConst.HitHeight.MID
	scene.camera = FightCamera.new()
	scene.add_child(scene.camera)
	victim.last_hit_point = Vector3(1.2, 1.35, 0.0)
	scene._on_struck(victim, false)
	_check("hit visual updates before spark spawn", rig.pose_count == 1 and scene.get_child_count() >= 2)
	var impact_spark := scene.get_child(scene.get_child_count() - 1) as HitSpark
	_check("hit spark spawns at the recorded contact point", impact_spark != null and impact_spark.position.distance_to(victim.last_hit_point) < 0.001)
	scene.free()

func _test_slowmo_director() -> void:
	print("[slow-mo director]")
	var d := SlowMoDirector.new()
	_check("starts at normal speed", d.scale == 1.0 and not d.active())
	d.request(0.3, 5)
	_check("dip engaged at < 1x", d.active() and d.scale < 1.0)
	for i in range(5):
		d.tick()
	_check("speed restored after the dip", d.scale == 1.0 and not d.active())
	d.request(0.3, 5)
	_check("re-trigger blocked during cooldown", not d.active())
	d.request(0.3, 8, true)
	_check("KO (force) overrides cooldown", d.active() and d.scale < 1.0)
	d.reset()
	_check("reset clears the dip", d.scale == 1.0 and not d.active())

# --- blaze-sf6-combat-feel: combos, drive gauge, drive rush, rising uppercut ---

func _test_combo() -> void:
	print("[combo system]")
	var kit := CharacterLibrary.create("blaze")
	_check("Blaze has authored combo routes", kit.get_move("st_mp").cancel_into.has("st_hp") and kit.get_move("st_hp").cancel_into.has("flame_step_m"))
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.38
	f2.position.x = 0.38
	var hp0: int = f2.health
	var saw_target := false
	_step(ctx, _mk(0, 0, GameConst.Btn.MP), _neutral(), 1)
	for i in range(12):
		if f2.health < hp0:
			break
		_step(ctx, _neutral(), _neutral(), 1)
	_step(ctx, _mk(0, 0, GameConst.Btn.HP), _neutral(), 2)
	for i in range(18):
		_step(ctx, _neutral(), _neutral(), 1)
		if f1.current_move != null and f1.current_move.id == "st_hp":
			saw_target = true
			break
	for i in range(24):
		if f2.health < hp0 - 90:
			break
		_step(ctx, _neutral(), _neutral(), 1)
	_check("st.MP target-combos into st.HP", saw_target)
	_check("target route dealt multiple hits", f2.combo_count >= 2 and f2.health < hp0 - 90)
	ctx["arena"].queue_free()
	var heavy := _build()
	var ha: Fighter = heavy["f1"]
	var hb: Fighter = heavy["f2"]
	ha.position.x = -0.38
	hb.position.x = 0.38
	var hhp: int = hb.health
	_step(heavy, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	for i in range(14):
		if hb.health < hhp:
			break
		_step(heavy, _neutral(), _neutral(), 1)
	_step(heavy, _mk(0, -1), _neutral(), 2)
	_step(heavy, _mk(1, -1), _neutral(), 2)
	_step(heavy, _mk(1, 0, GameConst.Btn.MK), _neutral(), 1)
	var saw_flame := false
	for i in range(24):
		_step(heavy, _neutral(), _neutral(), 1)
		if ha.current_move != null and ha.current_move.id == "flame_step_m":
			saw_flame = true
			break
	_check("st.HP cancels into Flame Step M", saw_flame)
	heavy["arena"].queue_free()
	var light := _build()
	var la: Fighter = light["f1"]
	var lb: Fighter = light["f2"]
	la.position.x = -0.38
	lb.position.x = 0.38
	var lhp: int = lb.health
	_step(light, _mk(0, -1, GameConst.Btn.LP), _neutral(), 1)
	for i in range(12):
		if lb.health < lhp:
			break
		_step(light, _mk(0, -1), _neutral(), 1)
	_step(light, _mk(0, -1), _neutral(), 2)
	_step(light, _mk(1, -1), _neutral(), 2)
	_step(light, _mk(1, 0, GameConst.Btn.LK), _neutral(), 1)
	var saw_light_step := false
	for i in range(18):
		_step(light, _neutral(), _neutral(), 1)
		if la.current_move != null and la.current_move.id == "flame_step_l":
			saw_light_step = true
			break
	_check("cr.LP confirms into Flame Step L", saw_light_step)
	light["arena"].queue_free()
	var drc := _build()
	var da: Fighter = drc["f1"]
	var db: Fighter = drc["f2"]
	da.position.x = -0.5
	db.position.x = 0.5
	_step(drc, _mk(0, -1, GameConst.Btn.MK), _neutral(), 1)
	var dhp: int = db.health
	for i in range(14):
		if db.health < dhp:
			break
		_step(drc, _neutral(), _neutral(), 1)
	_step(drc, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	var entered_drc := false
	for i in range(36):
		_step(drc, _neutral(), _neutral(), 1)
		if da.state == Fighter.State.DRIVE_RUSH:
			entered_drc = true
			break
	_step(drc, _mk(0, 0, GameConst.Btn.MP), _neutral(), 1)
	var dr_target := false
	for i in range(24):
		_step(drc, _neutral(), _neutral(), 1)
		if da.current_move != null and da.current_move.id == "st_mp":
			dr_target = true
			break
	_check("cr.MK can DRC into combo starter", entered_drc and dr_target)
	drc["arena"].queue_free()

## New combo routes (see the combo-route comment in characters/blaze/blaze.gd). Verifies the
## wiring and that the headline combos connect: the light/low confirms, the new Flame Surge
## launcher, and the launcher -> super "Rising Inferno" juggle. Stays footsies-first:
## st.MK keeps no cancel routes.
func _test_blaze_combo_expansion() -> void:
	print("[blaze combo expansion]")
	var b := CharacterLibrary.create("blaze")
	# --- wiring (data) ---
	_check("st.MK stays a pure poke (no cancels)", b.get_move("st_mk").cancel_into.is_empty())
	_check("Cinder Low wired: cr.LK -> cr.MK", b.get_move("cr_lk").cancel_into.has("cr_mk"))
	var fs := b.get_move("flame_surge")
	_check("Flame Surge exists as a special", fs != null and fs.kind == GameConst.MoveKind.SPECIAL)
	_check("Flame Surge is 236 + MP", fs != null and fs.button == GameConst.Btn.MP and fs.motion == MotionParser.QCF)
	_check("Flame Surge is a launcher", fs != null and fs.launch and fs.launch_velocity > 0.0)
	_check("Flame Surge is committal on whiff (long recovery)", fs != null and fs.recovery >= 20)
	_check("Flame Surge has no invulnerable rise (route tool, not a reversal)", fs != null and not fs.rises)
	for starter in ["st_mp", "cr_mp", "cr_mk", "st_hp", "st_hk", "cr_hp"]:
		_check("%s can cancel into Flame Surge" % starter, b.get_move(starter).cancel_into.has("flame_surge"))
	for launcher in ["flame_surge", "cinder_lash", "ember_wheel", "cr_hk"]:
		_check("%s cancels into the super (Rising Inferno)" % launcher, b.get_move(launcher).cancel_into.has("super_inferno"))

	# --- Cinder into the air (headline): cr.MK > Flame Surge > Inferno Rush. A low medium
	# confirms into the new launcher, which juggles into the super. ---
	var air := _build()
	var aa: Fighter = air["f1"]
	var ab: Fighter = air["f2"]
	aa.meter = aa.character.max_meter
	aa.position.x = -0.34
	ab.position.x = 0.34
	var ahp: int = ab.health
	var amax := 0
	# cr.MK, then wait for it to connect before cancelling.
	_step(air, _mk(0, -1, GameConst.Btn.MK), _neutral(), 1)
	var amark: int = ab.health
	for i in range(12):
		if ab.health < amark:
			break
		_step(air, _mk(0, -1), _neutral(), 1)
	# Flame Surge (cancel): 236 + MP.
	_p1_qcf(air, GameConst.Btn.MP)
	for i in range(12):
		_step(air, _neutral(), _neutral(), 1)
		amax = maxi(amax, ab.combo_count)
		if ab.launched:
			break
	# Inferno Rush (cancel): 236236 + HP.
	_p1_qcf(air, 0)
	_p1_qcf(air, GameConst.Btn.HP)
	for i in range(60):
		_step(air, _neutral(), _neutral(), 1)
		amax = maxi(amax, ab.combo_count)
	_check("Cinder-into-the-air links cr.MK > Flame Surge > super (>=4 hits)", amax >= 4)
	_check("the full launching combo deals heavy damage", ahp - ab.health >= 150)
	air["arena"].queue_free()

	# --- Cinder Low: cr.LK > cr.MK (low-starting confirm) ---
	var low := _build()
	var la: Fighter = low["f1"]
	var lb: Fighter = low["f2"]
	la.position.x = -0.34
	lb.position.x = 0.34
	var lhp: int = lb.health
	var lmax := 0
	_step(low, _mk(0, -1, GameConst.Btn.LK), _neutral(), 1)
	for i in range(10):
		if lb.health < lhp:
			break
		_step(low, _mk(0, -1), _neutral(), 1)
	_step(low, _mk(0, -1, GameConst.Btn.MK), _neutral(), 2)
	for i in range(20):
		_step(low, _neutral(), _neutral(), 1)
		lmax = maxi(lmax, lb.combo_count)
	_check("Cinder Low links cr.LK > cr.MK (>=2 hits)", lmax >= 2)
	low["arena"].queue_free()

	# --- Flame Surge launcher + Rising Inferno juggle: 236+MP launches, super-cancel juggles ---
	var jug := _build()
	var ua: Fighter = jug["f1"]
	var ub: Fighter = jug["f2"]
	ua.meter = ua.character.max_meter
	ua.position.x = -0.4
	ub.position.x = 0.4
	var uhp: int = ub.health
	var umax := 0
	# Flame Surge (236 + MP).
	_step(jug, _mk(0, -1), _neutral(), 2)
	_step(jug, _mk(1, -1), _neutral(), 2)
	_step(jug, _mk(1, 0, GameConst.Btn.MP), _neutral(), 1)
	var surge_started := false
	for i in range(16):
		_step(jug, _neutral(), _neutral(), 1)
		umax = maxi(umax, ub.combo_count)
		if ua.current_move != null and ua.current_move.id == "flame_surge":
			surge_started = true
		if ub.launched:
			break
	var launched := ub.launched or not ub.on_ground
	_check("Flame Surge comes out on 236 + MP", surge_started)
	_check("Flame Surge launches the opponent into the air", launched)
	# Cancel into Inferno Rush (236236 + HP) while the launcher is connected.
	_step(jug, _mk(0, -1), _neutral(), 1)
	_step(jug, _mk(1, -1), _neutral(), 1)
	_step(jug, _mk(1, 0), _neutral(), 1)
	_step(jug, _mk(0, -1), _neutral(), 1)
	_step(jug, _mk(1, -1), _neutral(), 1)
	_step(jug, _mk(1, 0, GameConst.Btn.HP), _neutral(), 1)
	for i in range(60):
		_step(jug, _neutral(), _neutral(), 1)
		umax = maxi(umax, ub.combo_count)
	_check("Rising Inferno juggle: Flame Surge > super extends the combo (>=3 hits)", umax >= 3)
	_check("Rising Inferno juggle deals real damage", uhp - ub.health >= 100)
	jug["arena"].queue_free()

func _test_drive_gauge() -> void:
	print("[drive gauge]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	_check("Drive full at round start", f1.drive == f1.character.max_drive)
	f1.drive = 500
	var big := f1.spend_drive(1000)
	_check("spend fails when insufficient", big == false and f1.drive == 500)
	var ok := f1.spend_drive(300)
	_check("spend succeeds when affordable", ok and f1.drive == 200)
	var before: int = f1.drive
	_step(ctx, _neutral(), _neutral(), 30)
	_check("Drive regenerates over ticks", f1.drive > before)
	f1.meter = 50
	f1.drive = 4000
	f1.spend_drive(3000)
	_check("spending Drive leaves the Super meter unchanged", f1.meter == 50)
	ctx["arena"].queue_free()

func _drive_rush_dbltap(ctx: Dictionary) -> void:
	for fr in [_mk(1, 0), _mk(0, 0), _mk(1, 0)]:
		ctx["c1"].frame = fr
		ctx["c2"].frame = _neutral()
		ctx["arena"].step(DELTA)

func _test_drive_rush() -> void:
	print("[drive rush]")
	# Any two punch buttons from neutral start a raw green rush.
	for pair in [GameConst.Btn.LP | GameConst.Btn.MP, GameConst.Btn.LP | GameConst.Btn.HP, GameConst.Btn.MP | GameConst.Btn.HP]:
		var raw := _build()
		var r: Fighter = raw["f1"]
		var d_before: int = r.drive
		_step(raw, _mk(0, 0, pair), _neutral(), 1)
		_check("two-punch neutral input starts green rush", r.state == Fighter.State.DRIVE_RUSH)
		_check("raw green rush spends Drive", r.drive < d_before)
		raw["arena"].queue_free()
	# A genuine two-punch chord may be a frame staggered, but the buttons must OVERLAP (both held
	# at once). Press LP, then MP while still holding LP -> green rush.
	var stagger := _build()
	var sr: Fighter = stagger["f1"]
	var sd: int = sr.drive
	_step(stagger, _mk(0, 0, GameConst.Btn.LP, GameConst.Btn.LP), _neutral(), 1)
	_step(stagger, _mk(0, 0, GameConst.Btn.MP, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_check("overlapping staggered two-punch starts green rush", sr.state == Fighter.State.DRIVE_RUSH)
	_check("staggered raw green rush spends Drive", sr.drive < sd)
	stagger["arena"].queue_free()
	# A sequential string (press LP, release, then press MP -- no overlap) must NOT green rush;
	# it is a normal combo attempt. Regression: LP-then-MP used to false-trigger a raw rush.
	var seq := _build()
	var qr: Fighter = seq["f1"]
	var qd: int = qr.drive
	_step(seq, _mk(0, 0, GameConst.Btn.LP, GameConst.Btn.LP), _neutral(), 1)
	_step(seq, _mk(0, 0, GameConst.Btn.MP, GameConst.Btn.MP), _neutral(), 1)
	_check("sequential LP then MP does not green rush", qr.state != Fighter.State.DRIVE_RUSH)
	_check("sequential LP then MP spends no Drive", qr.drive == qd)
	seq["arena"].queue_free()
	var late := _build()
	var lr: Fighter = late["f1"]
	var ld: int = lr.drive
	_step(late, _mk(0, 0, GameConst.Btn.LP, GameConst.Btn.LP), _neutral(), 1)
	_step(late, _neutral(), _neutral(), Fighter.GREEN_RUSH_CHORD_BUFFER + 1)
	_step(late, _mk(0, 0, GameConst.Btn.MP, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_check("late normal-startup green rush input is ignored", lr.state == Fighter.State.ATTACK)
	_check("late startup green rush input spends no Drive", lr.drive == ld)
	late["arena"].queue_free()
	var accel := _build()
	var gr: Fighter = accel["f1"]
	var start_x: float = gr.position.x
	_step(accel, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	var start_speed := absf(gr.velocity.x)
	_step(accel, _neutral(), _neutral(), 1)
	var startup_speed := absf(gr.velocity.x)
	_step(accel, _neutral(), _neutral(), Fighter.DRIVE_RUSH_STARTUP_TICKS - 1)
	var startup_dist: float = gr.position.x - start_x
	var still_starting := gr.state == Fighter.State.DRIVE_RUSH
	_step(accel, _neutral(), _neutral(), 6)
	var mid_speed := absf(gr.velocity.x)
	_step(accel, _neutral(), _neutral(), Fighter.DRIVE_RUSH_ACCEL_TICKS)
	var full_speed := absf(gr.velocity.x)
	_step(accel, _neutral(), _neutral(), Fighter.DRIVE_RUSH_DURATION)
	var total_dist: float = gr.position.x - start_x
	_check("green rush starts below full speed", start_speed < 0.1 and startup_speed > 0.1 and startup_speed < Fighter.DRIVE_RUSH_SPEED * 0.025)
	_check("green rush has a visible startup wind-up", startup_dist > 0.015 and startup_dist < 0.06 and still_starting)
	_check("green rush accelerates gradually", mid_speed > startup_speed and mid_speed < Fighter.DRIVE_RUSH_SPEED * 0.65)
	_check("green rush accelerates to full speed", full_speed > startup_speed + 5.0 and full_speed >= Fighter.DRIVE_RUSH_SPEED * 0.95)
	_check("green rush total travel is closer", total_dist > 2.4 and total_dist < 4.2)
	accel["arena"].queue_free()
	var cancel := _build()
	var cr: Fighter = cancel["f1"]
	_step(cancel, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_step(cancel, _neutral(), _neutral(), Fighter.DRIVE_RUSH_STARTUP_TICKS + Fighter.DRIVE_RUSH_ACCEL_TICKS)
	var rush_speed_before_brake := absf(cr.velocity.x)
	_step(cancel, _mk(-cr.facing, 0), _neutral(), 1)
	var speed_after_back := absf(cr.velocity.x)
	var drive_before_reinput: int = cr.drive
	_step(cancel, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_check("back input cannot cancel green rush", cr.state == Fighter.State.DRIVE_RUSH and speed_after_back > rush_speed_before_brake * 0.8)
	_check("green rush input is ignored while already rushing", cr.drive > drive_before_reinput - Fighter.RAW_DRIVE_RUSH_COST)
	cancel["arena"].queue_free()
	var whiff := _build()
	var wr: Fighter = whiff["f1"]
	wr.position.x = -5.0
	whiff["f2"].position.x = 5.0
	_step(whiff, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_step(whiff, _neutral(), _neutral(), Fighter.DRIVE_RUSH_STARTUP_TICKS + 1)
	_step(whiff, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	for i in range(wr.character.get_move("st_hp").total_frames() + 4):
		_step(whiff, _neutral(), _neutral(), 1)
	_check("Drive Rush whiff normal clears pending FX state", not wr.drive_rush_pending and wr.state != Fighter.State.DRIVE_RUSH)
	whiff["arena"].queue_free()
	# Attacking out of Green Rush stays responsive even while the two punch buttons that
	# launched the rush are still held (regression: leftover held punches must not swallow the
	# attack), and the normal still gets the enhanced Drive Rush bonus.
	var heldatk := _build()
	var grf: Fighter = heldatk["f1"]
	_step(heldatk, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_step(heldatk, _neutral(), _neutral(), Fighter.DRIVE_RUSH_STARTUP_TICKS + 1)
	_step(heldatk, _mk(0, 0, GameConst.Btn.HP, GameConst.Btn.LP | GameConst.Btn.MP | GameConst.Btn.HP), _neutral(), 1)
	_check("Green Rush attack fires while rush punches still held", grf.state == Fighter.State.ATTACK and grf.current_move != null)
	_check("held-button Green Rush attack keeps the enhanced bonus", grf.drive_rush_pending)
	heldatk["arena"].queue_free()
	# Back-back (<-<-) interrupts Green Rush, but the momentum brakes over a short skid instead
	# of stopping dead, then control returns to neutral. A single back must NOT cancel.
	var brk := _build()
	var bf: Fighter = brk["f1"]
	_step(brk, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_step(brk, _neutral(), _neutral(), Fighter.DRIVE_RUSH_STARTUP_TICKS + Fighter.DRIVE_RUSH_ACCEL_TICKS)
	var full_rush := absf(bf.velocity.x)
	_step(brk, _mk(-bf.facing, 0), _neutral(), 1)            # first back tap: still rushing
	var rushing_on_first_back := bf.state == Fighter.State.DRIVE_RUSH and absf(bf.velocity.x) > full_rush * 0.8
	_step(brk, _neutral(), _neutral(), 1)                    # release
	_step(brk, _mk(-bf.facing, 0), _neutral(), 1)            # second back tap: interrupt + brake
	var brake_speed := absf(bf.velocity.x)
	_step(brk, _neutral(), _neutral(), 1)
	var brake_speed_2 := absf(bf.velocity.x)
	var brake_ticks := 0
	for i in range(30):
		if bf.state != Fighter.State.DRIVE_RUSH:
			break
		_step(brk, _neutral(), _neutral(), 1)
		brake_ticks += 1
	_check("single back does not cancel Green Rush", rushing_on_first_back)
	_check("back-back brakes instead of stopping dead", brake_speed > 0.0 and brake_speed < full_rush)
	_check("Green Rush brake keeps decelerating", brake_speed_2 < brake_speed)
	_check("Green Rush brake is a process, not an instant stop", brake_ticks >= 1)
	_check("Green Rush brake returns to neutral after the skid", bf.state == Fighter.State.IDLE and absf(bf.velocity.x) < 0.001)
	brk["arena"].queue_free()
	# Forward double-tap is still a normal dash, not a raw Drive Rush.
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var d0: int = f1.drive
	_drive_rush_dbltap(ctx)
	_check("forward double-tap is dash, not raw Drive Rush", f1.state == Fighter.State.DASH_F)
	_check("forward double-tap spends no Drive", f1.drive == d0)
	ctx["arena"].queue_free()
	# Drive Rush Cancel off a connected normal: two punches spend 3 bars, enters DRIVE_RUSH, extends.
	var ctxa := _build()
	var a: Fighter = ctxa["f1"]
	var b: Fighter = ctxa["f2"]
	a.position.x = -0.7
	b.position.x = 0.6
	var da: int = a.drive
	ctxa["c1"].frame = _mk(0, 0, GameConst.Btn.MP)
	ctxa["c2"].frame = _neutral()
	ctxa["arena"].step(DELTA)
	var bh0: int = b.health
	for i in range(8):
		if b.health < bh0: break
		ctxa["c1"].frame = _neutral()
		ctxa["c2"].frame = _neutral()
		ctxa["arena"].step(DELTA)
	var drc_entered := false
	for i in range(20):
		var fr := _neutral()
		if a.hitstop == 0:
			fr = _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP)
		ctxa["c1"].frame = fr
		ctxa["c2"].frame = _neutral()
		ctxa["arena"].step(DELTA)
		if a.state == Fighter.State.DRIVE_RUSH:
			drc_entered = true
			break
	var drive_after_drc: int = a.drive
	_check("DRC entered Drive Rush off a connected normal", drc_entered)
	_check("DRC spent ~3 bars", drive_after_drc <= da - Fighter.DRC_COST + 60)
	var bh1: int = b.health
	var follow_hit := false
	for i in range(Fighter.DRIVE_RUSH_STARTUP_TICKS + 18):
		ctxa["c1"].frame = _mk(0, 0, GameConst.Btn.HP)
		ctxa["c2"].frame = _neutral()
		ctxa["arena"].step(DELTA)
		if b.health < bh1:
			follow_hit = true
	_check("Drive Rush follow-up normal connected", follow_hit)
	ctxa["arena"].queue_free()
	# DRC accepts slightly staggered two-punch inputs, even when the first punch is released.
	var ctxs := _build()
	var sa: Fighter = ctxs["f1"]
	var sb: Fighter = ctxs["f2"]
	sa.position.x = -0.7
	sb.position.x = 0.6
	var sdrive: int = sa.drive
	ctxs["c1"].frame = _mk(0, 0, GameConst.Btn.MK)
	ctxs["c2"].frame = _neutral()
	ctxs["arena"].step(DELTA)
	var shp: int = sb.health
	for i in range(12):
		if sb.health < shp:
			break
		ctxs["c1"].frame = _neutral()
		ctxs["c2"].frame = _neutral()
		ctxs["arena"].step(DELTA)
	_step(ctxs, _mk(0, 0, GameConst.Btn.LP, GameConst.Btn.LP), _neutral(), 1)
	_step(ctxs, _mk(0, 0, GameConst.Btn.MP, GameConst.Btn.MP), _neutral(), 1)
	var staggered_drc := false
	for i in range(30):
		_step(ctxs, _neutral(), _neutral(), 1)
		if sa.state == Fighter.State.DRIVE_RUSH:
			staggered_drc = true
			break
	_check("DRC accepts staggered two-punch input", staggered_drc)
	_check("staggered DRC spent ~3 bars", sa.drive <= sdrive - Fighter.DRC_COST + 60)
	ctxs["arena"].queue_free()
	# DRC can be input slightly before contact; it waits for the normal to connect.
	var ctxe := _build()
	var ea: Fighter = ctxe["f1"]
	var eb: Fighter = ctxe["f2"]
	ea.position.x = -0.7
	eb.position.x = 0.6
	var edrive: int = ea.drive
	_step(ctxe, _mk(0, 0, GameConst.Btn.MK), _neutral(), 1)
	_step(ctxe, _neutral(), _neutral(), 2)
	_step(ctxe, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	var early_drc := false
	for i in range(40):
		_step(ctxe, _neutral(), _neutral(), 1)
		if ea.state == Fighter.State.DRIVE_RUSH:
			early_drc = true
			break
	_check("DRC input slightly before contact is buffered", early_drc)
	_check("early DRC spent ~3 bars", ea.drive <= edrive - Fighter.DRC_COST + 60)
	ctxe["arena"].queue_free()
	# A DRC follow-up pressed during the startup keeps its direction, so early 2HP becomes cr.HP.
	var ctxc := _build()
	var ca: Fighter = ctxc["f1"]
	var cb: Fighter = ctxc["f2"]
	ca.position.x = -0.7
	cb.position.x = 0.6
	_step(ctxc, _mk(0, 0, GameConst.Btn.MP), _neutral(), 1)
	var chp: int = cb.health
	for i in range(8):
		if cb.health < chp:
			break
		_step(ctxc, _neutral(), _neutral(), 1)
	for i in range(20):
		var fr := _neutral()
		if ca.hitstop == 0:
			fr = _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP)
		_step(ctxc, fr, _neutral(), 1)
		if ca.state == Fighter.State.DRIVE_RUSH:
			break
	_step(ctxc, _mk(0, -1, GameConst.Btn.HP), _neutral(), 1)
	var crhp_started := false
	for i in range(Fighter.DRIVE_RUSH_STARTUP_TICKS + 8):
		_step(ctxc, _neutral(), _neutral(), 1)
		if ca.current_move != null and ca.current_move.id == "cr_hp":
			crhp_started = true
			break
	_check("DRC startup buffers crouch HP direction", crhp_started)
	ctxc["arena"].queue_free()
	# DRC input is buffered through hitstop: players can press two punches during impact freeze and
	# get the cancel on the first actionable frame after freeze.
	var ctxh := _build()
	var ha: Fighter = ctxh["f1"]
	var hb: Fighter = ctxh["f2"]
	ha.position.x = -0.7
	hb.position.x = 0.6
	var hda: int = ha.drive
	ctxh["c1"].frame = _mk(0, 0, GameConst.Btn.MP)
	ctxh["c2"].frame = _neutral()
	ctxh["arena"].step(DELTA)
	var hhp: int = hb.health
	for i in range(8):
		if hb.health < hhp:
			break
		ctxh["c1"].frame = _neutral()
		ctxh["c2"].frame = _neutral()
		ctxh["arena"].step(DELTA)
	var buffered_drc_started_in_hitstop := ha.hitstop > 0
	ctxh["c1"].frame = _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP)
	ctxh["c2"].frame = _neutral()
	ctxh["arena"].step(DELTA)
	var hitstop_buffered_drc := false
	for i in range(20):
		ctxh["c1"].frame = _neutral()
		ctxh["c2"].frame = _neutral()
		ctxh["arena"].step(DELTA)
		if ha.state == Fighter.State.DRIVE_RUSH:
			hitstop_buffered_drc = true
			break
	_check("DRC accepts two punches buffered during hitstop", buffered_drc_started_in_hitstop and hitstop_buffered_drc)
	_check("hitstop-buffered DRC spent ~3 bars", ha.drive <= hda - Fighter.DRC_COST + 60)
	ctxh["arena"].queue_free()
	# Heavy punish-counter hitstop exceeds the DRC input buffer window; a two-punch input at
	# the start of freeze must still survive until the attacker advances again.
	var ctxp := _build()
	var pa: Fighter = ctxp["f1"]
	var pb: Fighter = ctxp["f2"]
	pa.position.x = -0.38
	pb.position.x = 0.38
	# Put the victim in HP recovery so P1's heavy hit becomes a Punish Counter with long freeze.
	pb.current_move = pb.character.get_move("st_hp")
	pb._goto(Fighter.State.ATTACK)
	pb.state_frame = pb.current_move.startup + pb.current_move.active + 1
	var pdrive: int = pa.drive
	_step(ctxp, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	var php: int = pb.health
	for i in range(14):
		if pb.health < php:
			break
		_step(ctxp, _neutral(), _neutral(), 1)
	var long_hitstop_started := pa.hitstop > 0
	pa.hitstop = Fighter.DRC_INPUT_BUFFER + 4
	_step(ctxp, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	var long_hitstop_drc := false
	for i in range(40):
		_step(ctxp, _neutral(), _neutral(), 1)
		if pa.state == Fighter.State.DRIVE_RUSH:
			long_hitstop_drc = true
			break
	_check("DRC input survives long punish hitstop", long_hitstop_started and long_hitstop_drc)
	_check("long-hitstop DRC spent ~3 bars", pa.drive <= pdrive - Fighter.DRC_COST + 60)
	ctxp["arena"].queue_free()
	# DRC also works off a blocked normal (pressure). Corner the defender so holding back
	# blocks in place instead of walking out of range (Blaze's MP reach is short).
	var ctxb := _build()
	var p: Fighter = ctxb["f1"]
	var q: Fighter = ctxb["f2"]
	p.position.x = 6.0
	q.position.x = 6.6
	ctxb["c1"].frame = _mk(0, 0, GameConst.Btn.MP)
	ctxb["c2"].frame = _mk(1, 0)
	ctxb["arena"].step(DELTA)
	var did_block := false
	for i in range(8):
		ctxb["c1"].frame = _neutral()
		ctxb["c2"].frame = _mk(1, 0)
		ctxb["arena"].step(DELTA)
		if q.state == Fighter.State.BLOCKSTUN:
			did_block = true
	var drc_block := false
	for i in range(20):
		var fr := _neutral()
		if p.hitstop == 0:
			fr = _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP)
		ctxb["c1"].frame = fr
		ctxb["c2"].frame = _mk(1, 0)
		ctxb["arena"].step(DELTA)
		if p.state == Fighter.State.DRIVE_RUSH:
			drc_block = true
			break
	_check("normal was blocked", did_block)
	_check("DRC off a blocked normal (pressure)", drc_block)
	ctxb["arena"].queue_free()

func _test_uppercut_rise() -> void:
	print("[rising specials removed]")
	var b := CharacterLibrary.create("blaze")
	var any_rising_special := false
	for m in b.specials:
		any_rising_special = any_rising_special or m.rises
	_check("Blaze has no shoryuken/rising special", not any_rising_special and b.get_move("uppercut") == null)
	_check("new combo specials are grounded route tools", b.get_move("flame_step_m") != null and b.get_move("ember_wheel") != null)

func _test_rise_interruption_lands() -> void:
	print("[rise interruption]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	var uppercut := _find_move(f1.character, "uppercut")
	var jab := _find_move(f2.character, "st_lp")
	f1.current_move = uppercut
	f1._goto(Fighter.State.ATTACK)
	f1.state_frame = uppercut.startup + 2
	f1.position.y = uppercut.rise_height
	f1.on_ground = true
	f1.velocity = Vector3.ZERO
	f1.receive_attack(jab, f2.facing)
	var suspended_y := f1.position.y
	var started_falling := false
	for i in range(jab.hitstop + 20):
		_step(ctx, _neutral(), _neutral(), 1)
		if not f1.on_ground and f1.position.y < suspended_y:
			started_falling = true
			break
	_check("interrupted rise leaves the grounded state and starts falling", started_falling)
	var landed := false
	for i in range(120):
		_step(ctx, _neutral(), _neutral(), 1)
		if f1.on_ground and absf(f1.position.y) < 0.01:
			landed = true
			break
	_check("interrupted rise lands back on the floor", landed)
	ctx["arena"].queue_free()

func _test_camera() -> void:
	print("[camera]")
	var cam := FightCamera.new()
	root.add_child(cam)
	# Close (fighters ~touching): camera pulls in to its nearest framing.
	for i in range(40):
		cam.track(Vector3(-0.4, 0, 0), Vector3(0.4, 0, 0))
	_check("camera pulls in when fighters are close", cam.position.z <= FightCamera.MIN_Z + 0.3)
	# Far (fighters near the widest legal separation): camera zooms out, capped at MAX_Z.
	var far_x := Arena.MAX_VISIBLE_SEPARATION * 0.5
	for i in range(80):
		cam.track(Vector3(-far_x, 0, 0), Vector3(far_x, 0, 0))
	_check("camera zooms out when fighters separate", cam.position.z > FightCamera.MIN_Z + 0.7)
	_check("camera zoom stays within MAX_Z", cam.position.z <= FightCamera.MAX_Z + 0.01)
	var halfw: float = cam.position.z * cam._half_width_tan()
	_check("both fighters stay on screen when far", far_x - absf(cam.position.x) <= halfw + 0.05)
	# Feet anchored near the bottom across zoom: derive the feet's screen fraction from the
	# camera pitch (rotation.x), which look_at_from_position sets reliably (unlike the global
	# basis out of tree). Verify it stays put at both near and far zoom.
	var feet_frac := func(c: FightCamera) -> float:
		var center := rad_to_deg(c.rotation.x)
		var feet_world := -rad_to_deg(atan(c.position.y / c.position.z))
		return (1.0 - (feet_world - center) / (FightCamera.FOV * 0.5)) * 0.5
	var world_frac := func(c: FightCamera, world_y: float) -> float:
		var center := rad_to_deg(c.rotation.x)
		var world_deg := -rad_to_deg(atan((c.position.y - world_y) / c.position.z))
		return (1.0 - (world_deg - center) / (FightCamera.FOV * 0.5)) * 0.5
	var far_frac: float = feet_frac.call(cam)
	for i in range(60):
		cam.track(Vector3(-0.4, 0, 0), Vector3(0.4, 0, 0))
	var near_frac: float = feet_frac.call(cam)
	_check("feet anchored near bottom when far", absf(far_frac - FightCamera.FEET_FRAC) < 0.03)
	_check("feet anchored near bottom when close", absf(near_frac - FightCamera.FEET_FRAC) < 0.03)
	for i in range(40):
		cam.track(Vector3(-0.4, 2.8, 0), Vector3(0.4, 0, 0))
	_check("camera lifts a bit for a high jump", cam.position.y > FightCamera.HEIGHT + 0.35)
	_check("camera pans upward for a high jump", world_frac.call(cam, 0.0) > FightCamera.FEET_FRAC + 0.02)
	for i in range(60):
		cam.track(Vector3(-0.4, 0, 0), Vector3(0.4, 0, 0))
	_check("camera settles back after landing", absf(cam.position.y - FightCamera.HEIGHT) < 0.2)
	cam.free()

func _test_input_buffer() -> void:
	print("[input buffer]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	# Keep them apart so st_hp whiffs (no cancels available) and LP can only come from the
	# neutral input buffer, not a cancel.
	f1.position.x = -4.0
	f2.position.x = 5.0
	var hp := f1.character.get_move("st_hp")
	# Start stand HP.
	_step(ctx, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	_check("stand HP started", f1.current_move != null and f1.current_move.id == "st_hp")
	# Advance to within the buffer window of the end of recovery.
	while f1.state == Fighter.State.ATTACK and f1.state_frame < hp.total_frames() - 2:
		_step(ctx, _neutral(), _neutral(), 1)
	# Press LP a couple frames BEFORE actionable; release; it must fire on the first free frame.
	_step(ctx, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)
	var saw_lp := false
	for i in range(6):
		_step(ctx, _neutral(), _neutral(), 1)
		if f1.current_move != null and f1.current_move.id == "st_lp":
			saw_lp = true
	_check("buffered attack fires on the first actionable frame", saw_lp)
	ctx["arena"].queue_free()

func _test_overdrive() -> void:
	print("[overdrive removed]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var arena: Arena = ctx["arena"]
	var od := f1.character.get_move("od_fireball")
	_check("OD fireball removed", od == null)
	var od_dp := f1.character.get_move("od_uppercut")
	_check("OD uppercut removed", od_dp == null)
	var d0: int = f1.drive
	# QCF + two punches now means the universal green rush input, not an OD special.
	_step(ctx, _mk(0, -1), _neutral(), 3)
	_step(ctx, _mk(1, -1), _neutral(), 3)
	_step(ctx, _mk(1, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_check("two-punch motion starts green rush, not OD", f1.state == Fighter.State.DRIVE_RUSH and f1.drive < d0)
	_check("two-punch motion spawns no OD projectile", arena.projectiles.is_empty())
	ctx["arena"].queue_free()

func _test_combo_scaling() -> void:
	print("[combo scaling]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	# Scaling function: unscaled early, tapering later, floored.
	_check("hit 1 unscaled", f2._scaled_damage(100, 1) == 100)
	_check("hit 3 unscaled", f2._scaled_damage(100, 3) == 100)
	_check("hit 5 scaled to 80%", f2._scaled_damage(100, 5) == 80)
	_check("deep combo floored at 60%", f2._scaled_damage(100, 20) == 60)
	# Combo counter still tracks true multi-hit attacks, even though authored normal routes
	# have been removed.
	f1.meter = f1.character.max_meter
	f1.position.x = 5.2
	f2.position.x = 6.2
	var max_combo := 0
	var script: Array = []
	for i in range(2): script.append(_mk(0, -1))
	for i in range(2): script.append(_mk(1, -1))
	for i in range(2): script.append(_mk(1, 0))
	for i in range(2): script.append(_mk(0, -1))
	for i in range(2): script.append(_mk(1, -1))
	script.append(_mk(1, 0, GameConst.Btn.HP))
	for i in range(90): script.append(_neutral())
	for fr in script:
		ctx["c1"].frame = fr
		ctx["c2"].frame = _neutral()
		ctx["arena"].step(DELTA)
		max_combo = maxi(max_combo, f2.combo_count)
	_check("combo counter reached >= 2 hits", max_combo >= 2)
	_step(ctx, _neutral(), _neutral(), 90)
	_check("combo counter resets after the victim recovers", f2.combo_count == 0)
	ctx["arena"].queue_free()

func _test_burnout() -> void:
	print("[burnout]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	f1.drive = 1000
	var ok := f1.spend_drive(1000)
	_check("spending the last bar empties the gauge", ok and f1.drive == 0)
	_check("Burnout is active when the gauge empties", f1.is_burnout())
	_step(ctx, _neutral(), _neutral(), 30)
	_check("Drive regen is paused during Burnout", f1.drive == 0)
	_step(ctx, _neutral(), _neutral(), 120)
	_check("Drive recovers after the Burnout window", f1.drive > 0)
	ctx["arena"].queue_free()

func _test_drive_rush_carry() -> void:
	print("[drive rush carry]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.7
	f2.position.x = 0.6
	ctx["c1"].frame = _mk(0, 0, GameConst.Btn.MP)
	ctx["c2"].frame = _neutral()
	ctx["arena"].step(DELTA)
	var hp_before: int = f2.health
	for i in range(8):
		if f2.health < hp_before:
			break
		ctx["c1"].frame = _neutral()
		ctx["c2"].frame = _neutral()
		ctx["arena"].step(DELTA)
	ctx["c1"].frame = _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP)
	ctx["c2"].frame = _neutral()
	ctx["arena"].step(DELTA)
	var entered_drc := false
	for i in range(20):
		ctx["c1"].frame = _neutral()
		ctx["c2"].frame = _neutral()
		ctx["arena"].step(DELTA)
		if f1.state == Fighter.State.DRIVE_RUSH:
			entered_drc = true
			break
	_check("entered Drive Rush from DRC", entered_drc)
	# Cancel the rush into a standing normal: pressing during startup buffers and then slides forward.
	_step(ctx, _mk(0, 0, GameConst.Btn.MP), _neutral(), 1)
	for i in range(Fighter.DRIVE_RUSH_STARTUP_TICKS + 2):
		if f1.state == Fighter.State.ATTACK:
			break
		_step(ctx, _neutral(), _neutral(), 1)
	_check("Drive Rush normal started", f1.state == Fighter.State.ATTACK)
	_check("Drive Rush normal carries forward momentum", f1.velocity.x > 0.8)
	ctx["arena"].queue_free()

## System guardrails (see docs/footsies-design.md): Green Rush / DRC must AMPLIFY a spacing
## win, not replace neutral. The cheap, powerful extending cancel (DRC) is gated behind a
## CONNECTED normal; a whiffed poke cannot be cancelled into a rush to skip neutral.
func _test_system_amplifies_neutral() -> void:
	print("[system amplifies neutral]")
	# Invariants: the post-contact rush is dearer than the raw neutral rush, and the raw rush
	# has a real wind-up, so it cannot instantly teleport past mid-range.
	_check("DRC (post-contact rush) costs more than a raw neutral green rush",
		Fighter.DRC_COST > Fighter.RAW_DRIVE_RUSH_COST)
	_check("raw green rush has a startup wind-up (not an instant neutral skip)",
		Fighter.DRIVE_RUSH_STARTUP_TICKS > 0 and Fighter.DRIVE_RUSH_START_SPEED < Fighter.DRIVE_RUSH_SPEED)

	# A) "Starts after a spacing win": a CONNECTED normal can DRC into a rush, spending ~3 bars.
	var ctx := _build()
	var a: Fighter = ctx["f1"]
	var b: Fighter = ctx["f2"]
	a.position.x = -0.7
	b.position.x = 0.6
	var drive0: int = a.drive
	ctx["c1"].frame = _mk(0, 0, GameConst.Btn.MP)
	ctx["c2"].frame = _neutral()
	ctx["arena"].step(DELTA)
	var bh0: int = b.health
	for i in range(8):
		if b.health < bh0:
			break
		_step(ctx, _neutral(), _neutral(), 1)
	var drc_entered := false
	for i in range(20):
		var fr := _neutral()
		if a.hitstop == 0:
			fr = _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP)
		ctx["c1"].frame = fr
		ctx["c2"].frame = _neutral()
		ctx["arena"].step(DELTA)
		if a.state == Fighter.State.DRIVE_RUSH:
			drc_entered = true
			break
	_check("a connected poke can DRC into a rush (cash out a spacing win)", drc_entered)
	_check("DRC off a connected normal spent ~3 bars", a.drive <= drive0 - Fighter.DRC_COST + 100)
	ctx["arena"].queue_free()

	# B) "Does not skip neutral too easily": a WHIFFED poke cannot be cancelled into a rush
	# during its recovery (after the brief from-startup green-rush window has passed).
	var miss := _build()
	var m1: Fighter = miss["f1"]
	var m2: Fighter = miss["f2"]
	m1.position.x = -5.0
	m2.position.x = 5.0
	var miss_drive0: int = m1.drive
	var st_mp := m1.character.get_move("st_mp")
	_step(miss, _mk(0, 0, GameConst.Btn.MP), _neutral(), 1)
	# Advance past the early from-startup green-rush window into the whiff's recovery.
	_step(miss, _neutral(), _neutral(), Fighter.GREEN_RUSH_CHORD_BUFFER + 2)
	var poke_whiffed := m1.move_hits_done == 0
	var rushed_off_whiff := false
	for i in range(st_mp.active + st_mp.recovery):
		if m1.state != Fighter.State.ATTACK:
			break
		_step(miss, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
		if m1.state == Fighter.State.DRIVE_RUSH:
			rushed_off_whiff = true
			break
	_check("the test poke actually whiffed (no contact)", poke_whiffed)
	_check("a whiffed poke cannot be cancelled into a rush (no free skip past neutral)",
		not rushed_off_whiff)
	_check("a whiffed-poke two-punch input spends no Drive", m1.drive == miss_drive0)
	miss["arena"].queue_free()

func _test_hud_combo_and_fx() -> void:
	print("[hud combo + drive-rush fx]")
	var c1 := CharacterLibrary.create("blaze")
	var c2 := CharacterLibrary.create("blaze")
	var hud := HUD.new()
	root.add_child(hud)
	hud.build(c1, c2)
	# Recoverable-health trail: after damage it lags above the real HP, then eases down.
	hud.set_health(0, 1000, 1000)
	hud.set_health(0, 500, 1000)
	_check("trail starts above the damaged HP", hud._trail_frac[0] > 0.55)
	for i in range(120):
		hud.tick_visuals(1.0 / 60.0)
	_check("trail eases down to the real HP", absf(hud._trail_frac[0] - 0.5) < 0.05)
	# Combo counter shows on >= 2 hits, then fades out.
	hud.set_combo(0, 7, 312)
	_check("combo label visible immediately on update", hud._combo_label[0].modulate.a > 0.9)
	hud.tick_visuals(1.0 / 60.0)
	_check("combo label populated", hud._combo_label[0].text.contains("7 HITS"))
	_check("combo label visible while live", hud._combo_label[0].modulate.a > 0.5)
	for i in range(120):
		hud.tick_visuals(1.0 / 60.0)
	_check("combo label faded after the combo ended", hud._combo_label[0].modulate.a < 0.05)
	# Meter MAX glow + Drive Burnout flash don't error and toggle off cleanly.
	hud.set_meter(0, 100, 100)
	hud.set_burnout(0, true)
	hud.set_dr_tint(MatchScene.DRIVE_RUSH_TINT_TARGET, Color(0.35, 1.0, 0.7))
	hud.tick_visuals(1.0 / 60.0)
	_check("drive-rush screen tint is subtle", hud._dr_tint.color.a <= 0.08)
	_check("MAX glow active when meter full", hud._mp_glow[0].color.a > 0.0)
	hud.set_meter(0, 40, 100)
	hud.set_burnout(0, false)
	hud.tick_visuals(1.0 / 60.0)
	_check("MAX glow clears when meter spent", hud._mp_glow[0].color.a == 0.0)
	hud.free()
	# DriveRushFx emits pose snapshots while the fighter rushes and stops otherwise.
	var f := Fighter.new()
	f.setup(CharacterLibrary.create("blaze"), Manual.new(), GameConst.Side.P1, 0.0)
	root.add_child(f)
	var rig := FighterRig.new()
	f.add_child(rig)
	rig.build(f.character)
	f.rig = rig
	var fx := DriveRushFx.new()
	root.add_child(fx)
	fx.setup(f, Color(0.35, 1.0, 0.7))
	f.state = Fighter.State.DRIVE_RUSH
	f.update_visual()
	for i in range(6):
		fx._process(0.03)
	_check("drive-rush fx spawned ghost trail snapshots", fx._ghosts.size() >= 1)
	_check("drive-rush fx emits fewer ghost snapshots", fx._ghosts.size() <= 4)
	if not fx._ghosts.is_empty():
		_check("drive-rush fx ghost copies character meshes", fx._ghosts[0]["meshes"].size() > 1)
		var ghost_mat: StandardMaterial3D = fx._ghosts[0]["mats"][0]
		_check("drive-rush fx ghost is faint", ghost_mat.albedo_color.a <= DriveRushFx.GHOST_ALPHA and ghost_mat.emission_energy_multiplier <= DriveRushFx.GHOST_EMISSION)
	f.state = Fighter.State.IDLE
	f.drive_rush_pending = false
	for i in range(20):
		fx._process(0.03)
	_check("drive-rush fx ghost trail fades out", fx._ghosts.is_empty())
	f.free()
