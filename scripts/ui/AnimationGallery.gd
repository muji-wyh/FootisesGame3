extends Node3D

## Animation Gallery: a big scene with one character per Kubold animation clip, each looping
## its clip with a floating name label. A pannable camera lets you fly over the grid.
## Reached from the main menu. Requires the (gitignored) Maskman model + KB anim FBX; if
## they're absent it shows a notice instead.

const MASKMAN := "res://assets/models/maskman.fbx"
const COLS := 14
const SPACING_X := 2.4
const SPACING_Z := 3.2

var _cam: Camera3D
var _pan_speed := 14.0

func _ready() -> void:
	_add_environment()
	if not ResourceLoader.exists(MASKMAN):
		_show_notice("Animation assets not installed.\n(Drop the licensed FBX into assets/models/.)")
		return

	var lib := AnimatedFighterRig.build_kb_library()
	var names := lib.get_animation_list()
	names.sort()
	var ps := load(MASKMAN) as PackedScene
	var rows := int(ceil(float(names.size()) / COLS))
	for i in range(names.size()):
		var col := i % COLS
		var row := i / COLS
		_spawn(ps, lib, names[i], Vector3(col * SPACING_X, 0, -row * SPACING_Z))

	_setup_camera(rows)
	_build_ui(names.size())

func _spawn(ps: PackedScene, lib: AnimationLibrary, clip: String, pos: Vector3) -> void:
	var model := ps.instantiate() as Node3D
	if model == null:
		return
	model.position = pos
	add_child(model)

	# Keep only the lowest LOD; texture it.
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	var keep: MeshInstance3D = null
	for m in meshes:
		if "LOD3" in m.name:
			keep = m
	if keep == null and not meshes.is_empty():
		keep = meshes[0]
	for m in meshes:
		if m == keep:
			AnimatedFighterRig.apply_maskman_materials(m, Color(0.85, 0.85, 0.9), Color(0.7, 0.7, 0.72))
		else:
			m.queue_free()

	var ap := _find(model, "AnimationPlayer") as AnimationPlayer
	if ap:
		ap.add_animation_library("kb", lib)
		var anim := lib.get_animation(clip)
		anim.loop_mode = Animation.LOOP_LINEAR     # loop every clip in the gallery
		ap.play("kb/" + clip)
		ap.seek(randf() * anim.length, true)        # desync so the grid isn't in lockstep

	var label := Label3D.new()
	label.text = clip
	label.position = pos + Vector3(0, 2.15, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.0045
	label.outline_size = 16
	label.modulate = Color(1, 0.95, 0.7)
	add_child(label)

# --- camera ----------------------------------------------------------------

func _setup_camera(rows: int) -> void:
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.rotation_degrees = Vector3(-28, 0, 0)
	_cam.position = Vector3((COLS - 1) * SPACING_X * 0.5, 5.0, 6.0)
	_cam.current = true
	add_child(_cam)

func _process(delta: float) -> void:
	if _cam == null:
		return
	var mv := Vector3.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		mv.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		mv.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		mv.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		mv.z += 1
	if Input.is_key_pressed(KEY_Q):
		mv.y -= 1
	if Input.is_key_pressed(KEY_E):
		mv.y += 1
	_cam.position += mv * _pan_speed * delta * clampf(_cam.position.y / 5.0, 0.5, 4.0)
	_cam.position.y = clampf(_cam.position.y, 1.5, 40.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.goto_scene("res://scenes/ui/MainMenu.tscn")

# --- scene setup -----------------------------------------------------------

func _add_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.1, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.65)
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	floor.mesh = pm
	floor.position = Vector3(0, 0, -120)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.16, 0.17, 0.22)
	floor.material_override = fmat
	add_child(floor)

func _build_ui(count: int) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.position = Vector2(24, 16)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	title.text = "ANIMATION GALLERY  -  %d clips" % count
	layer.add_child(title)
	var hint := Label.new()
	hint.position = Vector2(24, 56)
	hint.add_theme_font_size_override("font_size", 18)
	hint.text = "WASD / arrows: pan    Q / E: down / up    ESC: back to menu"
	layer.add_child(hint)

func _show_notice(text: String) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.position = Vector2(440, 320)
	l.add_theme_font_size_override("font_size", 26)
	l.text = text + "\n\nESC: back"
	layer.add_child(l)

# --- helpers ---------------------------------------------------------------

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)

func _find(node: Node, klass: String) -> Node:
	if node.is_class(klass):
		return node
	for c in node.get_children():
		var r := _find(c, klass)
		if r:
			return r
	return null
