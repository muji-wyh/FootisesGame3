class_name MatchScene
extends Node3D

## Top-level match controller. Builds the stage, two fighters (with rigs and the right
## controllers for the current Game.mode), the camera, the HUD and the RoundManager, then
## advances the simulation one fixed tick per _physics_process. (Named MatchScene because
## "match" is a GDScript keyword.)

var arena: Arena
var camera: FightCamera
var hud: HUD
var round_manager: RoundManager
var audio: AudioManager
var f1: Fighter
var f2: Fighter

var _match_over: bool = false
var _post_match_timer: int = 0
var _slowmo := SlowMoDirector.new()
var _dr_was := [false, false]   # per-fighter "was drive-rushing last frame" edge tracker
var _dr_tint_level: float = 0.0
var _depth_front_p1: bool = true   # which fighter is on the near (toward-camera) depth plane

const DRIVE_RUSH_TINT_TARGET := 0.07
# Dynamic anti-clip depth: fighters share one line (z=0) at range and only stagger a SMALL amount
# in depth at point-blank so their limbs don't pass through each other ("穿模"). The attacker is
# put on the near plane so its strike draws in front, not behind. See _update_model_depth.
const MODEL_DEPTH_OFFSET := 0.05   # max per-side depth stagger, reached at/under DEPTH_RAMP_NEAR
const DEPTH_RAMP_NEAR := 0.70      # |dx| at/below which the full stagger applies (bodies overlapping)
const DEPTH_RAMP_FAR := 1.05       # |dx| at/above which there is no stagger (clearly on one line)

func _ready() -> void:
	var stage := Stage.new()
	stage.build()
	add_child(stage)

	var game := _game()
	var c1 := CharacterLibrary.create(String(game.get("p1_char_id")))
	var c2 := CharacterLibrary.create(String(game.get("p2_char_id")))

	var ctrl1 := PlayerController.new("p1")
	var ctrl2: InputController
	if int(game.get("mode")) == GameConst.Mode.VS_CPU:
		ctrl2 = CpuController.new(1)
	else:
		ctrl2 = PlayerController.new("p2")

	f1 = Fighter.new()
	f1.name = "P1"
	f1.setup(c1, ctrl1, GameConst.Side.P1, -Arena.START_DISTANCE)
	_attach_rig(f1, c1)

	f2 = Fighter.new()
	f2.name = "P2"
	f2.setup(c2, ctrl2, GameConst.Side.P2, Arena.START_DISTANCE)
	_attach_rig(f2, c2)

	arena = Arena.new()
	add_child(arena)
	arena.setup_fighters(f1, f2)
	arena.ko.connect(func(_loser): _slowmo.request(0.3, 30, true))   # dramatic KO finish

	camera = FightCamera.new()
	add_child(camera)
	camera.current = true

	hud = HUD.new()
	hud.build(c1, c2)
	add_child(hud)
	_wire_hud(c1, c2)

	audio = AudioManager.new()
	add_child(audio)
	audio.wire_fighter(f1)
	audio.wire_fighter(f2)
	audio.wire_arena(arena)
	audio.start_bgm()

	round_manager = RoundManager.new()
	add_child(round_manager)
	round_manager.arena = arena
	round_manager.announce.connect(hud.show_banner)
	round_manager.announce_clear.connect(hud.clear_banner)
	round_manager.timer_changed.connect(hud.set_timer)
	round_manager.rounds_changed.connect(hud.set_rounds)
	round_manager.match_over.connect(_on_match_over)
	round_manager.start()

func _attach_rig(f: Fighter, ch: CharacterData) -> void:
	var rig: Node = null
	# Use the model-backed rig when the (licensed, gitignored) model is present;
	# otherwise fall back to the procedural blockout so a clean clone still runs.
	if ch.model_path != "" and ResourceLoader.exists(ch.model_path):
		var arig := AnimatedFighterRig.new()
		f.add_child(arig)
		arig.build(ch)
		if arig.ok:
			rig = arig
		else:
			arig.queue_free()
	if rig == null:
		var brig := FighterRig.new()
		f.add_child(brig)
		brig.build(ch)
		rig = brig
	f.rig = rig
	# The depth stagger is applied dynamically per-frame (see _update_model_depth): zero at range
	# so the fighters share one line, ramping in only at point-blank to avoid limb clipping ("穿模").
	f.update_visual()

