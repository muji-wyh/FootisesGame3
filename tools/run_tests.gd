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

func _initialize() -> void:
	print("=== Brawl Arena combat tests ===")
	_test_walk()
	_test_pushbox_spacing()
	_test_visible_spacing_limit()
	_test_stage_width_split()
	_test_normal_hit()
	_test_lp_whiff_range()
	_test_blaze_mp_hp_range()
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
	_test_drive_gauge()
	_test_drive_rush()
	_test_uppercut_rise()
	_test_camera()
	_test_input_buffer()
	_test_overdrive()
	_test_combo_scaling()
	_test_burnout()
	_test_drive_rush_carry()
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
	var all_empty := true
	for m in b.normals:
		all_empty = all_empty and m.cancel_into.is_empty()
	_check("normals no longer contain authored combo cancel routes", all_empty)

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
	_check("Inferno Rush hitbox matches model scale", inferno.hit_size.x <= 0.7 and inferno.hit_size.y <= 0.95 and inferno.hit_size.z <= 0.7)
	_check("Inferno Rush reach is not oversized", inferno.hit_offset.x + inferno.hit_size.x * 0.5 <= 1.1)
	f1.meter = f1.character.max_meter   # grant full meter
	# Corner P2 so Blaze's advancing multi-hit super connects in full.
	f1.position.x = 5.4
	f2.position.x = 6.3
	var hp_before: int = f2.health
	# QCF QCF + HP as P1.
	_step(ctx, _mk(0, -1), _neutral(), 2)
	_step(ctx, _mk(1, -1), _neutral(), 2)
	_step(ctx, _mk(1, 0), _neutral(), 2)
	_step(ctx, _mk(0, -1), _neutral(), 2)
	_step(ctx, _mk(1, -1), _neutral(), 2)
	_step(ctx, _mk(1, 0, GameConst.Btn.HP), _neutral(), 1)
	_check("super consumed meter", f1.meter < f1.character.max_meter)
	_step(ctx, _neutral(), _neutral(), 90)
	_check("super dealt heavy damage", hp_before - f2.health >= 200)
	ctx["arena"].queue_free()
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
	_check("blaze has no specials", b.specials.is_empty())
	_check("blaze has 1 super", b.supers.size() == 1)
	for removed in ["fireball", "uppercut", "hurricane", "od_fireball", "od_uppercut", "od_hurricane"]:
		_check("removed move absent: " + removed, b.get_move(removed) == null)
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
	scene._on_struck(victim, false)
	_check("hit visual updates before spark spawn", rig.pose_count == 1 and scene.get_child_count() >= 2)
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
	print("[combo routes removed]")
	var kit := CharacterLibrary.create("blaze")
	var all_empty := true
	for m in kit.normals:
		all_empty = all_empty and m.cancel_into.is_empty()
	_check("Blaze normals have no authored combo routes", all_empty)
	var ctx := _build()
	var f1: Fighter = ctx["f1"]
	var f2: Fighter = ctx["f2"]
	f1.position.x = -0.6
	f2.position.x = 0.6
	var a: Fighter = f1
	var b: Fighter = f2
	var jab := a.character.get_move("st_lp")
	ctx["c1"].frame = _mk(0, 0, GameConst.Btn.LP)
	ctx["c2"].frame = _neutral()
	ctx["arena"].step(DELTA)
	var bh := b.health
	for i in range(8):
		if b.health < bh: break
		ctx["c1"].frame = _neutral()
		ctx["c2"].frame = _neutral()
		ctx["arena"].step(DELTA)
	# Press MP during LP hitstop. It must not chain-cancel before LP's own recovery ends.
	var saw_mp_before_recovery := false
	for i in range(2):
		ctx["c1"].frame = _mk(0, 0, GameConst.Btn.MP)
		ctx["c2"].frame = _neutral()
		ctx["arena"].step(DELTA)
	for i in range(jab.total_frames()):
		ctx["c1"].frame = _neutral()
		ctx["c2"].frame = _neutral()
		ctx["arena"].step(DELTA)
		if a.current_move != null and a.current_move.id == "st_mp" and a.state_frame < jab.total_frames():
			saw_mp_before_recovery = true
	_check("LP cannot chain-cancel into MP", not saw_mp_before_recovery)
	ctx["arena"].queue_free()

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
	var stagger := _build()
	var sr: Fighter = stagger["f1"]
	var sd: int = sr.drive
	_step(stagger, _mk(0, 0, GameConst.Btn.LP, GameConst.Btn.LP), _neutral(), 1)
	_step(stagger, _mk(0, 0, GameConst.Btn.MP, GameConst.Btn.MP), _neutral(), 1)
	_check("slightly staggered two-punch starts green rush", sr.state == Fighter.State.DRIVE_RUSH)
	_check("staggered raw green rush spends Drive", sr.drive < sd)
	stagger["arena"].queue_free()
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
