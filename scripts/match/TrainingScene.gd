class_name TrainingScene
extends MatchScene

## Dedicated practice scene. It reuses the match presentation/combat pieces but omits
## RoundManager so training never times out, awards rounds, or transitions to results.

const RESET_DELAY_TICKS := 45
const HP_RECOVERY_DELAY_TICKS := 90
const HP_RECOVERY_PER_TICK := 12

var _reset_timer: int = 0
var _hp_recovery_timers := [0, 0]
var _training_overlay: CanvasLayer
var _built: bool = false

func _ready() -> void:
	_build_training()

func _build_training(game_override: Node = null) -> void:
	if _built:
		return
	_built = true
	var stage := Stage.new()
	stage.build()
	add_child(stage)

	var game := game_override if game_override != null else _game()
	var c1 := CharacterLibrary.create(String(game.get("p1_char_id")))
	var c2 := CharacterLibrary.create(String(game.get("p2_char_id")))

	f1 = Fighter.new()
	f1.name = "P1"
	f1.setup(c1, PlayerController.new("p1"), GameConst.Side.P1, -Arena.START_DISTANCE)
	f1.allow_zero_health_hit_reactions = true
	_attach_rig(f1, c1)

	f2 = Fighter.new()
	f2.name = "Dummy"
	f2.setup(c2, InputController.new(), GameConst.Side.P2, Arena.START_DISTANCE)
	f2.allow_zero_health_hit_reactions = true
	_attach_rig(f2, c2)

	arena = Arena.new()
	add_child(arena)
	arena.setup_fighters(f1, f2)
	arena.set_active(true)

	camera = FightCamera.new()
	add_child(camera)
	camera.current = true

	hud = HUD.new()
	hud.build(c1, c2)
	add_child(hud)
	_wire_hud(c1, c2)
	hud.set_timer_text("TRAIN")

	audio = AudioManager.new()
	add_child(audio)
	audio.wire_fighter(f1)
	audio.wire_fighter(f2)
	audio.wire_arena(arena)
	audio.start_bgm()

	_build_training_overlay()
	_refill_training_resources()

func _physics_process(delta: float) -> void:
	if _reset_timer > 0:
		arena.step_inactive(delta)
		_reset_timer -= 1
		if _reset_timer <= 0:
			_reset_training_state()
	else:
		arena.step(delta)
	f1.update_visual()
	f2.update_visual()
	hud.tick_counter()
	hud.tick_visuals(delta)
	_update_drive_rush(delta)
	camera.track(f1.position, f2.position)
	_slowmo.tick()
	Engine.time_scale = _slowmo.scale
	_refill_training_resources()
	_recover_training_hp()

func _on_training_ko(_loser_side: int) -> void:
	pass

func _reset_training_state() -> void:
	_slowmo.reset()
	arena.reset_positions()
	for f in arena.fighters:
		f.reset_for_round()
	arena.set_active(true)
	_hp_recovery_timers = [0, 0]
	hud.set_rounds(0, 0)
	hud.set_timer_text("TRAIN")
	_refill_training_resources()

func _refill_training_resources() -> void:
	for f in [f1, f2]:
		if f == null:
			continue
		if f.meter != f.character.max_meter:
			f.meter = f.character.max_meter
			f.meter_changed.emit(f.meter, f.character.max_meter)
		if f.drive != f.character.max_drive:
			f.drive = f.character.max_drive
			f.drive_changed.emit(f.drive, f.character.max_drive)

func _recover_training_hp() -> void:
	var fs := [f1, f2]
	for i in range(2):
		var f: Fighter = fs[i]
		if f == null:
			continue
		if f.health >= f.character.max_health:
			_hp_recovery_timers[i] = 0
			continue
		if f.state in [Fighter.State.HITSTUN, Fighter.State.BLOCKSTUN, Fighter.State.KNOCKDOWN, Fighter.State.WAKEUP] or f.hitstop > 0:
			_hp_recovery_timers[i] = 0
			continue
		_hp_recovery_timers[i] += 1
		if _hp_recovery_timers[i] >= HP_RECOVERY_DELAY_TICKS:
			f.health = mini(f.character.max_health, f.health + HP_RECOVERY_PER_TICK)
			f.health_changed.emit(f.health, f.character.max_health)

func _build_training_overlay() -> void:
	_training_overlay = CanvasLayer.new()
	add_child(_training_overlay)
	var label := Label.new()
	label.position = Vector2(430, 112)
	label.size = Vector2(420, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.76, 0.9, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.text = "TRAINING: idle dummy  |  TAB move list  |  ESC menu"
	_training_overlay.add_child(label)