## Dynamic depth stagger (anti-clip): keep both fighters on the same line (z=0) at range, and only
## when their bodies overlap at close quarters slide them apart in depth a little so their limbs
## don't pass through each other ("穿模"). Each is size-compensated so the depth never changes its
## on-screen size. Presentation only; the simulation, hitboxes and bounds all stay on z = 0.
func _update_model_depth() -> void:
	if f1 == null or f2 == null or f1.rig == null or f2.rig == null:
		return
	var dx := absf(f2.position.x - f1.position.x)
	var t := clampf((DEPTH_RAMP_FAR - dx) / (DEPTH_RAMP_FAR - DEPTH_RAMP_NEAR), 0.0, 1.0)
	var half := t * MODEL_DEPTH_OFFSET
	# Put the ATTACKER on the near (toward-camera) plane so its strike draws in front of the
	# opponent, never behind it. Hysteresis keeps the ordering stable when neither/both attack.
	var p1_atk := f1.state == Fighter.State.ATTACK
	var p2_atk := f2.state == Fighter.State.ATTACK
	if p1_atk and not p2_atk:
		_depth_front_p1 = true
	elif p2_atk and not p1_atk:
		_depth_front_p1 = false
	var cam_z := (FightCamera.MIN_Z + FightCamera.MAX_Z) * 0.5   # nominal camera distance
	var f1_z := half if _depth_front_p1 else -half
	_apply_depth(f1.rig, f1_z, cam_z)
	_apply_depth(f2.rig, -f1_z, cam_z)

## Place one rig at depth `depth_z` and counter-scale it so the perspective camera renders it at
## the same on-screen size as if it were on z = 0 (scaled about the rig origin = the feet, so it
## stays grounded).
func _apply_depth(rig: Node, depth_z: float, cam_z: float) -> void:
	var r := rig as Node3D
	r.position.z = depth_z
	r.scale = Vector3.ONE * (1.0 - depth_z / cam_z)

func _wire_hud(c1: CharacterData, c2: CharacterData) -> void:
	f1.health_changed.connect(func(c, m): hud.set_health(0, c, m))
	f1.meter_changed.connect(func(c, m): hud.set_meter(0, c, m))
	f1.drive_changed.connect(func(c, m): hud.set_drive(0, c, m))
	f2.health_changed.connect(func(c, m): hud.set_health(1, c, m))
	f2.meter_changed.connect(func(c, m): hud.set_meter(1, c, m))
	f2.drive_changed.connect(func(c, m): hud.set_drive(1, c, m))
	f1.countered.connect(_on_countered)
	f2.countered.connect(_on_countered)
	f1.meaty_hit.connect(func(): _on_meaty(f1))
	f2.meaty_hit.connect(func(): _on_meaty(f2))
	f1.got_hit.connect(func(blocked): _on_struck(f1, blocked))
	f2.got_hit.connect(func(blocked): _on_struck(f2, blocked))
	# Combo counters: a fighter's own combo (hits it has taken) drives the OTHER side's display.
	f1.combo_changed.connect(func(h, d): hud.set_combo(1, h, d))
	f2.combo_changed.connect(func(h, d): hud.set_combo(0, h, d))
	hud.set_health(0, f1.health, c1.max_health)
	hud.set_health(1, f2.health, c2.max_health)
	hud.set_meter(0, 0, c1.max_meter)
	hud.set_meter(1, 0, c2.max_meter)
	hud.set_drive(0, f1.drive, c1.max_drive)
	hud.set_drive(1, f2.drive, c2.max_drive)

## A fighter was hit / blocked: spawn an impact spark at the contact point and shake the
## camera, scaling intensity, colour and height by strength / counter / where it landed.
func _on_struck(victim: Fighter, blocked: bool) -> void:
	var atk: Fighter = victim.opponent
	# Start the hit/block pose before spawning the spark so impact visuals line up.
	victim.update_visual()
	if atk != null and is_instance_valid(atk):
		atk.update_visual()
	var p := _spark_params(victim, blocked)
	var col: Color = p["color"]
	var sc: float = p["scale"]
	var amp: float = p["shake"]
	var fr: int = p["frames"]
	var y: float = p["y"]
	var spark := HitSpark.new()
	add_child(spark)
	spark.position = _spark_position(victim, atk, y)
	spark.setup(col, sc)
	camera.shake(amp, fr)

func _spark_position(victim: Fighter, atk: Fighter, fallback_y: float) -> Vector3:
	if victim.last_hit_point != Vector3.ZERO:
		return victim.last_hit_point
	var cx: float = victim.position.x
	if atk != null and is_instance_valid(atk):
		cx = (victim.position.x + atk.position.x) * 0.5
	return Vector3(cx, fallback_y, 0.0)

