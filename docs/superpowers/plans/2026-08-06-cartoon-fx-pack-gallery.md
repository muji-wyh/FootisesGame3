# CartoonFXPack Gallery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a home-menu and `/testcartoonfxpack` gallery for all 22 CartoonFXPack textures.

**Architecture:** Create one texture-specific gallery script that subclasses the existing gallery camera/UI. It enumerates PNG resources, renders labeled additive billboard quads, and uses the existing menu and boot-link patterns for navigation.

**Tech Stack:** Godot 4.7, typed GDScript, existing headless test harness.

## Global Constraints

- Display the 22 PNG resources under `res://assets/cartoon_fx_pack/textures`.
- Preserve texture aspect ratios.
- Use unshaded, additive, transparent, emissive, depth-independent billboard materials.
- Support path, hash, and query forms of `testcartoonfxpack`.
- Leave match mode and character selection untouched.
- Do not add particle authoring, debris mesh previews, a route table, or changes to the existing VFXImpactAndHit gallery.

---

### Task 1: Add the CartoonFXPack gallery and navigation

**Files:**
- Create: `scripts/ui/CartoonFXGallery.gd`
- Create: `scenes/ui/GALLERY-CartoonFXPack.tscn`
- Modify: `scripts/ui/MainMenu.gd:61-66`
- Modify: `scripts/ui/Main.gd:9-33`
- Modify: `tools/run_tests.gd:1150-1195,1263-1425`

**Interfaces:**
- Consumes: inherited `AnimationGallery._add_environment()`, `_setup_camera(rows: int)`, `_build_ui(count: int)`, and `_show_notice(text: String)`
- Produces: `CartoonFXGallery._texture_paths() -> Array[String]`
- Produces: `CartoonFXGallery._paths_from_files(file_names: PackedStringArray) -> Array[String]`
- Produces: `CartoonFXGallery._spawn_texture(path: String, pos: Vector3) -> MeshInstance3D`
- Produces: `Main.apply_boot_link()` recognition of `testcartoonfxpack`

- [ ] **Step 1: Write failing gallery and navigation tests**

Add deep-link coverage to `_test_boot_deep_link()`:

```gdscript
	for url in ["http://localhost:8090/testcartoonfxpack",
			"http://localhost:8090/#testcartoonfxpack",
			"http://localhost:8090/?testcartoonfxpack"]:
		game.set("mode", GameConst.Mode.LOCAL_2P)
		game.set("p1_char_id", "")
		game.set("p2_char_id", "")
		_check("%s boots the CartoonFXPack gallery" % url,
			main.apply_boot_link(url) == "res://scenes/ui/GALLERY-CartoonFXPack.tscn")
		_check("%s leaves the match config untouched" % url,
			int(game.get("mode")) == GameConst.Mode.LOCAL_2P
			and String(game.get("p1_char_id")) == ""
			and String(game.get("p2_char_id")) == "")
```

Extend `_test_vfx_gallery()`:

```gdscript
	var cartoon_scene_path := "res://scenes/ui/GALLERY-CartoonFXPack.tscn"
	_check("CartoonFXPack gallery scene exists", ResourceLoader.exists(cartoon_scene_path))
	_check("main menu links CartoonFXPack gallery", menu_source.contains(cartoon_scene_path))
	if ResourceLoader.exists(cartoon_scene_path):
		var cartoon_gallery := (load(cartoon_scene_path) as PackedScene).instantiate()
		var texture_root := "res://assets/cartoon_fx_pack/textures"
		var exported_textures: Array[String] = cartoon_gallery._paths_from_files(
			PackedStringArray([
				"Effect01.png.import",
				"Medium01.png.remap",
				"Thin01.png",
				"ignore.txt",
			]))
		_check("CartoonFXPack gallery maps exported listings back to PNG resources",
			exported_textures == [
				texture_root + "/Effect01.png",
				texture_root + "/Medium01.png",
				texture_root + "/Thin01.png",
			])
		var texture_paths: Array[String] = cartoon_gallery._texture_paths()
		_check("CartoonFXPack gallery imports all 22 textures", texture_paths.size() == 22)
		var textures_load := true
		for path in texture_paths:
			textures_load = textures_load and load(path) is Texture2D
		_check("CartoonFXPack gallery textures load", textures_load)
		var preview: MeshInstance3D = cartoon_gallery._spawn_texture(
			texture_root + "/Effect02.png", Vector3.ZERO)
		var material := preview.material_override as StandardMaterial3D
		var quad := preview.mesh as QuadMesh
		_check("CartoonFXPack gallery builds readable billboard previews",
			preview != null and material != null and quad != null
			and quad.size.x > quad.size.y
			and material.albedo_texture != null
			and material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD
			and material.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED
			and material.no_depth_test)
		cartoon_gallery.free()
```

