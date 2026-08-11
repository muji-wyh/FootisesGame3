# Drax Character Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Drax as a playable Blaze gameplay clone using an exact Maskman-compatible conversion of the supplied FBX, and display Drax in `GALLERY-AIGeneratedAnimations`.

**Architecture:** Reuse the existing task-local Robot2-to-Maskman converter, extending it only to ignore Drax's unweighted cube and select the main skinned mesh. Runtime wiring follows the Ultron module: clone Blaze data, replace identity/model fields, preserve the embedded PBR material, register the character, and point the existing 48-clip gallery at the same exact skeleton.

**Tech Stack:** Godot 4.7, typed GDScript, Blender 5.2 Python API, FBX 7.4, Chrome/WebAssembly

## Global Constraints

- Use `C:\uworks\editing_assets\robot2\bak4\Drax.fbx` as the Drax source.
- Keep Blaze's moves, stats, animation maps, and rig configuration unchanged.
- Replace only Drax's `id`, `display_name`, and `model_path`; set `preserve_materials = true`.
- The final FBX must contain only one Drax mesh and the immutable armature from `characters\blaze\assets\maskman.fbx`.
- Do not ship source actions, cameras, lights, the unweighted cube, runtime retargeting, or leaf bones.
- Every skinned vertex must retain one through four normalized influences.
- Embed a Web-friendly 1024px base-color, metallic, roughness, and normal texture set.
- Keep `characters\drax\assets\drax.fbx` and its imported texture artifacts gitignored.
- Keep all 48 AI-generated clips, `/testaigeneratedanimations`, and the existing gallery layout unchanged.
- A validator pass alone is `unverified`; Drax must also deform correctly in the gallery and a match.

## File Map

- Task-local converter: selects and converts Drax's main skinned mesh.
- `characters\drax\drax.gd`: exposes Drax identity while reusing Blaze gameplay.
- `scripts\data\CharacterLibrary.gd`: registers Drax in the playable roster.
- `tools\run_tests.gd`: locks roster, gameplay parity, rig, material, and gallery behavior.
- `scenes\ui\GALLERY-AIGeneratedAnimations.tscn`: selects Drax as the display model.
- `assets\ai_generated_animations\manifest.json`: records Drax as the current display target.
- Existing Gallery scripts and copied animation assets remain the implementation from the preceding Gallery task.

---

### Task 1: Convert Drax onto the Exact Maskman Armature

**Files:**
- Modify task-local: `C:\Users\yaohuiwang\.copilot\session-state\9266f7cb-050c-4f96-ae6e-afb6fe0f5bb5\files\test_robot2_converter.py`
- Modify task-local: `C:\Users\yaohuiwang\.copilot\session-state\9266f7cb-050c-4f96-ae6e-afb6fe0f5bb5\files\convert_robot2_to_blaze.py`
- Create task-local: `C:\Users\yaohuiwang\.copilot\session-state\9266f7cb-050c-4f96-ae6e-afb6fe0f5bb5\files\drax_conversion\report.json`
- Create local gitignored: `characters\drax\assets\drax.fbx`

**Interfaces:**
- Consumes: Drax's Mixamo armature, skinned `node_0` mesh, four PBR textures, and canonical Maskman FBX.
- Produces: `choose_character_mesh(meshes) -> bpy.types.Object` and one validator-passing 85-bone Drax FBX.

- [ ] **Step 1: Add the failing main-mesh selection test**

Add this import and test to `test_robot2_converter.py`:

```python
from types import SimpleNamespace


def fake_mesh(vertex_count: int, group_count: int):
    return SimpleNamespace(
        data=SimpleNamespace(vertices=[None] * vertex_count),
        vertex_groups=[None] * group_count,
    )


cube = fake_mesh(8, 0)
drax = fake_mesh(24968, 52)
assert module.choose_character_mesh([cube, drax]) is drax
```

- [ ] **Step 2: Run the converter unit checks to verify the new test fails**

Run:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --factory-startup --python-exit-code 1 `
  --python "C:\Users\yaohuiwang\.copilot\session-state\9266f7cb-050c-4f96-ae6e-afb6fe0f5bb5\files\test_robot2_converter.py"
```

Expected: non-zero exit with `AttributeError` because `choose_character_mesh` does not exist.

- [ ] **Step 3: Implement skinned main-mesh selection**

Add this function after `import_fbx()` in `convert_robot2_to_blaze.py`:

