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

func _ready() -> void:
	var stage := Stage.new()
	stage.build()
	add_child(stage)

	var c1 := CharacterLibrary.create(Game.p1_char_id)
	var c2 := CharacterLibrary.create(Game.p2_char_id)

	var ctrl1 := PlayerController.new("p1")
	var ctrl2: InputController
	if Game.mode == GameConst.Mode.VS_CPU:
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
	f.update_visual()

func _wire_hud(c1: CharacterData, c2: CharacterData) -> void:
	f1.health_changed.connect(func(c, m): hud.set_health(0, c, m))
	f1.meter_changed.connect(func(c, m): hud.set_meter(0, c, m))
	f2.health_changed.connect(func(c, m): hud.set_health(1, c, m))
	f2.meter_changed.connect(func(c, m): hud.set_meter(1, c, m))
	f1.countered.connect(_on_countered)
	f2.countered.connect(_on_countered)
	hud.set_health(0, f1.health, c1.max_health)
	hud.set_health(1, f2.health, c2.max_health)
	hud.set_meter(0, 0, c1.max_meter)
	hud.set_meter(1, 0, c2.max_meter)

## A fighter was hit as a Counter / Punish Counter: flash the HUD call-out.
func _on_countered(kind: int) -> void:
	hud.show_counter(kind)

func _physics_process(delta: float) -> void:
	round_manager.tick(delta)
	# Keep the rigs posed every frame (incl. intro / round-over), so a fighter never holds
	# the previous round's pose into the next round.
	f1.update_visual()
	f2.update_visual()
	hud.tick_counter()
	camera.track(f1.position, f2.position)
	if _match_over:
		_post_match_timer -= 1
		if _post_match_timer <= 0:
			Game.goto_scene("res://scenes/ui/ResultsScreen.tscn")

func _on_match_over(winner_side: int) -> void:
	_match_over = true
	_post_match_timer = 210
	Game.last_winner_side = winner_side
	Game.last_winner_name = arena.fighters[winner_side].character.display_name

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.goto_scene("res://scenes/ui/MainMenu.tscn")
