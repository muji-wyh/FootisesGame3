extends SceneTree

## Headless test harness for the combat simulation. Run with:
##   godot --headless --script res://tools/run_tests.gd
## Scripts inputs into the Arena and asserts outcomes (movement, hits, blocking,
## hitstun, projectiles, meter, supers, KO). Prints a PASS/FAIL summary.

const DELTA := 1.0 / 60.0
const FORCE_FAIL_ARG := "--force-fail"

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

func _p1_qcb(ctx: Dictionary, button: int) -> void:
	_step(ctx, _mk(0, -1), _neutral(), 2)
	_step(ctx, _mk(-1, -1), _neutral(), 2)
	_step(ctx, _mk(-1, 0, button), _neutral(), 1)

func _same_string_set(actual: Array, expected: Array) -> bool:
	var lhs := actual.duplicate()
	var rhs := expected.duplicate()
	lhs.sort()
	rhs.sort()
	return lhs == rhs

func _initialize() -> void:
	print("=== Brawl Arena combat tests ===")
	if OS.get_cmdline_user_args().has(FORCE_FAIL_ARG):
		_check("forced harness failure", false)
		_finish()
		return
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
	_test_boot_deep_link()
	_test_blaze_roster()
	_test_ember_lift()
	_test_animation_ownership()
	_test_animation_gallery2()
	_test_vfx_gallery()
	_test_move_list_overlay()
	_test_multihit()
	_test_move_sfx()
	_test_animated_rig()
	_test_impact_shake()
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
	_test_okizeme()
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
	_finish()

func _finish() -> void:
	print("=== Results: %d passed, %d failed ===" % [_passed, _failed])
	if _failed == 0:
		print("ALL TESTS PASSED")
	else:
		print("THERE WERE FAILURES")
	quit(1 if _failed > 0 else 0)

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
	_check("standing LP impact spawns at jab fist height", f2.last_hit_point.y >= 1.25)
	ctx["arena"].queue_free()

	var hk_ctx := _build()
	var h1: Fighter = hk_ctx["f1"]
	var h2: Fighter = hk_ctx["f2"]
	h1.position.x = -0.5
	h2.position.x = 0.5
	_step(hk_ctx, _mk(0, 0, GameConst.Btn.HK), _neutral(), 1)
	_step(hk_ctx, _neutral(), _neutral(), 24)
	_check("standing HK impact spawns at high-kick height", h2.last_hit_point.y >= 1.3)
	hk_ctx["arena"].queue_free()

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
	_check("stand HP hitbox is centered at shoulder height",
		st_hp.hit_offset.y >= 1.35 and st_hp.hit_offset.y <= 1.45)
	# Flame Step H (236+HK) hitbox must stay proportionate to the model: not wider/taller than the
	# character hurtbox (~0.84 wide). Regression: it used to be 0.90 wide -- bigger than the model.
	var flame_step_h := blaze.get_move("flame_step_h")
	_check("Flame Step H (236+HK) hitbox fits the model", flame_step_h.hit_size.x < 0.8 and flame_step_h.hit_size.y < 0.65)
	var cinder_lash := blaze.get_move("cinder_lash")
	_check("Cinder Lash (236+HP) hitbox fits the overhand animation",
		cinder_lash.hit_size.x <= 0.42 and cinder_lash.hit_size.y <= 0.48
		and cinder_lash.hit_offset.x + cinder_lash.hit_size.x * 0.5 <= 0.93)
	var ember_wheel := blaze.get_move("ember_wheel")
	_check("Ember Wheel (214+HK) hitbox fits the spin animation",
		ember_wheel.hit_size.x <= 0.36 and ember_wheel.hit_size.y <= 0.44
		and ember_wheel.hit_offset.x + ember_wheel.hit_size.x * 0.5 <= 0.76)
	# Flame Surge is a cancel route, not a neutral tool, so its box has to stay a rising fist:
	# it used to be the largest box in the kit outside the dedicated anti-air and out-reached
	# st.MK, which let the launcher take over the spacing st.MK is supposed to rule. Cinder Lash
	# is the reference -- the other single-arm punch launcher -- so Flame Surge is held to the
	# same volume rather than to a number picked on its own.
	var flame_surge := blaze.get_move("flame_surge")
	var surge_volume := flame_surge.hit_size.x * flame_surge.hit_size.y * flame_surge.hit_size.z
	var lash_volume := cinder_lash.hit_size.x * cinder_lash.hit_size.y * cinder_lash.hit_size.z
	_check("Flame Surge (236+MP) hitbox fits the uppercut animation",
		flame_surge.hit_size.x <= 0.40 and flame_surge.hit_size.y <= 0.54
		and _reach(flame_surge) <= 0.84 and _reach(flame_surge) < _reach(st_mk))
	_check("Flame Surge box is no bulkier than the other arm launcher (Cinder Lash)",
		surge_volume <= lash_volume * 1.1)
	_check("stand LK/MK/HK ranges scale up light -> medium -> heavy",
		st_lk.hit_offset.x + st_lk.hit_size.x * 0.5 < st_mk.hit_offset.x + st_mk.hit_size.x * 0.5
		and st_mk.hit_offset.x + st_mk.hit_size.x * 0.5 < st_hk.hit_offset.x + st_hk.hit_size.x * 0.5)
	_check("crouch LK/MK/HK ranges scale up light -> medium -> heavy",
		cr_lk.hit_offset.x + cr_lk.hit_size.x * 0.5 < cr_mk.hit_offset.x + cr_mk.hit_size.x * 0.5
		and cr_mk.hit_offset.x + cr_mk.hit_size.x * 0.5 < cr_hk.hit_offset.x + cr_hk.hit_size.x * 0.5)
	var cr_lp := blaze.get_move("cr_lp")
	var cr_mp := blaze.get_move("cr_mp")
	var cr_hp := blaze.get_move("cr_hp")
	var cr_mp_bottom := cr_mp.hit_offset.y - cr_mp.hit_size.y * 0.5
	var cr_mp_top := cr_mp.hit_offset.y + cr_mp.hit_size.y * 0.5
	# Reach caps include a small tolerance for float32 addition.
	_check("crouch MP hitbox fits its jab animation",
		cr_mp.hit_size.x >= 0.30 and cr_mp.hit_size.x <= 0.42
		and cr_mp.hit_size.y >= 0.20 and cr_mp.hit_size.y <= 0.32
		and cr_mp.hit_size.z >= 0.50 and cr_mp.hit_size.z <= 0.6001
		and _reach(cr_mp) > _reach(cr_lp) and _reach(cr_mp) <= 0.8801
		and cr_mp_bottom >= 0.80 and cr_mp_bottom <= 1.11 and cr_mp_top >= 1.13)
	var cr_hp_bottom := cr_hp.hit_offset.y - cr_hp.hit_size.y * 0.5
	var cr_hp_top := cr_hp.hit_offset.y + cr_hp.hit_size.y * 0.5
	_check("crouch HP hitbox is a close vertical uppercut",
		cr_hp.hit_size.x >= 0.30 and cr_hp.hit_size.x <= 0.44
		and cr_hp.hit_size.y >= 0.70 and cr_hp.hit_size.y <= 0.90
		and cr_hp.hit_size.z >= 0.50 and cr_hp.hit_size.z <= 0.64
		and _reach(cr_hp) <= 0.5601
		and cr_hp_bottom >= 0.90 and cr_hp_bottom <= 1.15 and cr_hp_top >= 1.88)

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
	_check("blocked jab records its fallback impact texture",
		f2.last_hit_fx == f1.character.get_move("st_lp").hit_fx)
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
	# Lights are footsies "stop signs", not chain starters: no light self-chain (st.LP -> cr.LP or cr.LP -> cr.LP).
	_check("lights do not chain into a light jab", not b.get_move("st_lp").cancel_into.has("cr_lp") and not b.get_move("cr_lp").cancel_into.has("cr_lp"))
	_check("kick lights route into Flame Step L", b.get_move("st_lk").cancel_into.has("flame_step_l") and b.get_move("cr_lk").cancel_into.has("flame_step_l"))
	_check("heavies route into corner carry specials", b.get_move("st_hp").cancel_into.has("ember_wheel") and b.get_move("st_hp").cancel_into.has("cinder_lash"))
	_check("kick heavies route into corner carry specials", b.get_move("st_hk").cancel_into.has("flame_step_h") and b.get_move("st_hk").cancel_into.has("ember_wheel"))
	_check("crouch heavies route into combo enders", b.get_move("cr_hp").cancel_into.has("ember_wheel") and b.get_move("cr_hk").cancel_into.has("super_inferno"))
	var sf6_like_kb := {
		"st_lp": [3.4, 3.8], "st_mp": [4.1, 4.5], "st_hp": [5.8, 6.3],
		"st_lk": [3.1, 3.5], "st_mk": [4.6, 5.0], "st_hk": [5.8, 6.2],
		"cr_lp": [3.2, 3.6], "cr_mp": [3.9, 4.3], "cr_hp": [5.3, 5.8],
		"cr_lk": [2.9, 3.3], "cr_mk": [4.3, 4.8], "cr_hk": [6.0, 6.6],
		"air_lp": [2.9, 3.3], "air_mp": [4.2, 4.6], "air_hp": [5.7, 6.3],
		"air_lk": [3.0, 3.4], "air_mk": [4.5, 4.9], "air_hk": [6.2, 6.8],
		"flame_step_l": [3.0, 3.4], "flame_step_m": [3.8, 4.3], "flame_step_h": [5.0, 5.5],
		"flame_surge": [3.4, 3.8], "cinder_lash": [6.4, 7.0], "ember_wheel": [3.2, 3.7],
		"super_inferno": [7.0, 7.8],
	}
	for id in sf6_like_kb.keys():
		var m := b.get_move(id)
		var r: Array = sf6_like_kb[id]
		_check("%s knockback is in its SF6-like role range" % id, m != null and m.knockback >= float(r[0]) and m.knockback <= float(r[1]))
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	var light := b.get_move("st_lp")
	var medium := b.get_move("st_mp")
	var heavy := b.get_move("st_hp")
	f1.mark_connected(false, light)
	var light_recoil := absf(f1._recoil_vel) / ((1.0 - f1._recoil_friction) * 60.0)
	f1._recoil_vel = 0.0
	f1.mark_connected(false, medium)
	var medium_recoil := absf(f1._recoil_vel) / ((1.0 - f1._recoil_friction) * 60.0)
	f1._recoil_vel = 0.0
	f1.mark_connected(false, heavy)
	var heavy_recoil := absf(f1._recoil_vel) / ((1.0 - f1._recoil_friction) * 60.0)
	_check("open-space hit gives attacker a small SF6-like recoil", light_recoil > 0.0)
	_check("attacker recoil scales light < medium < heavy", light_recoil < medium_recoil and medium_recoil < heavy_recoil)
	# Corner pushback transfer: the wall eats the victim's slide and hands the attacker only
	# part of it, so cornering still buys ground instead of ejecting the attacker further than
	# an open-space hit would have moved the victim.
	var lim: float = Arena.FIGHT_BOUNDS_HALF_WIDTH - Fighter.PUSHBOX_HALF
	f2.position.x = lim
	f1.position.x = lim - 0.7
	f1._recoil_vel = 0.0
	f1.mark_connected(false, heavy)
	var corner_recoil := absf(f1._recoil_vel) / ((1.0 - f1._recoil_friction) * 60.0)
	var heavy_slide := Fighter.slide_distance(heavy.knockback, Fighter.SLIDE_FRICTION[2], heavy.hitstun)
	_check("corner hit recoils the attacker more than an open-space hit", corner_recoil > heavy_recoil)
	_check("corner recoil stays under the slide the wall ate", corner_recoil < heavy_slide)
	ctx["arena"].queue_free()

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
	# The attacker's corner recoil must ease back over several frames (a passive slide), not
	# teleport the whole distance in one frame (regression: it used to snap position instantly).
	var prev_x: float = f1.position.x
	var max_step := 0.0
	var moving_frames := 0
	for i in range(30):
		_step(ctx, _neutral(), _neutral(), 1)
		var d: float = prev_x - f1.position.x   # backward (leftward) movement this frame
		if d > 0.0001:
			moving_frames += 1
			max_step = maxf(max_step, d)
		prev_x = f1.position.x
	var total: float = start_x - f1.position.x
	_check("attacker recoils on a cornered hit", total > 0.08)
	_check("corner recoil eases back over multiple frames (no teleport)", moving_frames >= 3)
	_check("corner recoil has no single-frame teleport", max_step < total * 0.6)
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
	for i in range(super_move.total_frames() + super_move.hitstop * super_move.hits + 40):
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
	# Hitbox viewer (1): it has to draw the very AABBs the simulation collides with, otherwise
	# it is worse than useless -- a viewer that lies sends tuning in the wrong direction.
	_check("training hitbox viewer starts hidden", not scene.is_box_view_visible())
	scene.f1._start_move(scene.f1.character.get_move("st_hp"))
	while not scene.f1.has_active_hitbox():
		scene._physics_process(DELTA)
	scene.toggle_box_view()
	_check("training hitbox viewer draws when toggled on",
		scene.is_box_view_visible() and scene._box_mesh.get_surface_count() == 1)
	var drawn_verts: PackedVector3Array = scene._box_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var drawn := AABB(drawn_verts[0], Vector3.ZERO)
	for v in drawn_verts:
		drawn = drawn.expand(v)
	_check("training hitbox viewer covers the live hurtboxes and hitbox",
		drawn.encloses(scene.f1.hurtboxes()[0]) and drawn.encloses(scene.f2.hurtboxes()[0])
		and drawn.encloses(scene.f1.active_hitbox()))
	scene.toggle_box_view()
	_check("training hitbox viewer clears when toggled off",
		not scene.is_box_view_visible() and scene._box_mesh.get_surface_count() == 0)
	scene.f1.state = Fighter.State.GREEN_RUSH
	scene.f1.green_rush_timer = Fighter.GREEN_RUSH_MODE_TICKS
	scene.f1.state_frame = 0
	scene._physics_process(DELTA)
	var training_fx_spawned := false
	for child in scene.arena.get_children():
		if child is DriveRushFx:
			training_fx_spawned = true
			break
	_check("training scene spawns Green Rush mode ghost trail", training_fx_spawned)
	# Frame meter (3): the numbers ARE the feature, so they are checked against the character's
	# own tuning data and against the independently measured advantage -- a meter that drew
	# plausible-looking cells while miscounting would quietly teach the wrong frame data.
	_check("training frame meter starts hidden", not scene.is_frame_meter_visible())
	var meter_input := Manual.new()
	scene.f1.controller = meter_input
	var meter_hk: MoveData = scene.f1.character.get_move("st_hk")
	scene.f1.reset_for_round()
	scene.f2.reset_for_round()
	scene.arena.set_active(true)
	scene.f1.position.x = -3.0
	scene.f2.position.x = 3.0
	scene.toggle_frame_meter()
	meter_input.frame = _mk(0, 0, GameConst.Btn.HK)
	scene._physics_process(DELTA)
	meter_input.frame = _neutral()
	for i in range(meter_hk.startup):
		scene._physics_process(DELTA)
	# state_frame is now == startup, so the hitbox is live and the startup count is final.
	_check("startup is reported the moment the hitbox goes live, not when the move ends",
		scene._frame_meter.startup_frames(0) == meter_hk.startup
		and scene._frame_meter.total_frames(0) == 0)
	for i in range(meter_hk.active + meter_hk.recovery + 4):
		scene._physics_process(DELTA)
	_check("frame meter cells match the move's own startup/active/recovery data",
		scene._frame_meter.phase_count(0, FrameMeter.Phase.STARTUP) == meter_hk.startup
		and scene._frame_meter.phase_count(0, FrameMeter.Phase.ACTIVE) == meter_hk.active
		and scene._frame_meter.phase_count(0, FrameMeter.Phase.RECOVERY) == meter_hk.recovery)
	_check("frame meter publishes startup and total once the action ends",
		scene._frame_meter.startup_frames(0) == meter_hk.startup
		and scene._frame_meter.total_frames(0) == meter_hk.total_frames())
	_check("an idle dummy leaves its own row blank",
		scene._frame_meter.phase_count(1, FrameMeter.Phase.STARTUP) == 0
		and scene._frame_meter.phase_count(1, FrameMeter.Phase.STUN) == 0)
	_check("a whiff never reports an advantage", not scene._frame_meter.has_advantage(0))
	# The strip is a record of one exchange, not a rolling window: idling for longer than it can
	# hold must not scroll the action away, because the whole point is reading it afterwards.
	for i in range(FrameMeter.CAPACITY + 20):
		scene._physics_process(DELTA)
	_check("the strip stays put after the action ends instead of scrolling away",
		scene._frame_meter.cell_count(0) == meter_hk.total_frames()
		and scene._frame_meter.phase_count(0, FrameMeter.Phase.STARTUP) == meter_hk.startup)
	# ...and the next action wipes it and refills from the left, rather than appending forever.
	var meter_mk: MoveData = scene.f1.character.get_move("st_mk")
	meter_input.frame = _mk(0, 0, GameConst.Btn.MK)
	scene._physics_process(DELTA)
	meter_input.frame = _neutral()
	for i in range(meter_mk.startup - 1):
		scene._physics_process(DELTA)
	_check("a new action wipes the strip and refills from the left",
		scene._frame_meter.cell_count(0) == meter_mk.startup
		and scene._frame_meter.phase_count(0, FrameMeter.Phase.STARTUP) == meter_mk.startup)
	for i in range(meter_mk.total_frames()):
		scene._physics_process(DELTA)
	scene.toggle_frame_meter()
	scene.toggle_frame_meter()
	_check("toggling the frame meter clears the old strip",
		scene._frame_meter.phase_count(0, FrameMeter.Phase.STARTUP) == 0)
	scene.f1.reset_for_round()
	scene.f2.reset_for_round()
	scene.arena.set_active(true)
	scene.f1.position.x = -0.45
	scene.f2.position.x = 0.45
	meter_input.frame = _mk(0, 0, GameConst.Btn.HK)
	scene._physics_process(DELTA)
	meter_input.frame = _neutral()
	for i in range(160):
		scene._physics_process(DELTA)
		if scene._frame_meter.has_advantage(0):
			break
	# -2 is the value measured by stepping the arena directly: the dummy leaves hitstun two
	# ticks before Blaze leaves st.HK's recovery.
	_check("frame meter reports st.HK's measured on-hit advantage",
		scene._frame_meter.has_advantage(0) and scene._frame_meter.advantage(0) == -2)
	# Hitstop is real time, but no move frame advances during it -- counting it would report
	# this 35F move as 50F on hit and 35F on whiff.
	_check("hitstop does not inflate the reported move length",
		scene._frame_meter.total_frames(0) == meter_hk.total_frames()
		and scene._frame_meter.startup_frames(0) == meter_hk.startup)
	_check("frozen ticks are still drawn, in their own colour",
		scene._frame_meter.phase_count(0, FrameMeter.Phase.FREEZE) > 0)
	_check("both rows stay on the same timeline through a freeze",
		scene._frame_meter.cell_count(0) == scene._frame_meter.cell_count(1))
	_check("the dummy's row records the hitstun it was actually in",
		scene._frame_meter.phase_count(1, FrameMeter.Phase.STUN) > 0)
	scene.toggle_frame_meter()
	_check("training frame meter hides when toggled off", not scene.is_frame_meter_visible())
	# Attack playback: the mocap clips are real-time (a 35F move is 0.58s, its clip is 2.18s), so
	# fitting the whole clip in played every attack at ~3.7x. Seek in instead and land the strike
	# on the first active frame.
	# Attack playback: the mocap clips are real-time (a 35F move is 0.58s, its clip is 2.18s), so
	# fitting the whole clip in played every attack at ~3.7x. Seek in instead and land the strike
	# on the first active frame.
	var hk_clip_len := 2.18333
	var hk_frac := 0.18
	var hk_t := AnimatedFighterRig.attack_timing(hk_clip_len, hk_frac, meter_hk.startup)
	_check("a wind-up far longer than the startup window is capped, not blurred",
		is_equal_approx(hk_t.x, AnimatedFighterRig.ATTACK_MAX_SPEED))
	_check("the strike lands on the move's first active frame",
		is_equal_approx(hk_t.y + (float(meter_hk.startup) / GameConst.TICK_RATE) * hk_t.x,
			hk_clip_len * hk_frac))
	# A clip whose wind-up is shorter than the startup window has nothing to seek past, so it
	# starts at 0 and slows down instead of leaving the strike early.
	var short_t := AnimatedFighterRig.attack_timing(0.20, 0.5, 20)
	_check("a short wind-up starts at the top of the clip rather than before it",
		short_t.y == 0.0 and is_equal_approx(short_t.x, AnimatedFighterRig.ATTACK_MIN_SPEED))
	# Without a measured impact the rig cannot know which part of the clip is the strike and
	# falls back to the old squeeze-it-all-in playback, so an unmeasured clip is a silent
	# regression rather than a crash. Catch it here instead.
	var rig_cfg: RigConfig = scene.f1.character.rig
	var unmeasured: Array = []
	for mv in scene.f1.character.moves.values():
		var mv_clip: String = mv.anim_clip if mv.anim_clip != "" else rig_cfg.default_move_clip
		if not rig_cfg.clip_impacts.has(mv_clip):
			unmeasured.append(mv.id)
	_check("every attack clip has a measured impact point (see tools/probe_impact.gd)",
		unmeasured.is_empty())
	scene.f1.reset_for_round()
	scene.f2.reset_for_round()
	# Slow-motion toggle (2): a persistent training speed, unlike the transient dips the match
	# already fires. Two things it must not do: compound with those dips, or leak out of the scene.
	_check("training starts at full speed", not scene.is_slow_speed())
	scene.toggle_slow_speed()
	scene._physics_process(DELTA)
	_check("training 2 key drops speed to 30%",
		scene.is_slow_speed() and is_equal_approx(Engine.time_scale, TrainingScene.SLOW_SPEED_SCALE))
	# time_scale only shrinks the physics delta; Godot keeps running 60 ticks a second. Since all
	# frame data here is counted in ticks, the toggle has to drop the tick rate too, or a move's
	# startup would still blow past at full speed while the model crawled.
	_check("slow mode slows the frame data itself, not just on-screen movement",
		Engine.physics_ticks_per_second == int(round(GameConst.TICK_RATE * TrainingScene.SLOW_SPEED_SCALE)))
	_check("a slowed tick is still a whole 1/60 step for the simulation",
		is_equal_approx(Engine.time_scale / float(Engine.physics_ticks_per_second), 1.0 / float(GameConst.TICK_RATE)))
	scene._slowmo.request(0.35, 12, true)
	scene._physics_process(DELTA)
	_check("a dramatic dip does not compound with the slow toggle",
		is_equal_approx(Engine.time_scale, TrainingScene.SLOW_SPEED_SCALE))
	scene._slowmo.reset()
	scene.toggle_slow_speed()
	scene._physics_process(DELTA)
	_check("training 2 key restores full speed",
		not scene.is_slow_speed() and is_equal_approx(Engine.time_scale, 1.0))
	_check("full speed restores the normal tick rate",
		Engine.physics_ticks_per_second == GameConst.TICK_RATE)
	scene.toggle_slow_speed()
	scene._physics_process(DELTA)
	scene._exit_tree()
	_check("leaving training restores normal time flow even while slowed",
		is_equal_approx(Engine.time_scale, 1.0)
		and Engine.physics_ticks_per_second == GameConst.TICK_RATE)
	scene.queue_free()
	game.set("mode", old_mode)
	game.set("p1_char_id", old_p1)
	game.set("p2_char_id", old_p2)

