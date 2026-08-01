extends "res://scripts/ui/AnimationGallery.gd"

const EFFECT_ROOT := "res://assets/third_party/vfx_impact_and_hit/effects"
const EFFECT_SCALE := 0.35
const REPLAY_INTERVAL := 1.4

var _effects: Array[Node3D] = []
var _replay_timer := REPLAY_INTERVAL

func _ready() -> void:
	_gallery_title = "GALLERY-VFXImpactAndHit"
	_add_environment()
	var paths := _effect_paths()
	if paths.is_empty():
		_show_notice("VFX Impact and Hit assets not installed.")
		return
	var rows := int(ceil(float(paths.size()) / COLS))
	for i in range(paths.size()):
		var col := i % COLS
		var row := i / COLS
		_spawn_effect(paths[i], Vector3(col * SPACING_X, 1.0, -row * SPACING_Z))
	_setup_camera(rows)
	_build_ui(paths.size())
	_restart_effects()

func _process(delta: float) -> void:
	super._process(delta)
	_replay_timer -= delta
	if _replay_timer <= 0.0:
		_replay_timer = REPLAY_INTERVAL
		_restart_effects()

func _effect_paths() -> Array[String]:
	var paths: Array[String] = []
	_collect_effect_paths(EFFECT_ROOT, paths)
	paths.sort()
	return paths

func _collect_effect_paths(dir_path: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	paths.append_array(_paths_from_files(dir_path, dir.get_files()))
	for child_dir in dir.get_directories():
		_collect_effect_paths(dir_path + "/" + String(child_dir), paths)

func _paths_from_files(dir_path: String, file_names: PackedStringArray) -> Array[String]:
	var paths: Array[String] = []
	for entry in file_names:
		var file_name := String(entry)
		if file_name.ends_with(".tscn.remap"):
			file_name = file_name.left(file_name.length() - ".remap".length())
		elif file_name.get_extension().to_lower() != "tscn":
			continue
		var path := dir_path + "/" + file_name
		if path not in paths:
			paths.append(path)
	paths.sort()
	return paths

func _spawn_effect(path: String, pos: Vector3) -> void:
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var effect := scene.instantiate() as Node3D
	if effect == null:
		return
	effect.position = pos
	effect.scale = Vector3.ONE * EFFECT_SCALE
	add_child(effect)
	_effects.append(effect)

	var label := Label3D.new()
	label.text = path.get_file().get_basename()
	label.position = pos + Vector3(0, 1.25, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.pixel_size = 0.0016
	label.outline_size = 6
	label.modulate = Color(1, 0.95, 0.7)
	add_child(label)

func _restart_effects() -> void:
	for effect in _effects:
		_restart_effect(effect)

func _restart_effect(node: Node) -> void:
	if node is GPUParticles3D:
		var particles := node as GPUParticles3D
		particles.one_shot = false
		particles.restart()
		particles.emitting = true
	elif node is AnimationPlayer:
		var player := node as AnimationPlayer
		for animation_name in player.get_animation_list():
			if String(animation_name) != "RESET":
				player.stop()
				player.play(animation_name)
				break
	for child in node.get_children():
		_restart_effect(child)