- [ ] **Step 2: Run the suite and verify RED**

Run:

```powershell
godot4.7 --headless --path . --log-file .godot\cartoonfx-gallery-red.log --script res://tools/run_tests.gd
```

Expected: CartoonFXPack scene, menu, and deep-link checks fail because the gallery does not exist.

- [ ] **Step 3: Create the gallery script**

Create `scripts/ui/CartoonFXGallery.gd`:

```gdscript
extends "res://scripts/ui/AnimationGallery.gd"

const TEXTURE_ROOT := "res://assets/cartoon_fx_pack/textures"
const PREVIEW_LONG_SIDE := 1.6

func _ready() -> void:
	_gallery_title = "GALLERY-CartoonFXPack"
	_add_environment()
	var paths := _texture_paths()
	if paths.is_empty():
		_show_notice("CartoonFXPack textures not installed.")
		return
	var rows := int(ceil(float(paths.size()) / COLS))
	for i in range(paths.size()):
		var col := i % COLS
		var row := i / COLS
		_spawn_texture(paths[i], Vector3(col * SPACING_X, 1.0, -row * SPACING_Z))
	_setup_camera(rows)
	_build_ui(paths.size())

func _texture_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(TEXTURE_ROOT)
	return paths if dir == null else _paths_from_files(dir.get_files())

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
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.no_depth_test = true
	material.albedo_texture = texture
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	preview.material_override = material
	add_child(preview)
	var label := Label3D.new()
	label.text = path.get_file().get_basename()
	label.position = pos + Vector3(0, 1.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.pixel_size = 0.0016
	label.outline_size = 6
	label.modulate = Color(1, 0.95, 0.7)
	add_child(label)
	return preview
```

- [ ] **Step 4: Create the gallery scene**

Create `scenes/ui/GALLERY-CartoonFXPack.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/CartoonFXGallery.gd" id="1"]

[node name="GALLERY-CartoonFXPack" type="Node3D"]
script = ExtResource("1")
```

- [ ] **Step 5: Add menu and deep-link navigation**

Add this button after `GALLERY-VFXImpactAndHit` in `MainMenu.gd`:

```gdscript
	var b_gallery5 := _button("GALLERY-CartoonFXPack")
	b_gallery5.pressed.connect(func(): Game.goto_scene("res://scenes/ui/GALLERY-CartoonFXPack.tscn"))
	vb.add_child(b_gallery5)
```

Add these constants in `Main.gd`:

```gdscript
const CARTOON_FX_PACK_LINK := "testcartoonfxpack"
const CARTOON_FX_PACK_SCENE := "res://scenes/ui/GALLERY-CartoonFXPack.tscn"
```

Add this check before the `TESTBLAZE_LINK` fallback:

```gdscript
	if url.contains(CARTOON_FX_PACK_LINK):
		return CARTOON_FX_PACK_SCENE
```

- [ ] **Step 6: Run the full suite**

Run:

```powershell
godot4.7 --headless --path . --log-file .godot\cartoonfx-gallery-green.log --script res://tools/run_tests.gd
```

Expected: the final `=== Results` line reports zero failures, including the 720p menu-fit check.

- [ ] **Step 7: Verify Web presentation**

Run:

```powershell
godot4.7 --headless --export-release "Web" web-build\index.html --path .
python tools\serve.py
```

Open `http://localhost:8090/` and confirm the `GALLERY-CartoonFXPack` button is visible. Open
`http://localhost:8090/testcartoonfxpack` and confirm the 22 labeled previews render with no
console or network errors.

- [ ] **Step 8: Commit**

```powershell
git add scripts\ui\CartoonFXGallery.gd scenes\ui\GALLERY-CartoonFXPack.tscn scripts\ui\MainMenu.gd scripts\ui\Main.gd tools\run_tests.gd
git commit -m "Add CartoonFXPack gallery"
```