func _test_boot_deep_link() -> void:
	print("[boot deep link]")
	var game := root.get_node("Game")
	var old_mode: int = int(game.get("mode"))
	var old_p1: String = String(game.get("p1_char_id"))
	var old_p2: String = String(game.get("p2_char_id"))
	var main = load("res://scripts/ui/Main.gd").new()

	game.set("mode", GameConst.Mode.LOCAL_2P)
	game.set("p1_char_id", "")
	game.set("p2_char_id", "")
	_check("a plain URL still boots the main menu",
		main.apply_boot_link("http://localhost:8090/") == "res://scenes/ui/MainMenu.tscn")
	_check("a plain URL leaves the match config untouched",
		int(game.get("mode")) == GameConst.Mode.LOCAL_2P
		and String(game.get("p1_char_id")) == "")

	for url in ["http://localhost:8090/testfightinganimsetpro",
			"http://localhost:8090/#testfightinganimsetpro",
			"http://localhost:8090/?testfightinganimsetpro"]:
		game.set("mode", GameConst.Mode.LOCAL_2P)
		game.set("p1_char_id", "")
		game.set("p2_char_id", "")
		_check("%s boots the FightingAnimsetPro gallery" % url,
			main.apply_boot_link(url) == "res://scenes/ui/GALLERY-FightingAnimsetPro.tscn")
		_check("%s leaves the match config untouched" % url,
			int(game.get("mode")) == GameConst.Mode.LOCAL_2P
			and String(game.get("p1_char_id")) == ""
			and String(game.get("p2_char_id")) == "")

	# Path, hash and query spellings all resolve, so the link survives whichever host serves it.
	for url in ["http://localhost:8090/testblaze", "http://localhost:8090/#testblaze",
			"http://localhost:8090/?testblaze"]:
		game.set("mode", GameConst.Mode.LOCAL_2P)
		game.set("p1_char_id", "")
		game.set("p2_char_id", "")
		_check("%s boots straight into training" % url,
			main.apply_boot_link(url) == "res://scenes/match/Training.tscn")
		_check("%s sets up Blaze vs Blaze" % url,
			int(game.get("mode")) == GameConst.Mode.TRAINING
			and String(game.get("p1_char_id")) == "blaze"
			and String(game.get("p2_char_id")) == "blaze")

	main.free()
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
	_check("blaze has combo specials", b.specials.size() >= 9)
	_check("blaze has 1 super", b.supers.size() == 1)
	for removed in ["fireball", "uppercut", "hurricane", "od_fireball", "od_uppercut", "od_hurricane"]:
		_check("removed move absent: " + removed, b.get_move(removed) == null)
	for added in ["flame_step_l", "flame_step_m", "flame_step_h", "cinder_lash", "ember_wheel", "ember_lift", "cinder_chain", "furnace_hooks"]:
		_check("combo move exists: " + added, b.get_move(added) != null)
	_check("Ken-like stand MP timing", b.get_move("st_mp").startup == 7 and b.get_move("st_mp").active == 3)
	_check("Ken-like cross-up air MK timing", b.get_move("air_mk").startup == 7 and b.get_move("air_mk").active == 6)

