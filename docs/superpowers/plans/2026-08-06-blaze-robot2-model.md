# Blaze Robot2 Model Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Blaze's Maskman mesh with the textured robot from `D:\uwork\AssetsSource\robot2_rigged.fbx` while retaining the exact Maskman armature and all existing Kubold animations.

**Architecture:** A task-local Blender script converts the source mesh onto an untouched duplicate of the canonical Maskman armature, transfers at most four normalized weights, embeds a 1024px texture, and exports one local gitignored FBX. Runtime changes only select the new FBX and preserve imported materials when a rig has no explicit texture overrides.

**Tech Stack:** Blender 5.2 Python API, bundled Blaze FBX validator, Godot 4.7 typed GDScript, existing headless test harness, Web export, Chrome DevTools.

## Global Constraints

- `characters\blaze\assets\maskman.fbx` is immutable and remains the compatibility authority.
- Discard the source robot rig, animation, Cube, Camera, and Light.
- Never rename, reparent, translate, rotate, scale, reroll, or edit canonical armature bones or the armature object.
- Export only one robot mesh and one armature, with no animation or leaf bones.
- Every vertex must have one through four finite Maskman-bone influences normalized to 1.0.
- Preserve the robot's original appearance; embed a 1024px version of its source texture.
- Combat simulation, hitboxes, AI, HUD, camera, and round behavior must not change.
- A machine pass without the required visual animation inspection is `unverified`, not `exact`.

---

### Task 1: Add Regression Coverage for the New Model Contract

**Files:**
- Modify: `tools/run_tests.gd`

**Interfaces:**
- Consumes: `Blaze.build()`, `AnimatedFighterRig.apply_materials(mesh, cfg, tint, flat)`
- Produces: regression checks for `robot2_blaze.fbx` selection and imported-material preservation

- [ ] **Step 1: Create an isolated feature worktree**

Use the `using-git-worktrees` skill, then copy the local ignored Blaze assets into it so
the canonical FBX and Kubold clips remain available:

```powershell
Copy-Item -Recurse -Force `
  "D:\uwork\FootisesGame3\characters\blaze\assets\*" `
  "D:\uwork\FootisesGame3\.worktrees\blaze-robot2-model\characters\blaze\assets\"
```

- [ ] **Step 2: Write the failing model-selection checks**

In `_test_blaze_roster()`, after creating Blaze, add:

```gdscript
_check("Blaze selects the Robot2 Maskman reskin",
	blaze.model_path == "res://characters/blaze/assets/robot2_blaze.fbx")
_check("Robot2 keeps its imported material",
	blaze.rig.surface_textures.is_empty()
	and blaze.rig.tex_dir == ""
	and blaze.rig.lod_keep == "LOD1")
```

- [ ] **Step 3: Write the failing imported-material behavior check**

In `_test_animated_rig()`, create a mesh with an authored material:

```gdscript
var imported_material := StandardMaterial3D.new()
imported_material.albedo_color = Color(0.2, 0.4, 0.8)
var imported_box := BoxMesh.new()
imported_box.material = imported_material
var imported_mesh := MeshInstance3D.new()
imported_mesh.mesh = imported_box
var imported_cfg := RigConfig.new()
imported_cfg.surface_textures = {}
AnimatedFighterRig.apply_materials(
	imported_mesh, imported_cfg, Color.RED, Color.ORANGE)
_check("empty texture mapping preserves the imported FBX material",
	imported_mesh.get_surface_override_material(0) == null
	and imported_mesh.mesh.surface_get_material(0) == imported_material)
imported_mesh.free()
```

- [ ] **Step 4: Run the full harness and verify RED**

Run:

```powershell
godot4.7 --headless --path . --script res://tools/run_tests.gd
```

Expected: the two Robot2 selection checks and imported-material check fail.

---

### Task 2: Select Robot2 and Preserve Its Imported Material

**Files:**
- Modify: `characters/blaze/blaze.gd`
- Modify: `scripts/fighter/AnimatedFighterRig.gd`
- Test: `tools/run_tests.gd`

**Interfaces:**
- Consumes: Task 1 checks
- Produces: Blaze model path `res://characters/blaze/assets/robot2_blaze.fbx`; empty surface mapping means "use the FBX material"

- [ ] **Step 1: Point Blaze at the converted model**

