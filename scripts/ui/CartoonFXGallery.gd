extends "res://scripts/ui/AnimationGallery.gd"

const TEXTURE_ROOT := "res://assets/cartoon_fx_pack/textures"
const PREVIEW_LONG_SIDE := 2.0
const PREVIEW_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform sampler2D preview_texture : source_color, filter_linear_mipmap;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec4 texel = texture(preview_texture, UV);
	float source_peak = max(max(texel.r, texel.g), texel.b);
	float is_alpha_mask = 1.0 - step(0.01, source_peak);
	float mask_alpha = smoothstep(0.43, 0.57, texel.a);
	vec3 preview_color = mix(texel.rgb, vec3(1.0), is_alpha_mask);
	float preview_alpha = mix(texel.a, mask_alpha, is_alpha_mask);
	ALBEDO = preview_color;
	EMISSION = preview_color;
	ALPHA = preview_alpha;
}
"""

var _preview_shader: Shader

func _ready() -> void:
	_gallery_title = "GALLERY-CartoonFXPack"
	_columns = 7
	_spacing_x = 3.0
	_spacing_z = 4.0
	_orbit_pitch = deg_to_rad(-45.0)
	_orbit_distance = 15.0
	_add_environment()
	var paths := _texture_paths()
	if paths.is_empty():
		_show_notice("CartoonFXPack textures not installed.")
		return
	var rows := int(ceil(float(paths.size()) / _columns))
	for i in range(paths.size()):
		var col := i % _columns
		var row := i / _columns
		var items_in_row := mini(_columns, paths.size() - row * _columns)
		var row_offset := float(_columns - items_in_row) * _spacing_x * 0.5
		_spawn_texture(paths[i], Vector3(row_offset + col * _spacing_x, 1.0, -row * _spacing_z))
	_setup_camera(rows)
	_orbit_target.z = -float(rows - 1) * _spacing_z * 0.5
	_apply_camera_transform()
	_build_ui(paths.size(), "textures")

func _texture_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(TEXTURE_ROOT)
	if dir == null:
		return paths
	return _paths_from_files(dir.get_files())

func _paths_from_files(file_names: PackedStringArray) -> Array[String]:
	var paths: Array[String] = []
	for entry in file_names:
		var file_name := String(entry)
		if file_name.ends_with(".png.import") or file_name.ends_with(".png.remap"):
			file_name = file_name.get_basename()
		elif file_name.get_extension().to_lower() != "png":
			continue
		var path := TEXTURE_ROOT + "/" + file_name
		if path not in paths:
			paths.append(path)
	paths.sort()
	return paths

func _spawn_texture(path: String, pos: Vector3) -> MeshInstance3D:
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var aspect := float(texture.get_width()) / float(texture.get_height())
	var size := Vector2(PREVIEW_LONG_SIDE, PREVIEW_LONG_SIDE)
	if aspect >= 1.0:
		size.y /= aspect
	else:
		size.x *= aspect

	var quad := QuadMesh.new()
	quad.size = size
	var preview := MeshInstance3D.new()
	preview.name = "Preview_" + path.get_file().get_basename()
	preview.position = pos
	preview.mesh = quad
	if _preview_shader == null:
		_preview_shader = Shader.new()
		_preview_shader.code = PREVIEW_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = _preview_shader
	material.set_shader_parameter("preview_texture", texture)
	preview.material_override = material
	add_child(preview)

	var label := Label3D.new()
	label.text = path.get_file().get_basename()
	label.position = pos + Vector3(0, 1.35, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.0022
	label.outline_size = 6
	label.modulate = Color(1, 0.95, 0.7)
	add_child(label)
	return preview