```python
def choose_character_mesh(meshes: list[bpy.types.Object]) -> bpy.types.Object:
    rigged = [mesh for mesh in meshes if len(mesh.vertex_groups) > 0]
    if not rigged:
        raise RuntimeError("source contains no skinned character mesh")
    return max(rigged, key=lambda mesh: len(mesh.data.vertices))
```

Replace the source-mesh count check in `main()`:

```python
source_armature, source_meshes, source_objects = import_fbx(args.source)
source_mesh = choose_character_mesh(source_meshes)
weights = source_vertex_weights(source_mesh)
```

Do not change bone mapping, vertex fitting, four-weight normalization, the Blender 5.2 light-import patch, material construction, or canonical-armature export.

- [ ] **Step 4: Run the converter unit checks**

Run:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --factory-startup --python-exit-code 1 `
  --python "C:\Users\yaohuiwang\.copilot\session-state\9266f7cb-050c-4f96-ae6e-afb6fe0f5bb5\files\test_robot2_converter.py"
```

Expected: exit code 0 and `robot2 converter mapping checks passed`.

- [ ] **Step 5: Convert Drax and embed its 1024px PBR textures**

Run:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --factory-startup --python-exit-code 1 `
  --python "C:\Users\yaohuiwang\.copilot\session-state\9266f7cb-050c-4f96-ae6e-afb6fe0f5bb5\files\convert_robot2_to_blaze.py" `
  -- `
  --source "C:\uworks\editing_assets\robot2\bak4\Drax.fbx" `
  --reference "characters\blaze\assets\maskman.fbx" `
  --texture-dir "C:\uworks\editing_assets\robot2\bak4" `
  --work-dir "C:\Users\yaohuiwang\.copilot\session-state\9266f7cb-050c-4f96-ae6e-afb6fe0f5bb5\files\drax_conversion\textures_1024" `
  --output "characters\drax\assets\drax.fbx" `
  --report "C:\Users\yaohuiwang\.copilot\session-state\9266f7cb-050c-4f96-ae6e-afb6fe0f5bb5\files\drax_conversion\report.json"
```

Expected report:

```json
{
  "vertices": 24968,
  "triangles": 50008,
  "armature": "Armature",
  "bones": 85,
  "mesh": "Robot2_LOD1",
  "weights": {
    "max_influences": 4
  },
  "textures": "1024px PBR embedded"
}
```

The report may include additional `used_bones`, `dropped_source_weight`, and absolute-path fields.

- [ ] **Step 6: Validate exact armature and skinning compatibility**

Run:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --factory-startup --python-exit-code 1 `
  --python ".github\skills\creating-blaze-compatible-models\scripts\validate_blaze_fbx.py" `
  -- --candidate "characters\drax\assets\drax.fbx"
```

Expected: JSON result with `"passed": true` at the validator's default `2e-5` serialization tolerance. Do not raise the tolerance or modify the canonical armature to obtain a pass.

- [ ] **Step 7: Confirm the local model remains untracked**

Run:

```powershell
git check-ignore -v characters\drax\assets\drax.fbx
```

Expected: the `characters/**/assets/**/*.fbx` rule from `.gitignore`. There is no git commit for this task because the converter, report, textures, and FBX are task-local or intentionally gitignored.

---

### Task 2: Register Drax and Switch the AI Animation Gallery

**Files:**
- Create: `characters\drax\drax.gd`
- Generated: `characters\drax\drax.gd.uid`
- Modify: `scripts\data\CharacterLibrary.gd`
- Modify: `tools\run_tests.gd`
- Modify: `scenes\ui\GALLERY-AIGeneratedAnimations.tscn`
- Modify: `assets\ai_generated_animations\manifest.json`
- Include existing Gallery work: `scripts\ui\AnimationGallery.gd`
- Include existing Gallery work: `scripts\ui\AnimationGallery2.gd`
- Include existing Gallery work: `scripts\ui\Main.gd`
- Include existing Gallery work: `scripts\ui\MainMenu.gd`
- Include existing Gallery work: `assets\ai_generated_animations\fbx\*.fbx`
- Include generated Gallery imports: `assets\ai_generated_animations\fbx\*.fbx.import`

**Interfaces:**
- Consumes: `BLAZE.build() -> CharacterData`, validator-passing `drax.fbx`, and the existing 48-clip gallery.
- Produces: `CharacterLibrary.create("drax") -> CharacterData` and a Drax-backed `/testaigeneratedanimations` scene.