Change the build configuration to:

```gdscript
c.model_path = ASSETS + "robot2_blaze.fbx"
c.model_scale = 1.0
c.model_face_deg = 90.0
```

In `_rig()`, replace the Maskman texture settings with:

```gdscript
r.surface_textures = {}
r.tex_dir = ""
r.material_roughness = 0.7
r.lod_keep = "LOD1"
```

- [ ] **Step 2: Preserve imported materials when no overrides are configured**

At the start of `AnimatedFighterRig.apply_materials()` add:

```gdscript
if cfg.surface_textures.is_empty():
	return
```

This leaves existing Maskman behavior unchanged because its old configuration used a
non-empty mapping; Robot2 relies on its embedded FBX material.

- [ ] **Step 3: Run the harness and verify GREEN**

Run:

```powershell
godot4.7 --headless --path . --script res://tools/run_tests.gd
```

Expected: all tests pass; model-backed checks may still skip until Task 3 creates the
local FBX.

- [ ] **Step 4: Commit the runtime contract**

```powershell
git add characters\blaze\blaze.gd scripts\fighter\AnimatedFighterRig.gd tools\run_tests.gd
git commit -m "Select Blaze robot model"
```

Include the required Copilot co-author trailer.

---

### Task 3: Convert Robot2 onto the Exact Maskman Armature

**Files:**
- Create task-local: `C:\Users\yaohuiwang\.copilot\session-state\959a7977-c44e-4a2b-91d3-c289f3ff37aa\files\robot2_blaze\convert_robot2_to_blaze.py`
- Create local gitignored output: `characters/blaze/assets/robot2_blaze.fbx`

**Interfaces:**
- Consumes: source FBX, canonical Maskman FBX
- Produces: one candidate FBX containing `Armature` and `Robot2_LOD1`

- [ ] **Step 1: Record the source validator failure**

Run:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --factory-startup `
  --python ".github\skills\creating-blaze-compatible-models\scripts\validate_blaze_fbx.py" `
  -- --candidate "D:\uwork\AssetsSource\robot2_rigged.fbx"