func _test_ember_lift() -> void:
	print("[ember lift]")
	var blaze := CharacterLibrary.create("blaze")
	var move := blaze.get_move("ember_lift")
	var wheel := blaze.get_move("ember_wheel")
	_check("Ember Lift is 214 + LK",
		move != null and move.motion == MotionParser.QCB and move.button == GameConst.Btn.LK)
	_check("Ember Lift is a grounded light launcher",
		move != null and move.launch and not move.rises and move.hits == 2)
	_check("Ember Lift super-cancels",
		move != null and move.cancel_into == ["super_inferno"])
	_check("Ember Lift stays lighter than Ember Wheel",
		move != null and wheel != null
		and move.damage < wheel.damage
		and move.launch_velocity < wheel.launch_velocity
		and move.recovery < wheel.recovery)
	_check("Ember Lift reach is strictly less than Ember Wheel reach",
		move != null and wheel != null
		and _reach(move) < _reach(wheel))

	var ctx := _build()
	var fighter: Fighter = ctx["f1"]
	_step(ctx, _mk(0, -1), _neutral(), 2)
	_step(ctx, _mk(-1, -1), _neutral(), 2)
	_step(ctx, _mk(-1, 0, GameConst.Btn.LK), _neutral(), 1)
	_check("214 + LK starts Ember Lift",
		fighter.current_move != null and fighter.current_move.id == "ember_lift")
	ctx["arena"].queue_free()

	var heavy := _build()
	var heavy_fighter: Fighter = heavy["f1"]
	_step(heavy, _mk(0, -1), _neutral(), 2)
	_step(heavy, _mk(-1, -1), _neutral(), 2)
	_step(heavy, _mk(-1, 0, GameConst.Btn.HK), _neutral(), 1)
	_check("214 + HK still starts Ember Wheel",
		heavy_fighter.current_move != null and heavy_fighter.current_move.id == "ember_wheel")
	heavy["arena"].queue_free()

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