func _spark_params(victim: Fighter, blocked: bool) -> Dictionary:
	if blocked:
		return {"color": Color(0.6, 0.8, 1.0), "scale": 0.42, "shake": 0.03, "frames": 5, "y": 1.0}
	var y := _hit_y(victim)
	if victim.last_meaty:
		return {"color": Color(1.0, 0.7, 0.1), "scale": 1.0, "shake": 0.16, "frames": 10, "y": y}
	match victim.last_counter:
		GameConst.Counter.PUNISH:
			return {"color": Color(1.0, 0.35, 0.9), "scale": 1.15, "shake": 0.22, "frames": 12, "y": y}
		GameConst.Counter.COUNTER:
			return {"color": Color(0.45, 0.9, 1.0), "scale": 0.95, "shake": 0.15, "frames": 10, "y": y}
	match victim.hit_strength:
		2:
			return {"color": Color(1.0, 0.5, 0.2), "scale": 0.9, "shake": 0.12, "frames": 9, "y": y}
		1:
			return {"color": Color(1.0, 0.8, 0.35), "scale": 0.68, "shake": 0.07, "frames": 7, "y": y}
	return {"color": Color(1.0, 0.95, 0.7), "scale": 0.52, "shake": 0.04, "frames": 6, "y": y}

func _hit_y(victim: Fighter) -> float:
	match victim.hit_height:
		GameConst.HitHeight.HIGH:
			return 1.5
		GameConst.HitHeight.LOW:
			return 0.55
	return 1.1

## A fighter was hit as a Counter / Punish Counter: flash the HUD call-out, and on a
## Punish Counter add a brief slow-motion beat.
func _on_countered(kind: int) -> void:
	hud.show_counter(kind)
	if kind == GameConst.Counter.PUNISH:
		_slowmo.request(0.35, 12)

## A fighter landed a meaty on the opponent's wake-up: flash "MEATY!" and a short slow-mo beat
## so a well-timed okizeme reads as a reward.
func _on_meaty(_attacker: Fighter) -> void:
	hud.show_meaty()
	_slowmo.request(0.4, 10)

## Drive Rush presentation: spawn an afterimage trail on the frame a fighter starts rushing,
## play a whoosh, pulse the screen tint while anyone is rushing, and surface Burnout on the HUD.
func _update_drive_rush(delta: float) -> void:
	var fs := [f1, f2]
	var any_rush := false
	for i in range(2):
		var f: Fighter = fs[i]
		var rushing: bool = f.state == Fighter.State.DRIVE_RUSH
		if rushing or f.drive_rush_pending:
			any_rush = true
		if rushing and not _dr_was[i]:
			_spawn_dr_fx(f)
			if audio != null:
				audio.play("spin", -4.0)
		_dr_was[i] = rushing
		hud.set_burnout(i, f.is_burnout())
	var target: float = DRIVE_RUSH_TINT_TARGET if any_rush else 0.0
	_dr_tint_level = lerpf(_dr_tint_level, target, 0.25)
	hud.set_dr_tint(_dr_tint_level, Color(0.35, 1.0, 0.7))

func _spawn_dr_fx(f: Fighter) -> void:
	var fx := DriveRushFx.new()
	arena.add_child(fx)
	fx.setup(f, Color(0.35, 1.0, 0.7))

func _physics_process(delta: float) -> void:
	round_manager.tick(delta)
	# Keep the rigs posed every frame (incl. intro / round-over), so a fighter never holds
	# the previous round's pose into the next round.
	f1.update_visual()
	f2.update_visual()
	_update_model_depth()
	hud.tick_counter()
	hud.tick_visuals(delta)
	_update_drive_rush(delta)
	camera.track(f1.position, f2.position)
	# Slow-motion beats (Punish Counter / KO): advance the director and apply its scale.
	_slowmo.tick()
	Engine.time_scale = _slowmo.scale
	if _match_over:
		_post_match_timer -= 1
		if _post_match_timer <= 0:
			_game().call("goto_scene", "res://scenes/ui/ResultsScreen.tscn")

## Restore normal time flow when leaving the match (guards against a scene change while a
## slow-motion dip is active).
func _exit_tree() -> void:
	_slowmo.reset()
	Engine.time_scale = 1.0

func _on_match_over(winner_side: int) -> void:
	_match_over = true
	_post_match_timer = 210
	var game := _game()
	game.set("last_winner_side", winner_side)
	game.set("last_winner_name", arena.fighters[winner_side].character.display_name)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_move_list"):
		hud.toggle_move_list()
		return
	if event.is_action_pressed("ui_cancel"):
		_game().call("goto_scene", "res://scenes/ui/MainMenu.tscn")

func _game() -> Node:
	return get_tree().root.get_node("Game")
