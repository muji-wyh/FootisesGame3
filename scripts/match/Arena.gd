class_name Arena
extends Node3D

## The simulation core: owns the two fighters and all projectiles and advances them by
## exactly one fixed tick in a deterministic order. Has no camera/HUD dependencies, so it
## can be driven by the visual Match scene OR by a headless test harness.

const FIGHT_BOUNDS_HALF_WIDTH := 7.0
const VISUAL_STAGE_HALF_WIDTH := 9.0
const START_DISTANCE := 1.5

signal ko(loser_side: int)

var fighters: Array[Fighter] = []
var projectiles: Array[Projectile] = []
var _proj_root: Node3D
var _ko_emitted: bool = false

func _ensure_roots() -> void:
	if _proj_root == null:
		_proj_root = Node3D.new()
		_proj_root.name = "Projectiles"
		add_child(_proj_root)

func setup_fighters(p1: Fighter, p2: Fighter) -> void:
	_ensure_roots()
	fighters = [p1, p2]
	p1.opponent = p2
	p2.opponent = p1
	p1.position = Vector3(-START_DISTANCE, 0, 0)
	p2.position = Vector3(START_DISTANCE, 0, 0)
	for f in fighters:
		if f.get_parent() == null:
			add_child(f)

## Advance the whole simulation by one fixed tick.
func step(delta: float) -> void:
	for f in fighters:
		f.poll_input()
	for f in fighters:
		f.advance(delta)
	_spawn_pending_projectiles()
	_update_projectiles(delta)
	_resolve_pushboxes()
	_resolve_bounds()
	HitResolver.resolve(fighters, projectiles)
	for f in fighters:
		f.update_facing()
	for f in fighters:
		f.update_visual()
	_check_ko()

func set_active(value: bool) -> void:
	for f in fighters:
		f.active = value

func reset_positions() -> void:
	fighters[0].position = Vector3(-START_DISTANCE, 0, 0)
	fighters[1].position = Vector3(START_DISTANCE, 0, 0)
	_ko_emitted = false
	_clear_projectiles()

# --- projectiles -----------------------------------------------------------

func _spawn_pending_projectiles() -> void:
	for f in fighters:
		for m in f.pending_projectiles:
			var p := Projectile.new()
			var color: Color = f.character.accent
			var start: Vector3 = f.position + Vector3(f.facing * 0.8, 1.0, 0)
			p.setup(m, f.side, f.facing, start, color)
			_proj_root.add_child(p)
			projectiles.append(p)
		f.pending_projectiles.clear()

func _update_projectiles(delta: float) -> void:
	var survivors: Array[Projectile] = []
	for p in projectiles:
		var alive := p.advance(delta)
		if alive and absf(p.position.x) <= VISUAL_STAGE_HALF_WIDTH + 1.0:
			survivors.append(p)
		else:
			p.queue_free()
	projectiles = survivors

func _clear_projectiles() -> void:
	for p in projectiles:
		p.queue_free()
	projectiles.clear()

# --- spacing / bounds ------------------------------------------------------

func _resolve_pushboxes() -> void:
	if fighters.size() < 2:
		return
	var a := fighters[0]
	var b := fighters[1]
	var min_dist := Fighter.PUSHBOX_HALF * 2.0
	var dx := b.position.x - a.position.x
	if absf(dx) < min_dist:
		var overlap := min_dist - absf(dx)
		var dir := 1.0 if dx >= 0 else -1.0
		a.position.x -= dir * overlap * 0.5
		b.position.x += dir * overlap * 0.5

func _resolve_bounds() -> void:
	var lim := FIGHT_BOUNDS_HALF_WIDTH - Fighter.PUSHBOX_HALF
	for f in fighters:
		f.position.x = clampf(f.position.x, -lim, lim)
	# Corner correction: if clamping forced an overlap, shove the non-cornered fighter.
	var a := fighters[0]
	var b := fighters[1]
	var min_dist := Fighter.PUSHBOX_HALF * 2.0
	var dx := b.position.x - a.position.x
	if absf(dx) < min_dist:
		var overlap := min_dist - absf(dx)
		var dir := 1.0 if dx >= 0 else -1.0
		if a.position.x <= -lim + 0.001:
			b.position.x += dir * overlap
		elif b.position.x >= lim - 0.001:
			a.position.x -= dir * overlap
		else:
			a.position.x -= dir * overlap * 0.5
			b.position.x += dir * overlap * 0.5
		a.position.x = clampf(a.position.x, -lim, lim)
		b.position.x = clampf(b.position.x, -lim, lim)

func _check_ko() -> void:
	if _ko_emitted:
		return
	for f in fighters:
		if f.is_dead():
			_ko_emitted = true
			ko.emit(f.side)
			return
