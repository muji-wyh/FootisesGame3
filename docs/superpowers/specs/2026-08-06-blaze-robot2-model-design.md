# Blaze Robot2 Model Replacement Design

## Goal

Replace Blaze's visible Maskman mesh with `D:\uwork\AssetsSource\robot2_rigged.fbx`
while keeping Blaze's existing Kubold animation set and combat behavior unchanged.

The final runtime model must use the exact armature from
`characters\blaze\assets\maskman.fbx`. The source robot rig and animation are inputs
for fitting and weight transfer only; they must not ship.

## Source Findings

- `robot2_rigged.fbx` contains one 24,968-vertex / 50,008-triangle robot mesh.
- It uses a 65-bone `mixamorig:*` armature and includes one animation action.
- Some vertices have five or six influences.
- Its 4096px PBR texture is embedded in the FBX.
- It also contains unrelated default Cube, Camera, and Light objects.
- The canonical Maskman armature has 85 bones, different hierarchy/rest data, and is
  the compatibility authority for the existing `KB_*.fbx` clips.

The source therefore cannot be used directly or made compatible by renaming bones.

## Approaches Considered

### 1. Exact Maskman reskin (selected)

Import both FBXs in Blender, keep the robot mesh/material, discard its rig and
animation, fit the mesh to an untouched duplicate of Maskman's bind pose, transfer
weights, and export the robot mesh with the canonical armature.

This is the only approach that can pass the repository's exact validator and retain
the current animation pipeline.

### 2. Use the robot's Mixamo armature

Rejected. Bone names, count, hierarchy, rest transforms, animation, and weight limits
all violate the Maskman contract. Godot animation grafting would remain unreliable.

### 3. Runtime humanoid retargeting

Rejected. It adds import-time configuration and runtime uncertainty, still does not
meet the exact Maskman contract, and is unnecessary for one replacement model.

## Conversion

1. Import the source robot and canonical Maskman FBXs with Blender 5.2.
2. Delete the source Cube, Camera, Light, action, and armature after reading its bind
   matrices and weights.
3. Duplicate Maskman's armature without changing its object transform, bones, order,
   names, parents, heads, tails, rolls, or rest matrices.
4. Fit each robot vertex from the source bind pose into the target bind pose using
   its weighted source-bone-to-Maskman-bone rest transforms.
   - Strip the `mixamorig:` prefix for shared humanoid and finger bones.
   - Map the source's extra `Spine2` contribution into Maskman's `Spine1`.
   - Ignore unweighted source end bones.
5. Transfer weights to Maskman bone groups, keep the four strongest nonzero
   influences, and normalize each vertex to exactly 1.0.
6. Preserve the robot material and embedded texture, downscaled to 1024px for the Web
   target.
7. Name the single mesh `Robot2_LOD1`.
8. Export only `Robot2_LOD1` and the duplicated `Armature` to
   `characters\blaze\assets\robot2_blaze.fbx`, with no animation or leaf bones.

The conversion script is task-local; the reusable authority remains the bundled
validator rather than a second validation implementation.

## Runtime Wiring

- Change Blaze's `model_path` to `robot2_blaze.fbx`.
- Keep `model_scale = 1.0` and `model_face_deg = 90.0` unless visual inspection proves
  the canonical export needs a model-only adjustment.
- Keep `lod_keep = "LOD1"` so the generic rig selects `Robot2_LOD1`.
- Set Blaze's surface texture mapping empty for the robot model.
- When a rig config has no explicit surface mapping, preserve the FBX's imported
  material instead of replacing it with Blaze's flat fallback color. Existing
  Maskman behavior remains unchanged because its mapping is non-empty.

The FBX remains gitignored like the existing licensed Blaze assets. A clean clone
continues to use the procedural rig fallback when the local robot FBX is absent.

## Validation

### Automated

1. Add a regression check for Blaze's new model path and imported-material policy.
2. Run the bundled validator:

   ```powershell
   & "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
     --background `
     --python ".github\skills\creating-blaze-compatible-models\scripts\validate_blaze_fbx.py" `
     -- --candidate "characters\blaze\assets\robot2_blaze.fbx"
   ```

3. Refresh Godot imports.
4. Run the full headless suite.
5. Export the Web build.

### Visual

Inspect the robot in the running game with:

- idle and forward/back movement
- crouch
- jump
- representative punch and kick attacks
- hit reactions
- knockdown
- get-up

Check shoulders, hips, fingers, feet, armor intersections, grounding, facing, and
texture integrity. A machine-validator pass without these visual checks is
`unverified`, not `exact`.

## Success Criteria

- Blaze displays the robot model with its original material and texture.
- Existing Kubold clips animate the robot without visible deformation failures.
- Combat timing, hitboxes, AI, camera, HUD, and round logic are unchanged.
- The bundled machine validator passes at its default tolerance.
- The required visual clip set passes.

## Rollback

If conversion or visual validation fails, leave `robot2_blaze.fbx` unselected and
restore Blaze's `model_path`, surface mapping, and LOD setting to the current Maskman
values.
