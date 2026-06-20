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

func _build(id1: String = "kael", id2: String = "rho") -> Dictionary:
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

func _neutral() -> InputFrame:
	return _mk(0, 0)

func _initialize() -> void:
	print("=== Brawl Arena combat tests ===")
	_test_walk()
	_test_normal_hit()
	_test_block()
	_test_fireball()
	_test_super()
	_test_ko()
	_test_round_flow()
	_test_cpu_ai()
	_test_blaze_roster()
	_test_multihit()
	_test_move_sfx()
	_test_animated_rig()
	_test_six_buttons()
	_test_dash()
	_test_air_attack()
	_test_jump_in()
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

func _test_normal_hit() -> void:
	print("[normal hit]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	# Place them within jab range.
	f1.position.x = -0.6
	f2.position.x = 0.6
	var hp_before: int = f2.health
	_step(ctx, _mk(0, 0, GameConst.Btn.LP), _neutral(), 1)
	_step(ctx, _neutral(), _neutral(), 20)
	_check("P2 took jab damage", f2.health < hp_before)
	_check("P1 gained meter on hit", f1.meter > 0)
	ctx["arena"].queue_free()

func _test_block() -> void:
	print("[block]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.6
	f2.position.x = 0.6
	var hp_before: int = f2.health
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
	ctx["arena"].queue_free()

func _test_fireball() -> void:
	print("[fireball]")
	var ctx := _build()
	var f2: Fighter = ctx["f2"]
	var arena: Arena = ctx["arena"]
	# Keep distance; perform QCF + LP as P1.
	var hp_before: int = f2.health
	_step(ctx, _mk(0, -1), _neutral(), 3)        # down
	_step(ctx, _mk(1, -1), _neutral(), 3)        # down-forward
	_step(ctx, _mk(1, 0, GameConst.Btn.LP), _neutral(), 1)  # forward + punch
	# The projectile spawns on the move's active frame (startup=12), not instantly.
	_step(ctx, _neutral(), _mk(0, 0), 14)
	_check("a projectile spawned", arena.projectiles.size() >= 1)
	# Let the fireball travel into P2 (standing, not blocking).
	_step(ctx, _neutral(), _mk(0, 0), 90)
	_check("fireball hit P2 for damage", f2.health < hp_before)
	ctx["arena"].queue_free()

func _test_super() -> void:
	print("[super]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	var arena: Arena = ctx["arena"]
	f1.meter = f1.character.max_meter   # grant full meter
	var hp_before: int = f2.health
	# QCF QCF + HP as P1.
	_step(ctx, _mk(0, -1), _neutral(), 2)
	_step(ctx, _mk(1, -1), _neutral(), 2)
	_step(ctx, _mk(1, 0), _neutral(), 2)
	_step(ctx, _mk(0, -1), _neutral(), 2)
	_step(ctx, _mk(1, -1), _neutral(), 2)
	_step(ctx, _mk(1, 0, GameConst.Btn.HP), _neutral(), 1)
	_check("super consumed meter", f1.meter < f1.character.max_meter)
	_step(ctx, _neutral(), _mk(0, 0), 90)
	_check("super dealt heavy damage", hp_before - f2.health >= 200)
	ctx["arena"].queue_free()

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

func _test_cpu_ai() -> void:
	print("[cpu ai]")
	seed(20260619)
	var arena := Arena.new()
	root.add_child(arena)
	var human := Manual.new()                 # P1 stands still
	var cpu := CpuController.new(2)            # P2 is the AI (difficulty 2)
	var f1 := Fighter.new()
	var f2 := Fighter.new()
	f1.setup(CharacterLibrary.create("rho"), human, GameConst.Side.P1, -2.4)
	f2.setup(CharacterLibrary.create("kael"), cpu, GameConst.Side.P2, 2.4)
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

func _test_blaze_roster() -> void:
	print("[blaze roster]")
	_check("roster includes blaze", CharacterLibrary.ids().has("blaze"))
	var b := CharacterLibrary.create("blaze")
	_check("blaze display name", b.display_name == "Blaze")
	_check("blaze has 3 specials", b.specials.size() == 3)
	_check("blaze has 1 super", b.supers.size() == 1)
	_check("blaze hurricane uses QCB", b.get_move("hurricane") != null and b.get_move("hurricane").motion == MotionParser.QCB)

func _test_multihit() -> void:
	print("[multi-hit]")
	var ctx := _build("blaze", "rho")
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	# Corner P2 so Blaze's advancing hurricane keeps connecting.
	f1.position.x = 5.2
	f2.position.x = 6.2
	var hits := [0]
	f1.contact.connect(func(blocked, _m): if not blocked: hits[0] += 1)
	var hp_before: int = f2.health
	# Cyclone Kick: QCB ( down, down-back, back ) + LK.
	_step(ctx, _mk(0, -1), _neutral(), 3)
	_step(ctx, _mk(-1, -1), _neutral(), 3)
	_step(ctx, _mk(-1, 0, GameConst.Btn.LK), _neutral(), 1)
	_step(ctx, _neutral(), _neutral(), 75)
	_check("hurricane connected multiple times", hits[0] >= 2)
	_check("multi-hit dealt cumulative damage", hp_before - f2.health >= 70)
	ctx["arena"].queue_free()

func _test_move_sfx() -> void:
	print("[per-move sfx]")
	var b := CharacterLibrary.create("blaze")
	var fb := b.get_move("fireball")
	var hur := b.get_move("hurricane")
	var sup := b.get_move("super_inferno")
	_check("fireball has its own sfx", fb != null and fb.sfx == "fire")
	_check("hurricane has its own sfx", hur != null and hur.sfx == "spin")
	_check("super has its own sfx", sup != null and sup.sfx == "super")

func _test_animated_rig() -> void:
	print("[animated rig]")
	var kael := CharacterLibrary.create("kael")
	if kael.model_path == "" or not ResourceLoader.exists(kael.model_path):
		print("  SKIP: model assets not present (clean clone)")
		return
	var arig := AnimatedFighterRig.new()
	root.add_child(arig)
	arig.build(kael)
	_check("animated rig built ok", arig.ok)
	_check("grafted idle clip", arig._player != null and arig._player.has_animation("kb/KB_Idle_1"))
	_check("grafted jab clip", arig._player != null and arig._player.has_animation("kb/KB_p_Jab_R_1"))
	_check("grafted super clip", arig._player != null and arig._player.has_animation("kb/KB_Superpunch"))
	# Air-attack clips must be grafted so the move animations are visible (not a fallback).
	for clip in ["KB_JumpPunch", "KB_m_Hook_R", "KB_m_Overhand_R", "KB_JumpKick", "KB_m_HighKickRound_R_1", "KB_AxeKick"]:
		_check("grafted air clip " + clip, arig._player.has_animation("kb/" + clip))
	for clip in ["KB_Hit_p_MidFront_Weak", "KB_Hit_m_MidFront_Med", "KB_Hit_m_HighFront_Stagger"]:
		_check("grafted hit clip " + clip, arig._player.has_animation("kb/" + clip))
	# Idle must be set to loop (otherwise it stops after one play ~3s).
	_check("idle clip loops", arig._player.get_animation("kb/KB_Idle_1").loop_mode == Animation.LOOP_LINEAR)
	arig.queue_free()

func _test_six_buttons() -> void:
	print("[six buttons]")
	var k := CharacterLibrary.create("kael")
	_check("18 normals (6 buttons x 3 stances)", k.normals.size() == 18)
	var st_mp := k.get_move("st_mp")
	_check("standing MP exists", st_mp != null and st_mp.button == GameConst.Btn.MP and st_mp.stance == GameConst.Stance.STAND)
	var cr_mk := k.get_move("cr_mk")
	_check("crouch MK is a low", cr_mk != null and cr_mk.stance == GameConst.Stance.CROUCH and cr_mk.guard == GameConst.Guard.LOW)
	var air_hp := k.get_move("air_hp")
	_check("air HP is an overhead", air_hp != null and air_hp.stance == GameConst.Stance.AIR and air_hp.guard == GameConst.Guard.OVERHEAD)

func _test_dash() -> void:
	print("[dash]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var start_x: float = f1.position.x
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
	_check("forward dash triggered", saw_dash)
	_check("dash moved forward quickly", f1.position.x > start_x + 1.2)
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

func _test_air_clips_distinct() -> void:
	print("[air clip variety]")
	var k := CharacterLibrary.create("kael")
	var clips := {}
	for id in ["air_lp", "air_mp", "air_hp", "air_lk", "air_mk", "air_hk"]:
		var m := k.get_move(id)
		clips[m.anim_clip] = true
	_check("air normals use 6 distinct clips", clips.size() == 6)

func _hit_with(button: int) -> int:
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.6
	f2.position.x = 0.6
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
	if not ResourceLoader.exists("res://assets/models/maskman.fbx"):
		print("  SKIP: model assets not present (clean clone)")
		return
	var lib := AnimatedFighterRig.build_kb_library()
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
	var ctx := _build("kael", "rho")
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
	_check("crouch uppercut (crouch HP) -> upper knockdown", _knockdown_from(GameConst.Btn.HP, -1) == GameConst.Knockdown.UPPER)
	_check("stand HK launcher -> heavy knockdown", _knockdown_from(GameConst.Btn.HK, 0) == GameConst.Knockdown.HEAVY)

func _test_wakeup() -> void:
	print("[knockdown / wakeup flow]")
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	# Corner P2 and launch with Stand HK, then watch the full down -> get-up -> idle cycle.
	f1.position.x = 5.4
	f2.position.x = 6.2
	_step(ctx, _mk(0, 0, GameConst.Btn.HK), _neutral(), 1)
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
	var kael := CharacterLibrary.create("kael")
	if kael.model_path == "" or not ResourceLoader.exists(kael.model_path):
		print("  SKIP: model assets not present (clean clone)")
		return
	var arig := AnimatedFighterRig.new()
	root.add_child(arig)
	arig.build(kael)
	var f := Fighter.new()
	f.setup(kael, Manual.new(), GameConst.Side.P1, 0.0)
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
	f1.position.x = -0.6
	f2.position.x = 0.6
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
	spark.free()

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