- [ ] **Step 1: Write failing Drax runtime and gallery checks**

In `_initialize()`, add:

```gdscript
_test_drax_roster()
_test_drax_animated_rig()
```

Place the roster call after `_test_ultron_roster()` and the rig call after `_test_ultron_animated_rig()`.

Change the Blaze roster assertion to:

```gdscript
_check("roster is exactly [blaze, drax, ultron]",
    CharacterLibrary.ids() == ["blaze", "drax", "ultron"])
```

Add:

```gdscript
func _test_drax_roster() -> void:
    print("[drax roster]")
    _check("drax is registered",
        CharacterLibrary.ids() == ["blaze", "drax", "ultron"])
    _check("drax display name is registered",
        CharacterLibrary.display_name("drax") == "Drax")
    var blaze := CharacterLibrary.create("blaze")
    var drax := CharacterLibrary.create("drax")
    _check("drax has its own identity",
        drax.id == "drax" and drax.display_name == "Drax")
    _check("drax uses its own model",
        drax.model_path == "res://characters/drax/assets/drax.fbx")
    _check("drax copies Blaze gameplay",
        drax.max_health == blaze.max_health
        and drax.walk_speed == blaze.walk_speed
        and _same_string_set(drax.moves.keys(), blaze.moves.keys()))
    _check("drax preserves its embedded materials",
        drax.rig != null and drax.rig.get("preserve_materials") == true)

func _test_drax_animated_rig() -> void:
    print("[drax animated rig]")
    var drax := CharacterLibrary.create("drax")
    if not ResourceLoader.exists(drax.model_path):
        print("  SKIP: Drax model asset not present (clean clone)")
        return
    var rig := AnimatedFighterRig.new()
    root.add_child(rig)
    rig.build(drax)
    var mesh := AnimatedFighterRig._find(
        rig._model, "MeshInstance3D"
    ) as MeshInstance3D
    var material := (
        mesh.get_active_material(0) as StandardMaterial3D if mesh else null
    )
    _check("drax real FBX builds with Blaze animations",
        drax.model_path == "res://characters/drax/assets/drax.fbx"
        and rig.ok
        and rig._skel != null
        and rig._skel.get_bone_count() == 85
        and rig._player.has_animation("kb/KB_Idle_1"))
    _check("drax real FBX keeps its embedded PBR material",
        material != null and material.albedo_texture != null)
    rig.queue_free()
```

Update the AI gallery assertions to require:

```gdscript
String(gallery.get("display_model_path")) \
    == "res://characters/drax/assets/drax.fbx"
String(manifest.get("retargeted_for", "")) == "drax"
```

Rename assertion text that says `Ultron` to `Drax`, including the material/settings,
display-model, and normalized-skeleton checks.

- [ ] **Step 2: Run the suite to verify the new checks fail**

Run:

```powershell
godot4.7 --headless --path . --script res://tools/run_tests.gd
```

Expected: non-zero exit with failures for Drax roster identity/path and AI gallery Drax path/metadata. Existing Blaze, Ultron, combat, and 48-clip checks must continue to pass.

- [ ] **Step 3: Add the minimal Drax module and wiring**

Create `characters\drax\drax.gd`:

```gdscript
extends RefCounted

const ID := "drax"
const DISPLAY_NAME := "Drax"
const MODEL := "res://characters/drax/assets/drax.fbx"
const BLAZE := preload("res://characters/blaze/blaze.gd")

static func build() -> CharacterData:
    var character := BLAZE.build()
    character.id = ID
    character.display_name = DISPLAY_NAME
    character.model_path = MODEL
    character.rig.preserve_materials = true
    return character
```

Set `CharacterLibrary.REGISTRY` to:

```gdscript
const REGISTRY := {
    "blaze": preload("res://characters/blaze/blaze.gd"),
    "drax": preload("res://characters/drax/drax.gd"),
    "ultron": preload("res://characters/ultron/ultron.gd"),
}
```

In `GALLERY-AIGeneratedAnimations.tscn`, set:

```gdscript
display_model_path = "res://characters/drax/assets/drax.fbx"
```

In `manifest.json`, set:

```json
"retargeted_for": "drax"
```

Do not change gallery columns, spacing, clip loading, track normalization, grounding, or material-preservation logic.

- [ ] **Step 4: Refresh Godot's import cache**

Run:

```powershell
godot4.7 --headless --path . --import
```

