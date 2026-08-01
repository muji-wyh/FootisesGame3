extends "res://scripts/ui/AnimationGallery.gd"

@export var gallery_name := "GALLERY-HitReactionAnimation"
@export_file("*.fbx") var display_model_path := "res://assets/third_party/hit_reaction_animation/model.fbx"
@export_dir var animation_dir := "res://assets/third_party/hit_reaction_animation/anims"
@export_dir var texture_dir := "res://assets/third_party/hit_reaction_animation/tex/"
@export var animation_library_name := "hit"
@export var display_yaw := -90.0
@export_range(0.1, 2.0, 0.05) var playback_speed := 1.0
@export_range(1, 32, 1) var columns := 14
@export_range(1.0, 8.0, 0.1) var spacing_x := 2.4
@export_range(1.0, 8.0, 0.1) var spacing_z := 3.2

func _ready() -> void:
	_gallery_title = gallery_name
	_model_yaw = display_yaw
	_animation_speed = playback_speed
	_columns = columns
	_spacing_x = spacing_x
	_spacing_z = spacing_z
	_add_environment()
	_cfg = _rig_config()
	if not ResourceLoader.exists(display_model_path):
		_show_notice("Animation Gallery2 assets not installed.")
		return
	var paths := _animation_paths()
	if paths.is_empty():
		_show_notice("No hit-reaction FBX files found.")
		return
	var library := _build_library(paths)
	var names := library.get_animation_list()
	names.sort()
	var model_scene := load(display_model_path) as PackedScene
	if model_scene == null:
		_show_notice("Gallery2 display model failed to load.")
		return
	var rows := int(ceil(float(names.size()) / _columns))
	for i in range(names.size()):
		var col := i % _columns
		var row := i / _columns
		_spawn(model_scene, library, names[i], Vector3(col * _spacing_x, 0, -row * _spacing_z))
	_setup_camera(rows)
	_build_ui(names.size())

func _animation_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(animation_dir)
	if dir == null:
		return paths
	return _paths_from_files(dir.get_files())

func _paths_from_files(file_names: PackedStringArray) -> Array[String]:
	var paths: Array[String] = []
	for entry in file_names:
		var file_name := String(entry)
		if file_name.ends_with(".fbx.import"):
			file_name = file_name.left(file_name.length() - ".import".length())
		elif file_name.get_extension().to_lower() != "fbx":
			continue
		var path := animation_dir + "/" + file_name
		if path not in paths:
			paths.append(path)
	paths.sort()
	return paths

func _build_library(paths: Array[String]) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for path in paths:
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var instance := scene.instantiate()
		var player := _find(instance, "AnimationPlayer") as AnimationPlayer
		if player != null:
			var source_names := player.get_animation_list()
			if not source_names.is_empty():
				var source_name := source_names[0]
				for candidate in source_names:
					if String(candidate) != "RESET":
						source_name = candidate
						break
				var animation: Animation = player.get_animation(source_name).duplicate(true)
				_normalize_animation(animation)
				animation.loop_mode = Animation.LOOP_LINEAR
				library.add_animation(path.get_file().get_basename(), animation)
		instance.free()
	return library

func _normalize_animation(animation: Animation) -> void:
	for track in range(animation.get_track_count() - 1, -1, -1):
		var path := animation.track_get_path(track)
		var names := String(path.get_concatenated_names())
		if names == "Skeleton3D":
			continue
		if names.ends_with("/Skeleton3D") and path.get_subname_count() > 0:
			var bone := String(path.get_subname(path.get_subname_count() - 1))
			animation.track_set_path(track, NodePath("Skeleton3D:" + bone))
		else:
			animation.remove_track(track)

func _rig_config() -> RigConfig:
	var config := RigConfig.new()
	config.lib_name = animation_library_name
	config.surface_textures = {"CG_NCG_mtl": "9CG"}
	config.tex_dir = texture_dir
	config.material_roughness = 0.6
	config.lod_keep = "NCG_Mesh"
	return config