func _test_animation_gallery2() -> void:
	print("[animation gallery 2]")
	var fighting_scene_path := "res://scenes/ui/GALLERY-FightingAnimsetPro.tscn"
	var hit_scene_path := "res://scenes/ui/GALLERY-HitReactionAnimation.tscn"
	var fighter_pack_scene_path := "res://scenes/ui/GALLERY-FighterAnimationPack.tscn"
	_check("FightingAnimsetPro gallery scene exists", ResourceLoader.exists(fighting_scene_path))
	_check("HitReactionAnimation gallery scene exists", ResourceLoader.exists(hit_scene_path))
	_check("FighterAnimationPack gallery scene exists", ResourceLoader.exists(fighter_pack_scene_path))
	_check("old gallery scene names are removed",
		not ResourceLoader.exists("res://scenes/ui/AnimationGallery.tscn")
		and not ResourceLoader.exists("res://scenes/ui/AnimationGallery2.tscn"))
	var menu_source := FileAccess.get_file_as_string("res://scripts/ui/MainMenu.gd")
	_check("main menu links all named galleries",
		menu_source.contains(fighting_scene_path)
		and menu_source.contains(hit_scene_path)
		and menu_source.contains(fighter_pack_scene_path))
	var menu := (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	menu._ready()
	var menu_stack: VBoxContainer = null
	var pending: Array[Node] = [menu]
	while not pending.is_empty() and menu_stack == null:
		var node: Node = pending.pop_back()
		if node is VBoxContainer:
			menu_stack = node as VBoxContainer
		else:
			pending.append_array(node.get_children())
	_check("main menu gallery buttons fit the 720p viewport",
		menu_stack != null and menu_stack.get_combined_minimum_size().y <= 720.0)
	menu.free()
	if not ResourceLoader.exists(hit_scene_path):
		return
	var gallery := (load(hit_scene_path) as PackedScene).instantiate()
	var supports_export_listing := gallery.has_method("_paths_from_files")
	_check("Gallery2 recognizes exported .fbx.import listings", supports_export_listing)
	if supports_export_listing:
		var exported_paths: Array[String] = gallery._paths_from_files(PackedStringArray([
			"UE4M_HitReaction_Back_01.fbx.import",
			"UE4M_HitReaction_Front_01.fbx.import",
			"README.md",
		]))
		_check("Gallery2 maps exported listings back to FBX resource paths",
			exported_paths == [
				"res://assets/third_party/hit_reaction_animation/anims/UE4M_HitReaction_Back_01.fbx",
				"res://assets/third_party/hit_reaction_animation/anims/UE4M_HitReaction_Front_01.fbx",
			])
	var paths: Array[String] = gallery._animation_paths()
	if paths.is_empty():
		print("  SKIP: licensed hit-reaction FBX assets not present (clean clone)")
		gallery.free()
		return
	_check("Gallery2 imports all 97 unique UE4 no-root actions", paths.size() == 97)
	var library: AnimationLibrary = gallery._build_library(paths)
	_check("Gallery2 exposes one clip per imported FBX", library.get_animation_list().size() == 97)
	var normalized := true
	for clip_name in library.get_animation_list():
		var animation := library.get_animation(clip_name)
		for track in range(animation.get_track_count()):
			if animation.track_get_type(track) in [
				Animation.TYPE_POSITION_3D,
				Animation.TYPE_ROTATION_3D,
				Animation.TYPE_SCALE_3D,
			]:
				normalized = normalized and String(animation.track_get_path(track).get_concatenated_names()) == "Skeleton3D"
	_check("Gallery2 strips control-rig tracks and targets the display skeleton", normalized)
	gallery.free()
	if not ResourceLoader.exists(fighter_pack_scene_path):
		return
	var fighter_gallery := (load(fighter_pack_scene_path) as PackedScene).instantiate()
	var has_playback_speed := false
	var has_spacing_x := false
	var has_spacing_z := false
	for property in fighter_gallery.get_property_list():
		match String(property["name"]):
			"playback_speed":
				has_playback_speed = true
			"spacing_x":
				has_spacing_x = true
			"spacing_z":
				has_spacing_z = true
	_check("FighterAnimationPack gallery exposes playback speed", has_playback_speed)
	if has_playback_speed:
		_check("FighterAnimationPack gallery runs at half speed",
			is_equal_approx(float(fighter_gallery.get("playback_speed")), 0.5))
	_check("FighterAnimationPack gallery exposes model spacing", has_spacing_x and has_spacing_z)
	if has_spacing_x and has_spacing_z:
		_check("FighterAnimationPack gallery uses wider model spacing",
			is_equal_approx(float(fighter_gallery.get("spacing_x")), 3.6)
			and is_equal_approx(float(fighter_gallery.get("spacing_z")), 4.4))
	var fighter_paths: Array[String] = fighter_gallery._animation_paths()
	if fighter_paths.is_empty():
		print("  SKIP: licensed Fighter Animation Pack assets not present (clean clone)")
		fighter_gallery.free()
		return
	_check("FighterAnimationPack gallery imports all 313 actions", fighter_paths.size() == 313)
	var sample_paths: Array[String] = []
	for i in range(mini(3, fighter_paths.size())):
		sample_paths.append(fighter_paths[i])
	var sample_library: AnimationLibrary = fighter_gallery._build_library(sample_paths)
	_check("FighterAnimationPack gallery loads single-clip FBX animations",
		sample_library.get_animation_list().size() == sample_paths.size())
	fighter_gallery.free()

func _test_vfx_gallery() -> void:
	print("[VFX impact gallery]")
	var scene_path := "res://scenes/ui/GALLERY-VFXImpactAndHit.tscn"
	_check("VFXImpactAndHit gallery scene exists", ResourceLoader.exists(scene_path))
	var menu_source := FileAccess.get_file_as_string("res://scripts/ui/MainMenu.gd")
	_check("main menu links VFXImpactAndHit gallery", menu_source.contains(scene_path))
	if not ResourceLoader.exists(scene_path):
		return
	var gallery := (load(scene_path) as PackedScene).instantiate()
	var supports_export_listing := gallery.has_method("_paths_from_files")
	_check("VFX gallery recognizes exported .tscn.remap listings", supports_export_listing)
	if supports_export_listing:
		var effect_root := "res://assets/third_party/vfx_impact_and_hit/effects"
		var exported_paths: Array[String] = gallery._paths_from_files(
			effect_root,
			PackedStringArray(["VFX_A.tscn.remap", "VFX_B.tscn", "ignore.txt"]))
		_check("VFX gallery maps exported listings back to scene paths",
			exported_paths == [
				effect_root + "/VFX_A.tscn",
				effect_root + "/VFX_B.tscn",
			])
	var effect_paths: Array[String] = gallery._effect_paths()
	if effect_paths.is_empty():
		print("  SKIP: licensed VFX Impact and Hit assets not present (clean clone)")
		gallery.free()
		return
	_check("VFX gallery imports all 63 effect scenes", effect_paths.size() == 63)
	var samples_load := true
	for i in range(mini(3, effect_paths.size())):
		samples_load = samples_load and load(effect_paths[i]) is PackedScene
	_check("VFX gallery effect scenes load", samples_load)
	var sample_effect := (load(effect_paths[0]) as PackedScene).instantiate()
	gallery._restart_effect(sample_effect)
	var particles_found := false
	var particles_continuous := true
	var pending: Array[Node] = [sample_effect]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is GPUParticles3D:
			var particles := node as GPUParticles3D
			particles_found = true
			particles_continuous = particles_continuous and not particles.one_shot and particles.emitting
		pending.append_array(node.get_children())
	_check("VFX gallery keeps particle previews continuously visible",
		particles_found and particles_continuous)
	sample_effect.free()
	gallery.free()

func _test_move_list_overlay() -> void:
	print("[move list overlay]")
	var hud := HUD.new()
	root.add_child(hud)
	var blaze := CharacterLibrary.create("blaze")
	hud.build(blaze, blaze)
	var has_combo_data := false
	for property in blaze.get_property_list():
		if property["name"] == "combos":
			has_combo_data = true
			break
	var combos: Variant = blaze.get("combos") if has_combo_data else null
	_check("Blaze authors the three verified training combos",
		combos is PackedStringArray
		and combos.size() == 3
		and combos[0].contains("st.MP > 214 + MP")
		and combos[1].contains("st.HP > 214 + HP")
		and combos[2].contains("cr.LP > 214 + LK > 236236 + HP"))
	var has_combo_list_api := hud.has_method("toggle_combo_list") and hud.has_method("is_combo_list_visible")
	_check("HUD exposes a combo-list toggle", has_combo_list_api)
	var empty_character := CharacterData.new()
	empty_character.display_name = "Empty"
	_check("combo list explains when a character has no authored routes",
		hud._combo_list_text(empty_character).contains("No authored combos."))
	_check("move list hidden by default", not hud.is_move_list_visible())
	hud.toggle_move_list()
	_check("move list opens on toggle", hud.is_move_list_visible())
	var left: Label = hud._move_list_labels[0]
	_check("move list hides removed specials", not left.text.contains("Flare Bolt") and not left.text.contains("Blaze Rise") and not left.text.contains("Cyclone Kick"))
	_check("move list shows Blaze combo tools",
		left.text.contains("Flame Step")
		and left.text.contains("Cinder Lash")
		and left.text.contains("Ember Wheel")
		and left.text.contains("Cinder Chain")
		and left.text.contains("Furnace Hooks"))
	_check("move list still shows super", left.text.contains("Inferno Rush"))
	_check("move list uses numpad super notation", left.text.contains("236236") and left.text.contains("(100% Super)"))
	hud.toggle_move_list()
	_check("move list closes on second toggle", not hud.is_move_list_visible())
	if has_combo_list_api:
		_check("combo list hidden by default", not bool(hud.call("is_combo_list_visible")))
		hud.call("toggle_combo_list")
		_check("combo list opens on toggle",
			bool(hud.call("is_combo_list_visible")) and not hud.is_move_list_visible())
		_check("combo list shows every authored Blaze combo",
			left.text.contains("Cinder Chain Confirm")
			and left.text.contains("Furnace Hooks Punish")
			and left.text.contains("Ember Lift Super"))
		hud.toggle_move_list()
		_check("move list replaces combo list in the shared panel",
			hud.is_move_list_visible() and not bool(hud.call("is_combo_list_visible")))
		hud.call("toggle_combo_list")
		_check("combo list replaces move list in the shared panel",
			bool(hud.call("is_combo_list_visible")) and not hud.is_move_list_visible())
		hud.call("toggle_combo_list")
		_check("combo list closes on second combo toggle",
			not bool(hud.call("is_combo_list_visible")) and not hud.is_move_list_visible())
	hud.queue_free()

func _test_multihit() -> void:
	print("[multi-hit]")
	var ctx := _build("blaze", "blaze")
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	var inferno := f1.character.get_move("super_inferno")
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

	var cadence := _build()
	var attacker: Fighter = cadence["f1"]
	var victim: Fighter = cadence["f2"]
	attacker.current_move = inferno
	attacker.state = Fighter.State.ATTACK
	var smooth_cadence := true
	for i in range(inferno.hits):
		victim.receive_attack(inferno, attacker.facing)
		var normal_stop := inferno.hitstop + victim._hitstop_bonus()
		attacker.mark_connected(false, inferno)
		var expected_stop := normal_stop if i == 0 else 2
		smooth_cadence = smooth_cadence \
			and attacker.hitstop == expected_stop \
			and victim.hitstop == expected_stop
		attacker.hitstop = 0
		victim.hitstop = 0
	_check("multi-hit opens with normal hit-stop, then follows a micro-stop rhythm", smooth_cadence)
	cadence["arena"].queue_free()

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
	# A clip started DURING hitstop must snap into pose: the player is frozen (speed_scale 0),
	# so a crossfade can never progress and the victim would otherwise hold its pre-impact
	# pose for the whole freeze, only jumping into the reaction once the freeze releases.
	# A clip started DURING hitstop must snap into pose: the player is frozen (speed_scale 0),
	# so a crossfade can never progress and the victim collapses toward a stale/rest pose for
	# the whole freeze instead of holding the hit reaction.
	f.on_ground = true
	f.stun_timer = 16
	f.state = Fighter.State.HITSTUN
	var hit_clip: String = arig._resolve_hit_clip(f)
	arig._player.speed_scale = 1.0
	arig._player.play(arig._cfg.lib_name + "/" + hit_clip, 0.0)
	arig._player.seek(0.0, true)
	var want_pose := _skel_sig(arig._skel)
	f.state = Fighter.State.ATTACK
	f.state_frame = 0
	f.hitstop = 0
	arig.pose(f)
	arig._player.advance(0.12)
	var parked_pose := _skel_sig(arig._skel)
	f.state = Fighter.State.HITSTUN
	f.hitstop = 8
	arig.pose(f)
	arig._player.advance(0.016)   # the next engine frame, still frozen (speed_scale 0)
	var frozen_pose := _skel_sig(arig._skel)
	_check("hit reaction leaves the pre-impact pose during hitstop", absf(frozen_pose - parked_pose) > 0.0001)
	_check("hit reaction reaches its own pose during hitstop", absf(frozen_pose - want_pose) < 0.0001)
	arig.queue_free()

## Cheap signature of the whole skeleton pose, so a test can assert the rig actually moved.
func _skel_sig(sk: Skeleton3D) -> float:
	var s := 0.0
	for i in sk.get_bone_count():
		var q := sk.get_bone_pose_rotation(i)
		s += q.x + q.y * 2.0 + q.z * 3.0 + q.w * 5.0
	return s

func _test_impact_shake() -> void:
	print("[impact shake]")
	var blaze := CharacterLibrary.create("blaze")
	var f := Fighter.new()
	f.setup(blaze, Manual.new(), GameConst.Side.P1, 0.0)
	_check("no shake outside hitstop", f._impact_shake_x() == 0.0)
	f.state = Fighter.State.HITSTUN
	f.hitstop = 6
	f.hit_strength = 0
	var light: float = absf(f._impact_shake_x())
	f.hit_strength = 2
	var heavy: float = absf(f._impact_shake_x())
	_check("hitstop shakes the rig", light > 0.0)
	_check("heavier hits shake harder", heavy > light)
	# Alternating each tick is what reads as a vibration rather than a lean.
	var a := f._impact_shake_x()
	f.hitstop = 5
	var b := f._impact_shake_x()
	_check("shake alternates direction each tick", a * b < 0.0)
	# It must fade out so the rig lands back on centre when the freeze releases.
	f.hitstop = 1
	_check("shake decays as hitstop drains", absf(f._impact_shake_x()) < heavy)
	f.hitstop = 6
	var victim: float = absf(f._impact_shake_x())
	f.state = Fighter.State.ATTACK
	_check("attacker shakes less than the victim", absf(f._impact_shake_x()) < victim)
	f.hitstop = 0
	_check("shake returns to centre after hitstop", f._impact_shake_x() == 0.0)

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

	# Verify knockback scaling and dynamic slide friction
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.38
	f2.position.x = 0.38
	# Hit with LP (light attack -> SLIDE_FRICTION[0])
	_step(ctx, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)
	for i in range(20):
		_step(ctx, _neutral(), _neutral(), 1)
		if f2.state == Fighter.State.HITSTUN and f2.hitstop == 0:
			break
	_check("LP hitstun sets correct light hit strength", f2.hit_strength == 0)
	var initial_vel := absf(f2.velocity.x)
	_check("LP base knockback applied", initial_vel > 0.0)
	_step(ctx, _neutral(), _neutral(), 1)
	var next_vel := absf(f2.velocity.x)
	# Lights decay faster than mediums/heavies for a short, crisp slide.
	_check("light hitstun uses the light slide friction",
		is_equal_approx(next_vel, initial_vel * Fighter.SLIDE_FRICTION[0]))
	# Friction is the settle RATE, not the distance (heavies settle fastest because they carry
	# the biggest impulse). The contract that matters is that a heavier button in the same
	# family pushes further.
	var bz := CharacterLibrary.create("blaze")
	for fam in [["st_lp", "st_mp", "st_hp"], ["st_lk", "st_mk", "st_hk"]]:
		var dist: Array[float] = []
		for i in range(3):
			var mv: MoveData = bz.get_move(fam[i])
			dist.append(Fighter.slide_distance(mv.knockback, Fighter.SLIDE_FRICTION[i], mv.hitstun))
		_check("%s family pushback rises light -> medium -> heavy" % fam[2], dist[0] < dist[1] and dist[1] < dist[2])
	ctx["arena"].queue_free()

func _test_kb_library() -> void:
	print("[kb library / gallery source]")
	var blaze := CharacterLibrary.create("blaze")
	if not ResourceLoader.exists(blaze.model_path):
		print("  SKIP: model assets not present (clean clone)")
		return
	var lib := AnimatedFighterRig.build_library(blaze.rig)
	_check("kb library exposes 200+ clips for the gallery", lib.get_animation_list().size() > 200)
	# Every authored move must name a clip the library actually has, so a deleted or renamed
	# source FBX fails loudly instead of silently falling back to the default jab.
	var missing: Array[String] = []
	for move_id in blaze.moves.keys():
		var m: MoveData = blaze.moves[move_id]
		if m.anim_clip != "" and not lib.has_animation(m.anim_clip):
			missing.append("%s -> %s" % [move_id, m.anim_clip])
	_check("every Blaze move clip resolves in the kb library (missing: %s)" % [missing],
		missing.is_empty())
	_check("kb library includes Cinder Chain clip", lib.has_animation("KB_m_Jab_RLhookRMidKick_combo"))
	_check("kb library includes Furnace Hooks clip", lib.has_animation("KB_p_DoubleHooks"))
	_check("Cinder Chain impact timing is authored",
		blaze.rig.clip_impacts.has("KB_m_Jab_RLhookRMidKick_combo")
		and is_equal_approx(blaze.rig.clip_impacts["KB_m_Jab_RLhookRMidKick_combo"], 0.13))
	_check("Furnace Hooks impact timing is authored",
		blaze.rig.clip_impacts.has("KB_p_DoubleHooks")
		and is_equal_approx(blaze.rig.clip_impacts["KB_p_DoubleHooks"], 0.22))

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
	var kd_start := -1
	var up_at := -1
	for i in range(260):
		_step(ctx, _neutral(), _neutral(), 1)
		if f2.state == Fighter.State.KNOCKDOWN:
			saw_knockdown = true
			if kd_start < 0:
				kd_start = i
		if f2.state == Fighter.State.WAKEUP:
			saw_wakeup = true
		if kd_start >= 0 and up_at < 0 and f2.state == Fighter.State.IDLE:
			up_at = i
	_check("victim was knocked down", saw_knockdown)
	_check("victim played a get-up (WAKEUP)", saw_wakeup)
	_check("victim recovered to neutral", f2.state == Fighter.State.IDLE)
	_check("knockdown kind cleared after wake-up", f2.knockdown_kind == GameConst.Knockdown.NONE)
	# SF6 reference: a non-teched soft knockdown is ~31 frames from hitting the ground until the
	# riser is actionable. Keep the down-time (lying + get-up) tuned to that so wake-ups feel quick.
	# Retune these constants and this check together if the knockdown feel changes.
	_check("knockdown + get-up tuned to SF6 soft knockdown (31f)",
		Fighter.KNOCKDOWN_TICKS + Fighter.WAKEUP_TICKS == 31)
	_check("down-time from knockdown to actionable is SF6-quick (~31f)",
		kd_start >= 0 and up_at >= 0 and (up_at - kd_start) >= 28 and (up_at - kd_start) <= 34)
	ctx["arena"].queue_free()

## 压起身 / okizeme: the get-up's final frames are vulnerable + blockable (the meaty window). A
## well-timed meaty (attack already active when the riser becomes hittable) is rewarded; the riser
## can block to escape but cannot mash an attack out.
func _test_okizeme() -> void:
	print("[okizeme / meaty wake-up]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	var jab := _find_move(f1.character, "st_lp")   # startup 4, active 3, hitstun 16
	var af: int = f1.facing

	# a. Vulnerability window: invulnerable early in the get-up and while down, hittable in the tail.
	f2.on_ground = true
	f2.state = Fighter.State.WAKEUP
	f2.state_frame = 1
	_check("wake-up is invulnerable early in the get-up", f2.hurtboxes().is_empty())
	f2.state_frame = Fighter.WAKEUP_TICKS - 1
	_check("wake-up exposes a hurtbox in the meaty tail", not f2.hurtboxes().is_empty())
	f2.state = Fighter.State.KNOCKDOWN
	_check("knockdown stays fully invulnerable", f2.hurtboxes().is_empty())

	# b. A meaty (attack already active before the riser becomes hittable) connects and is rewarded.
	f2.state = Fighter.State.WAKEUP
	f2.state_frame = Fighter.WAKEUP_TICKS - 3
	f2.health = f2.character.max_health
	f1.current_move = jab
	f1.state = Fighter.State.ATTACK
	f1.state_frame = jab.startup + 1   # already active a tick earlier => meaty
	ctx["c2"].frame = _neutral()
	f2.poll_input()
	var blocked_meaty := f2.receive_attack(jab, af)
	_check("meaty connects (not blocked) on a neutral riser", not blocked_meaty)
	_check("meaty is flagged on the victim", f2.last_meaty)
	_check("meaty grants a combo-window of extra hitstun",
		f2.stun_timer >= jab.hitstun + Fighter.MEATY_BONUS_HITSTUN)

	# c. A same-frame poke (first active frame lands on the riser) is NOT a meaty.
	f2.state = Fighter.State.WAKEUP
	f2.state_frame = Fighter.WAKEUP_TICKS - 3
	f2.health = f2.character.max_health
	f1.current_move = jab
	f1.state = Fighter.State.ATTACK
	f1.state_frame = jab.startup     # first active frame => not a placed meaty
	ctx["c2"].frame = _neutral()
	f2.poll_input()
	f2.receive_attack(jab, af)
	_check("a same-frame poke on wake-up is not a meaty", not f2.last_meaty)

	# d. Holding back through the tail blocks the meaty (the defence option) -- no damage, no reward.
	f2.state = Fighter.State.WAKEUP
	f2.state_frame = Fighter.WAKEUP_TICKS - 3
	f2.health = f2.character.max_health
	var hp: int = f2.health
	f1.current_move = jab
	f1.state = Fighter.State.ATTACK
	f1.state_frame = jab.startup + 1
	ctx["c2"].frame = _mk(af, 0)     # hold away from the attacker = guard
	f2.poll_input()
	var blocked := f2.receive_attack(jab, af)
	_check("a rising fighter can block the meaty", blocked and f2.state == Fighter.State.BLOCKSTUN)
	_check("a blocked meaty deals no life damage", f2.health == hp)
	_check("a blocked meaty is not rewarded as a meaty", not f2.last_meaty)

	# e. A rising fighter cannot attack during wake-up (no mash reversal).
	f2.state = Fighter.State.WAKEUP
	f2.stun_timer = 6
	f2.state_frame = Fighter.WAKEUP_TICKS - 6
	f2.current_move = null
	var attacked := false
	for i in range(4):
		ctx["c2"].frame = _mk(0, 0, GameConst.Btn.LP)
		f2.poll_input()
		f2.advance(DELTA)
		if f2.state == Fighter.State.ATTACK:
			attacked = true
	_check("a rising fighter cannot attack during wake-up (no mash reversal)", not attacked)
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
	f.hit_strength = 0
	f.hit_height = GameConst.HitHeight.MID
	f.hit_reaction_clip = ""
	f.state = Fighter.State.HITSTUN
	f.stun_timer = 13
	f.hitstop = 0
	arig.pose(f)
	_check("grounded hit reactions play at authored speed instead of fitting the whole clip",
		is_equal_approx(arig._player.get_playing_speed(), 1.0))
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
	_check("light hits have obvious impact freeze", int(light["vic"]) == 9)
	_check("heavy hits have obvious impact freeze", int(heavy["vic"]) == 15)
	# The stacked worst case (heavy punish counter on a meaty) is the one that reads as a hang.
	var f := Fighter.new()
	var blaze := CharacterLibrary.create("blaze")
	f.setup(blaze, Manual.new(), GameConst.Side.P1, 0.0)
	f.hit_strength = 2
	f.last_counter = GameConst.Counter.PUNISH
	f.last_meaty = true
	var worst: int = blaze.get_move("st_hp").hitstop + f._hitstop_bonus()
	_check("worst-case impact freeze stays readable", worst <= 20)

func _test_impact_fx_smoke() -> void:
	print("[impact fx smoke]")
	var cam := FightCamera.new()
	root.add_child(cam)
	cam.shake(0.35, 8, 1.0, 0.10)
	_check("camera shake armed", cam._shake_t == 8 and cam._shake_amp > 0.0)
	cam.track(Vector3(-0.4, 0, 0), Vector3(0.4, 0, 0))
	_check("impact shake has a visible first-frame kick without wild roll",
		cam.position.distance_to(cam._base) > 0.18 and absf(cam.rotation.z) < deg_to_rad(2.0))
	_check("impact shake kicks away from the hit side with a modest punch-in",
		cam.position.x > cam._base.x + 0.12 and cam.position.z < cam._base.z - 0.04)
	_check("impact shake avoids flash-like FOV jumps", cam.fov > FightCamera.FOV - 2.0)
	for i in range(12):
		cam.track(Vector3(-0.4, 0, 0), Vector3(0.4, 0, 0))
	_check("impact shake decays back to stable framing",
		cam._shake_t == 0 and cam.position.distance_to(cam._base) < 0.001
		and absf(cam.rotation.z) < 0.001 and absf(cam.fov - FightCamera.FOV) < 0.001)
	cam.free()
	var spark := HitSpark.new()
	root.add_child(spark)
	spark.setup(Color(1.0, 0.5, 0.2), 1.3)
	_check("hit spark built core + ring", spark.get_child_count() == 2)
	var core := spark.get_child(0) as MeshInstance3D
	var ring := spark.get_child(1) as MeshInstance3D
	_check("hit spark core is compact", core != null and core.mesh is SphereMesh and (core.mesh as SphereMesh).radius <= 0.12)
	_check("hit spark ring is compact", ring != null and ring.mesh is TorusMesh and (ring.mesh as TorusMesh).outer_radius <= 0.19)
	_check("hit spark draws over fighters",
		core != null and ring != null
		and (core.material_override as StandardMaterial3D).no_depth_test
		and (ring.material_override as StandardMaterial3D).no_depth_test)
	# Rebuilding these per hit regenerated the torus on the contact frame, which cost ~100ms in
	# the Web build. Every spark has the same geometry, so they have to come from one shared mesh.
	var spark2 := HitSpark.new()
	root.add_child(spark2)
	spark2.setup(Color(0.2, 0.6, 1.0), 0.7)
	_check("hit sparks share one core mesh instead of rebuilding it per hit",
		(spark2.get_child(0) as MeshInstance3D).mesh == core.mesh)
	_check("hit sparks share one ring mesh instead of rebuilding it per hit",
		(spark2.get_child(1) as MeshInstance3D).mesh == ring.mesh)
	_check("hit spark ring is cheap to tessellate",
		(ring.mesh as TorusMesh).rings <= 24 and (ring.mesh as TorusMesh).ring_segments <= 12)
	spark2.free()
	spark.free()
	var fx_path := "res://assets/cartoon_fx_pack/textures/Effect01.png"
	_check("CartoonFXPack spark texture imported", ResourceLoader.exists(fx_path))
	var textured_spark := HitSpark.new()
	root.add_child(textured_spark)
	textured_spark.setup(Color(1.0, 0.5, 0.2), 1.0, fx_path)
	_check("textured hit spark adds a pack texture layer", textured_spark.get_child_count() >= 3)
	textured_spark._process(1.0 / 60.0)
	_check("textured hit spark starts at readable size",
		textured_spark._fx_quad != null and textured_spark._fx_quad.scale.x >= 0.8 and textured_spark.scale == Vector3.ONE)
	for i in range(12):
		textured_spark._process(1.0 / 60.0)
	_check("textured hit spark persists long enough to read", not textured_spark.is_queued_for_deletion())
	textured_spark.free()
	var vfx_root := "res://assets/third_party/vfx_impact_and_hit/effects/impact_1_1_0/"
	var vfx_paths := [
		vfx_root + "VFX_ImpactCross_1.1.0.tscn",
		vfx_root + "VFX_ImpactClassic01_1.1.0.tscn",
		vfx_root + "VFX_ImpactClassic03_1.1.0.tscn",
		vfx_root + "VFX_ImpactToon_1.1.0.tscn",
		vfx_root + "VFX_ImpactCrossCritical_1.1.0.tscn",
		vfx_root + "VFX_ImpactCritical_1.1.0_Red.tscn",
		vfx_root + "VFX_ImpactCritical_1.1.0_Yellow.tscn",
	]
	var vfx_installed := ResourceLoader.exists(vfx_paths[0])
	if vfx_installed:
		for path in vfx_paths:
			_check("VFX Impact and Hit scene imported: " + path.get_file(), ResourceLoader.exists(path))
		var scene_spark := HitSpark.new()
		root.add_child(scene_spark)
		scene_spark.setup(Color.WHITE, 0.68, vfx_paths[2])
		var fx_node := scene_spark.get_node_or_null("VFX_ImpactClassic03_1_1_0")
		_check("hit spark instances VFX Impact and Hit scenes", fx_node != null)
		# At the authored rate the spark burst trails the shockwave by 8-14 frames, so the effect
		# reads as arriving after the hit instead of with it.
		var slow_emitter := ""
		for particles in fx_node.find_children("*", "GPUParticles3D", true, false):
			if not is_equal_approx((particles as GPUParticles3D).speed_scale, HitSpark.VFX_SPEED):
				slow_emitter = particles.name
		_check("impact VFX plays fast enough to land inside the hit reaction", slow_emitter == "")
		# Instancing one of these costs ~80ms in the Web build, right on the contact frame, so
		# every hit dropped frames. They have to be reused, not rebuilt.
		HitSpark.clear_fx_pool()
		for i in range(int(HitSpark.LIFE * 60.0) + 2):
			scene_spark._process(1.0 / 60.0)
		_check("a spent spark hands its particle instance back instead of destroying it",
			HitSpark.fx_pool_size() == 1)
		var reuse_spark := HitSpark.new()
		root.add_child(reuse_spark)
		reuse_spark.setup(Color.WHITE, 0.68, vfx_paths[2])
		_check("the next hit reuses the pooled particle instance",
			reuse_spark.get_node_or_null("VFX_ImpactClassic03_1_1_0") == fx_node
			and HitSpark.fx_pool_size() == 0)
		var other_spark := HitSpark.new()
		root.add_child(other_spark)
		other_spark.setup(Color.WHITE, 0.68, vfx_paths[3])
		_check("a different VFX still gets its own instance",
			other_spark.get_node_or_null("VFX_ImpactToon_1_1_0") != null)
		reuse_spark._release_fx()
		other_spark._release_fx()
		_check("pooled instances are keyed per VFX", HitSpark.fx_pool_size() == 2)
		reuse_spark.free()
		other_spark.free()
		HitSpark.clear_fx_pool()
		_check("clearing the pool frees the idle instances", HitSpark.fx_pool_size() == 0)
	else:
		print("  SKIP: licensed VFX Impact and Hit assets not present (CartoonFX fallback)")
	var blaze := CharacterLibrary.create("blaze")
	var moves: Array = []
	moves.append_array(blaze.normals)
	moves.append_array(blaze.specials)
	moves.append_array(blaze.supers)
	for m in moves:
		var hit_fx := String(m.get("hit_fx"))
		_check("%s has a CartoonFXPack hit effect" % m.id, hit_fx != "" and ResourceLoader.exists(hit_fx))
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
	victim.last_counter = GameConst.Counter.NONE
	victim.last_meaty = false
	victim.hit_strength = 1
	victim.last_hit_fx = fx_path
	victim.last_hit_point = Vector3(1.2, 1.35, 0.0)
	var has_vfx_router := scene.has_method("_impact_fx_path")
	_check("match routes every impact context through VFX Impact and Hit", has_vfx_router)
	if has_vfx_router and vfx_installed:
		victim.last_counter = GameConst.Counter.NONE
		victim.last_meaty = false
		victim.hit_strength = 0
		_check("block uses VFX Impact and Hit", String(scene.call("_impact_fx_path", victim, true)) == vfx_paths[0])
		_check("light hit uses VFX Impact and Hit", String(scene.call("_impact_fx_path", victim, false)) == vfx_paths[1])
		victim.hit_strength = 1
		_check("medium hit uses VFX Impact and Hit", String(scene.call("_impact_fx_path", victim, false)) == vfx_paths[2])
		victim.hit_strength = 2
		_check("heavy hit uses VFX Impact and Hit", String(scene.call("_impact_fx_path", victim, false)) == vfx_paths[3])
		victim.last_counter = GameConst.Counter.COUNTER
		_check("counter uses VFX Impact and Hit", String(scene.call("_impact_fx_path", victim, false)) == vfx_paths[4])
		victim.last_counter = GameConst.Counter.PUNISH
		_check("punish counter uses VFX Impact and Hit", String(scene.call("_impact_fx_path", victim, false)) == vfx_paths[5])
		victim.last_counter = GameConst.Counter.NONE
		victim.last_meaty = true
		_check("meaty uses VFX Impact and Hit", String(scene.call("_impact_fx_path", victim, false)) == vfx_paths[6])
		victim.last_meaty = false
		victim.hit_strength = 1
	scene._on_struck(victim, false)
	_check("hit visual updates before spark spawn", rig.pose_count == 1 and scene.get_child_count() >= 2)
	_check("medium impact arms readable directional camera punch",
		scene.camera._shake_amp >= 0.1 and scene.camera._shake_t >= 7 and scene.camera._shake_zoom > 0.02)
	victim.hit_strength = 2
	var heavy_p := scene._spark_params(victim, false)
	_check("heavy impact uses camera punch without screen flash",
		not heavy_p.has("flash") and float(heavy_p["shake"]) >= 0.3 and float(heavy_p["zoom"]) <= 0.12)
	var impact_spark := scene.get_child(scene.get_child_count() - 1) as HitSpark
	_check("hit spark spawns at the recorded contact point", impact_spark != null and impact_spark.position.distance_to(victim.last_hit_point) < 0.001)
	if vfx_installed:
		_check("spawned gameplay spark uses the routed medium VFX scene",
			impact_spark != null and impact_spark.get_node_or_null("VFX_ImpactClassic03_1_1_0") != null)
	else:
		_check("spawned gameplay spark falls back to the move texture",
			impact_spark != null and impact_spark._fx_quad != null)
	scene.free()
	# Loading a VFX scene / compiling its particle shaders on the frame a hit connects stalls
	# the Web build long enough to read as a dropped frame, so entering the tree must pre-spawn
	# a throwaway spark for every VFX the router can return. (The harness root is not "in tree"
	# during _initialize, so the callback is invoked directly, as the other scene tests do.)
	var warmed := MatchScene.new()
	root.add_child(warmed)
	_check("warm-up is wired to the tree-entry callback", warmed.has_method("_enter_tree"))
	warmed._enter_tree()
	var warm_sparks := 0
	var warm_scenes := 0
	for child in warmed.get_children():
		if child is HitSpark:
			warm_sparks += 1
			if (child as HitSpark)._fx_scene != null:
				warm_scenes += 1
	_check("entering a match warms every impact VFX up front",
		warm_sparks == MatchScene.HIT_VFX_ALL.size() and warm_sparks == 7)
	if vfx_installed:
		_check("warm-up actually instances the VFX scenes (so their shaders compile)",
			warm_scenes == 7)
		_check("warm-up sparks are a speck, but big enough to rasterize",
			MatchScene.HIT_VFX_WARM_SCALE * HitSpark.VFX_SCENE_SCALE < 0.02
			and MatchScene.HIT_VFX_WARM_SCALE * HitSpark.VFX_SCENE_SCALE > 0.001)
		# ResourceLoader caches weakly, so dropping the loaded scene would re-pay the disk read on
		# the first real hit. And a disabled warm spark never emits, so nothing would be drawn and
		# no shader would compile -- both halves have to hold for the warm-up to be worth anything.
		var warm_live := 0
		for child in warmed.get_children():
			if child is HitSpark and child.process_mode == Node.PROCESS_MODE_INHERIT:
				warm_live += 1
		_check("warm-up sparks are left running so their particles actually draw", warm_live == 7)
		_check("warm-up keeps the loaded VFX scenes referenced",
			warmed._hit_vfx_warm.size() == 7 and warmed._hit_vfx_warm[0] is PackedScene)
	warmed.free()
	# The warm list has to cover every path the router can pick, or that hit type still stalls.
	if vfx_installed:
		var router := MatchScene.new()
		var missed := ""
		for ctx in [[0, GameConst.Counter.NONE, false, true], [0, GameConst.Counter.NONE, false, false],
				[1, GameConst.Counter.NONE, false, false], [2, GameConst.Counter.NONE, false, false],
				[1, GameConst.Counter.COUNTER, false, false], [1, GameConst.Counter.PUNISH, false, false],
				[1, GameConst.Counter.NONE, true, false]]:
			victim.hit_strength = int(ctx[0])
			victim.last_counter = int(ctx[1])
			victim.last_meaty = bool(ctx[2])
			var routed := String(router.call("_impact_fx_path", victim, bool(ctx[3])))
			if not MatchScene.HIT_VFX_ALL.has(routed):
				missed = routed
		_check("every routed impact VFX is in the warm list", missed == "")
		router.free()

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
	var scene := MatchScene.new()
	root.add_child(scene)
	scene.hud = HUD.new()
	scene.add_child(scene.hud)
	var blaze := CharacterLibrary.create("blaze")
	scene.hud.build(blaze, blaze)
	var fighter := Fighter.new()
	scene._on_meaty(fighter)
	_check("meaty callout does not slow gameplay input timing", not scene._slowmo.active() and scene._slowmo.scale == 1.0)
	fighter.free()
	scene.free()

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
	var cinder := b.get_move("cinder_chain")
	var furnace := b.get_move("furnace_hooks")
	var ember_lift := b.get_move("ember_lift")
	_check("Cinder Chain exists as a special", cinder != null and cinder.kind == GameConst.MoveKind.SPECIAL)
	_check("Cinder Chain is 214 + MP",
		cinder != null and cinder.button == GameConst.Btn.MP and cinder.motion == MotionParser.QCB)
	_check("Cinder Chain uses the combo clip",
		cinder != null and cinder.anim_clip == "KB_m_Jab_RLhookRMidKick_combo")
	_check("Cinder Chain is a grounded 3-hit route extender",
		cinder != null and cinder.hits == 3 and not cinder.launch and not cinder.rises)
	_check("Cinder Chain super-cancels",
		cinder != null and cinder.cancel_into == ["super_inferno"])

	_check("Furnace Hooks exists as a special", furnace != null and furnace.kind == GameConst.MoveKind.SPECIAL)
	_check("Furnace Hooks is 214 + HP",
		furnace != null and furnace.button == GameConst.Btn.HP and furnace.motion == MotionParser.QCB)
	_check("Furnace Hooks uses the double-hooks clip",
		furnace != null and furnace.anim_clip == "KB_p_DoubleHooks")
	_check("Furnace Hooks is a grounded 2-hit ender",
		furnace != null and furnace.hits == 2 and not furnace.launch and not furnace.rises)
	_check("Furnace Hooks is more committal than Cinder Chain",
		furnace != null and cinder != null and furnace.startup > cinder.startup and furnace.recovery > cinder.recovery)
	_check("Furnace Hooks has no cancel route",
		furnace != null and furnace.cancel_into.is_empty())

	var expected_routes := {
		"st_lp": ["flame_step_l", "ember_lift"],
		"st_lk": ["flame_step_l", "ember_lift"],
		"cr_lp": ["flame_step_l", "ember_lift"],
		"cr_lk": ["cr_mk", "flame_step_l", "ember_lift"],
		"st_mp": ["st_hp", "flame_surge", "flame_step_m", "cinder_lash", "super_inferno", "cinder_chain"],
		"cr_mp": ["st_mp", "flame_surge", "flame_step_m", "super_inferno", "cinder_chain"],
		"cr_mk": ["flame_surge", "flame_step_m", "super_inferno", "cinder_chain"],
		"st_hp": ["flame_surge", "flame_step_m", "flame_step_h", "cinder_lash", "ember_wheel", "super_inferno", "cinder_chain", "furnace_hooks"],
		"st_hk": ["flame_surge", "flame_step_h", "cinder_lash", "ember_wheel", "super_inferno", "cinder_chain", "furnace_hooks"],
		"cr_hp": ["flame_surge", "flame_step_h", "cinder_lash", "ember_wheel", "super_inferno", "cinder_chain", "furnace_hooks"],
	}
	for move_id in expected_routes.keys():
		_check("%s cancel routes match the combo-expansion spec" % move_id,
			_same_string_set(b.get_move(move_id).cancel_into, expected_routes[move_id]))
	_check("st.MK stays a pure poke (no cancels)", b.get_move("st_mk").cancel_into.is_empty())
	_check("cr.HK keeps only its super cancel", b.get_move("cr_hk").cancel_into == ["super_inferno"])
	var light_normals := {"st_lp": true, "st_lk": true, "cr_lp": true, "cr_lk": true}
	for starter in ["st_lp", "st_lk", "cr_lp", "cr_lk"]:
		var keeps_light_stop_sign := true
		for route in b.get_move(starter).cancel_into:
			if light_normals.has(route):
				keeps_light_stop_sign = false
				break
		_check("%s still has no light-normal chain" % starter, keeps_light_stop_sign)
	_check("Ember Lift is reachable from all four close lights",
		b.get_move("st_lp").cancel_into.has("ember_lift")
		and b.get_move("st_lk").cancel_into.has("ember_lift")
		and b.get_move("cr_lp").cancel_into.has("ember_lift")
		and b.get_move("cr_lk").cancel_into.has("ember_lift"))
	_check("Ember Lift super-cancels in the route table",
		ember_lift != null and ember_lift.cancel_into == ["super_inferno"])

	var cinder_ctx := _build()
	var ca: Fighter = cinder_ctx["f1"]
	var cb: Fighter = cinder_ctx["f2"]
	ca.position.x = -0.38
	cb.position.x = 0.38
	var cmax := 0
	_step(cinder_ctx, _mk(0, 0, GameConst.Btn.MP), _neutral(), 1)
	for i in range(12):
		if cb.combo_count > 0:
			break
		_step(cinder_ctx, _neutral(), _neutral(), 1)
	_p1_qcb(cinder_ctx, GameConst.Btn.MP)
	for i in range(60):
		_step(cinder_ctx, _neutral(), _neutral(), 1)
		cmax = maxi(cmax, cb.combo_count)
	_check("st.MP > Cinder Chain reaches at least 4 combo hits", cmax >= 4)
	cinder_ctx["arena"].queue_free()

	var furnace_ctx := _build()
	var fa: Fighter = furnace_ctx["f1"]
	var fb: Fighter = furnace_ctx["f2"]
	fa.position.x = -0.38
	fb.position.x = 0.38
	var fmax := 0
	_step(furnace_ctx, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	for i in range(14):
		if fb.combo_count > 0:
			break
		_step(furnace_ctx, _neutral(), _neutral(), 1)
	_p1_qcb(furnace_ctx, GameConst.Btn.HP)
	for i in range(60):
		_step(furnace_ctx, _neutral(), _neutral(), 1)
		fmax = maxi(fmax, fb.combo_count)
	_check("st.HP > Furnace Hooks reaches at least 3 combo hits", fmax >= 3)
	furnace_ctx["arena"].queue_free()

	var ember_ctx := _build()
	var ea: Fighter = ember_ctx["f1"]
	var eb: Fighter = ember_ctx["f2"]
	ea.meter = ea.character.max_meter
	ea.position.x = -0.34
	eb.position.x = 0.34
	var emax := 0
	_step(ember_ctx, _mk(0, -1, GameConst.Btn.LP), _neutral(), 1)
	for i in range(12):
		if eb.combo_count > 0:
			break
		_step(ember_ctx, _mk(0, -1), _neutral(), 1)
	_p1_qcb(ember_ctx, GameConst.Btn.LK)
	for i in range(20):
		_step(ember_ctx, _neutral(), _neutral(), 1)
		emax = maxi(emax, eb.combo_count)
		if ea.current_move != null and ea.current_move.id == "ember_lift" and eb.combo_count >= 2:
			break
	_p1_qcf(ember_ctx, 0)
	_p1_qcf(ember_ctx, GameConst.Btn.HP)
	for i in range(80):
		_step(ember_ctx, _neutral(), _neutral(), 1)
		emax = maxi(emax, eb.combo_count)
	_check("cr.LP > Ember Lift > Inferno Rush reaches at least 4 combo hits", emax >= 4)
	ember_ctx["arena"].queue_free()

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
		var x_before: float = r.position.x
		_step(raw, _mk(0, 0, pair), _neutral(), 1)
		var raw_timer: Variant = r.get("green_rush_timer")
		_check("two-punch neutral input enters Green Rush mode",
			r.state != Fighter.State.DRIVE_RUSH and raw_timer is int and int(raw_timer) > 0)
		_check("raw Green Rush mode does not lunge immediately",
			absf(r.position.x - x_before) < 0.01 and absf(r.velocity.x) < 0.01)
		_check("raw green rush spends Drive", r.drive < d_before)
		raw["arena"].queue_free()
	# A genuine two-punch chord may be a frame staggered, but the buttons must OVERLAP (both held
	# at once). Press LP, then MP while still holding LP -> green rush.
	var stagger := _build()
	var sr: Fighter = stagger["f1"]
	var sd: int = sr.drive
	_step(stagger, _mk(0, 0, GameConst.Btn.LP, GameConst.Btn.LP), _neutral(), 1)
	_step(stagger, _mk(0, 0, GameConst.Btn.MP, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	var stagger_timer: Variant = sr.get("green_rush_timer")
	_check("overlapping staggered two-punch enters Green Rush mode",
		sr.state != Fighter.State.DRIVE_RUSH and stagger_timer is int and int(stagger_timer) > 0)
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
	var entered_timer: Variant = gr.get("green_rush_timer")
	_check("Green Rush mode starts without forward rush",
		gr.state != Fighter.State.DRIVE_RUSH and entered_timer is int and int(entered_timer) > 0 and absf(gr.position.x - start_x) < 0.01)
	_check("Green Rush mode uses a dedicated non-neutral state",
		not (gr.state in [Fighter.State.IDLE, Fighter.State.WALK_F, Fighter.State.WALK_B, Fighter.State.CROUCH,
		Fighter.State.DRIVE_RUSH, Fighter.State.GREEN_RUSH_DASH]))
	_step(accel, _neutral(), _neutral(), 179)
	var held_timer: Variant = gr.get("green_rush_timer")
	_check("Green Rush mode lasts for nearly three seconds", held_timer is int and int(held_timer) > 0)
	_step(accel, _neutral(), _neutral(), 1)
	var expired_timer: Variant = gr.get("green_rush_timer")
	_check("Green Rush mode expires after three seconds", not (expired_timer is int and int(expired_timer) > 0))
	accel["arena"].queue_free()

	var stale_tap := _build()
	var tf: Fighter = stale_tap["f1"]
	_step(stale_tap, _mk(1, 0), _neutral(), 1)
	_step(stale_tap, _neutral(), _neutral(), 1)
	_step(stale_tap, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_step(stale_tap, _neutral(), _neutral(), 1)
	_step(stale_tap, _mk(1, 0), _neutral(), 1)
	_check("Green Rush mode ignores pre-mode forward taps", tf.green_rush_active() and tf.state != Fighter.State.DRIVE_RUSH)
	stale_tap["arena"].queue_free()

	var held_forward := _build()
	var hf: Fighter = held_forward["f1"]
	var held_start_x: float = hf.position.x
	_step(held_forward, _mk(1, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_step(held_forward, _mk(1, 0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 10)
	_check("Green Rush mode keeps held forward walking from trigger",
		hf.green_rush_active() and hf.state == Fighter.State.WALK_F and hf.position.x > held_start_x + 0.1)
	_step(held_forward, _mk(1, 0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 50)
	_check("Green Rush mode held forward does not auto-rush",
		hf.green_rush_active() and hf.state == Fighter.State.WALK_F
		and hf.state != Fighter.State.DRIVE_RUSH and hf.state != Fighter.State.GREEN_RUSH_DASH)
	_step(held_forward, _mk(0, 0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 10)
	_check("Green Rush mode waits for trigger buttons to release",
		hf.green_rush_active() and hf.state == Fighter.State.GREEN_RUSH)
	_step(held_forward, _neutral(), _neutral(), 1)
	var after_release_x: float = hf.position.x
	_step(held_forward, _mk(1, 0), _neutral(), 1)
	_check("Green Rush mode can walk on the first fresh forward",
		hf.green_rush_active() and hf.state == Fighter.State.WALK_F and hf.position.x > after_release_x + 0.01)
	_check("Green Rush mode still requires two fresh forward taps to rush",
		hf.green_rush_active() and hf.state != Fighter.State.DRIVE_RUSH and hf.state != Fighter.State.GREEN_RUSH_DASH)
	held_forward["arena"].queue_free()

	var reentry := _build()
	var rf: Fighter = reentry["f1"]
	_step(reentry, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	var reentry_timer: int = rf.green_rush_timer
	_step(reentry, _mk(1, 0), _neutral(), 1)
	var reentry_x: float = rf.position.x
	var reentry_drive: int = rf.drive
	_step(reentry, _mk(1, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_check("Green Rush mode ignores re-entry chord",
		rf.green_rush_active() and rf.drive >= reentry_drive and rf.green_rush_timer < reentry_timer
		and rf.state == Fighter.State.WALK_F and rf.position.x > reentry_x)
	reentry["arena"].queue_free()

	var held_back := _build()
	var back_f: Fighter = held_back["f1"]
	var held_back_start_x: float = back_f.position.x
	_step(held_back, _mk(-1, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_step(held_back, _mk(-1, 0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 10)
	_check("Green Rush mode keeps held back walking from trigger",
		back_f.green_rush_active() and back_f.state == Fighter.State.WALK_B and back_f.position.x < held_back_start_x - 0.1)
	held_back["arena"].queue_free()

	var stale_dash_req := _build()
	var df: Fighter = stale_dash_req["f1"]
	_step(stale_dash_req, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	df._dash_req = 1
	df._step_neutral(_neutral())
	_check("Green Rush mode ignores normal dash requests",
		df.green_rush_active() and df.state != Fighter.State.DRIVE_RUSH and df.state != Fighter.State.GREEN_RUSH_DASH)
	stale_dash_req["arena"].queue_free()

	var normal_mode := _build()
	var nf: Fighter = normal_mode["f1"]
	_step(normal_mode, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_step(normal_mode, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)
	var normal_timer: Variant = nf.get("green_rush_timer")
	_check("normal attacks do not consume Green Rush mode",
		nf.current_move != null and nf.current_move.id == "st_lp"
		and normal_timer is int and int(normal_timer) > 0
		and not nf.drive_rush_pending and nf.get("green_rush_pending") != true)
	normal_mode["arena"].queue_free()

	var special_mode := _build()
	var sf: Fighter = special_mode["f1"]
	var sv: Fighter = special_mode["f2"]
	sf.position.x = -0.5
	sv.position.x = 0.5
	_step(special_mode, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_p1_qcf(special_mode, GameConst.Btn.MP)
	_check("special attacks consume Green Rush mode and become enhanced",
		sf.current_move != null and sf.current_move.id == "flame_surge"
		and not (sf.get("green_rush_timer") is int and int(sf.get("green_rush_timer")) > 0)
		and not sf.drive_rush_pending and sf.get("green_rush_pending") == true
		and sf.drive_rush_fx_active())
	for i in range(14):
		_step(special_mode, _neutral(), _neutral(), 1)
		if sv.health < sv.character.max_health:
			break
	var surge := sf.character.get_move("flame_surge")
	_check("enhanced Green Rush special gets the Drive Rush stun bonus",
		sv.stun_timer >= surge.hitstun + Fighter.DRIVE_RUSH_HITSTUN_BONUS)
	special_mode["arena"].queue_free()

	var special_whiff := _build()
	var sw: Fighter = special_whiff["f1"]
	sw.position.x = -5.0
	special_whiff["f2"].position.x = 5.0
	_step(special_whiff, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_p1_qcf(special_whiff, GameConst.Btn.MP)
	_check("enhanced Green Rush special keeps FX while active", sw.drive_rush_fx_active())
	var whiff_surge := sw.character.get_move("flame_surge")
	for i in range(whiff_surge.total_frames() + 4):
		_step(special_whiff, _neutral(), _neutral(), 1)
	_check("enhanced Green Rush special clears FX after whiff", not sw.drive_rush_fx_active())
	special_whiff["arena"].queue_free()

	var super_mode := _build()
	var sm: Fighter = super_mode["f1"]
	sm.meter = sm.character.max_meter
	_step(super_mode, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_p1_qcf(super_mode, 0)
	_p1_qcf(super_mode, GameConst.Btn.HP)
	_check("super attacks consume Green Rush mode",
		sm.current_move != null and sm.current_move.id == "super_inferno"
		and not (sm.get("green_rush_timer") is int and int(sm.get("green_rush_timer")) > 0))
	super_mode["arena"].queue_free()

	var rush := _build()
	var rr: Fighter = rush["f1"]
	_step(rush, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	var drive_after_mode: int = rr.drive
	_drive_rush_dbltap(rush)
	_check("forward double-tap during Green Rush mode starts a non-DRC rush",
		rr.state != Fighter.State.DRIVE_RUSH and absf(rr.velocity.x) < 0.1)
	_check("mode forward rush spends no extra Drive", rr.drive >= drive_after_mode)
	var rush_start_x: float = rr.position.x
	var start_speed := absf(rr.velocity.x)
	_step(rush, _neutral(), _neutral(), 1)
	var startup_speed := absf(rr.velocity.x)
	_step(rush, _neutral(), _neutral(), Fighter.DRIVE_RUSH_STARTUP_TICKS - 1)
	var startup_dist: float = rr.position.x - rush_start_x
	var still_starting := rr.state != Fighter.State.IDLE and rr.state != Fighter.State.DRIVE_RUSH
	_step(rush, _neutral(), _neutral(), 6)
	var mid_speed := absf(rr.velocity.x)
	_step(rush, _neutral(), _neutral(), Fighter.DRIVE_RUSH_ACCEL_TICKS)
	var full_speed := absf(rr.velocity.x)
	_step(rush, _neutral(), _neutral(), Fighter.DRIVE_RUSH_DURATION)
	var total_dist: float = rr.position.x - rush_start_x
	_check("green rush startup tuning is snappier",
		Fighter.DRIVE_RUSH_SPEED >= 11.6
		and Fighter.DRIVE_RUSH_START_SPEED >= 3.2
		and Fighter.DRIVE_RUSH_STARTUP_TICKS <= 5
		and Fighter.DRIVE_RUSH_STARTUP_ANIM_TICKS <= 5)
	_check("green rush starts faster but below full speed",
		start_speed < 0.1 and startup_speed >= 3.19 and startup_speed < Fighter.DRIVE_RUSH_SPEED * 0.3)
	_check("green rush has a shorter visible startup wind-up", startup_dist > 0.26 and startup_dist < 0.42 and still_starting)
	_check("green rush accelerates gradually", mid_speed > startup_speed and mid_speed < Fighter.DRIVE_RUSH_SPEED * 0.65)
	_check("green rush accelerates to full speed", full_speed > startup_speed + 5.0 and full_speed >= Fighter.DRIVE_RUSH_SPEED * 0.95)
	_check("green rush total travel is closer", total_dist > 2.9 and total_dist < 5.0)
	rush["arena"].queue_free()
	var cancel := _build()
	var cr: Fighter = cancel["f1"]
	_step(cancel, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_drive_rush_dbltap(cancel)
	_step(cancel, _neutral(), _neutral(), Fighter.DRIVE_RUSH_STARTUP_TICKS + Fighter.DRIVE_RUSH_ACCEL_TICKS)
	var rush_speed_before_brake := absf(cr.velocity.x)
	_step(cancel, _mk(-cr.facing, 0), _neutral(), 1)
	var speed_after_back := absf(cr.velocity.x)
	_check("back input stops Green Rush rush",
		cr.state == Fighter.State.IDLE and speed_after_back < 0.001 and rush_speed_before_brake > 0.1)
	cancel["arena"].queue_free()
	var whiff := _build()
	var wr: Fighter = whiff["f1"]
	wr.position.x = -5.0
	whiff["f2"].position.x = 5.0
	_step(whiff, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_drive_rush_dbltap(whiff)
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
	_drive_rush_dbltap(heldatk)
	_step(heldatk, _neutral(), _neutral(), Fighter.DRIVE_RUSH_STARTUP_TICKS + 1)
	_step(heldatk, _mk(0, 0, GameConst.Btn.HP, GameConst.Btn.LP | GameConst.Btn.MP | GameConst.Btn.HP), _neutral(), 1)
	_check("Green Rush attack fires while rush punches still held", grf.state == Fighter.State.ATTACK and grf.current_move != null)
	_check("held-button Green Rush attack keeps the Green Rush bonus", not grf.drive_rush_pending and grf.get("green_rush_pending") == true)
	heldatk["arena"].queue_free()
	# A single back now stops Green Rush immediately.
	var brk := _build()
	var bf: Fighter = brk["f1"]
	_step(brk, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_drive_rush_dbltap(brk)
	_step(brk, _neutral(), _neutral(), Fighter.DRIVE_RUSH_STARTUP_TICKS + Fighter.DRIVE_RUSH_ACCEL_TICKS)
	var full_rush := absf(bf.velocity.x)
	_step(brk, _mk(-bf.facing, 0), _neutral(), 1)
	_check("single back immediately stops Green Rush", bf.state == Fighter.State.IDLE and absf(bf.velocity.x) < 0.001 and full_rush > 0.1)
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
	var drc_speed_before_back := absf(a.velocity.x)
	_step(ctxa, _mk(-a.facing, 0), _neutral(), 1)
	_check("single back does not stop DRC rush", a.state == Fighter.State.DRIVE_RUSH and absf(a.velocity.x) > drc_speed_before_back * 0.8)
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
	# DRC accepts a slightly staggered two-punch chord as long as the buttons OVERLAP (hold LP,
	# then press MP while LP is still down).
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
	_step(ctxs, _mk(0, 0, GameConst.Btn.MP, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	var staggered_drc := false
	for i in range(30):
		_step(ctxs, _neutral(), _neutral(), 1)
		if sa.state == Fighter.State.DRIVE_RUSH:
			staggered_drc = true
			break
	_check("DRC accepts overlapping staggered two-punch input", staggered_drc)
	_check("staggered DRC spent ~3 bars", sa.drive <= sdrive - Fighter.DRC_COST + 60)
	ctxs["arena"].queue_free()
	# Regression: a DRC chord pressed within GREEN_RUSH_CHORD_BUFFER of a punch normal starting was
	# stolen by the raw-Green-Rush rescue -- the normal was aborted for 1 bar and the DRC never
	# happened. The rescue now only covers a chord this normal was itself half of.
	var ctxi := _build()
	var ia: Fighter = ctxi["f1"]
	var ib: Fighter = ctxi["f2"]
	ia.position.x = -0.7
	ib.position.x = 0.6
	var idrive: int = ia.drive
	_step(ctxi, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	_check("st.HP started for the immediate-DRC case",
		ia.current_move != null and ia.current_move.id == "st_hp")
	_step(ctxi, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	_check("an immediate DRC chord does not abort the normal into a raw rush",
		ia.state == Fighter.State.ATTACK and not ia.green_rush_active())
	var immediate_drc := false
	for i in range(40):
		_step(ctxi, _neutral(), _neutral(), 1)
		if ia.state == Fighter.State.DRIVE_RUSH:
			immediate_drc = true
			break
	_check("a DRC pressed immediately after st.HP is not swallowed", immediate_drc)
	_check("the immediate DRC spent the DRC cost, not the raw rush cost",
		ia.drive <= idrive - Fighter.DRC_COST + 60)
	ctxi["arena"].queue_free()
	# A sequential string (press LP, release, press MP -- no overlap) during a connected normal
	# must NOT DRC; it is just a combo attempt. Regression: LP-then-MP used to false-trigger a DRC.
	var ctxq := _build()
	var qa: Fighter = ctxq["f1"]
	var qb: Fighter = ctxq["f2"]
	qa.position.x = -0.7
	qb.position.x = 0.6
	var qdrive: int = qa.drive
	ctxq["c1"].frame = _mk(0, 0, GameConst.Btn.MK)
	ctxq["c2"].frame = _neutral()
	ctxq["arena"].step(DELTA)
	var qhp: int = qb.health
	for i in range(12):
		if qb.health < qhp:
			break
		ctxq["c1"].frame = _neutral()
		ctxq["c2"].frame = _neutral()
		ctxq["arena"].step(DELTA)
	_step(ctxq, _mk(0, 0, GameConst.Btn.LP, GameConst.Btn.LP), _neutral(), 1)
	_step(ctxq, _mk(0, 0, GameConst.Btn.MP, GameConst.Btn.MP), _neutral(), 1)  # LP released
	var seq_drc := false
	for i in range(30):
		_step(ctxq, _neutral(), _neutral(), 1)
		if qa.state == Fighter.State.DRIVE_RUSH:
			seq_drc = true
			break
	_check("sequential LP then MP does not DRC", not seq_drc)
	_check("sequential LP then MP spends no Drive on DRC", qa.drive >= qdrive - Fighter.DRC_COST + 1)
	ctxq["arena"].queue_free()
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
	# Heavy DRC routes must preserve enough advantage for the queued heavy follow-up to combo.
	var ctxx := _build()
	var xa: Fighter = ctxx["f1"]
	var xb: Fighter = ctxx["f2"]
	xa.position.x = -0.7
	xb.position.x = 0.6
	_step(ctxx, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	var xhp: int = xb.health
	for i in range(14):
		if xb.health < xhp:
			break
		_step(ctxx, _neutral(), _neutral(), 1)
	for i in range(24):
		var fr := _neutral()
		if xa.hitstop == 0:
			fr = _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP)
		_step(ctxx, fr, _neutral(), 1)
		if xa.state == Fighter.State.DRIVE_RUSH:
			break
	_step(ctxx, _mk(0, -1, GameConst.Btn.HP), _neutral(), 1)
	var crhp_combo_hit := false
	for i in range(Fighter.DRIVE_RUSH_STARTUP_TICKS + 16):
		_step(ctxx, _neutral(), _neutral(), 1)
		if xb.combo_count >= 2:
			crhp_combo_hit = true
			break
	_check("st.HP DRC cr.HP forms a combo", crhp_combo_hit)
	ctxx["arena"].queue_free()
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
	# A refused DRC chord must not leak out as a stray attack. The player asked for a rush; when
	# the poke whiffs there is nothing to cancel, and re-arming the press at the end of recovery
	# used to turn the chord into an unwanted st.LP on the most vulnerable frame.
	var ctxz := _build()
	var za: Fighter = ctxz["f1"]
	var zb: Fighter = ctxz["f2"]
	za.position.x = -4.0
	zb.position.x = 5.0
	_step(ctxz, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	_step(ctxz, _neutral(), _neutral(), 11)
	_step(ctxz, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	var zleak := false
	for i in range(40):
		_step(ctxz, _neutral(), _neutral(), 1)
		if za.current_move and za.current_move.id != "st_hp":
			zleak = true
			break
	_check("refused DRC chord does not leak a stray attack", not zleak)
	ctxz["arena"].queue_free()
	# A stale motion must not let a single-button special cancel steal the chord. Cancels validate
	# motions over DRC_INPUT_BUFFER ticks, far wider than neutral's window, so a quarter-circle
	# left over from walking in could eat the DRC and fire a fireball instead.
	var ctxstl := _build()
	var stla: Fighter = ctxstl["f1"]
	var stlb: Fighter = ctxstl["f2"]
	stla.position.x = -0.7
	stlb.position.x = 0.6
	_step(ctxstl, _mk(0, -1, 0), _neutral(), 1)
	_step(ctxstl, _mk(1, -1, 0), _neutral(), 1)
	_step(ctxstl, _mk(1, 0, 0), _neutral(), 1)
	_step(ctxstl, _neutral(), _neutral(), 10)
	_step(ctxstl, _mk(0, 0, GameConst.Btn.MP), _neutral(), 1)
	var stl_normal := stla.state == Fighter.State.ATTACK and stla.current_move and stla.current_move.id == "st_mp"
	var stlhp: int = stlb.health
	for i in range(14):
		if stlb.health < stlhp:
			break
		_step(ctxstl, _neutral(), _neutral(), 1)
	_step(ctxstl, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	var stlrush := false
	for i in range(24):
		_step(ctxstl, _neutral(), _neutral(), 1)
		if stla.state == Fighter.State.DRIVE_RUSH:
			stlrush = true
			break
		if stla.current_move and stla.current_move.id != "st_mp":
			break
	_check("stale motion does not steal the DRC chord", stl_normal and stlrush)
	ctxstl["arena"].queue_free()
	# An unaffordable DRC must not eat the input: _consume_drc_input() clears the buffer as a side
	# effect, so checking Drive only after consuming threw the chord away with no feedback.
	var ctxw := _build()
	var wa: Fighter = ctxw["f1"]
	var wb: Fighter = ctxw["f2"]
	wa.position.x = -0.7
	wb.position.x = 0.6
	_step(ctxw, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	var whp: int = wb.health
	for i in range(14):
		if wb.health < whp:
			break
		_step(ctxw, _neutral(), _neutral(), 1)
	wa.drive = Fighter.DRC_COST - 20
	_step(ctxw, _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP), _neutral(), 1)
	var wrush := false
	for i in range(24):
		_step(ctxw, _neutral(), _neutral(), 1)
		if wa.state == Fighter.State.DRIVE_RUSH:
			wrush = true
			break
	_check("DRC input survives until Drive can pay for it", wrush)
	ctxw["arena"].queue_free()
	# A freeze longer than the DRC input buffer window (forced below, since real hitstop stays
	# well under it): a two-punch input at the start of freeze must still survive until the
	# attacker advances again.
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
	# DRC also works off a connected special/skill: the input is still gated by contact, not whiff.
	var ctxskill := _build()
	var sk: Fighter = ctxskill["f1"]
	var skill_victim: Fighter = ctxskill["f2"]
	sk.position.x = -0.45
	skill_victim.position.x = 0.45
	var skill_drive: int = sk.drive
	_p1_qcf(ctxskill, GameConst.Btn.MK) # Flame Step M
	var skill_hit := false
	for i in range(20):
		if skill_victim.health < skill_victim.character.max_health:
			skill_hit = true
			break
		_step(ctxskill, _neutral(), _neutral(), 1)
	var skill_drc := false
	for i in range(20):
		var fr := _neutral()
		if sk.hitstop == 0:
			fr = _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP)
		_step(ctxskill, fr, _neutral(), 1)
		if sk.state == Fighter.State.DRIVE_RUSH:
			skill_drc = true
			break
	_check("DRC off a connected special/skill", skill_hit and skill_drc)
	_check("skill DRC spent ~3 bars", sk.drive <= skill_drive - Fighter.DRC_COST + 60)
	ctxskill["arena"].queue_free()
	# 236+HP launches; DRC should push against the airborne victim instead of crossing through.
	var ctxlaunch := _build()
	var la: Fighter = ctxlaunch["f1"]
	var lv: Fighter = ctxlaunch["f2"]
	la.position.x = 5.4
	lv.position.x = 6.3
	var side_before := signf(lv.position.x - la.position.x)
	_p1_qcf(ctxlaunch, GameConst.Btn.HP) # Cinder Lash
	var launched := false
	for i in range(24):
		if lv.launched:
			launched = true
			break
		_step(ctxlaunch, _neutral(), _neutral(), 1)
	var launch_drc := false
	var crossed_launch := false
	for i in range(80):
		var fr := _neutral()
		if la.hitstop == 0:
			fr = _mk(0, 0, GameConst.Btn.LP | GameConst.Btn.MP)
		_step(ctxlaunch, fr, _neutral(), 1)
		if la.state == Fighter.State.DRIVE_RUSH:
			launch_drc = true
		if lv.launched and signf(lv.position.x - la.position.x) != side_before:
			crossed_launch = true
			break
	_check("Cinder Lash DRC starts from a launched hit", launched and launch_drc)
	_check("Cinder Lash DRC does not cross through the launched victim", not crossed_launch)
	ctxlaunch["arena"].queue_free()

func _test_uppercut_rise() -> void:
	print("[rising specials removed]")
	var b := CharacterLibrary.create("blaze")
	var any_rising_special := false
	for m in b.specials:
		any_rising_special = any_rising_special or m.rises
	_check("Blaze has no shoryuken/rising special", not any_rising_special and b.get_move("uppercut") == null)
	_check("new combo specials are grounded route tools", b.get_move("flame_step_m") != null and b.get_move("ember_wheel") != null)
	var ember_lift := b.get_move("ember_lift")
	_check("Ember Lift launches only the victim",
		ember_lift != null and ember_lift.launch and not ember_lift.rises)

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
	# A press made DEEP in recovery -- far outside both the cancel window and INPUT_BUFFER --
	# must still come out on the first actionable frame instead of being silently eaten.
	var ctx2 := _build()
	var g1: Fighter = ctx2["f1"]
	var g2: Fighter = ctx2["f2"]
	g1.position.x = -4.0
	g2.position.x = 5.0
	_step(ctx2, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	_step(ctx2, _neutral(), _neutral(), 12)
	var frames_left := hp.total_frames() - g1.state_frame
	_step(ctx2, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)
	_check("the deep press really was outside every buffer",
		frames_left > Fighter.CANCEL_BUFFER and frames_left > Fighter.INPUT_BUFFER
		and g1.current_move != null and g1.current_move.id == "st_hp")
	var deep_lp := false
	for i in range(frames_left + 6):
		_step(ctx2, _neutral(), _neutral(), 1)
		if g1.current_move != null and g1.current_move.id == "st_lp":
			deep_lp = true
			break
	_check("a press deep in recovery is not swallowed", deep_lp)
	ctx2["arena"].queue_free()
	# st.MK is a pure poke with no cancel routes: pressing HP after it connects must NOT chain
	# cancel, but the press must survive recovery rather than vanish.
	var ctx3 := _build()
	var k1: Fighter = ctx3["f1"]
	var k2: Fighter = ctx3["f2"]
	k1.position.x = -0.7
	k2.position.x = 0.6
	var k_hp: int = k2.health
	_step(ctx3, _mk(0, 0, GameConst.Btn.MK), _neutral(), 1)
	for i in range(14):
		if k2.health < k_hp:
			break
		_step(ctx3, _neutral(), _neutral(), 1)
	_check("st.MK connected", k2.health < k_hp)
	for i in range(20):
		if k1.hitstop == 0:
			break
		_step(ctx3, _neutral(), _neutral(), 1)
	_step(ctx3, _neutral(), _neutral(), Fighter.CANCEL_BUFFER + 1)
	_step(ctx3, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	_check("no chain cancel outside the cancel window",
		k1.current_move != null and k1.current_move.id == "st_mk")
	var late_hp := false
	for i in range(30):
		_step(ctx3, _neutral(), _neutral(), 1)
		if k1.current_move != null and k1.current_move.id == "st_hp":
			late_hp = true
			break
	_check("a press with no cancel route still comes out after recovery", late_hp)
	ctx3["arena"].queue_free()
	# The carry is capped: a press made near the START of a long move is mashing, not a follow-up,
	# and must stay dropped so no phantom move fires half a second later.
	var ctx4 := _build()
	var e1: Fighter = ctx4["f1"]
	var e2: Fighter = ctx4["f2"]
	e1.position.x = -4.0
	e2.position.x = 5.0
	_step(ctx4, _mk(0, 0, GameConst.Btn.HP), _neutral(), 1)
	_step(ctx4, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)
	_check("the early press is older than the carry cap",
		hp.total_frames() - e1.state_frame > Fighter.MOVE_END_BUFFER)
	var phantom_lp := false
	for i in range(hp.total_frames() + 8):
		_step(ctx4, _neutral(), _neutral(), 1)
		if e1.current_move != null and e1.current_move.id == "st_lp":
			phantom_lp = true
			break
	_check("a press near the start of a long move stays dropped", not phantom_lp)
	ctx4["arena"].queue_free()

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
	_check("two-punch motion enters Green Rush mode, not OD",
		f1.state != Fighter.State.DRIVE_RUSH and f1.green_rush_active() and f1.drive < d0)
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
	# Invariants: the post-contact rush is dearer than the raw neutral mode, and raw Green Rush
	# is a timed mode before any forward rush, so it cannot instantly teleport past mid-range.
	_check("DRC (post-contact rush) costs more than a raw neutral green rush",
		Fighter.DRC_COST > Fighter.RAW_DRIVE_RUSH_COST)
	_check("raw Green Rush is a 3-second mode, not an instant neutral skip",
		Fighter.GREEN_RUSH_MODE_TICKS == 180 and Fighter.DRIVE_RUSH_STARTUP_TICKS > 0)

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
	# Combo counter shows immediately, even for a single hit, then fades out.
	hud.set_combo(0, 1, 27)
	_check("single-hit damage label visible immediately", hud._combo_label[0].modulate.a > 0.9)
	_check("single-hit damage label populated", hud._combo_label[0].text.contains("1 HIT") and hud._combo_label[0].text.contains("27 DMG"))
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
	f.green_rush_timer = Fighter.GREEN_RUSH_MODE_TICKS
	f.state = Fighter.State.GREEN_RUSH
	f.update_visual()
	for i in range(6):
		fx._process(0.03)
	_check("green-rush mode fx spawned ghost trail snapshots", fx._ghosts.size() >= 1)
	f.state = Fighter.State.GREEN_RUSH_DASH
	for i in range(6):
		fx._process(0.03)
	_check("green-rush dash fx spawned ghost trail snapshots", fx._ghosts.size() >= 1)
	_check("drive-rush fx emits fewer ghost snapshots", fx._ghosts.size() <= 4)
	if not fx._ghosts.is_empty():
		_check("drive-rush fx ghost copies character meshes", fx._ghosts[0]["meshes"].size() > 1)
		var ghost_mat: StandardMaterial3D = fx._ghosts[0]["mats"][0]
		_check("drive-rush fx ghost is faint", ghost_mat.albedo_color.a <= DriveRushFx.GHOST_ALPHA and ghost_mat.emission_energy_multiplier <= DriveRushFx.GHOST_EMISSION)
	f.green_rush_timer = 0
	f.state = Fighter.State.ATTACK
	f.drive_rush_pending = false
	f.green_rush_pending = true
	for i in range(6):
		fx._process(0.03)
	_check("green-rush enhanced skill fx keeps ghost trail snapshots", fx._ghosts.size() >= 1)
	f.green_rush_pending = false
	for i in range(20):
		fx._process(0.03)
	_check("green-rush enhanced skill fx fades after bonus clears", fx._ghosts.is_empty())
	f.free()