Expected: Drax's FBX imports as a `PackedScene`, `characters\drax\drax.gd.uid` is generated, and there are no GDScript parse or resource errors.

- [ ] **Step 5: Run the complete headless suite**

Run:

```powershell
godot4.7 --headless --path . --script res://tools/run_tests.gd
```

Expected: `=== Results: 809 passed, 0 failed ===`.

- [ ] **Step 6: Commit the complete Drax and AI Gallery feature**

Run:

```powershell
git add -- `
  characters\drax\drax.gd `
  characters\drax\drax.gd.uid `
  scripts\data\CharacterLibrary.gd `
  scripts\ui\AnimationGallery.gd `
  scripts\ui\AnimationGallery2.gd `
  scripts\ui\Main.gd `
  scripts\ui\MainMenu.gd `
  tools\run_tests.gd `
  scenes\ui\GALLERY-AIGeneratedAnimations.tscn `
  assets\ai_generated_animations

git commit `
  -m "Add Drax character and animation gallery" `
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: the tracked character module, Gallery code, manifest, 48 FBXs, and their Godot import sidecars are committed. `characters\drax\assets\drax.fbx` is not staged.

---

### Task 3: Verify Drax in Web Gallery and Combat

**Files:**
- Generated local: `web-build\index.html`
- Optional evidence: `C:\Users\yaohuiwang\.copilot\session-state\9266f7cb-050c-4f96-ae6e-afb6fe0f5bb5\files\drax_gallery.png`
- Optional evidence: `C:\Users\yaohuiwang\.copilot\session-state\9266f7cb-050c-4f96-ae6e-afb6fe0f5bb5\files\drax_match.png`

**Interfaces:**
- Consumes: committed Drax runtime, imported local Drax FBX, and Web export.
- Produces: visual deformation evidence for all gallery categories and a playable Drax match.

- [ ] **Step 1: Export the Web build**

Run:

```powershell
godot4.7 --headless --export-release "Web" web-build\index.html --path .
```

Expected: exit code 0 with `web-build\index.html`, `.wasm`, and `.pck` regenerated.

- [ ] **Step 2: Serve the Web build**

Start `python tools\serve.py` as a detached/background process from the repository root.

Expected: `http://localhost:8090/` responds with HTTP 200 and the server remains running during browser checks.

- [ ] **Step 3: Inspect the Drax AI animation gallery**

Open `http://localhost:8090/testaigeneratedanimations` in Chrome DevTools.

Expected:

- 48 Drax instances appear in the existing 8-column layout.
- Movement, crouch, attack, signature, hit, knockdown, and get-up clips visibly deform Drax.
- Feet remain near the ground for grounded clips.
- The model is upright, textured, and not replaced by the procedural fallback.
- Shoulders, hips, fingers, feet, and armor do not show catastrophic stretching or detached geometry.

Capture `drax_gallery.png` after the full grid is visible.

- [ ] **Step 4: Inspect Drax in a training match**

Open `http://localhost:8090/`, focus the Godot canvas, and use keyboard focus:

1. Press `ArrowDown` twice and `Enter` to open Training.
2. Press `Shift+Tab` twice, then `Enter`, to change Player 1 from Blaze to Drax.
3. Press `Tab` twice, then `Enter`, to start Drax versus Drax.
4. Use `A/D`, `S`, `W`, `U/I/O`, and `J/K/L` to inspect movement, crouch, jump, punches, and kicks.

Expected: both fighters use the Drax model and Blaze gameplay without bind-pose snaps, missing materials, severe joint deformation, floating, or facing errors.

Capture `drax_match.png` while Drax is performing an attack.

- [ ] **Step 5: Check browser health**

In Chrome DevTools:

- List console messages and require no errors.
- List document, script, WebAssembly, pack, FBX, and texture requests and require HTTP 200 responses.
- Confirm no request references `characters/ultron/assets/ultron.fbx` while the AI gallery is open.

If visual deformation fails, return to Task 1's vertex fitting/weight mapping. If only runtime selection or materials fail, return to Task 2. Do not call the model `exact` until both the bundled validator and these visual checks pass.

- [ ] **Step 6: Confirm repository state**

Run:

```powershell
git --no-pager status --short
git --no-pager log -3 --oneline
```

Expected: no tracked working-tree changes and commits for the Drax design, implementation plan, and Drax/Gallery implementation. The local Drax FBX remains hidden by `.gitignore`.