```

Expected: failed armature count/order/names/rest checks, animation present, and vertices
with more than four influences.

- [ ] **Step 2: Implement the task-local converter**

The script must expose these exact functions:

```python
def import_fbx(path: Path) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Return the single imported armature and imported meshes."""

def target_bone_name(source_name: str) -> str | None:
    """Strip mixamorig:, map Spine2 to Spine1, and drop source end bones."""

def fit_mesh_to_target(
    mesh: bpy.types.Object,
    source_armature: bpy.types.Object,
    target_armature: bpy.types.Object,
) -> None:
    """Move vertices by weighted source-rest -> target-rest transforms."""

def remap_and_normalize_weights(
    mesh: bpy.types.Object,
    target_armature: bpy.types.Object,
) -> None:
    """Merge mapped groups, retain top four weights, normalize, and bind target."""

def preserve_robot_material(mesh: bpy.types.Object) -> None:
    """Keep the embedded source image, resize it to 1024px, and retain one material."""

def export_candidate(
    mesh: bpy.types.Object,
    armature: bpy.types.Object,
    output: Path,
) -> None:
    """Export only mesh + armature, embedded textures, no actions or leaf bones."""
```

For each vertex, calculate the fitted world position as:

```python
fitted = Vector((0.0, 0.0, 0.0))
total = 0.0
for source_bone_name, weight in source_weights:
    target_name = target_bone_name(source_bone_name)
    if target_name is None or target_name not in target_armature.data.bones:
        continue
    source_rest = (
        source_armature.matrix_world
        @ source_armature.data.bones[source_bone_name].matrix_local
    )
    target_rest = (
        target_armature.matrix_world
        @ target_armature.data.bones[target_name].matrix_local
    )
    fitted += weight * (target_rest @ source_rest.inverted() @ source_world_position)
    total += weight
vertex.co = mesh.matrix_world.inverted() @ (fitted / total)
```

After fitting, rebuild groups from source weights using `target_bone_name()`, sort each
vertex's influences by descending weight, keep four, and divide by their sum. Remove
all actions and NLA tracks. Do not modify the imported canonical armature.

Export with:

```python
bpy.ops.export_scene.fbx(
    filepath=str(output),
    use_selection=True,
    object_types={"ARMATURE", "MESH"},
    use_mesh_modifiers=True,
    add_leaf_bones=False,
    bake_anim=False,
    path_mode="COPY",
    embed_textures=True,
    axis_forward="-Z",
    axis_up="Y",
)
```

- [ ] **Step 3: Run the converter**

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --factory-startup `
  --python "C:\Users\yaohuiwang\.copilot\session-state\959a7977-c44e-4a2b-91d3-c289f3ff37aa\files\robot2_blaze\convert_robot2_to_blaze.py" `
  -- `
  --source "D:\uwork\AssetsSource\robot2_rigged.fbx" `
  --reference "characters\blaze\assets\maskman.fbx" `
  --output "characters\blaze\assets\robot2_blaze.fbx"
```

Expected: one mesh, one armature, no action, 24,968 vertices, and at most four weights
per vertex.

- [ ] **Step 4: Run the bundled validator**

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --factory-startup `
  --python ".github\skills\creating-blaze-compatible-models\scripts\validate_blaze_fbx.py" `
  -- --candidate "characters\blaze\assets\robot2_blaze.fbx"
```

Expected: `"passed": true` at the default `2e-5` tolerance.

If only serialization deltas fail, adjust FBX axis/unit export settings and rerun. Do
not alter bones, the armature object, or validator tolerance.

---

### Task 4: Import and Verify the Converted Model

**Files:**
- Generated local: `characters/blaze/assets/robot2_blaze.fbx.import`
- Modify only if required by observed import behavior: `characters/blaze/blaze.gd`

**Interfaces:**
- Consumes: validator-passing candidate FBX
- Produces: Godot-importable Robot2 Blaze using the existing `AnimatedFighterRig`

- [ ] **Step 1: Refresh Godot's import cache**

```powershell
godot4.7 --headless --path . --import
```

Expected: `robot2_blaze.fbx` imports as a `PackedScene` without errors.

- [ ] **Step 2: Run the full suite**

```powershell
godot4.7 --headless --path . --script res://tools/run_tests.gd
```

Expected: all tests pass and model-backed Blaze rig checks run instead of skipping.

- [ ] **Step 3: Export Web**

```powershell
godot4.7 --headless --export-release "Web" web-build\index.html --path .
```

Expected: exit code 0; the embedded 1024px texture is included without external-file
load errors.

- [ ] **Step 4: Commit any import-driven runtime correction**

Only if Godot proves scale, facing, or mesh selection differs from the canonical
expectation, make the smallest data correction in `characters/blaze/blaze.gd`, rerun
the validator and suite, then commit that correction.

---

### Task 5: Visual Gate, Review, and Integration

**Files:**
- Local validated asset: `characters/blaze/assets/robot2_blaze.fbx`
- Review diff: branch base through current HEAD

**Interfaces:**
- Consumes: imported candidate and Web build
- Produces: `exact` or `unverified` verdict and merged main checkout

- [ ] **Step 1: Serve the Web build**

```powershell
python tools\serve.py
```

- [ ] **Step 2: Inspect the required animation set**

Open `http://localhost:8090/testblaze` and
`http://localhost:8090/testfightinganimsetpro`. Inspect:

```text
idle
walk forward / backward
crouch
jump
representative punch
representative kick
hit reaction
knockdown
get-up
```

Check shoulders, hips, fingers, feet, armor intersections, grounding, facing, and
texture integrity. Record screenshots in the session folder.

- [ ] **Step 3: Assign the verdict**

```text
validator pass + every visual clip passes = exact
validator fail or missing/failed visual evidence = unverified
```

- [ ] **Step 4: Request code review**

Review all committed code/config changes plus the validator report. Fix every Critical
or Important issue and rerun the full suite.

- [ ] **Step 5: Merge and preserve the ignored asset**

Before removing the worktree, copy the validated FBX into main:

```powershell
Copy-Item -Force `
  "D:\uwork\FootisesGame3\.worktrees\blaze-robot2-model\characters\blaze\assets\robot2_blaze.fbx" `
  "D:\uwork\FootisesGame3\characters\blaze\assets\robot2_blaze.fbx"
```

Compare SHA-256 hashes, fast-forward the feature branch into `main`, rerun the full
suite and Web export on `main`, then remove the worktree and feature branch.
